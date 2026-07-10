const std = @import("std");
const vkmtl = @import("vkmtl");

const Options = struct {
    backend: vkmtl.Backend = .metal,
    require_gpu_timestamps: bool = false,
    markers_only: bool = false,
};

pub fn main(init: std.process.Init) !void {
    var debug_allocator = std.heap.DebugAllocator(.{}){};
    defer _ = debug_allocator.deinit();
    const allocator = debug_allocator.allocator();

    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer args.deinit();
    _ = args.skip();
    const options = try parseOptions(&args);

    const capabilities = vkmtl.diagnostics.ProfilingCapabilities.fromFeatures(
        options.backend,
        vkmtl.DeviceFeatures{
            .debug_labels = true,
            .debug_markers = true,
            .timestamp_queries = true,
        },
    );
    const descriptor = vkmtl.diagnostics.ProfilingPlanDescriptor{
        .require_gpu_timestamps = options.require_gpu_timestamps,
        .allow_cpu_fallback = !options.markers_only,
        .allow_markers_only = true,
    };

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("vkmtl profiling plan\n", .{});
    try stdout.print("backend: {s}\n", .{@tagName(options.backend)});
    try stdout.print("query source: {s}\n", .{@tagName(capabilities.timestamp_source)});
    try stdout.print("native GPU timestamps: {}\n", .{capabilities.native_gpu_timestamps});

    const plan = descriptor.resolve(capabilities) catch |err| switch (err) {
        error.UnsupportedGpuTimestamps => {
            try stdout.print("plan error: UnsupportedGpuTimestamps\n", .{});
            try stdout.print("reason: current query values preserve command order and are not GPU time\n", .{});
            try stdout.flush();
            return;
        },
        else => return err,
    };
    try stdout.print("mode: {s}\n", .{@tagName(plan.mode)});
    try stdout.print("GPU duration available: {}\n", .{plan.gpu_duration_available});
    try stdout.print("reason: {s}\n", .{plan.reason});
    try stdout.flush();
}

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options = Options{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--backend")) {
            const value = args.next() orelse return error.MissingBackendValue;
            options.backend = try parseBackend(value);
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--backend=")) {
            options.backend = try parseBackend(arg["--backend=".len..]);
            continue;
        }
        if (std.mem.eql(u8, arg, "--require-gpu")) {
            options.require_gpu_timestamps = true;
            continue;
        }
        if (std.mem.eql(u8, arg, "--markers-only")) {
            options.markers_only = true;
            continue;
        }
        return error.UnknownArgument;
    }
    return options;
}

fn parseBackend(value: []const u8) !vkmtl.Backend {
    if (std.mem.eql(u8, value, "vulkan")) return .vulkan;
    if (std.mem.eql(u8, value, "metal")) return .metal;
    return error.InvalidBackend;
}
