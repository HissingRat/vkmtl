const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

extern fn getenv(name: [*:0]const u8) ?[*:0]u8;

const app_name = "vkmtl offscreen texture";
const shader_source = @embedFile("shaders/offscreen_texture.slang");

const offscreen_width = 512;
const offscreen_height = 512;

const ColorVertex = extern struct {
    position: [2]f32,
    color: [3]f32,
};

const ScreenVertex = extern struct {
    position: [2]f32,
    uv: [2]f32,
};

const color_vertices = [_]ColorVertex{
    .{ .position = .{ 0.0, -0.72 }, .color = .{ 0.98, 0.20, 0.16 } },
    .{ .position = .{ 0.72, 0.58 }, .color = .{ 0.20, 0.86, 0.42 } },
    .{ .position = .{ -0.72, 0.58 }, .color = .{ 0.24, 0.46, 1.00 } },
};

const screen_vertices = [_]ScreenVertex{
    .{ .position = .{ -0.72, -0.72 }, .uv = .{ 0.0, 1.0 } },
    .{ .position = .{ 0.72, -0.72 }, .uv = .{ 1.0, 1.0 } },
    .{ .position = .{ 0.72, 0.72 }, .uv = .{ 1.0, 0.0 } },
    .{ .position = .{ -0.72, 0.72 }, .uv = .{ 0.0, 0.0 } },
};

const screen_indices = [_]u16{ 0, 1, 2, 0, 2, 3 };

const offscreen_color_attachments = [_]vkmtl.RenderPipelineColorAttachmentDescriptor{
    .{ .format = .rgba8_unorm },
};

const screen_color_attachments = [_]vkmtl.RenderPipelineColorAttachmentDescriptor{
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

    var color_vertex_buffer = try context.makeBuffer(.{
        .bytes = std.mem.sliceAsBytes(color_vertices[0..]),
        .usage = .{ .vertex = true },
        .storage_mode = .shared,
    });
    defer color_vertex_buffer.deinit();

    var screen_vertex_buffer = try context.makeBuffer(.{
        .bytes = std.mem.sliceAsBytes(screen_vertices[0..]),
        .usage = .{ .vertex = true },
        .storage_mode = .shared,
    });
    defer screen_vertex_buffer.deinit();

    var screen_index_buffer = try context.makeBuffer(.{
        .bytes = std.mem.sliceAsBytes(screen_indices[0..]),
        .usage = .{ .index = true },
        .storage_mode = .shared,
    });
    defer screen_index_buffer.deinit();

    var offscreen_texture = try context.makeTexture(.{
        .format = .rgba8_unorm,
        .width = offscreen_width,
        .height = offscreen_height,
        .usage = .{
            .shader_read = true,
            .render_attachment = true,
        },
        .storage_mode = .private,
    });
    defer offscreen_texture.deinit();

    var offscreen_view = try offscreen_texture.makeTextureView(.{});
    defer offscreen_view.deinit();

    var sampler = try context.makeSamplerState(.{
        .min_filter = .linear,
        .mag_filter = .linear,
    });
    defer sampler.deinit();

    var offscreen_shader = try context.compileRenderShader("offscreen_texture_offscreen", shader_source, .{
        .vertex_entry = "offscreen_vs",
        .fragment_entry = "offscreen_fs",
    });
    defer offscreen_shader.deinit();

    var screen_shader = try context.compileRenderShader("offscreen_texture_screen", shader_source, .{
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

    var bind_group_layout = try context.makeBindGroupLayout(derived_bind_group_layouts.descriptors()[0]);
    defer bind_group_layout.deinit();

    const bind_group_entries = [_]vkmtl.BindGroupEntry{
        .{
            .binding = 0,
            .resource = .{ .sampled_texture = &offscreen_view },
        },
        .{
            .binding = 1,
            .resource = .{ .sampler = &sampler },
        },
    };
    var bind_group = try context.makeBindGroup(.{
        .layout = &bind_group_layout,
        .entries = bind_group_entries[0..],
    });
    defer bind_group.deinit();

    const offscreen_stages = offscreen_shader.stageDescriptors(context.selectedBackend());
    var offscreen_vertex_descriptor = try vkmtl.ShaderReflection.deriveSingleBufferVertexDescriptor(
        allocator,
        offscreen_stages.vertex,
        .{ .stride = @sizeOf(ColorVertex) },
    );
    defer offscreen_vertex_descriptor.deinit();

    var offscreen_pipeline = try context.makeRenderPipelineState(offscreenPipelineDescriptor(
        offscreen_stages.vertex,
        offscreen_stages.fragment,
        offscreen_vertex_descriptor.descriptor,
    ));
    defer offscreen_pipeline.deinit();

    var screen_vertex_descriptor = try vkmtl.ShaderReflection.deriveSingleBufferVertexDescriptor(
        allocator,
        screen_stages.vertex,
        .{ .stride = @sizeOf(ScreenVertex) },
    );
    defer screen_vertex_descriptor.deinit();

    const pipeline_bind_group_layouts = [_]vkmtl.BindGroupLayoutDescriptor{
        bind_group_layout.descriptor(),
    };
    var screen_pipeline = try context.makeRenderPipelineState(screenPipelineDescriptor(
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

        try context.resize(extent);

        var offscreen_command_buffer = try context.makeCommandBuffer();
        var offscreen_encoder = try offscreen_command_buffer.makeRenderCommandEncoder(.{
            .color_attachments = &.{.{
                .target = .{ .texture_view = &offscreen_view },
                .clear_color = .{
                    .red = 0.02,
                    .green = 0.025,
                    .blue = 0.035,
                    .alpha = 1.0,
                },
            }},
        });
        try offscreen_encoder.setRenderPipelineState(&offscreen_pipeline);
        try offscreen_encoder.setVertexBuffer(&color_vertex_buffer, .{ .index = 0 });
        try offscreen_encoder.drawPrimitives(.{
            .primitive_type = .triangle,
            .vertex_count = @intCast(color_vertices.len),
        });
        try offscreen_encoder.endEncoding();
        try offscreen_command_buffer.commit();

        var screen_command_buffer = try context.makeCommandBuffer();
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

fn offscreenPipelineDescriptor(
    vertex_stage: vkmtl.ProgrammableStageDescriptor,
    fragment_stage: vkmtl.ProgrammableStageDescriptor,
    vertex_descriptor: vkmtl.VertexDescriptor,
) vkmtl.RenderPipelineDescriptor {
    return .{
        .vertex = vertex_stage,
        .fragment = fragment_stage,
        .vertex_descriptor = vertex_descriptor,
        .primitive_topology = .triangle,
        .color_attachments = offscreen_color_attachments[0..],
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
