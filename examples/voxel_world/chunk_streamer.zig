const std = @import("std");
const voxel = @import("voxel.zig");

pub const Job = struct {
    coord: voxel.ChunkCoord,
    ticket: u64,
    seed: u32,
};

pub const Result = struct {
    coord: voxel.ChunkCoord,
    ticket: u64,
    mesh_nanoseconds: u64,
    outcome: union(enum) {
        mesh: voxel.Mesh,
        failure: anyerror,
    },

    pub fn deinit(self: *Result, allocator: std.mem.Allocator) void {
        switch (self.outcome) {
            .mesh => |*mesh| mesh.deinit(allocator),
            .failure => {},
        }
        self.* = undefined;
    }
};

/// A one-worker, one-result CPU meshing pipeline. GPU objects deliberately
/// remain on the render thread; the fixed capacity keeps memory bounded and
/// makes the worker naturally follow the render-thread upload rate.
pub const Streamer = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    mutex: std.Io.Mutex = .init,
    job_available: std.Io.Condition = .init,
    result_available: std.Io.Condition = .init,
    job: ?Job = null,
    result: ?Result = null,
    busy: bool = false,
    stopping: bool = false,
    thread: ?std.Thread = null,

    pub fn init(allocator: std.mem.Allocator, io: std.Io) Streamer {
        return .{ .allocator = allocator, .io = io };
    }

    /// Call only after the Streamer has reached its final memory address.
    pub fn start(self: *Streamer) std.Thread.SpawnError!void {
        std.debug.assert(self.thread == null);
        self.thread = try std.Thread.spawn(.{}, workerMain, .{self});
    }

    pub fn isStarted(self: *const Streamer) bool {
        return self.thread != null;
    }

    pub fn isBusy(self: *Streamer) bool {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        return self.busy;
    }

    /// Non-blocking submission. Exactly one job may be queued, executing, or
    /// awaiting collection at a time.
    pub fn submit(self: *Streamer, job: Job) bool {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        if (self.stopping or self.busy or self.thread == null) return false;
        self.job = job;
        self.busy = true;
        self.job_available.signal(self.io);
        return true;
    }

    /// Collects a completed mesh. Validation runs may wait so their finite
    /// frame limits remain deterministic; interactive runs pass `false` and
    /// never wait for CPU meshing on the render thread.
    pub fn take(self: *Streamer, wait: bool) ?Result {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        if (wait) {
            while (self.result == null and self.busy and !self.stopping) {
                self.result_available.waitUncancelable(self.io, &self.mutex);
            }
        }
        const result = self.result orelse return null;
        self.result = null;
        self.busy = false;
        return result;
    }

    pub fn deinit(self: *Streamer) void {
        if (self.thread) |thread| {
            self.mutex.lockUncancelable(self.io);
            self.stopping = true;
            self.job_available.broadcast(self.io);
            self.result_available.broadcast(self.io);
            self.mutex.unlock(self.io);
            thread.join();
            self.thread = null;
        }
        if (self.result) |*result| result.deinit(self.allocator);
        self.result = null;
        self.job = null;
        self.busy = false;
    }

    fn workerMain(self: *Streamer) void {
        while (true) {
            self.mutex.lockUncancelable(self.io);
            while (self.job == null and !self.stopping) {
                self.job_available.waitUncancelable(self.io, &self.mutex);
            }
            if (self.stopping) {
                self.mutex.unlock(self.io);
                return;
            }
            const job = self.job.?;
            self.job = null;
            self.mutex.unlock(self.io);

            const started = std.Io.Clock.awake.now(self.io);
            const outcome: @FieldType(Result, "outcome") = if (voxel.meshTerrainChunk(
                self.allocator,
                job.coord,
                job.seed,
            )) |mesh|
                .{ .mesh = mesh }
            else |err|
                .{ .failure = err };
            const elapsed = started.durationTo(std.Io.Clock.awake.now(self.io)).nanoseconds;
            var result = Result{
                .coord = job.coord,
                .ticket = job.ticket,
                .mesh_nanoseconds = @intCast(@max(elapsed, 0)),
                .outcome = outcome,
            };

            self.mutex.lockUncancelable(self.io);
            if (self.stopping) {
                self.mutex.unlock(self.io);
                result.deinit(self.allocator);
                return;
            }
            std.debug.assert(self.result == null);
            self.result = result;
            self.result_available.signal(self.io);
            self.mutex.unlock(self.io);
        }
    }
};

test "streamer bounds work to one outstanding mesh" {
    var streamer = Streamer.init(std.testing.allocator, std.testing.io);
    try streamer.start();
    defer streamer.deinit();

    try std.testing.expect(streamer.submit(.{
        .coord = .{ .x = 0, .z = 0 },
        .ticket = 7,
        .seed = 0x564f_584c,
    }));
    try std.testing.expect(!streamer.submit(.{
        .coord = .{ .x = 1, .z = 0 },
        .ticket = 8,
        .seed = 0x564f_584c,
    }));

    var result = streamer.take(true).?;
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u64, 7), result.ticket);
    try std.testing.expectEqual(voxel.ChunkCoord{ .x = 0, .z = 0 }, result.coord);
    switch (result.outcome) {
        .mesh => |mesh| try std.testing.expect(mesh.indices.len != 0),
        .failure => |err| return err,
    }
}

test "streamer shutdown joins and releases an active mesh" {
    var streamer = Streamer.init(std.testing.allocator, std.testing.io);
    try streamer.start();
    try std.testing.expect(streamer.submit(.{
        .coord = .{ .x = 7, .z = -11 },
        .ticket = 3,
        .seed = 0x564f_584c,
    }));
    streamer.deinit();
}
