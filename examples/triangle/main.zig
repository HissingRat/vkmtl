const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

extern fn getenv(name: [*:0]const u8) ?[*:0]u8;

const app_name = "vkmtl triangle";
const shader_source = @embedFile("shaders/triangle.slang");

const Vertex = extern struct {
    position: [2]f32,
    color: [3]f32,
};

const vertices = [_]Vertex{
    .{ .position = .{ 0.0, -0.5 }, .color = .{ 1.0, 0.15, 0.10 } },
    .{ .position = .{ 0.5, 0.5 }, .color = .{ 0.15, 0.85, 0.25 } },
    .{ .position = .{ -0.5, 0.5 }, .color = .{ 0.20, 0.35, 1.0 } },
};

const color_attachments = [_]vkmtl.RenderPipelineColorAttachmentDescriptor{
    .{ .format = .bgra8_unorm_srgb },
};

pub fn main(init: std.process.Init.Minimal) !void {
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
        .debug_backend_override = backendOverrideFromEnv(),
        .process_args = init.args,
        .surface = common.surfaceDescriptor(window),
        .presentation = common.presentationDescriptor(window, .fifo),
    });
    defer context.deinit();
    std.debug.print("Using backend: {}\n", .{context.selectedBackend()});

    var device = context.device();
    var queue = context.queue();
    var swapchain = context.swapchain();

    var vertex_buffer = try device.makeBuffer(.{
        .bytes = std.mem.sliceAsBytes(vertices[0..]),
        .usage = .{ .vertex = true },
        .storage_mode = .shared,
    });
    defer vertex_buffer.deinit();

    var compiled_shader = try device.compileRenderShader("triangle", shader_source, .{
        .vertex_entry = "vs_main",
        .fragment_entry = "fs_main",
    });
    defer compiled_shader.deinit();

    const stages = compiled_shader.stageDescriptors(context.selectedBackend());
    var derived_vertex_descriptor = try vkmtl.ShaderReflection.deriveSingleBufferVertexDescriptor(
        allocator,
        stages.vertex,
        .{ .stride = @sizeOf(Vertex) },
    );
    defer derived_vertex_descriptor.deinit();

    var pipeline = try device.makeRenderPipelineState(.{
        .vertex = stages.vertex,
        .fragment = stages.fragment,
        .vertex_descriptor = derived_vertex_descriptor.descriptor,
        .primitive_topology = .triangle,
        .color_attachments = color_attachments[0..],
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
                .clear_color = .{
                    .red = 0.03,
                    .green = 0.04,
                    .blue = 0.06,
                    .alpha = 1.0,
                },
            }},
        });
        try encoder.setRenderPipelineState(&pipeline);
        try encoder.setVertexBuffer(&vertex_buffer, .{ .index = 0 });
        try encoder.drawPrimitives(.{
            .primitive_type = .triangle,
            .vertex_count = @intCast(vertices.len),
        });
        try encoder.endEncoding();
        try command_buffer.presentDrawable();
        try command_buffer.commit();

        glfw.pollEvents();
    }
}

fn backendOverrideFromEnv() ?vkmtl.Backend {
    const value = std.mem.span(getenv("VKMTL_BACKEND") orelse return null);
    if (std.ascii.eqlIgnoreCase(value, "vulkan")) return .vulkan;
    if (std.ascii.eqlIgnoreCase(value, "metal")) return .metal;

    std.debug.print("Ignoring unsupported VKMTL_BACKEND value: {s}\n", .{value});
    return null;
}
