const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

extern fn getenv(name: [*:0]const u8) ?[*:0]u8;

const app_name = "vkmtl transfer readback";
const pixels = [_]u8{
    0xf5, 0x4e, 0x42, 0xff,
    0xff, 0xd1, 0x4a, 0xff,
    0x28, 0xd6, 0x7a, 0xff,
    0x46, 0x95, 0xff, 0xff,
};

const LifecycleProbe = struct {
    count: std.atomic.Value(u32) = .init(0),
    status_mask: std.atomic.Value(u32) = .init(0),
};

fn lifecycleCallback(context: ?*anyopaque, status: vkmtl.command.CommandBufferLifecycleStatus) callconv(.c) void {
    const probe: *LifecycleProbe = @ptrCast(@alignCast(context orelse return));
    _ = probe.count.fetchAdd(1, .acq_rel);
    _ = probe.status_mask.fetchOr(@as(u32, 1) << @intCast(@intFromEnum(status)), .acq_rel);
}

fn verifyLifecycle(probe: *const LifecycleProbe) !void {
    if (probe.count.load(.acquire) != 2) return error.CommandLifecycleCallbackCountMismatch;
    const expected = (@as(u32, 1) << @intCast(@intFromEnum(vkmtl.command.CommandBufferLifecycleStatus.scheduled))) |
        (@as(u32, 1) << @intCast(@intFromEnum(vkmtl.command.CommandBufferLifecycleStatus.completed)));
    if (probe.status_mask.load(.acquire) != expected) return error.CommandLifecycleStatusMismatch;
}

pub fn main() !void {
    try glfw.init();
    defer glfw.terminate();

    const window = try glfw.createWindow(.{
        .width = 64,
        .height = 64,
        .title = app_name,
    });
    defer glfw.destroyWindow(window);

    var debug_allocator = std.heap.DebugAllocator(.{}){};
    defer _ = debug_allocator.deinit();
    const allocator = debug_allocator.allocator();

    var context = try vkmtl.WindowContext.init(allocator, .{
        .app_name = app_name,
        .backend = .auto,
        .debug_backend_override = backendOverrideFromEnv(),
        .surface = common.surfaceDescriptor(window),
        .presentation = common.presentationDescriptor(window, .fifo),
    });
    defer context.deinit();
    std.debug.print("Using backend: {}\n", .{context.selectedBackend()});

    var device = context.device();
    var queue = context.queue();
    const features = device.features();
    var work_queue = try device.queueWithDescriptor(.{
        .kind = .transfer,
        .allow_fallback = true,
    });

    var timeline_fence: ?vkmtl.sync.Fence = if (features.timeline_fences)
        try device.makeFence(.{ .kind = .timeline })
    else
        null;
    defer if (timeline_fence) |*fence| fence.deinit();
    var shared_event: ?vkmtl.sync.Event = if (features.shared_events)
        try device.makeEvent(.{ .shared = true })
    else
        null;
    defer if (shared_event) |*event| event.deinit();

    var source_buffer = try device.makeBuffer(.{
        .bytes = pixels[0..],
        .usage = .{ .copy_source = true },
        .storage_mode = .managed,
    });
    defer source_buffer.deinit();

    var buffer_readback = try device.makeBuffer(.{
        .length = pixels.len,
        .usage = .{ .copy_destination = true },
        .storage_mode = .managed,
    });
    defer buffer_readback.deinit();

    var texture = try device.makeTexture(.{
        .format = .rgba8_unorm,
        .width = 2,
        .height = 2,
        .usage = .{
            .copy_source = true,
            .copy_destination = true,
        },
        .storage_mode = .private,
    });
    defer texture.deinit();

    var texture_readback = try device.makeBuffer(.{
        .length = pixels.len,
        .usage = .{ .copy_destination = true },
        .storage_mode = .managed,
    });
    defer texture_readback.deinit();

    if (work_queue.kind() != .graphics) {
        var ownership_command_buffer = try queue.makeCommandBuffer();
        var ownership = try ownership_command_buffer.makeBlitCommandEncoder();
        try ownership.bufferOwnershipTransfer(&source_buffer, .{
            .source = .graphics,
            .destination = work_queue.kind(),
            .before = .copy_source,
            .after = .copy_source,
        });
        try ownership.bufferOwnershipTransfer(&buffer_readback, .{
            .source = .graphics,
            .destination = work_queue.kind(),
            .before = .copy_destination,
            .after = .copy_destination,
        });
        try ownership.textureOwnershipTransfer(&texture, .{
            .source = .graphics,
            .destination = work_queue.kind(),
            .before = .copy_destination,
            .after = .copy_destination,
        });
        try ownership.bufferOwnershipTransfer(&texture_readback, .{
            .source = .graphics,
            .destination = work_queue.kind(),
            .before = .copy_destination,
            .after = .copy_destination,
        });
        try ownership.endEncoding();
        try ownership_command_buffer.commit();
    }

    var signal_fences: [1]vkmtl.sync.FenceSignalOperation = undefined;
    var signal_fence_count: usize = 0;
    if (timeline_fence) |*fence| {
        signal_fences[0] = .{ .fence = fence, .descriptor = .{ .value = 1 } };
        signal_fence_count = 1;
    }
    var signal_events: [1]vkmtl.sync.EventSignalOperation = undefined;
    var signal_event_count: usize = 0;
    if (shared_event) |*event| {
        signal_events[0] = .{ .event = event };
        signal_event_count = 1;
    }

    var upload_lifecycle = LifecycleProbe{};
    var upload_command_buffer = try work_queue.makeCommandBufferWithDescriptor(.{
        .lifecycle_callback = lifecycleCallback,
        .lifecycle_context = &upload_lifecycle,
    });
    var upload = try upload_command_buffer.makeBlitCommandEncoder();
    try upload.copyBufferToBuffer(&source_buffer, &buffer_readback, .{
        .size = pixels.len,
    });
    try upload.copyBufferToTexture(&source_buffer, &texture, .{
        .destination_region = .{ .size = .{ .width = 2, .height = 2 } },
    });
    try upload.endEncoding();
    try upload_command_buffer.commitWithSynchronization(.{
        .signal_fences = signal_fences[0..signal_fence_count],
        .signal_events = signal_events[0..signal_event_count],
    });
    try verifyLifecycle(&upload_lifecycle);

    var wait_fences: [1]vkmtl.sync.FenceWaitOperation = undefined;
    var wait_fence_count: usize = 0;
    if (timeline_fence) |*fence| {
        wait_fences[0] = .{ .fence = fence, .descriptor = .{ .value = 1 } };
        wait_fence_count = 1;
    }
    var wait_events: [1]vkmtl.sync.EventWaitOperation = undefined;
    var wait_event_count: usize = 0;
    if (shared_event) |*event| {
        wait_events[0] = .{ .event = event };
        wait_event_count = 1;
    }

    var readback_lifecycle = LifecycleProbe{};
    var readback_command_buffer = try work_queue.makeCommandBufferWithDescriptor(.{
        .lifecycle_callback = lifecycleCallback,
        .lifecycle_context = &readback_lifecycle,
    });
    var readback = try readback_command_buffer.makeBlitCommandEncoder();
    try readback.copyTextureToBuffer(&texture, &texture_readback, .{
        .source_region = .{ .size = .{ .width = 2, .height = 2 } },
    });
    try readback.endEncoding();
    try readback_command_buffer.commitWithSynchronization(.{
        .wait_fences = wait_fences[0..wait_fence_count],
        .wait_events = wait_events[0..wait_event_count],
    });
    try verifyLifecycle(&readback_lifecycle);

    var copied_buffer: [pixels.len]u8 = undefined;
    try buffer_readback.readBytes(0, copied_buffer[0..]);
    if (!std.mem.eql(u8, pixels[0..], copied_buffer[0..])) {
        return error.BufferCopyMismatch;
    }

    var copied_texture: [pixels.len]u8 = undefined;
    try texture_readback.readBytes(0, copied_texture[0..]);
    if (!std.mem.eql(u8, pixels[0..], copied_texture[0..])) {
        return error.TextureCopyMismatch;
    }

    if (timeline_fence) |*fence| {
        try fence.wait(.{ .value = 1, .timeout_ns = 1_000_000_000 });
        try fence.signal(.{ .value = 2 });
        try fence.wait(.{ .value = 2, .timeout_ns = 1_000_000_000 });
    }
    if (shared_event) |*event| {
        event.reset();
        try event.signal(.{});
        try event.wait(.{ .timeout_ns = 1_000_000_000 });
    }

    std.debug.print("transfer readback ok (queue={}, timeline={}, shared_event={})\n", .{
        work_queue.kind(),
        timeline_fence != null,
        shared_event != null,
    });
}

fn backendOverrideFromEnv() ?vkmtl.Backend {
    const value = std.mem.span(getenv("VKMTL_BACKEND") orelse return null);
    if (std.ascii.eqlIgnoreCase(value, "vulkan")) return .vulkan;
    if (std.ascii.eqlIgnoreCase(value, "metal")) return .metal;

    std.debug.print("Ignoring unsupported VKMTL_BACKEND value: {s}\n", .{value});
    return null;
}
