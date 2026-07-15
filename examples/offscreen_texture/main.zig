const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");
const reference_present_shader_source = @import("ray_traced_scene_present_source").source;

extern fn getenv(name: [*:0]const u8) ?[*:0]u8;

const app_name = "vkmtl offscreen texture";
const shader_source = @embedFile("shaders/offscreen_texture.slang");

const offscreen_width = 512;
const offscreen_height = 512;
const presentation_regression_width = 5;
const presentation_regression_height = 1;

const presentation_source_pixels = [presentation_regression_width][4]f16{
    .{ 0.0, 0.0, 0.0, 1.0 },
    .{ 0.18, 0.18, 0.18, 1.0 },
    .{ 0.5, 0.5, 0.5, 1.0 },
    .{ 1.0, 0.8, 0.0, 1.0 },
    .{ 0.0, 0.0, 1.0, 1.0 },
};

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

const offscreen_specialization_constants = [_]vkmtl.shader.ShaderSpecializationConstant{.{
    .id = 7,
    .name = "color_scale",
    .value = .{ .f32 = 1.0 },
}};

const offscreen_color_attachments = [_]vkmtl.RenderPipelineColorAttachmentDescriptor{
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

    var offscreen_texture = try device.makeTexture(.{
        .format = .rgba8_unorm,
        .width = offscreen_width,
        .height = offscreen_height,
        .usage = .{
            .copy_source = true,
            .shader_read = true,
            .render_attachment = true,
        },
        .storage_mode = .private,
    });
    defer offscreen_texture.deinit();

    var offscreen_view = try offscreen_texture.makeTextureView(.{});
    defer offscreen_view.deinit();

    var sampler = try device.makeSamplerState(.{
        .min_filter = .linear,
        .mag_filter = .linear,
    });
    defer sampler.deinit();

    var offscreen_shader = try device.compileRenderShader("offscreen_texture_offscreen", shader_source, .{
        .vertex_entry = "offscreen_vs",
        .fragment_entry = "offscreen_fs",
    });
    defer offscreen_shader.deinit();

    var screen_shader = try device.compileRenderShader("offscreen_texture_screen", shader_source, .{
        .vertex_entry = "screen_vs",
        .fragment_entry = "screen_fs",
    });
    defer screen_shader.deinit();

    const screen_stages = screen_shader.stageDescriptors(context.selectedBackend());
    var derived_bind_group_layouts = try vkmtl.shader.Reflection.deriveRenderPipelineBindGroupLayouts(
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
            .resource = .{ .sampled_texture = &offscreen_view },
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

    const offscreen_stages = offscreen_shader.stageDescriptors(context.selectedBackend());
    var offscreen_vertex_descriptor = try vkmtl.shader.Reflection.deriveSingleBufferVertexDescriptor(
        allocator,
        offscreen_stages.vertex,
        .{ .stride = @sizeOf(ColorVertex) },
    );
    defer offscreen_vertex_descriptor.deinit();

    var offscreen_pipeline = try device.makeRenderPipelineState(offscreenPipelineDescriptor(
        offscreen_stages.vertex,
        offscreen_stages.fragment,
        offscreen_vertex_descriptor.descriptor,
    ));
    defer offscreen_pipeline.deinit();

    var screen_vertex_descriptor = try vkmtl.shader.Reflection.deriveSingleBufferVertexDescriptor(
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

    var query_regression = try QueryRegression.init(&device);
    defer query_regression.deinit();

    while (!glfw.windowShouldClose(window)) {
        const extent = common.framebufferExtent(window);
        if (extent.isZero()) {
            glfw.pollEvents();
            continue;
        }

        try swapchain.resize(extent);

        var offscreen_command_buffer = try queue.makeCommandBuffer();
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
            .occlusion_query_set = query_regression.visibilitySet(),
        });
        try query_regression.beginPass(&offscreen_encoder);
        try offscreen_encoder.setRenderPipelineState(&offscreen_pipeline);
        try offscreen_encoder.setVertexBuffer(&color_vertex_buffer, .{ .index = 0 });
        try offscreen_encoder.drawPrimitives(.{
            .primitive_type = .triangle,
            .vertex_count = @intCast(color_vertices.len),
        });
        try query_regression.endPass(&offscreen_encoder);
        try offscreen_encoder.endEncoding();
        try offscreen_command_buffer.commit();

        if (pixelRegressionEnabled()) {
            if (try query_regression.validateAndPrepareReuse(&device, &queue)) continue;
            const max_channel_delta = try validateOffscreenPixels(
                allocator,
                &device,
                &queue,
                &offscreen_texture,
            );
            const presentation_max_channel_delta = try validateReferencePresentationPixels(
                allocator,
                &device,
                &queue,
            );
            std.debug.print("render pixel regression ok backend={s} max_channel_delta={} presentation_max_channel_delta={}\n", .{
                @tagName(context.selectedBackend()),
                max_channel_delta,
                presentation_max_channel_delta,
            });
            return;
        }

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
        try screen_command_buffer.presentDrawableWithDescriptor(.{
            .timing = .after_minimum_duration,
            .value_ns = 1_000_000,
            .allow_immediate_fallback = true,
        });
        try screen_command_buffer.commit();

        glfw.pollEvents();
    }
}

const QueryRegression = struct {
    visibility: ?vkmtl.diagnostics.QuerySet = null,
    timestamps: ?vkmtl.diagnostics.QuerySet = null,
    generation: u32 = 0,

    fn init(device: *vkmtl.Device) !QueryRegression {
        if (!queryRegressionEnabled()) return .{};

        var result = QueryRegression{};
        errdefer result.deinit();
        if (device.features().occlusion_queries) {
            result.visibility = try device.makeQuerySet(.{
                .label = "offscreen visibility regression",
                .query_type = .occlusion,
                .count = 2,
                .occlusion_mode = if (device.features().occlusion_counting_queries) .counting else .boolean,
            });
        }
        if (device.nativeFeatures().timestamp_queries) {
            result.timestamps = try device.makeQuerySet(.{
                .label = "offscreen timestamp regression",
                .query_type = .timestamp,
                .count = 2,
            });
            if (result.timestamps.?.resultSource() != .native_gpu) return error.ExpectedNativeGpuTimestamps;
        }
        return result;
    }

    fn deinit(self: *QueryRegression) void {
        if (self.timestamps) |*timestamps| timestamps.deinit();
        if (self.visibility) |*visibility| visibility.deinit();
        self.* = .{};
    }

    fn visibilitySet(self: *QueryRegression) ?*vkmtl.diagnostics.QuerySet {
        if (self.visibility) |*visibility| return visibility;
        return null;
    }

    fn beginPass(
        self: *QueryRegression,
        encoder: *vkmtl.command.RenderCommandEncoder,
    ) !void {
        if (self.timestamps) |*timestamps| try encoder.writeTimestamp(timestamps, 0);
        if (self.visibility) |*visibility| try encoder.beginOcclusionQuery(visibility, 0);
    }

    fn endPass(
        self: *QueryRegression,
        encoder: *vkmtl.command.RenderCommandEncoder,
    ) !void {
        if (self.visibility) |*visibility| {
            try encoder.endOcclusionQuery(visibility);
            try encoder.beginOcclusionQuery(visibility, 1);
            try encoder.endOcclusionQuery(visibility);
        }
        if (self.timestamps) |*timestamps| try encoder.writeTimestamp(timestamps, 1);
    }

    fn validateAndPrepareReuse(
        self: *QueryRegression,
        device: *vkmtl.Device,
        queue: *vkmtl.Queue,
    ) !bool {
        if (self.visibility == null and self.timestamps == null) {
            if (self.generation == 0) {
                std.debug.print("native query regression skipped: selected device exposes no native query lane\n", .{});
                self.generation = 2;
            }
            return false;
        }

        if (self.visibility) |*visibility| {
            const values = try validateQueryReadbackAndResolve(device, queue, visibility);
            if (values[0] == 0) return error.ExpectedVisibleOcclusionResult;
            if (values[1] != 0) return error.ExpectedEmptyOcclusionResult;
            std.debug.print("native occlusion regression ok mode={s} visible={} empty={}\n", .{
                @tagName(visibility.descriptor().occlusion_mode),
                values[0],
                values[1],
            });
        }
        if (self.timestamps) |*timestamps| {
            const values = try validateQueryReadbackAndResolve(device, queue, timestamps);
            if (values[1] <= values[0]) return error.ExpectedMonotonicGpuTimestamps;
            std.debug.print("native timestamp regression ok begin={} end={} source=native_gpu\n", .{ values[0], values[1] });
        }

        if (self.generation == 0) {
            if (self.visibility) |*visibility| visibility.reset();
            if (self.timestamps) |*timestamps| timestamps.reset();
            self.generation = 1;
            return true;
        }
        std.debug.print("native query reset/reuse regression ok\n", .{});
        self.generation = 2;
        return false;
    }
};

fn validateQueryReadbackAndResolve(
    device: *vkmtl.Device,
    queue: *vkmtl.Queue,
    query_set: *vkmtl.diagnostics.QuerySet,
) ![2]u64 {
    var direct = [_]u64{ 0, 0 };
    try query_set.readback(.{
        .first_query = 0,
        .query_count = direct.len,
        .destination = direct[0..],
    });

    var resolve_buffer = try device.makeBuffer(.{
        .label = "native query resolve regression",
        .length = @sizeOf(@TypeOf(direct)),
        .usage = .{ .copy_destination = true },
        .storage_mode = .shared,
    });
    defer resolve_buffer.deinit();

    var command_buffer = try queue.makeCommandBuffer();
    var blit = try command_buffer.makeBlitCommandEncoder();
    try blit.resolveQuerySet(query_set, &resolve_buffer, .{
        .first_query = 0,
        .query_count = direct.len,
    });
    try blit.endEncoding();
    try command_buffer.commit();

    var resolved = [_]u64{ 0, 0 };
    try resolve_buffer.readBytes(0, std.mem.sliceAsBytes(resolved[0..]));
    if (!std.mem.eql(u64, direct[0..], resolved[0..])) return error.QueryResolveMismatch;
    return direct;
}

fn validateOffscreenPixels(
    allocator: std.mem.Allocator,
    device: *vkmtl.Device,
    queue: *vkmtl.Queue,
    texture: *vkmtl.Texture,
) !u8 {
    const tight_bytes_per_row = offscreen_width * 4;
    const row_alignment: usize = @max(
        1,
        @as(usize, device.limits().buffer_texture_copy_row_pitch_alignment),
    );
    const bytes_per_row = std.mem.alignForward(usize, tight_bytes_per_row, row_alignment);
    const readback_len = bytes_per_row * offscreen_height;

    var readback = try device.makeBuffer(.{
        .label = "offscreen pixel regression readback",
        .length = readback_len,
        .usage = .{ .copy_destination = true },
        .storage_mode = .shared,
    });
    defer readback.deinit();

    var command_buffer = try queue.makeCommandBuffer();
    var blit = try command_buffer.makeBlitCommandEncoder();
    try blit.copyTextureToBuffer(texture, &readback, .{
        .source_region = .{ .size = .{
            .width = offscreen_width,
            .height = offscreen_height,
        } },
        .destination = .{ .bytes_per_row = bytes_per_row },
    });
    try blit.endEncoding();
    try command_buffer.commit();

    const bytes = try allocator.alloc(u8, readback_len);
    defer allocator.free(bytes);
    try readback.readBytes(0, bytes);

    var max_channel_delta: u8 = 0;
    max_channel_delta = @max(max_channel_delta, try validatePixel(
        pixelSlice(bytes, bytes_per_row, 8, 8),
        .{ 5, 6, 9, 255 },
        2,
    ));
    max_channel_delta = @max(max_channel_delta, try validatePixel(
        pixelSlice(bytes, bytes_per_row, offscreen_width / 2, offscreen_height / 2),
        .{ 143, 116, 118, 255 },
        12,
    ));
    return max_channel_delta;
}

fn validateReferencePresentationPixels(
    allocator: std.mem.Allocator,
    device: *vkmtl.Device,
    queue: *vkmtl.Queue,
) !u8 {
    var source_texture = try device.makeTexture(.{
        .label = "reference presentation source",
        .format = .rgba16_float,
        .width = presentation_regression_width,
        .height = presentation_regression_height,
        .usage = .{ .shader_read = true },
        .storage_mode = .shared,
    });
    defer source_texture.deinit();
    try source_texture.replaceAll2D(.{
        .bytes = std.mem.sliceAsBytes(presentation_source_pixels[0..]),
    });

    var source_view = try source_texture.makeTextureView(.{});
    defer source_view.deinit();

    var target_texture = try device.makeTexture(.{
        .label = "reference presentation sRGB target",
        .format = .bgra8_unorm_srgb,
        .width = presentation_regression_width,
        .height = presentation_regression_height,
        .usage = .{
            .copy_source = true,
            .render_attachment = true,
        },
        .storage_mode = .private,
    });
    defer target_texture.deinit();

    var target_view = try target_texture.makeTextureView(.{});
    defer target_view.deinit();

    var compiled_shader = try device.compileRenderShader(
        "ray_traced_scene_present",
        reference_present_shader_source,
        .{
            .vertex_entry = "present_vs",
            .fragment_entry = "present_fs",
        },
    );
    defer compiled_shader.deinit();

    const stages = compiled_shader.stageDescriptors(device.selectedBackend());
    var derived_layouts = try vkmtl.shader.Reflection.deriveRenderPipelineBindGroupLayouts(
        allocator,
        stages.vertex,
        stages.fragment,
    );
    defer derived_layouts.deinit();
    if (derived_layouts.descriptors().len != 1) return error.MissingDerivedBindGroupLayout;

    var bind_group_layout = try device.makeBindGroupLayout(derived_layouts.descriptors()[0]);
    defer bind_group_layout.deinit();
    var sampler = try device.makeSamplerState(.{
        .min_filter = .nearest,
        .mag_filter = .nearest,
    });
    defer sampler.deinit();

    const bind_group_entries = [_]vkmtl.BindGroupEntry{
        .{
            .binding = 0,
            .resource = .{ .sampled_texture = &source_view },
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

    const bind_group_layouts = [_]vkmtl.BindGroupLayoutDescriptor{
        bind_group_layout.descriptor(),
    };
    var pipeline = try device.makeRenderPipelineState(.{
        .label = "reference presentation regression",
        .vertex = stages.vertex,
        .fragment = stages.fragment,
        .bind_group_layouts = bind_group_layouts[0..],
        .primitive_topology = .triangle,
        .color_attachments = screen_color_attachments[0..],
    });
    defer pipeline.deinit();

    var render_commands = try queue.makeCommandBuffer();
    var render_encoder = try render_commands.makeRenderCommandEncoder(.{
        .color_attachments = &.{.{
            .target = .{ .texture_view = &target_view },
            .clear_color = .{ .alpha = 1.0 },
        }},
    });
    try render_encoder.setRenderPipelineState(&pipeline);
    try render_encoder.setBindGroup(&bind_group, .{ .index = 0 });
    try render_encoder.drawPrimitives(.{
        .primitive_type = .triangle,
        .vertex_count = 3,
    });
    try render_encoder.endEncoding();
    try render_commands.commit();

    const tight_bytes_per_row = presentation_regression_width * 4;
    const row_alignment: usize = @max(
        1,
        @as(usize, device.limits().buffer_texture_copy_row_pitch_alignment),
    );
    const bytes_per_row = std.mem.alignForward(usize, tight_bytes_per_row, row_alignment);
    const readback_len = bytes_per_row * presentation_regression_height;

    var readback = try device.makeBuffer(.{
        .label = "reference presentation readback",
        .length = readback_len,
        .usage = .{ .copy_destination = true },
        .storage_mode = .shared,
    });
    defer readback.deinit();

    var copy_commands = try queue.makeCommandBuffer();
    var blit = try copy_commands.makeBlitCommandEncoder();
    try blit.copyTextureToBuffer(&target_texture, &readback, .{
        .source_region = .{ .size = .{
            .width = presentation_regression_width,
            .height = presentation_regression_height,
        } },
        .destination = .{ .bytes_per_row = bytes_per_row },
    });
    try blit.endEncoding();
    try copy_commands.commit();

    const bytes = try allocator.alloc(u8, readback_len);
    defer allocator.free(bytes);
    try readback.readBytes(0, bytes);

    const expected_pixels = [_][4]u8{
        .{ 0, 0, 0, 255 },
        .{ 46, 46, 46, 255 },
        .{ 128, 128, 128, 255 },
        .{ 0, 204, 255, 255 },
        .{ 255, 0, 0, 255 },
    };
    var max_channel_delta: u8 = 0;
    for (expected_pixels, 0..) |expected, x| {
        max_channel_delta = @max(max_channel_delta, try validatePixel(
            pixelSlice(bytes, bytes_per_row, x, 0),
            expected,
            1,
        ));
    }
    return max_channel_delta;
}

fn pixelSlice(bytes: []const u8, bytes_per_row: usize, x: usize, y: usize) []const u8 {
    const offset = y * bytes_per_row + x * 4;
    return bytes[offset .. offset + 4];
}

fn validatePixel(actual: []const u8, expected: [4]u8, tolerance: u8) !u8 {
    var max_delta: u8 = 0;
    for (actual, expected) |actual_channel, expected_channel| {
        const delta = if (actual_channel >= expected_channel)
            actual_channel - expected_channel
        else
            expected_channel - actual_channel;
        max_delta = @max(max_delta, delta);
        if (delta > tolerance) return error.RenderPixelMismatch;
    }
    return max_delta;
}

fn pixelRegressionEnabled() bool {
    const value = std.mem.span(getenv("VKMTL_PIXEL_REGRESSION") orelse return false);
    return std.mem.eql(u8, value, "1") or std.ascii.eqlIgnoreCase(value, "true");
}

fn queryRegressionEnabled() bool {
    const value = std.mem.span(getenv("VKMTL_QUERY_REGRESSION") orelse return false);
    return std.mem.eql(u8, value, "1") or std.ascii.eqlIgnoreCase(value, "true");
}

fn offscreenPipelineDescriptor(
    vertex_stage: vkmtl.ProgrammableStageDescriptor,
    fragment_stage: vkmtl.ProgrammableStageDescriptor,
    vertex_descriptor: vkmtl.VertexDescriptor,
) vkmtl.RenderPipelineDescriptor {
    var specialized_fragment = fragment_stage;
    specialized_fragment.specialization = .{
        .constants = offscreen_specialization_constants[0..],
    };
    return .{
        .vertex = vertex_stage,
        .fragment = specialized_fragment,
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
