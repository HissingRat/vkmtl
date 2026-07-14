const std = @import("std");
const vkmtl = @import("vkmtl");

extern fn getenv(name: [*:0]const u8) ?[*:0]u8;

const app_name = "vkmtl compute readback";
const shader_source = @embedFile("shaders/compute_readback.slang");
const value_count = 4;
const texture_width = 2;
const texture_height = 2;
const texture_pixels_len = texture_width * texture_height * 4;

pub fn main(_: std.process.Init.Minimal) !void {
    var debug_allocator = std.heap.DebugAllocator(.{}){};
    defer _ = debug_allocator.deinit();
    const allocator = debug_allocator.allocator();

    var context = try vkmtl.HeadlessContext.init(allocator, .{
        .app_name = app_name,
        .backend = .auto,
        .debug_backend_override = backendOverrideFromEnv(),
    });
    defer context.deinit();
    std.debug.print("Using backend: {}\n", .{context.selectedBackend()});

    var device = context.device();
    var queue = context.queue();
    const features = device.features();
    const limits = device.limits();
    if (!features.compute_atomics) return error.ComputeAtomicsUnavailable;
    if (!features.compute_threadgroup_memory) return error.ComputeThreadgroupMemoryUnavailable;
    try (vkmtl.compute.ComputeAtomicDescriptor{
        .operations = .{ .add = true },
    }).validate(features);
    try (vkmtl.compute.ThreadgroupMemoryDescriptor{
        .bytes = 2 * @sizeOf(u32),
        .alignment = @sizeOf(u32),
    }).validate(features, limits);

    var output_buffer = try device.makeBuffer(.{
        .length = value_count * @sizeOf(u32),
        .usage = .{
            .copy_source = true,
            .storage = true,
        },
        .storage_mode = .private,
    });
    defer output_buffer.deinit();

    var readback_buffer = try device.makeBuffer(.{
        .length = value_count * @sizeOf(u32),
        .usage = .{ .copy_destination = true },
        .storage_mode = .shared,
    });
    defer readback_buffer.deinit();

    var output_texture = try device.makeTexture(.{
        .format = .rgba8_unorm,
        .width = texture_width,
        .height = texture_height,
        .usage = .{
            .copy_source = true,
            .shader_read = true,
            .shader_write = true,
        },
        .storage_mode = .private,
    });
    defer output_texture.deinit();

    var output_texture_view = try output_texture.makeTextureView(.{});
    defer output_texture_view.deinit();

    var texture_readback = try device.makeBuffer(.{
        .length = texture_pixels_len,
        .usage = .{ .copy_destination = true },
        .storage_mode = .shared,
    });
    defer texture_readback.deinit();

    var compiled_shader = try device.compileComputeShader("compute_readback", shader_source, .{
        .entry = "cs_main",
    });
    defer compiled_shader.deinit();

    const compute_stage = compiled_shader.stageDescriptor(context.selectedBackend());
    var derived_bind_group_layouts = try vkmtl.shader.Reflection.deriveComputePipelineBindGroupLayouts(
        allocator,
        compute_stage,
    );
    defer derived_bind_group_layouts.deinit();
    if (derived_bind_group_layouts.descriptors().len == 0) return error.MissingDerivedBindGroupLayout;

    var bind_group_layout = try device.makeBindGroupLayout(derived_bind_group_layouts.descriptors()[0]);
    defer bind_group_layout.deinit();

    const bind_group_entries = [_]vkmtl.BindGroupEntry{
        .{
            .binding = 0,
            .resource = .{ .storage_texture = &output_texture_view },
        },
        .{
            .binding = 1,
            .resource = .{ .storage_buffer = .{
                .buffer = &output_buffer,
                .size = value_count * @sizeOf(u32),
            } },
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
    var pipeline = try device.makeComputePipelineState(.{
        .compute = compute_stage,
        .bind_group_layouts = pipeline_bind_group_layouts[0..],
    });
    defer pipeline.deinit();

    var compute_command_buffer = try queue.makeCommandBuffer();
    var compute = try compute_command_buffer.makeComputeCommandEncoder();
    try compute.setComputePipelineState(&pipeline);
    try compute.setBindGroup(&bind_group, .{ .index = 0 });
    try compute.dispatchThreadgroups(.{
        .threadgroup_count_x = 1,
        .threads_per_threadgroup_x = value_count,
    });
    try compute.endEncoding();
    try compute_command_buffer.commit();

    var copy_command_buffer = try queue.makeCommandBuffer();
    var blit = try copy_command_buffer.makeBlitCommandEncoder();
    try blit.copyBufferToBuffer(&output_buffer, &readback_buffer, .{
        .size = value_count * @sizeOf(u32),
    });
    try blit.copyTextureToBuffer(&output_texture, &texture_readback, .{
        .source_region = .{ .size = .{ .width = texture_width, .height = texture_height } },
    });
    try blit.endEncoding();
    try copy_command_buffer.commit();

    const expected_values = [_]u32{ 27, 30, 33, 36 };
    var copied: [value_count * @sizeOf(u32)]u8 = undefined;
    try readback_buffer.readBytes(0, copied[0..]);
    if (!std.mem.eql(u8, std.mem.asBytes(&expected_values), copied[0..])) {
        return error.ComputeReadbackMismatch;
    }

    const expected_pixels = [_]u8{
        0xff, 0x00, 0x00, 0xff,
        0x00, 0xff, 0x00, 0xff,
        0x00, 0x00, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff,
    };
    var copied_texture: [texture_pixels_len]u8 = undefined;
    try texture_readback.readBytes(0, copied_texture[0..]);
    if (!std.mem.eql(u8, expected_pixels[0..], copied_texture[0..])) {
        return error.ComputeTextureReadbackMismatch;
    }

    std.debug.print("compute readback ok\n", .{});
}

fn backendOverrideFromEnv() ?vkmtl.Backend {
    const value = std.mem.span(getenv("VKMTL_BACKEND") orelse return null);
    if (std.ascii.eqlIgnoreCase(value, "vulkan")) return .vulkan;
    if (std.ascii.eqlIgnoreCase(value, "metal")) return .metal;

    std.debug.print("Ignoring unsupported VKMTL_BACKEND value: {s}\n", .{value});
    return null;
}
