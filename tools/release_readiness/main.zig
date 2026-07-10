const std = @import("std");
const matrix = @import("vkmtl_development_matrix");

const Evidence = struct {
    hosted_macos: bool = false,
    hosted_linux: bool = false,
    hosted_windows: bool = false,
    metal_smoke: bool = false,
    vulkan_smoke: bool = false,
    metal_pixels: bool = false,
    vulkan_pixels: bool = false,
    metal_soak: bool = false,
    vulkan_soak: bool = false,
    require_ready: bool = false,

    fn satisfiedCount(self: Evidence) usize {
        var count: usize = 0;
        inline for (.{
            self.hosted_macos,
            self.hosted_linux,
            self.hosted_windows,
            self.metal_smoke,
            self.vulkan_smoke,
            self.metal_pixels,
            self.vulkan_pixels,
            self.metal_soak,
            self.vulkan_soak,
        }) |satisfied| {
            if (satisfied) count += 1;
        }
        return count;
    }

    fn isReady(self: Evidence) bool {
        return self.satisfiedCount() == 9;
    }
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.skip();
    const evidence = try parseEvidence(&args);

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("vkmtl release readiness\n", .{});
    try writeGate(stdout, "hosted_macos", evidence.hosted_macos);
    try writeGate(stdout, "hosted_linux", evidence.hosted_linux);
    try writeGate(stdout, "hosted_windows", evidence.hosted_windows);
    try writeGate(stdout, "metal_smoke", evidence.metal_smoke);
    try writeGate(stdout, "vulkan_smoke", evidence.vulkan_smoke);
    try writeGate(stdout, "metal_pixels", evidence.metal_pixels);
    try writeGate(stdout, "vulkan_pixels", evidence.vulkan_pixels);
    try writeGate(stdout, "metal_soak", evidence.metal_soak);
    try writeGate(stdout, "vulkan_soak", evidence.vulkan_soak);
    try stdout.print("evidence: {}/9\n", .{evidence.satisfiedCount()});
    try stdout.print("known feature expectations: {}\n", .{matrix.period44_feature_expectations.len});
    try stdout.print("release ready: {}\n", .{evidence.isReady()});
    try stdout.print("voxel-world pressure test: deferred\n", .{});
    try stdout.flush();

    if (evidence.require_ready and !evidence.isReady()) return error.ReleaseEvidenceIncomplete;
}

fn writeGate(writer: *std.Io.Writer, name: []const u8, satisfied: bool) !void {
    try writer.print("gate {s}: {s}\n", .{ name, if (satisfied) "observed" else "missing" });
}

fn parseEvidence(args: *std.process.Args.Iterator) !Evidence {
    var evidence = Evidence{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--hosted-macos")) evidence.hosted_macos = true else if (std.mem.eql(u8, arg, "--hosted-linux")) evidence.hosted_linux = true else if (std.mem.eql(u8, arg, "--hosted-windows")) evidence.hosted_windows = true else if (std.mem.eql(u8, arg, "--metal-smoke")) evidence.metal_smoke = true else if (std.mem.eql(u8, arg, "--vulkan-smoke")) evidence.vulkan_smoke = true else if (std.mem.eql(u8, arg, "--metal-pixels")) evidence.metal_pixels = true else if (std.mem.eql(u8, arg, "--vulkan-pixels")) evidence.vulkan_pixels = true else if (std.mem.eql(u8, arg, "--metal-soak")) evidence.metal_soak = true else if (std.mem.eql(u8, arg, "--vulkan-soak")) evidence.vulkan_soak = true else if (std.mem.eql(u8, arg, "--all-hosted")) {
            evidence.hosted_macos = true;
            evidence.hosted_linux = true;
            evidence.hosted_windows = true;
        } else if (std.mem.eql(u8, arg, "--all-metal")) {
            evidence.metal_smoke = true;
            evidence.metal_pixels = true;
            evidence.metal_soak = true;
        } else if (std.mem.eql(u8, arg, "--all-vulkan")) {
            evidence.vulkan_smoke = true;
            evidence.vulkan_pixels = true;
            evidence.vulkan_soak = true;
        } else if (std.mem.eql(u8, arg, "--require-ready")) {
            evidence.require_ready = true;
        } else {
            return error.UnknownArgument;
        }
    }
    return evidence;
}
