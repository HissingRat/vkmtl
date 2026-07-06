const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

extern fn getenv(name: [*:0]const u8) ?[*:0]u8;

const app_name = "vkmtl sampled texture";
const shader_source = @embedFile("shaders/sampled_texture.slang");

const Vertex = extern struct {
    position: [2]f32,
    uv: [2]f32,
};

const vertices = [_]Vertex{
    .{ .position = .{ -0.65, -0.65 }, .uv = .{ 0.0, 1.0 } },
    .{ .position = .{ 0.65, -0.65 }, .uv = .{ 1.0, 1.0 } },
    .{ .position = .{ 0.65, 0.65 }, .uv = .{ 1.0, 0.0 } },
    .{ .position = .{ -0.65, 0.65 }, .uv = .{ 0.0, 0.0 } },
};

const indices = [_]u16{ 0, 1, 2, 0, 2, 3 };

const texture_width = 4;
const texture_height = 4;
const texture_pixels = [_]u8{
    0xf5, 0x4e, 0x42, 0xff, 0xf5, 0x4e, 0x42, 0xff, 0x28, 0xd6, 0x7a, 0xff, 0x28, 0xd6, 0x7a, 0xff,
    0xf5, 0x4e, 0x42, 0xff, 0xff, 0xd1, 0x4a, 0xff, 0x28, 0xd6, 0x7a, 0xff, 0x46, 0x95, 0xff, 0xff,
    0x46, 0x95, 0xff, 0xff, 0xff, 0xd1, 0x4a, 0xff, 0xff, 0xd1, 0x4a, 0xff, 0xf5, 0x4e, 0x42, 0xff,
    0x46, 0x95, 0xff, 0xff, 0x28, 0xd6, 0x7a, 0xff, 0xff, 0xd1, 0x4a, 0xff, 0xf5, 0x4e, 0x42, 0xff,
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

    var vertex_buffer = try context.makeBuffer(.{
        .bytes = std.mem.sliceAsBytes(vertices[0..]),
        .usage = .{ .vertex = true },
        .storage_mode = .shared,
    });
    defer vertex_buffer.deinit();

    var index_buffer = try context.makeBuffer(.{
        .bytes = std.mem.sliceAsBytes(indices[0..]),
        .usage = .{ .index = true },
        .storage_mode = .shared,
    });
    defer index_buffer.deinit();

    var texture = try context.makeTexture(.{
        .format = .rgba8_unorm,
        .width = texture_width,
        .height = texture_height,
        .usage = .{ .shader_read = true },
        .storage_mode = .shared,
    });
    defer texture.deinit();
    try texture.replaceAll2D(.{
        .bytes = texture_pixels[0..],
    });

    var texture_view = try texture.makeTextureView(.{});
    defer texture_view.deinit();

    var sampler = try context.makeSamplerState(.{
        .min_filter = .nearest,
        .mag_filter = .nearest,
    });
    defer sampler.deinit();

    var compiled_shader = try context.compileRenderShader("sampled_texture", shader_source, .{
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

    var derived_bind_group_layouts = try vkmtl.ShaderReflection.deriveRenderPipelineBindGroupLayouts(
        allocator,
        stages.vertex,
        stages.fragment,
    );
    defer derived_bind_group_layouts.deinit();
    if (derived_bind_group_layouts.descriptors().len == 0) return error.MissingDerivedBindGroupLayout;

    var bind_group_layout = try context.makeBindGroupLayout(derived_bind_group_layouts.descriptors()[0]);
    defer bind_group_layout.deinit();

    const bind_group_entries = [_]vkmtl.BindGroupEntry{
        .{
            .binding = 0,
            .resource = .{ .sampled_texture = &texture_view },
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

    const pipeline_bind_group_layouts = [_]vkmtl.BindGroupLayoutDescriptor{
        bind_group_layout.descriptor(),
    };
    var pipeline = try context.makeRenderPipelineState(.{
        .vertex = stages.vertex,
        .fragment = stages.fragment,
        .vertex_descriptor = derived_vertex_descriptor.descriptor,
        .bind_group_layouts = pipeline_bind_group_layouts[0..],
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

        try context.resize(extent);

        var command_buffer = try context.makeCommandBuffer();
        var encoder = try command_buffer.makeRenderCommandEncoder(.{
            .color_attachments = &.{.{
                .clear_color = .{
                    .red = 0.015,
                    .green = 0.018,
                    .blue = 0.023,
                    .alpha = 1.0,
                },
            }},
        });
        try encoder.setRenderPipelineState(&pipeline);
        try encoder.setBindGroup(&bind_group, .{ .index = 0 });
        try encoder.setVertexBuffer(&vertex_buffer, .{ .index = 0 });
        try encoder.setIndexBuffer(&index_buffer);
        try encoder.drawIndexedPrimitives(.{
            .primitive_type = .triangle,
            .index_type = .uint16,
            .index_count = @intCast(indices.len),
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
