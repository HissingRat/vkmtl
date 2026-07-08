const std = @import("std");
const vkmtl = @import("vkmtl");

pub fn main(init: std.process.Init) !void {
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.skip();

    const iterations = try parseIterations(&args);
    const descriptor = vkmtl.StabilityRunDescriptor{
        .iterations = iterations,
    };
    const plan = try descriptor.plan();
    const diagnostics = vkmtl.StabilityRunDiagnostics.fromPlan(plan);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("vkmtl stability plan\n", .{});
    try stdout.print("iterations: {}\n", .{plan.iterations});
    try stdout.print("resize events: {}\n", .{plan.resize_events});
    try stdout.print("resources created: {}\n", .{plan.resources_created});
    try stdout.print("shader cache cycles: {}\n", .{plan.shader_cache_cycles});
    try stdout.print("upload/readback cycles: {}\n", .{plan.upload_readback_cycles});
    try stdout.print("upload bytes: {}\n", .{plan.upload_bytes});
    try stdout.print("vulkan unaligned fill fallback checks: {}\n", .{plan.vulkan_unaligned_fill_fallback_checks});
    try stdout.print("max live resources: {}\n", .{diagnostics.max_live_resources});
    try stdout.flush();
}

fn parseIterations(args: *std.process.Args.Iterator) !u32 {
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations")) {
            const value = args.next() orelse return error.MissingIterationsValue;
            return try std.fmt.parseUnsigned(u32, value, 10);
        }
        if (std.mem.startsWith(u8, arg, "--iterations=")) {
            return try std.fmt.parseUnsigned(u32, arg["--iterations=".len..], 10);
        }
        if (std.mem.eql(u8, arg, "--help")) {
            return error.HelpRequested;
        }
        return error.UnknownArgument;
    }

    return 120;
}
