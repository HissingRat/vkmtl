const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

const app_name = "vkmtl bindless textures";

pub fn main() !void {
    try glfw.init();
    defer glfw.terminate();

    const window = try glfw.createWindow(.{
        .width = 640,
        .height = 480,
        .title = app_name,
    });
    defer glfw.destroyWindow(window);

    var debug_allocator = std.heap.DebugAllocator(.{}){};
    defer _ = debug_allocator.deinit();
    const allocator = debug_allocator.allocator();

    var context = try vkmtl.WindowContext.init(allocator, .{
        .app_name = app_name,
        .backend = .auto,
        .surface = common.surfaceDescriptor(window),
        .presentation = common.presentationDescriptor(window, .fifo),
    });
    defer context.deinit();

    var device = context.device();
    const model: vkmtl.AdvancedBindingModel = switch (device.selectedBackend()) {
        .vulkan => .descriptor_indexing,
        .metal => .argument_buffer,
    };
    const ranges = [_]vkmtl.DescriptorIndexingRange{.{
        .binding = 0,
        .resource = .sampled_texture,
        .visibility = .{ .fragment = true },
        .descriptor_count = 64,
        .partially_bound = true,
    }};

    var layout = device.makeAdvancedBindGroupLayout(.{
        .label = "bindless texture table",
        .model = model,
        .ranges = &ranges,
    }) catch |err| {
        std.debug.print("bindless textures unsupported: {s}\n", .{@errorName(err)});
        return;
    };
    defer layout.deinit();

    var table = try device.makeResourceTable(.{
        .label = "bindless texture table",
        .layout = &layout,
        .allow_partially_bound = layout.usesPartiallyBoundRanges(),
        .allow_update_after_bind = layout.usesUpdateAfterBindRanges(),
    });
    defer table.deinit();

    std.debug.print("bindless texture table ok: backend={s}, model={s}, ranges={}, slots={}\n", .{
        @tagName(device.selectedBackend()),
        @tagName(layout.model()),
        layout.rangeCount(),
        table.slotCount(),
    });
}
