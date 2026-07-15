const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

const app_name = "vkmtl mesh shader";
const shader_source = @embedFile("shaders/mesh_shader.slang");

pub fn main(_: std.process.Init.Minimal) !void {
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
    if (!device.features().mesh_shaders) {
        std.debug.print("mesh shaders unavailable on backend {s}\n", .{@tagName(device.selectedBackend())});
        return;
    }
    var queue = context.queue();
    var swapchain = context.swapchain();
    const color_attachments = [_]vkmtl.render.RenderPipelineColorAttachmentDescriptor{
        .{ .format = swapchain.selectedFormat() },
    };

    var compiled_shader = try vkmtl.shader.compileMeshShader(
        &device,
        "mesh_shader",
        shader_source,
        .{},
    );
    defer compiled_shader.deinit();
    const stages = compiled_shader.stageDescriptors(device.selectedBackend());

    const mesh_pipeline = vkmtl.render.MeshPipelineDescriptor{
        .mesh_entry_point = "mesh_main",
        .mesh_threads_per_threadgroup = 1,
    };
    var pipeline = try vkmtl.render.makeMeshPipelineState(&device, .{
        .pipeline = mesh_pipeline,
        .mesh = stages.mesh,
        .fragment = stages.fragment,
        .color_attachments = color_attachments[0..],
    });
    defer pipeline.deinit();

    var reported_submission = false;
    while (!glfw.windowShouldClose(window)) {
        const extent = common.framebufferExtent(window);
        if (extent.isZero()) {
            glfw.pollEvents();
            continue;
        }
        try swapchain.resize(extent);

        var command_buffer = try queue.makeCommandBuffer();
        var encoder = try command_buffer.makeRenderCommandEncoder(.{
            .color_attachments = &.{.{
                .clear_color = .{ .red = 0.025, .green = 0.035, .blue = 0.06, .alpha = 1.0 },
            }},
        });
        try encoder.setRenderPipelineState(&pipeline);
        try encoder.drawMeshThreadgroups(.{ .pipeline = mesh_pipeline });
        try encoder.endEncoding();
        try command_buffer.presentDrawable();
        try command_buffer.commit();
        if (!reported_submission) {
            std.debug.print("native_mesh_frame_submitted={s}\n", .{@tagName(device.selectedBackend())});
            reported_submission = true;
        }
        glfw.pollEvents();
    }
}
