const std = @import("std");
const vk = @import("vulkan");
const core = @import("../../core.zig");
const GraphicsContext = @import("graphics_context.zig");
const identity = @import("../pipeline_cache_identity.zig");

const magic = "VKMTLPC1";
const max_cache_bytes = 64 * 1024 * 1024;

pub const Session = struct {
    gc: *const GraphicsContext,
    allocator: std.mem.Allocator,
    handle: vk.PipelineCache,
    descriptor: ?core.DriverPipelineCacheDescriptor,

    pub fn init(
        gc: *const GraphicsContext,
        allocator: std.mem.Allocator,
        descriptor: ?core.DriverPipelineCacheDescriptor,
    ) !Session {
        var initial_data: []u8 = &.{};
        defer if (initial_data.len != 0) allocator.free(initial_data);
        if (descriptor) |cache| initial_data = readCompatibleCache(allocator, cache) catch &.{};

        const handle = gc.dev.createPipelineCache(&.{
            .initial_data_size = initial_data.len,
            .p_initial_data = if (initial_data.len == 0) null else initial_data.ptr,
        }, null) catch try gc.dev.createPipelineCache(&.{}, null);

        return .{
            .gc = gc,
            .allocator = allocator,
            .handle = handle,
            .descriptor = descriptor,
        };
    }

    pub fn deinit(self: *Session) void {
        if (self.descriptor) |descriptor| {
            if (!descriptor.read_only) self.store(descriptor) catch {};
        }
        self.gc.dev.destroyPipelineCache(self.handle, null);
    }

    fn store(self: Session, descriptor: core.DriverPipelineCacheDescriptor) !void {
        const data = try self.gc.dev.wrapper.getPipelineCacheDataAlloc(
            self.gc.dev.handle,
            self.handle,
            self.allocator,
        );
        defer self.allocator.free(data);
        const output = try self.allocator.alloc(u8, magic.len + @sizeOf(u64) + data.len);
        defer self.allocator.free(output);
        @memcpy(output[0..magic.len], magic);
        std.mem.writeInt(u64, output[magic.len..][0..8], identity.hash(descriptor.identity), .little);
        @memcpy(output[magic.len + 8 ..], data);
        try writeFile(descriptor.path, output);
    }
};

fn readCompatibleCache(allocator: std.mem.Allocator, descriptor: core.DriverPipelineCacheDescriptor) ![]u8 {
    const file = try readFile(allocator, descriptor.path);
    defer allocator.free(file);
    if (file.len < magic.len + 8 or !std.mem.eql(u8, file[0..magic.len], magic)) return error.StalePipelineCache;
    const stored_hash = std.mem.readInt(u64, file[magic.len..][0..8], .little);
    if (stored_hash != identity.hash(descriptor.identity)) return error.StalePipelineCache;
    return try allocator.dupe(u8, file[magic.len + 8 ..]);
}

fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const io = std.Options.debug_io;
    const parent = std.fs.path.dirname(path) orelse return std.Io.Dir.cwd().readFileAlloc(
        io,
        path,
        allocator,
        .limited(max_cache_bytes),
    );
    var dir = if (std.fs.path.isAbsolute(parent))
        try std.Io.Dir.openDirAbsolute(io, parent, .{})
    else
        try std.Io.Dir.cwd().openDir(io, parent, .{});
    defer dir.close(io);
    return dir.readFileAlloc(io, std.fs.path.basename(path), allocator, .limited(max_cache_bytes));
}

fn writeFile(path: []const u8, bytes: []const u8) !void {
    const io = std.Options.debug_io;
    const parent = std.fs.path.dirname(path);
    if (parent) |directory| try std.Io.Dir.createDirPath(.cwd(), io, directory);
    if (parent) |directory| {
        var dir = if (std.fs.path.isAbsolute(directory))
            try std.Io.Dir.openDirAbsolute(io, directory, .{})
        else
            try std.Io.Dir.cwd().openDir(io, directory, .{});
        defer dir.close(io);
        return dir.writeFile(io, .{ .sub_path = std.fs.path.basename(path), .data = bytes });
    }
    return std.Io.Dir.writeFile(.cwd(), io, .{ .sub_path = path, .data = bytes });
}

test "Vulkan pipeline cache identity changes with shader inputs" {
    const base = core.DriverCacheIdentityDescriptor{
        .backend = .vulkan,
        .device_id = "device",
        .driver_id = "driver",
        .shader_hash = "one",
        .schema_version = "1",
    };
    var changed = base;
    changed.shader_hash = "two";
    try std.testing.expect(identity.hash(base) != identity.hash(changed));
}
