const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

extern fn getenv(name: [*:0]const u8) ?[*:0]u8;

const app_name = "vkmtl msaa triangle";
const shader_source = @embedFile("shaders/msaa_triangle.slang");

const msaa_width = 512;
const msaa_height = 512;
const msaa_sample_count = 4;

const ColorVertex = extern struct {
    position: [2]f32,
    color: [3]f32,
};

const ScreenVertex = extern struct {
    position: [2]f32,
    uv: [2]f32,
};

const color_vertices = [_]ColorVertex{
    .{ .position = .{ 0.0, -0.78 }, .color = .{ 1.00, 0.18, 0.16 } },
    .{ .position = .{ 0.78, 0.64 }, .color = .{ 0.20, 0.88, 0.46 } },
    .{ .position = .{ -0.78, 0.64 }, .color = .{ 0.22, 0.42, 1.00 } },
};

const screen_vertices = [_]ScreenVertex{
    .{ .position = .{ -0.72, -0.72 }, .uv = .{ 0.0, 1.0 } },
    .{ .position = .{ 0.72, -0.72 }, .uv = .{ 1.0, 1.0 } },
    .{ .position = .{ 0.72, 0.72 }, .uv = .{ 1.0, 0.0 } },
    .{ .position = .{ -0.72, 0.72 }, .uv = .{ 0.0, 0.0 } },
};

const screen_indices = [_]u16{ 0, 1, 2, 0, 2, 3 };

const msaa_color_attachments = [_]vkmtl.RenderPipelineColorAttachmentDescriptor{
    .{ .format = .rgba8_unorm },
};

const screen_color_attachments = [_]vkmtl.RenderPipelineColorAttachmentDescriptor{
    .{ .format = .bgra8_unorm_srgb },
};

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
        .debug_backend_override = backendOverrideFromEnv(),
        .surface = common.surfaceDescriptor(window),
        .presentation = common.presentationDescriptor(window, .fifo),
    });
    defer context.deinit();
    std.debug.print("Using backend: {}\n", .{context.selectedBackend()});

    var device = context.device();
    var queue = context.queue();
    var swapchain = context.swapchain();

    var color_vertex_buffer = try device.makeBuffer(.{
        .bytes = std.mem.sliceAsBytes(color_vertices[0..]),
        .usage = .{ .vertex = true },
        .storage_mode = .shared,
    });
    defer color_vertex_buffer.deinit();

    var screen_vertex_buffer = try device.makeBuffer(.{
        .bytes = std.mem.sliceAsBytes(screen_vertices[0..]),
        .usage = .{ .vertex = true },
        .storage_mode = .shared,
    });
    defer screen_vertex_buffer.deinit();

    var screen_index_buffer = try device.makeBuffer(.{
        .bytes = std.mem.sliceAsBytes(screen_indices[0..]),
        .usage = .{ .index = true },
        .storage_mode = .shared,
    });
    defer screen_index_buffer.deinit();

    var msaa_texture = try device.makeTexture(.{
        .format = .rgba8_unorm,
        .width = msaa_width,
        .height = msaa_height,
        .sample_count = msaa_sample_count,
        .usage = .{ .render_attachment = true },
        .storage_mode = .private,
    });
    defer msaa_texture.deinit();

    var msaa_view = try msaa_texture.makeTextureView(.{});
    defer msaa_view.deinit();

    var resolved_texture = try device.makeTexture(.{
        .format = .rgba8_unorm,
        .width = msaa_width,
        .height = msaa_height,
        .usage = .{
            .shader_read = true,
            .render_attachment = true,
        },
        .storage_mode = .private,
    });
    defer resolved_texture.deinit();

    var resolved_view = try resolved_texture.makeTextureView(.{});
    defer resolved_view.deinit();

    var sampler = try device.makeSamplerState(.{
        .min_filter = .linear,
        .mag_filter = .linear,
    });
    defer sampler.deinit();

    var msaa_shader = try device.compileRenderShader("msaa_triangle_msaa", shader_source, .{
        .vertex_entry = "msaa_vs",
        .fragment_entry = "msaa_fs",
    });
    defer msaa_shader.deinit();

    var screen_shader = try device.compileRenderShader("msaa_triangle_screen", shader_source, .{
        .vertex_entry = "screen_vs",
        .fragment_entry = "screen_fs",
    });
    defer screen_shader.deinit();

    const screen_stages = screen_shader.stageDescriptors(context.selectedBackend());
    var derived_bind_group_layouts = try vkmtl.ShaderReflection.deriveRenderPipelineBindGroupLayouts(
        allocator,
        screen_stages.vertex,
        screen_stages.fragment,
    );
    defer derived_bind_group_layouts.deinit();
    if (derived_bind_group_layouts.descriptors().len == 0) return error.MissingDerivedBindGroupLayout;

    var bind_group_layout = try device.makeBindGroupLayout(derived_bind_group_layouts.descriptors()[0]);
    defer bind_group_layout.deinit();

    const bind_group_entries = [_]vkmtl.BindGroupEntry{
        .{
            .binding = 0,
            .resource = .{ .sampled_texture = &resolved_view },
        },
        .{
            .binding = 1,
            .resource = .{ .sampler = &sampler },
        },
    };
    var bind_group = try device.makeBindGroup(.{
        .layout = &bind_group_layout,
        .entries = bind_group_entries[0..],
    });
    defer bind_group.deinit();

    const msaa_stages = msaa_shader.stageDescriptors(context.selectedBackend());
    var msaa_vertex_descriptor = try vkmtl.ShaderReflection.deriveSingleBufferVertexDescriptor(
        allocator,
        msaa_stages.vertex,
        .{ .stride = @sizeOf(ColorVertex) },
    );
    defer msaa_vertex_descriptor.deinit();

    var msaa_pipeline = try device.makeRenderPipelineState(msaaPipelineDescriptor(
        msaa_stages.vertex,
        msaa_stages.fragment,
        msaa_vertex_descriptor.descriptor,
    ));
    defer msaa_pipeline.deinit();

    var screen_vertex_descriptor = try vkmtl.ShaderReflection.deriveSingleBufferVertexDescriptor(
        allocator,
        screen_stages.vertex,
        .{ .stride = @sizeOf(ScreenVertex) },
    );
    defer screen_vertex_descriptor.deinit();

    const pipeline_bind_group_layouts = [_]vkmtl.BindGroupLayoutDescriptor{
        bind_group_layout.descriptor(),
    };
    var screen_pipeline = try device.makeRenderPipelineState(screenPipelineDescriptor(
        screen_stages.vertex,
        screen_stages.fragment,
        screen_vertex_descriptor.descriptor,
        pipeline_bind_group_layouts[0..],
    ));
    defer screen_pipeline.deinit();

    while (!glfw.windowShouldClose(window)) {
        const extent = common.framebufferExtent(window);
        if (extent.isZero()) {
            glfw.pollEvents();
            continue;
        }

        try swapchain.resize(extent);

        var msaa_command_buffer = try queue.makeCommandBuffer();
        var msaa_encoder = try msaa_command_buffer.makeRenderCommandEncoder(.{
            .color_attachments = &.{.{
                .target = .{ .texture_view = &msaa_view },
                .resolve_target = &resolved_view,
                .clear_color = .{
                    .red = 0.02,
                    .green = 0.024,
                    .blue = 0.032,
                    .alpha = 1.0,
                },
            }},
        });
        try msaa_encoder.setRenderPipelineState(&msaa_pipeline);
        try msaa_encoder.setVertexBuffer(&color_vertex_buffer, .{ .index = 0 });
        try msaa_encoder.drawPrimitives(.{
            .primitive_type = .triangle,
            .vertex_count = @intCast(color_vertices.len),
        });
        try msaa_encoder.endEncoding();
        try msaa_command_buffer.commit();

        var screen_command_buffer = try queue.makeCommandBuffer();
        var screen_encoder = try screen_command_buffer.makeRenderCommandEncoder(.{
            .color_attachments = &.{.{
                .clear_color = .{
                    .red = 0.015,
                    .green = 0.018,
                    .blue = 0.023,
                    .alpha = 1.0,
                },
            }},
        });
        try screen_encoder.setRenderPipelineState(&screen_pipeline);
        try screen_encoder.setBindGroup(&bind_group, .{ .index = 0 });
        try screen_encoder.setVertexBuffer(&screen_vertex_buffer, .{ .index = 0 });
        try screen_encoder.setIndexBuffer(&screen_index_buffer);
        try screen_encoder.drawIndexedPrimitives(.{
            .primitive_type = .triangle,
            .index_type = .uint16,
            .index_count = @intCast(screen_indices.len),
        });
        try screen_encoder.endEncoding();
        try screen_command_buffer.presentDrawable();
        try screen_command_buffer.commit();

        glfw.pollEvents();
    }
}

fn msaaPipelineDescriptor(
    vertex_stage: vkmtl.ProgrammableStageDescriptor,
    fragment_stage: vkmtl.ProgrammableStageDescriptor,
    vertex_descriptor: vkmtl.VertexDescriptor,
) vkmtl.RenderPipelineDescriptor {
    return .{
        .vertex = vertex_stage,
        .fragment = fragment_stage,
        .vertex_descriptor = vertex_descriptor,
        .primitive_topology = .triangle,
        .sample_count = msaa_sample_count,
        .color_attachments = msaa_color_attachments[0..],
    };
}

fn screenPipelineDescriptor(
    vertex_stage: vkmtl.ProgrammableStageDescriptor,
    fragment_stage: vkmtl.ProgrammableStageDescriptor,
    vertex_descriptor: vkmtl.VertexDescriptor,
    bind_group_layouts: []const vkmtl.BindGroupLayoutDescriptor,
) vkmtl.RenderPipelineDescriptor {
    return .{
        .vertex = vertex_stage,
        .fragment = fragment_stage,
        .vertex_descriptor = vertex_descriptor,
        .bind_group_layouts = bind_group_layouts,
        .primitive_topology = .triangle,
        .color_attachments = screen_color_attachments[0..],
    };
}

fn backendOverrideFromEnv() ?vkmtl.Backend {
    const value = std.mem.span(getenv("VKMTL_BACKEND") orelse return null);
    if (std.ascii.eqlIgnoreCase(value, "vulkan")) return .vulkan;
    if (std.ascii.eqlIgnoreCase(value, "metal")) return .metal;

    std.debug.print("Ignoring unsupported VKMTL_BACKEND value: {s}\n", .{value});
    return null;
}
