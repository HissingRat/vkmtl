const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

const app_name = "vkmtl mesh shader";

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
    const descriptor = vkmtl.MeshPipelineDescriptor{
        .mesh_entry_point = "mesh_main",
        .mesh_threads_per_threadgroup = 32,
    };
    device.validateMeshPipelineDescriptor(descriptor) catch |err| {
        std.debug.print("mesh shader unsupported: {s}\n", .{@errorName(err)});
        return;
    };

    switch (device.selectedBackend()) {
        .vulkan => {
            const lowering = try vkmtl.VulkanMeshPipelineLowering.fromDescriptor(descriptor, device.features(), device.limits());
            std.debug.print("Vulkan mesh lowering ok: mesh_entry={s}, threads={}\n", .{
                lowering.mesh_entry_point,
                lowering.mesh_threads_per_threadgroup,
            });
        },
        .metal => {
            const lowering = try vkmtl.MetalMeshPipelineLowering.fromDescriptor(descriptor, device.features(), device.limits());
            std.debug.print("Metal mesh lowering ok: mesh_entry={s}, threads={}\n", .{
                lowering.mesh_entry_point,
                lowering.mesh_threads_per_threadgroup,
            });
        },
    }
}
