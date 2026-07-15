const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

const app_name = "vkmtl tessellation";
const shader_source = @embedFile("shaders/tessellation.slang");

pub fn main(_: std.process.Init.Minimal) !void {
    try glfw.init();
    defer glfw.terminate();

    const window = try glfw.createWindow(.{
        .width = 800,
        .height = 600,
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
    if (!device.features().tessellation) {
        std.debug.print("tessellation unavailable on backend {s}\n", .{@tagName(device.selectedBackend())});
        return;
    }
    var queue = context.queue();
    var swapchain = context.swapchain();
    const color_attachments = [_]vkmtl.render.RenderPipelineColorAttachmentDescriptor{
        .{ .format = swapchain.selectedFormat() },
    };

    var compiled_shader = try vkmtl.shader.compileTessellationShader(
        &device,
        "tessellation",
        shader_source,
        .{},
    );
    defer compiled_shader.deinit();
    const stages = try compiled_shader.stageDescriptors(device.selectedBackend());

    const tessellation = vkmtl.render.TessellationDescriptor{
        .control_point_count = 3,
        .domain = .triangle,
        .partition_mode = .integer,
        .control_stage = .{ .entry_point = "hs_main" },
        .evaluation_stage = .{ .entry_point = "ds_main" },
    };
    var pipeline = try vkmtl.render.makeTessellationPipelineState(&device, .{
        .render = .{
            .vertex = stages.vertex,
            .fragment = stages.fragment,
            .primitive_topology = .triangle,
            .color_attachments = color_attachments[0..],
        },
        .tessellation = tessellation,
        .control = stages.control,
        .evaluation = stages.evaluation,
    });
    defer pipeline.deinit();

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
        try encoder.drawTessellationPatches(.{
            .tessellation = tessellation,
            .patch_count = 1,
        });
        try encoder.endEncoding();
        try command_buffer.presentDrawable();
        try command_buffer.commit();
        glfw.pollEvents();
    }
}
