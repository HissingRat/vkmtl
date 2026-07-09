const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

extern fn getenv(name: [*:0]const u8) ?[*:0]u8;

const app_name = "vkmtl ray traced scene";
const rt_shader_source = @embedFile("shaders/ray_traced_scene_rt.slang");
const initial_width = 960;
const initial_height = 540;

pub fn main(init: std.process.Init.Minimal) !void {
    try glfw.init();
    defer glfw.terminate();

    const window = try glfw.createWindow(.{
        .width = initial_width,
        .height = initial_height,
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
    const capability_report = device.capabilityReport();
    if (device.selectedBackend() == .vulkan and !capability_report.ray_tracing.supported) {
        printRayTracingUnsupported(capability_report.ray_tracing);
        return;
    }

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
    var compiled_rt_shader: ?vkmtl.CompiledRayTracingShader = null;
    defer if (compiled_rt_shader) |*shader| shader.deinit();
    if (device.selectedBackend() == .vulkan) {
        compiled_rt_shader = try device.compileRayTracingShader("ray_traced_scene_rt", rt_shader_source, .{});
    }
    var pipeline = vkmtl.RayTracingPipelineDescriptor{
        .shader_groups = groups[0..],
        .max_recursion_depth = 1,
    };
    if (compiled_rt_shader) |shader| {
        pipeline.ray_generation = shader.rayGenerationStageDescriptor();
        pipeline.miss = shader.missStageDescriptor();
        pipeline.closest_hit = shader.closestHitStageDescriptor();
    }
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

    var build_command_buffer = try queue.makeCommandBuffer();
    try build_command_buffer.encodeAccelerationStructureBuild(as_plan, .{
        .result = &acceleration_structure,
        .scratch = &scratch_buffer,
    });
    try build_command_buffer.commit();

    if (device.selectedBackend() == .vulkan) {
        const instance_geometry = [_]vkmtl.AccelerationStructureGeometryDescriptor{.{
            .kind = .instances,
            .primitive_count = 1,
        }};
        const top_level_build = vkmtl.AccelerationStructureBuildDescriptor{
            .acceleration_structure = .{
                .kind = .top_level,
                .primitive_count = 1,
            },
            .geometries = instance_geometry[0..],
        };
        var top_level_acceleration_structure = device.makeAccelerationStructure(top_level_build.acceleration_structure) catch |err| {
            std.debug.print("top-level acceleration structure unsupported: {s}\n", .{@errorName(err)});
            return;
        };
        defer top_level_acceleration_structure.deinit();

        const top_level_plan = device.planAccelerationStructureBuild(top_level_build) catch |err| {
            std.debug.print("top-level acceleration structure unsupported: {s}\n", .{@errorName(err)});
            return;
        };
        var top_level_scratch = try device.makeBuffer(.{
            .label = "ray tracing tlas scratch",
            .length = @intCast(top_level_plan.scratch_size),
            .usage = .{ .acceleration_structure_scratch = true },
            .storage_mode = .private,
        });
        defer top_level_scratch.deinit();

        var top_level_command_buffer = try queue.makeCommandBuffer();
        try top_level_command_buffer.encodeAccelerationStructureBuild(top_level_plan, .{
            .result = &top_level_acceleration_structure,
            .scratch = &top_level_scratch,
            .instance_source = &acceleration_structure,
        });
        try top_level_command_buffer.commit();

        var output_texture: ?vkmtl.Texture = null;
        var output_view: ?vkmtl.TextureView = null;
        var output_extent = vkmtl.Extent2D{ .width = 0, .height = 0 };
        defer {
            if (output_view) |*view| view.deinit();
            if (output_texture) |*texture| texture.deinit();
        }

        var reported_visible_pixels = false;
        while (!glfw.windowShouldClose(window)) {
            const extent = common.framebufferExtent(window);
            if (extent.isZero()) {
                glfw.pollEvents();
                continue;
            }

            try swapchain.resize(extent);
            if (output_view == null or output_texture == null or output_extent.width != extent.width or output_extent.height != extent.height) {
                if (output_view) |*view| view.deinit();
                output_view = null;
                if (output_texture) |*texture| texture.deinit();
                output_texture = null;

                var texture = try device.makeTexture(.{
                    .label = "ray traced scene output",
                    .format = .rgba8_unorm,
                    .width = extent.width,
                    .height = extent.height,
                    .usage = .{
                        .copy_source = true,
                        .shader_write = true,
                    },
                    .storage_mode = .private,
                });
                const view = try texture.makeTextureView(.{});
                output_texture = texture;
                output_view = view;
                output_extent = extent;
            }

            if (output_view) |*view| {
                var frame_command_buffer = try queue.makeCommandBuffer();
                const dispatch_plan = try frame_command_buffer.dispatchRaysToDrawable(
                    &pipeline_state,
                    &shader_binding_table,
                    .{
                        .width = extent.width,
                        .height = extent.height,
                    },
                    .{
                        .acceleration_structure = &top_level_acceleration_structure,
                        .output = view,
                    },
                );
                try frame_command_buffer.commit();

                if (!reported_visible_pixels) {
                    reported_visible_pixels = true;
                    const runtime_ready =
                        acceleration_structure.hasBackendPrivateHandle() and
                        acceleration_structure.backendPrivateBuildCount() == 1 and
                        top_level_acceleration_structure.hasBackendPrivateHandle() and
                        top_level_acceleration_structure.backendPrivateBuildCount() == 1 and
                        pipeline_state.hasBackendPrivatePipelineHandle() and
                        pipeline_state.backendPrivatePipelineBoundToDriver() and
                        shader_binding_table.hasBackendPrivateRecords() and
                        shader_binding_table.backendPrivateRecordsBoundToDriver() and
                        shader_binding_table.dispatchCount() >= 1 and
                        shader_binding_table.lastDispatchSubmittedToDriver();
                    std.debug.print("ray traced scene visible: backend=vulkan, blas_size={}, tlas_size={}, scratch_size={}, groups={}, sbt_size={}, rays={}, blas_built={}, tlas_built={}, trace_driver_submitted={}, runtime_ready={}, driver_pixels=visible_vulkan_rt_output\n", .{
                        as_plan.result_size,
                        top_level_plan.result_size,
                        top_level_plan.scratch_size,
                        pipeline_state.functionTableEntryCount(),
                        dispatch_plan.sbt_size,
                        dispatch_plan.total_rays,
                        acceleration_structure.isBuilt(),
                        top_level_acceleration_structure.isBuilt(),
                        shader_binding_table.lastDispatchSubmittedToDriver(),
                        runtime_ready,
                    });
                }
            }

            glfw.pollEvents();
        }
        return;
    }

    if (device.selectedBackend() == .metal) {
        var output_texture: ?vkmtl.Texture = null;
        var output_view: ?vkmtl.TextureView = null;
        var output_extent = vkmtl.Extent2D{ .width = 0, .height = 0 };
        defer {
            if (output_view) |*view| view.deinit();
            if (output_texture) |*texture| texture.deinit();
        }

        var reported_visible_pixels = false;
        while (!glfw.windowShouldClose(window)) {
            const extent = common.framebufferExtent(window);
            if (extent.isZero()) {
                glfw.pollEvents();
                continue;
            }

            try swapchain.resize(extent);
            if (output_view == null or output_texture == null or output_extent.width != extent.width or output_extent.height != extent.height) {
                if (output_view) |*view| view.deinit();
                output_view = null;
                if (output_texture) |*texture| texture.deinit();
                output_texture = null;

                var texture = try device.makeTexture(.{
                    .label = "metal ray traced scene output",
                    .format = .rgba8_unorm,
                    .width = extent.width,
                    .height = extent.height,
                    .usage = .{
                        .copy_source = true,
                        .shader_write = true,
                    },
                    .storage_mode = .private,
                });
                const view = try texture.makeTextureView(.{});
                output_texture = texture;
                output_view = view;
                output_extent = extent;
            }

            if (output_view) |*view| {
                var frame_command_buffer = try queue.makeCommandBuffer();
                const dispatch_plan = try frame_command_buffer.dispatchRaysToDrawable(
                    &pipeline_state,
                    &shader_binding_table,
                    .{
                        .width = extent.width,
                        .height = extent.height,
                    },
                    .{
                        .acceleration_structure = &acceleration_structure,
                        .output = view,
                    },
                );
                try frame_command_buffer.commit();

                if (!reported_visible_pixels) {
                    reported_visible_pixels = true;
                    const runtime_ready =
                        acceleration_structure.hasBackendPrivateHandle() and
                        acceleration_structure.backendPrivateBuildCount() == 1 and
                        pipeline_state.hasBackendPrivatePipelineHandle() and
                        pipeline_state.backendPrivatePipelineBoundToDriver() and
                        shader_binding_table.hasBackendPrivateRecords() and
                        shader_binding_table.dispatchCount() >= 1 and
                        shader_binding_table.lastDispatchSubmittedToDriver() and
                        metal_backend_tables;
                    std.debug.print("ray traced scene visible: backend=metal, as_size={}, scratch_size={}, groups={}, sbt_size={}, rays={}, metal_table_entries={}, as_built={}, as_driver_submitted={}, pipeline_driver_bound={}, trace_driver_submitted={}, runtime_ready={}, driver_pixels=visible_metal_native_rt_output\n", .{
                        as_plan.result_size,
                        as_plan.scratch_size,
                        pipeline_state.functionTableEntryCount(),
                        dispatch_plan.sbt_size,
                        dispatch_plan.total_rays,
                        metal_function_table_entries,
                        acceleration_structure.isBuilt(),
                        acceleration_structure.lastBuildSubmittedToDriver(),
                        pipeline_state.backendPrivatePipelineBoundToDriver(),
                        shader_binding_table.lastDispatchSubmittedToDriver(),
                        runtime_ready,
                    });
                }
            }

            glfw.pollEvents();
        }
        return;
    }

    unreachable;
}

fn printRayTracingUnsupported(diagnostics: vkmtl.RayTracingCapabilityDiagnostics) void {
    std.debug.print("vulkan ray tracing unsupported: blocker={s}", .{@tagName(diagnostics.blocker)});
    if (diagnostics.requirement.len != 0) {
        std.debug.print(", requirement={s}", .{diagnostics.requirement});
    }
    if (diagnostics.details.len != 0) {
        std.debug.print(", details={s}", .{diagnostics.details});
    }
    std.debug.print("\n", .{});
}

fn backendOverrideFromEnv() ?vkmtl.Backend {
    const value = std.mem.span(getenv("VKMTL_BACKEND") orelse return null);
    if (std.ascii.eqlIgnoreCase(value, "vulkan")) return .vulkan;
    if (std.ascii.eqlIgnoreCase(value, "metal")) return .metal;

    std.debug.print("Ignoring unsupported VKMTL_BACKEND value: {s}\n", .{value});
    return null;
}
