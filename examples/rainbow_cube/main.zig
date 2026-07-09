const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

extern fn getenv(name: [*:0]const u8) ?[*:0]u8;

const app_name = "vkmtl rainbow cube";
const shader_source = @embedFile("shaders/rainbow_cube.slang");

const texture_width = 16;
const texture_height = 16;

const Vertex = extern struct {
    position: [3]f32,
    uv: [2]f32,
    color: [3]f32,
};

const Uniforms = extern struct {
    mvp_rows: [4][4]f32,
};

const vertices = [_]Vertex{
    // Front
    .{ .position = .{ -1, -1, 1 }, .uv = .{ 0, 1 }, .color = .{ 1.00, 0.22, 0.18 } },
    .{ .position = .{ 1, -1, 1 }, .uv = .{ 1, 1 }, .color = .{ 1.00, 0.22, 0.18 } },
    .{ .position = .{ 1, 1, 1 }, .uv = .{ 1, 0 }, .color = .{ 1.00, 0.22, 0.18 } },
    .{ .position = .{ -1, 1, 1 }, .uv = .{ 0, 0 }, .color = .{ 1.00, 0.22, 0.18 } },
    // Back
    .{ .position = .{ 1, -1, -1 }, .uv = .{ 0, 1 }, .color = .{ 0.22, 0.48, 1.00 } },
    .{ .position = .{ -1, -1, -1 }, .uv = .{ 1, 1 }, .color = .{ 0.22, 0.48, 1.00 } },
    .{ .position = .{ -1, 1, -1 }, .uv = .{ 1, 0 }, .color = .{ 0.22, 0.48, 1.00 } },
    .{ .position = .{ 1, 1, -1 }, .uv = .{ 0, 0 }, .color = .{ 0.22, 0.48, 1.00 } },
    // Left
    .{ .position = .{ -1, -1, -1 }, .uv = .{ 0, 1 }, .color = .{ 0.78, 0.25, 1.00 } },
    .{ .position = .{ -1, -1, 1 }, .uv = .{ 1, 1 }, .color = .{ 0.78, 0.25, 1.00 } },
    .{ .position = .{ -1, 1, 1 }, .uv = .{ 1, 0 }, .color = .{ 0.78, 0.25, 1.00 } },
    .{ .position = .{ -1, 1, -1 }, .uv = .{ 0, 0 }, .color = .{ 0.78, 0.25, 1.00 } },
    // Right
    .{ .position = .{ 1, -1, 1 }, .uv = .{ 0, 1 }, .color = .{ 0.16, 0.92, 0.42 } },
    .{ .position = .{ 1, -1, -1 }, .uv = .{ 1, 1 }, .color = .{ 0.16, 0.92, 0.42 } },
    .{ .position = .{ 1, 1, -1 }, .uv = .{ 1, 0 }, .color = .{ 0.16, 0.92, 0.42 } },
    .{ .position = .{ 1, 1, 1 }, .uv = .{ 0, 0 }, .color = .{ 0.16, 0.92, 0.42 } },
    // Top
    .{ .position = .{ -1, 1, 1 }, .uv = .{ 0, 1 }, .color = .{ 1.00, 0.82, 0.18 } },
    .{ .position = .{ 1, 1, 1 }, .uv = .{ 1, 1 }, .color = .{ 1.00, 0.82, 0.18 } },
    .{ .position = .{ 1, 1, -1 }, .uv = .{ 1, 0 }, .color = .{ 1.00, 0.82, 0.18 } },
    .{ .position = .{ -1, 1, -1 }, .uv = .{ 0, 0 }, .color = .{ 1.00, 0.82, 0.18 } },
    // Bottom
    .{ .position = .{ -1, -1, -1 }, .uv = .{ 0, 1 }, .color = .{ 0.16, 0.92, 0.92 } },
    .{ .position = .{ 1, -1, -1 }, .uv = .{ 1, 1 }, .color = .{ 0.16, 0.92, 0.92 } },
    .{ .position = .{ 1, -1, 1 }, .uv = .{ 1, 0 }, .color = .{ 0.16, 0.92, 0.92 } },
    .{ .position = .{ -1, -1, 1 }, .uv = .{ 0, 0 }, .color = .{ 0.16, 0.92, 0.92 } },
};

const indices = [_]u16{
    0,  1,  2,  0,  2,  3,
    4,  5,  6,  4,  6,  7,
    8,  9,  10, 8,  10, 11,
    12, 13, 14, 12, 14, 15,
    16, 17, 18, 16, 18, 19,
    20, 21, 22, 20, 22, 23,
};

const color_attachments = [_]vkmtl.RenderPipelineColorAttachmentDescriptor{
    .{ .format = .bgra8_unorm_srgb },
};

pub fn main(_: std.process.Init.Minimal) !void {
    try glfw.init();
    defer glfw.terminate();

    const window = try glfw.createWindow(.{
        .width = 900,
        .height = 700,
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

    var vertex_buffer = try device.makeBuffer(.{
        .bytes = std.mem.sliceAsBytes(vertices[0..]),
        .usage = .{ .vertex = true },
        .storage_mode = .shared,
    });
    defer vertex_buffer.deinit();

    var index_buffer = try device.makeBuffer(.{
        .bytes = std.mem.sliceAsBytes(indices[0..]),
        .usage = .{ .index = true },
        .storage_mode = .shared,
    });
    defer index_buffer.deinit();

    var uniforms = makeUniforms(900, 700, 0);
    var uniform_buffer = try device.makeBuffer(.{
        .bytes = std.mem.asBytes(&uniforms),
        .usage = .{ .uniform = true },
        .storage_mode = .shared,
    });
    defer uniform_buffer.deinit();

    var texture_pixels: [texture_width * texture_height * 4]u8 = undefined;
    fillRainbowTexture(&texture_pixels);

    var texture = try device.makeTexture(.{
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

    var sampler = try device.makeSamplerState(.{
        .min_filter = .linear,
        .mag_filter = .linear,
        .address_mode_u = .repeat,
        .address_mode_v = .repeat,
    });
    defer sampler.deinit();

    var compiled_shader = try device.compileRenderShader("rainbow_cube", shader_source, .{
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

    var bind_group_layout = try device.makeBindGroupLayout(derived_bind_group_layouts.descriptors()[0]);
    defer bind_group_layout.deinit();

    const bind_group_entries = [_]vkmtl.BindGroupEntry{
        .{
            .binding = 0,
            .resource = .{ .uniform_buffer = .{
                .buffer = &uniform_buffer,
                .size = @sizeOf(Uniforms),
            } },
        },
        .{
            .binding = 1,
            .resource = .{ .sampled_texture = &texture_view },
        },
        .{
            .binding = 2,
            .resource = .{ .sampler = &sampler },
        },
    };
    var bind_group = try device.makeBindGroup(.{
        .layout = &bind_group_layout,
        .entries = bind_group_entries[0..],
    });
    defer bind_group.deinit();

    const pipeline_bind_group_layouts = [_]vkmtl.BindGroupLayoutDescriptor{
        bind_group_layout.descriptor(),
    };
    var pipeline = try device.makeRenderPipelineState(.{
        .vertex = stages.vertex,
        .fragment = stages.fragment,
        .vertex_descriptor = derived_vertex_descriptor.descriptor,
        .bind_group_layouts = pipeline_bind_group_layouts[0..],
        .primitive_topology = .triangle,
        .color_attachments = color_attachments[0..],
        .depth_stencil = .{
            .format = .depth32_float,
            .depth_compare_function = .less_equal,
            .depth_write_enabled = true,
        },
    });
    defer pipeline.deinit();

    const start_seconds = glfw.timeSeconds();
    while (!glfw.windowShouldClose(window)) {
        const extent = common.framebufferExtent(window);
        if (extent.isZero()) {
            glfw.pollEvents();
            continue;
        }

        const elapsed = @as(f32, @floatCast(glfw.timeSeconds() - start_seconds));
        uniforms = makeUniforms(extent.width, extent.height, elapsed);
        try uniform_buffer.replaceBytes(0, std.mem.asBytes(&uniforms));

        try swapchain.resize(extent);

        var command_buffer = try queue.makeCommandBuffer();
        var encoder = try command_buffer.makeRenderCommandEncoder(.{
            .color_attachments = &.{.{
                .clear_color = .{
                    .red = 0.014,
                    .green = 0.016,
                    .blue = 0.022,
                    .alpha = 1.0,
                },
            }},
            .depth_attachment = .{
                .clear_depth = 1.0,
            },
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

fn makeUniforms(width: u32, height: u32, time_seconds: f32) Uniforms {
    const aspect = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height));
    const model = matMul(rotationY(time_seconds * 0.82), rotationX(time_seconds * 0.47));
    const view = translation(0, 0, -4.2);
    const projection = perspectiveRhZo(std.math.degreesToRadians(58.0), aspect, 0.1, 100.0);
    const mvp = matMul(projection, matMul(view, model));
    return .{ .mvp_rows = mvp };
}

const Mat4 = [4][4]f32;

fn identity() Mat4 {
    return .{
        .{ 1, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 1 },
    };
}

fn translation(x: f32, y: f32, z: f32) Mat4 {
    var result = identity();
    result[0][3] = x;
    result[1][3] = y;
    result[2][3] = z;
    return result;
}

fn rotationX(angle: f32) Mat4 {
    const c = @cos(angle);
    const s = @sin(angle);
    return .{
        .{ 1, 0, 0, 0 },
        .{ 0, c, -s, 0 },
        .{ 0, s, c, 0 },
        .{ 0, 0, 0, 1 },
    };
}

fn rotationY(angle: f32) Mat4 {
    const c = @cos(angle);
    const s = @sin(angle);
    return .{
        .{ c, 0, s, 0 },
        .{ 0, 1, 0, 0 },
        .{ -s, 0, c, 0 },
        .{ 0, 0, 0, 1 },
    };
}

fn perspectiveRhZo(fovy_radians: f32, aspect: f32, near: f32, far: f32) Mat4 {
    const f = 1.0 / @tan(fovy_radians * 0.5);
    return .{
        .{ f / aspect, 0, 0, 0 },
        .{ 0, f, 0, 0 },
        .{ 0, 0, far / (near - far), (far * near) / (near - far) },
        .{ 0, 0, -1, 0 },
    };
}

fn matMul(a: Mat4, b: Mat4) Mat4 {
    var result: Mat4 = undefined;
    for (0..4) |row| {
        for (0..4) |col| {
            var sum: f32 = 0;
            for (0..4) |i| {
                sum += a[row][i] * b[i][col];
            }
            result[row][col] = sum;
        }
    }
    return result;
}

fn fillRainbowTexture(out_pixels: *[texture_width * texture_height * 4]u8) void {
    for (0..texture_height) |y| {
        for (0..texture_width) |x| {
            const i = (y * texture_width + x) * 4;
            const band: u8 = @intCast((x + y) % 6);
            const accent: u8 = @intCast(72 + ((x * 11 + y * 17) % 96));
            const color: [3]u8 = switch (band) {
                0 => .{ 255, accent, 88 },
                1 => .{ 255, 222, accent },
                2 => .{ accent, 255, 118 },
                3 => .{ 80, 236, 255 },
                4 => .{ 120, accent, 255 },
                else => .{ 235, 96, 255 },
            };
            out_pixels[i + 0] = color[0];
            out_pixels[i + 1] = color[1];
            out_pixels[i + 2] = color[2];
            out_pixels[i + 3] = 255;
        }
    }
}

fn backendOverrideFromEnv() ?vkmtl.Backend {
    const value = std.mem.span(getenv("VKMTL_BACKEND") orelse return null);
    if (std.ascii.eqlIgnoreCase(value, "vulkan")) return .vulkan;
    if (std.ascii.eqlIgnoreCase(value, "metal")) return .metal;

    std.debug.print("Ignoring unsupported VKMTL_BACKEND value: {s}\n", .{value});
    return null;
}
