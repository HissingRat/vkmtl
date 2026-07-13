const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

extern fn getenv(name: [*:0]const u8) ?[*:0]u8;

const app_name = "vkmtl bindless textures";
const shader_source = @embedFile("shaders/bindless_textures.slang");
const table_size = 64;

const color_attachments = [_]vkmtl.RenderPipelineColorAttachmentDescriptor{
    .{ .format = .bgra8_unorm_srgb },
};

pub fn main(_: std.process.Init.Minimal) !void {
    try glfw.init();
    defer glfw.terminate();

    const window = try glfw.createWindow(.{
        .width = 640,
        .height = 480,
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

    var device = context.device();
    var queue = context.queue();
    var swapchain = context.swapchain();
    const backend = device.selectedBackend();
    const model: vkmtl.binding.AdvancedBindingModel = switch (backend) {
        .vulkan => .descriptor_indexing,
        .metal => .argument_buffer,
    };

    const ranges = [_]vkmtl.binding.DescriptorIndexingRange{
        .{
            .binding = 0,
            .resource = .sampled_texture,
            .visibility = .{ .fragment = true },
            .descriptor_count = table_size,
        },
        .{
            .binding = 1,
            .resource = .sampler,
            .visibility = .{ .fragment = true },
        },
    };
    const table_layout_descriptor = vkmtl.binding.DescriptorIndexingLayoutDescriptor{
        .label = "bindless texture table layout",
        .model = model,
        .ranges = &ranges,
    };
    var table_layout = device.makeAdvancedBindGroupLayout(table_layout_descriptor) catch |err| {
        std.debug.print("bindless textures unsupported: {s}\n", .{@errorName(err)});
        return;
    };
    defer table_layout.deinit();

    var texture = try device.makeTexture(.{
        .label = "bindless sample texel",
        .format = .rgba8_unorm,
        .width = 1,
        .height = 1,
        .usage = .{ .shader_read = true },
        .storage_mode = .shared,
    });
    defer texture.deinit();
    try texture.replaceAll2D(.{ .bytes = &.{ 38, 205, 255, 255 } });
    var texture_view = try texture.makeTextureView(.{ .label = "bindless sample view" });
    defer texture_view.deinit();

    var table = try device.makeResourceTable(.{
        .label = "bindless texture table",
        .layout = &table_layout,
    });
    defer table.deinit();
    for (0..table_size) |index| {
        try table.update(.{
            .slot = .{ .binding = 0, .array_element = @intCast(index) },
            .resource = .{ .sampled_texture = &texture_view },
        });
    }
    var sampler = try device.makeSamplerState(.{
        .label = "bindless sampler",
        .min_filter = .nearest,
        .mag_filter = .nearest,
    });
    defer sampler.deinit();
    try table.update(.{
        .slot = .{ .binding = 1 },
        .resource = .{ .sampler = &sampler },
    });

    var compiled_shader = try device.compileRenderShader("bindless_textures", shader_source, .{
        .vertex_entry = "vs_main",
        .fragment_entry = "fs_main",
    });
    defer compiled_shader.deinit();
    const compiled_stages = compiled_shader.stageDescriptors(backend);
    var vertex_stage = compiled_stages.vertex;
    var fragment_stage = compiled_stages.fragment;
    vertex_stage.reflection = null;
    fragment_stage.reflection = null;

    const table_layouts = [_]vkmtl.binding.DescriptorIndexingLayoutDescriptor{table_layout_descriptor};
    const driver_cache = driverCacheDescriptor(device);
    var pipeline = try device.makeRenderPipelineState(.{
        .label = "bindless indirect pipeline",
        .vertex = vertex_stage,
        .fragment = fragment_stage,
        .resource_table_layouts = &table_layouts,
        .primitive_topology = .triangle,
        .color_attachments = &color_attachments,
        .driver_cache = driver_cache,
    });
    defer pipeline.deinit();

    var indirect = try vkmtl.command.makeIndirectCommandBuffer(&device, .{
        .label = "bindless draw list",
        .kind = .render,
        .max_command_count = 1,
    });
    defer indirect.deinit();
    try indirect.encodeDrawPrimitives(0, .{
        .primitive_type = .triangle,
        .vertex_count = 3,
    });

    const single_frame = getenv("VKMTL_PIXEL_REGRESSION") != null;
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
                .clear_color = .{ .red = 0.02, .green = 0.03, .blue = 0.05, .alpha = 1.0 },
            }},
        });
        try encoder.setRenderPipelineState(&pipeline);
        try encoder.setResourceTable(&table, .{ .index = 0 });
        try encoder.executeIndirectCommands(&indirect, .{ .count = 1 });
        try encoder.endEncoding();
        try command_buffer.presentDrawable();
        try command_buffer.commit();

        glfw.pollEvents();
        if (single_frame) break;
    }

    std.debug.print("bindless texture execution ok: backend={s}, model={s}, slots={}, indirect={}, cache={s}\n", .{
        @tagName(backend),
        @tagName(model),
        table.slotCount(),
        indirect.encodedCommandCount(),
        if (driver_cache != null) "persistent" else "unavailable",
    });
}

fn driverCacheDescriptor(device: vkmtl.Device) ?vkmtl.diagnostics.DriverPipelineCacheDescriptor {
    const backend = device.selectedBackend();
    const features = device.features();
    const supported = switch (backend) {
        .vulkan => features.driver_pipeline_cache,
        .metal => features.metal_binary_archive,
    };
    if (!supported) return null;
    return .{
        .path = switch (backend) {
            .vulkan => "zig-out/cache/bindless-textures.vkpc",
            .metal => "zig-out/cache/bindless-textures.metallibarchive",
        },
        .kind = switch (backend) {
            .vulkan => .vulkan_pipeline_cache,
            .metal => .metal_binary_archive,
        },
        .identity = .{
            .backend = backend,
            .device_id = device.adapterInfo().name,
            .driver_id = @tagName(backend),
            .shader_hash = "bindless-textures-v3",
            .schema_version = "1",
        },
    };
}

fn backendOverrideFromEnv() ?vkmtl.Backend {
    const value = std.mem.span(getenv("VKMTL_BACKEND") orelse return null);
    if (std.ascii.eqlIgnoreCase(value, "vulkan")) return .vulkan;
    if (std.ascii.eqlIgnoreCase(value, "metal")) return .metal;
    return null;
}
