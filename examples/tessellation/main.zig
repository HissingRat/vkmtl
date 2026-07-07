const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

const app_name = "vkmtl tessellation";

pub fn main() !void {
    try glfw.init();
    defer glfw.terminate();

    const window = try glfw.createWindow(.{
        .width = 480,
        .height = 320,
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
    const descriptor = vkmtl.TessellationDescriptor{
        .control_point_count = 3,
        .domain = .triangle,
        .partition_mode = .integer,
        .has_control_stage = true,
        .has_evaluation_stage = true,
    };
    device.validateTessellationDescriptor(descriptor) catch |err| {
        std.debug.print("tessellation unsupported: {s}\n", .{@errorName(err)});
        return;
    };

    const backend = device.selectedBackend();
    switch (backend) {
        .vulkan => {
            const lowering = try vkmtl.VulkanTessellationLowering.fromDescriptor(descriptor, device.features(), device.limits());
            std.debug.print("Vulkan tessellation lowering ok: patch_points={}\n", .{lowering.patch_control_points});
        },
        .metal => {
            const lowering = try vkmtl.MetalTessellationLowering.fromDescriptor(descriptor, device.features(), device.limits());
            std.debug.print("Metal tessellation lowering ok: patch_points={}, factor_buffer={}\n", .{
                lowering.patch_control_points,
                lowering.requires_factor_buffer,
            });
        },
    }
}
