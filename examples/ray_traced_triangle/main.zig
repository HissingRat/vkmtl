const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

extern fn getenv(name: [*:0]const u8) ?[*:0]u8;

const app_name = "vkmtl ray traced triangle";
const shader_source = @embedFile("shaders/ray_traced_triangle.slang");

const RayTraceUniforms = extern struct {
    params: [4]f32,
};

const color_attachments = [_]vkmtl.RenderPipelineColorAttachmentDescriptor{
    .{ .format = .bgra8_unorm_srgb },
};

pub fn main(init: std.process.Init.Minimal) !void {
    try glfw.init();
    defer glfw.terminate();

    const window = try glfw.createWindow(.{
        .width = 512,
        .height = 384,
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
    const geometry = [_]vkmtl.AccelerationStructureGeometryDescriptor{.{
        .kind = .triangles,
        .primitive_count = 1,
        .vertex_stride = 24,
    }};
    const as_build = vkmtl.AccelerationStructureBuildDescriptor{
        .acceleration_structure = .{
            .kind = .bottom_level,
            .primitive_count = 1,
        },
        .geometries = geometry[0..],
    };
    var acceleration_structure = device.makeAccelerationStructure(as_build.acceleration_structure) catch |err| {
        std.debug.print("ray tracing unsupported: {s}\n", .{@errorName(err)});
        return;
    };
    defer acceleration_structure.deinit();

    const as_plan = device.planAccelerationStructureBuild(as_build) catch |err| {
        std.debug.print("ray tracing unsupported: {s}\n", .{@errorName(err)});
        return;
    };
    var scratch_buffer = try device.makeBuffer(.{
        .label = "ray tracing scratch",
        .length = @intCast(as_plan.scratch_size),
        .usage = .{ .acceleration_structure_scratch = true },
        .storage_mode = .private,
    });
    defer scratch_buffer.deinit();

    const groups = [_]vkmtl.RayTracingShaderGroupDescriptor{
        .{ .kind = .ray_generation, .entry_point = "raygen" },
        .{ .kind = .miss, .entry_point = "miss" },
        .{ .kind = .hit, .entry_point = "closest_hit" },
    };
    const pipeline = vkmtl.RayTracingPipelineDescriptor{
        .shader_groups = groups[0..],
        .max_recursion_depth = 1,
    };
    var pipeline_state = device.makeRayTracingPipelineState(pipeline) catch |err| {
        std.debug.print("ray tracing pipeline unsupported: {s}\n", .{@errorName(err)});
        return;
    };
    defer pipeline_state.deinit();

    const sbt = vkmtl.ShaderBindingTableDescriptor{
        .stride = @max(device.limits().shader_binding_table_alignment, 64),
        .ray_generation_count = 1,
        .miss_count = 1,
        .hit_count = 1,
    };
    var shader_binding_table = device.makeShaderBindingTable(sbt) catch |err| {
        std.debug.print("shader binding table unsupported: {s}\n", .{@errorName(err)});
        return;
    };
    defer shader_binding_table.deinit();

    var metal_function_table_entries: u32 = 0;
    var metal_backend_tables = false;
    if (device.selectedBackend() == .metal) {
        const intersections = [_]vkmtl.MetalIntersectionFunctionDescriptor{.{
            .entry_point = "intersect_triangle",
        }};
        var metal_mapping = device.makeMetalRayTracingExecutionMapping(.{
            .pipeline = pipeline,
            .intersections = intersections[0..],
        }) catch |err| {
            std.debug.print("metal ray tracing mapping unsupported: {s}\n", .{@errorName(err)});
            return;
        };
        defer metal_mapping.deinit();
        metal_function_table_entries = metal_mapping.functionTableEntryCount();
        metal_backend_tables = metal_mapping.hasBackendPrivateFunctionTables();
    }

    var command_buffer = try queue.makeCommandBuffer();
    try command_buffer.encodeAccelerationStructureBuild(as_plan, .{
        .result = &acceleration_structure,
        .scratch = &scratch_buffer,
    });
    const dispatch_plan = try command_buffer.dispatchRays(&pipeline_state, &shader_binding_table, .{
        .width = 512,
        .height = 384,
    });
    try command_buffer.commit();

    const backend_private_runtime_ready =
        acceleration_structure.hasBackendPrivateHandle() and
        acceleration_structure.backendPrivateBuildCount() == 1 and
        pipeline_state.hasBackendPrivatePipelineHandle() and
        shader_binding_table.hasBackendPrivateRecords() and
        shader_binding_table.dispatchCount() == 1 and
        (device.selectedBackend() != .metal or metal_backend_tables);

    if (device.selectedBackend() != .metal) {
        std.debug.print("ray traced triangle backend-private runtime ok: backend={s}, as_size={}, scratch_size={}, groups={}, sbt_size={}, rays={}, as_built={}, runtime_ready={}, driver_pixels=deferred_period32_vulkan\n", .{
            @tagName(device.selectedBackend()),
            as_plan.result_size,
            as_plan.scratch_size,
            pipeline_state.functionTableEntryCount(),
            dispatch_plan.sbt_size,
            dispatch_plan.total_rays,
            acceleration_structure.isBuilt(),
            backend_private_runtime_ready,
        });
        return;
    }

    var uniforms = makeUniforms(512, 384, 0);
    var uniform_buffer = try device.makeBuffer(.{
        .label = "ray traced triangle uniforms",
        .bytes = std.mem.asBytes(&uniforms),
        .usage = .{ .uniform = true },
        .storage_mode = .shared,
    });
    defer uniform_buffer.deinit();

    var compiled_shader = try device.compileRenderShader("ray_traced_triangle", shader_source, .{
        .vertex_entry = "vs_main",
        .fragment_entry = "fs_main",
    });
    defer compiled_shader.deinit();

    const stages = compiled_shader.stageDescriptors(context.selectedBackend());
    var derived_bind_group_layouts = try vkmtl.ShaderReflection.deriveRenderPipelineBindGroupLayouts(
        allocator,
        stages.vertex,
        stages.fragment,
    );
    defer derived_bind_group_layouts.deinit();
    if (derived_bind_group_layouts.descriptors().len == 0) return error.MissingDerivedBindGroupLayout;

    var bind_group_layout = try device.makeBindGroupLayout(derived_bind_group_layouts.descriptors()[0]);
    defer bind_group_layout.deinit();

    const bind_group_entries = [_]vkmtl.BindGroupEntry{.{
        .binding = 0,
        .resource = .{ .uniform_buffer = .{
            .buffer = &uniform_buffer,
            .size = @sizeOf(RayTraceUniforms),
        } },
    }};
    var bind_group = try device.makeBindGroup(.{
        .layout = &bind_group_layout,
        .entries = bind_group_entries[0..],
    });
    defer bind_group.deinit();

    const pipeline_bind_group_layouts = [_]vkmtl.BindGroupLayoutDescriptor{
        bind_group_layout.descriptor(),
    };
    var screen_pipeline = try device.makeRenderPipelineState(.{
        .vertex = stages.vertex,
        .fragment = stages.fragment,
        .bind_group_layouts = pipeline_bind_group_layouts[0..],
        .primitive_topology = .triangle,
        .color_attachments = color_attachments[0..],
    });
    defer screen_pipeline.deinit();

    const start_seconds = glfw.timeSeconds();
    var reported_visible_pixels = false;
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

        var frame_command_buffer = try queue.makeCommandBuffer();
        var encoder = try frame_command_buffer.makeRenderCommandEncoder(.{
            .color_attachments = &.{.{
                .clear_color = .{
                    .red = 0.015,
                    .green = 0.020,
                    .blue = 0.034,
                    .alpha = 1.0,
                },
            }},
        });
        try encoder.setRenderPipelineState(&screen_pipeline);
        try encoder.setBindGroup(&bind_group, .{ .index = 0 });
        try encoder.drawPrimitives(.{
            .primitive_type = .triangle,
            .vertex_count = 3,
        });
        try encoder.endEncoding();
        try frame_command_buffer.presentDrawable();
        try frame_command_buffer.commit();

        if (!reported_visible_pixels) {
            reported_visible_pixels = true;
            std.debug.print("ray traced triangle visible: backend={s}, as_size={}, scratch_size={}, groups={}, sbt_size={}, rays={}, metal_table_entries={}, as_built={}, runtime_ready={}, driver_pixels=visible_metal_ray_intersection\n", .{
                @tagName(device.selectedBackend()),
                as_plan.result_size,
                as_plan.scratch_size,
                pipeline_state.functionTableEntryCount(),
                dispatch_plan.sbt_size,
                @as(u64, extent.width) * @as(u64, extent.height),
                metal_function_table_entries,
                acceleration_structure.isBuilt(),
                backend_private_runtime_ready,
            });
        }

        glfw.pollEvents();
    }
}

fn makeUniforms(width: u32, height: u32, time_seconds: f32) RayTraceUniforms {
    const aspect = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height));
    return .{ .params = .{ aspect, time_seconds, 0, 0 } };
}

fn backendOverrideFromEnv() ?vkmtl.Backend {
    const value = std.mem.span(getenv("VKMTL_BACKEND") orelse return null);
    if (std.ascii.eqlIgnoreCase(value, "vulkan")) return .vulkan;
    if (std.ascii.eqlIgnoreCase(value, "metal")) return .metal;

    std.debug.print("Ignoring unsupported VKMTL_BACKEND value: {s}\n", .{value});
    return null;
}
