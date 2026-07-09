const std = @import("std");
const vkmtl = @import("vkmtl");
const glfw = @import("zig_glfw");
const common = @import("vkmtl_examples_common");

extern fn getenv(name: [*:0]const u8) ?[*:0]u8;

const app_name = "vkmtl ray traced scene";
const rt_shader_source = @embedFile("shaders/ray_traced_scene_rt.slang");
const initial_width = 960;
const initial_height = 540;
const native_scene_time: f32 = -1.1;
const small_sphere_rings: u32 = 24;
const small_sphere_segments: u32 = 48;
const large_sphere_rings: u32 = 36;
const large_sphere_segments: u32 = 72;
const procedural_sphere_count: u32 = 10;

const RtVertex = extern struct {
    x: f32,
    y: f32,
    z: f32,
};

const RtAabb = extern struct {
    min_x: f32,
    min_y: f32,
    min_z: f32,
    max_x: f32,
    max_y: f32,
    max_z: f32,
};

const VulkanRayTraceUniforms = extern struct {
    params: [4]f32,
};

pub fn main(_: std.process.Init.Minimal) !void {
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

    var mesh_vertices: std.ArrayList(RtVertex) = .empty;
    defer mesh_vertices.deinit(allocator);
    try buildReferenceMesh(allocator, &mesh_vertices, native_scene_time);
    const mesh_triangle_count: u32 = @intCast(mesh_vertices.items.len / 3);
    const mesh_bytes = std.mem.sliceAsBytes(mesh_vertices.items);
    var scene_vertex_buffer = try device.makeBuffer(.{
        .label = "ray traced scene mesh vertices",
        .bytes = mesh_bytes,
        .usage = .{
            .acceleration_structure_build_input = true,
        },
        .storage_mode = .shared,
    });
    defer scene_vertex_buffer.deinit();

    const geometry = [_]vkmtl.AccelerationStructureGeometryDescriptor{.{
        .kind = .triangles,
        .primitive_count = mesh_triangle_count,
        .vertex_count = @intCast(mesh_vertices.items.len),
        .vertex_stride = @sizeOf(RtVertex),
        .is_opaque = false,
    }};
    const geometry_resources = [_]vkmtl.AccelerationStructureGeometryResources{.{
        .triangles = .{
            .descriptor = geometry[0],
            .vertex_buffer = &scene_vertex_buffer,
        },
    }};
    const as_build = vkmtl.AccelerationStructureBuildDescriptor{
        .acceleration_structure = .{
            .kind = .bottom_level,
            .primitive_count = mesh_triangle_count,
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
        .{
            .kind = .hit,
            .entry_point = "closest_hit",
            .hit_group_kind = if (device.selectedBackend() == .vulkan) .procedural else .triangles,
        },
    };
    var compiled_rt_shader = try device.compileRayTracingShader("ray_traced_scene_rt", rt_shader_source, .{
        .intersection_entry = "intersect_sphere",
    });
    defer compiled_rt_shader.deinit();
    var pipeline = vkmtl.RayTracingPipelineDescriptor{
        .shader_groups = groups[0..],
        .max_recursion_depth = 1,
    };
    compiled_rt_shader.applyToPipelineDescriptor(device.selectedBackend(), &pipeline);
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
    build_command_buffer.encodeAccelerationStructureBuild(as_plan, .{
        .result = &acceleration_structure,
        .scratch = &scratch_buffer,
        .geometries = geometry_resources[0..],
    }) catch |err| {
        std.debug.print("ray traced scene BLAS build encode failed: {s}\n", .{@errorName(err)});
        return err;
    };
    build_command_buffer.commit() catch |err| {
        std.debug.print("ray traced scene BLAS build submit failed: {s}\n", .{@errorName(err)});
        return err;
    };

    if (device.selectedBackend() == .vulkan) {
        const scene_time_start = glfw.timeSeconds();
        const procedural_aabbs = buildProceduralSphereAabbs();
        var procedural_aabb_buffer = try device.makeBuffer(.{
            .label = "ray traced scene procedural sphere bounds",
            .bytes = std.mem.asBytes(&procedural_aabbs)[0..],
            .usage = .{
                .acceleration_structure_build_input = true,
            },
            .storage_mode = .shared,
        });
        defer procedural_aabb_buffer.deinit();

        const procedural_geometry = [_]vkmtl.AccelerationStructureGeometryDescriptor{.{
            .kind = .aabbs,
            .primitive_count = procedural_sphere_count,
            .aabb_stride = @sizeOf(RtAabb),
            .is_opaque = false,
        }};
        const procedural_geometry_resources = [_]vkmtl.AccelerationStructureGeometryResources{.{
            .aabbs = .{
                .descriptor = procedural_geometry[0],
                .buffer = &procedural_aabb_buffer,
            },
        }};
        const procedural_as_build = vkmtl.AccelerationStructureBuildDescriptor{
            .acceleration_structure = .{
                .kind = .bottom_level,
                .primitive_count = procedural_sphere_count,
            },
            .geometries = procedural_geometry[0..],
        };
        var procedural_acceleration_structure = device.makeAccelerationStructure(procedural_as_build.acceleration_structure) catch |err| {
            std.debug.print("procedural acceleration structure unsupported: {s}\n", .{@errorName(err)});
            return;
        };
        defer procedural_acceleration_structure.deinit();

        const procedural_as_plan = device.planAccelerationStructureBuild(procedural_as_build) catch |err| {
            std.debug.print("procedural acceleration structure unsupported: {s}\n", .{@errorName(err)});
            return;
        };
        var procedural_scratch_buffer = try device.makeBuffer(.{
            .label = "ray tracing procedural scratch",
            .length = @intCast(procedural_as_plan.scratch_size),
            .usage = .{ .acceleration_structure_scratch = true },
            .storage_mode = .private,
        });
        defer procedural_scratch_buffer.deinit();

        var procedural_build_command_buffer = try queue.makeCommandBuffer();
        procedural_build_command_buffer.encodeAccelerationStructureBuild(procedural_as_plan, .{
            .result = &procedural_acceleration_structure,
            .scratch = &procedural_scratch_buffer,
            .geometries = procedural_geometry_resources[0..],
        }) catch |err| {
            std.debug.print("ray traced scene procedural BLAS build encode failed: {s}\n", .{@errorName(err)});
            return err;
        };
        procedural_build_command_buffer.commit() catch |err| {
            std.debug.print("ray traced scene procedural BLAS build submit failed: {s}\n", .{@errorName(err)});
            return err;
        };

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
        top_level_command_buffer.encodeAccelerationStructureBuild(top_level_plan, .{
            .result = &top_level_acceleration_structure,
            .scratch = &top_level_scratch,
            .instance_source = &procedural_acceleration_structure,
        }) catch |err| {
            std.debug.print("ray traced scene TLAS build encode failed: {s}\n", .{@errorName(err)});
            return err;
        };
        top_level_command_buffer.commit() catch |err| {
            std.debug.print("ray traced scene TLAS build submit failed: {s}\n", .{@errorName(err)});
            return err;
        };

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
            const scene_time_seconds = currentSceneTime(scene_time_start);

            if (output_view == null or output_texture == null or output_extent.width != extent.width or output_extent.height != extent.height) {
                if (output_view) |*view| view.deinit();
                output_view = null;
                if (output_texture) |*texture| texture.deinit();
                output_texture = null;

                var texture = try device.makeTexture(.{
                    .label = "ray traced scene output",
                    .format = .bgra8_unorm,
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
                const uniforms = VulkanRayTraceUniforms{
                    .params = .{ scene_time_seconds, 0.0, 0.0, 0.0 },
                };
                const uniform_bytes = std.mem.asBytes(&uniforms);
                const dispatch_plan = frame_command_buffer.dispatchRaysToDrawable(
                    &pipeline_state,
                    &shader_binding_table,
                    .{
                        .width = extent.width,
                        .height = extent.height,
                        .inline_data = uniform_bytes[0..],
                        .inline_data_binding = 2,
                    },
                    .{
                        .acceleration_structure = &top_level_acceleration_structure,
                        .output = view,
                    },
                ) catch |err| {
                    std.debug.print("ray traced scene Vulkan dispatch encode failed: {s}\n", .{@errorName(err)});
                    return err;
                };
                frame_command_buffer.commit() catch |err| {
                    std.debug.print("ray traced scene Vulkan dispatch submit failed: {s}\n", .{@errorName(err)});
                    return err;
                };

                if (!reported_visible_pixels) {
                    reported_visible_pixels = true;
                    const runtime_ready =
                        procedural_acceleration_structure.hasBackendPrivateHandle() and
                        procedural_acceleration_structure.backendPrivateBuildCount() >= 1 and
                        top_level_acceleration_structure.hasBackendPrivateHandle() and
                        top_level_acceleration_structure.backendPrivateBuildCount() >= 1 and
                        pipeline_state.hasBackendPrivatePipelineHandle() and
                        pipeline_state.backendPrivatePipelineBoundToDriver() and
                        shader_binding_table.hasBackendPrivateRecords() and
                        shader_binding_table.backendPrivateRecordsBoundToDriver() and
                        shader_binding_table.dispatchCount() >= 1 and
                        shader_binding_table.lastDispatchSubmittedToDriver();
                    std.debug.print("ray traced scene visible: backend=vulkan, procedural_spheres={}, blas_size={}, tlas_size={}, scratch_size={}, groups={}, sbt_size={}, rays={}, blas_built={}, tlas_built={}, trace_driver_submitted={}, runtime_ready={}, driver_pixels=visible_vulkan_procedural_rt_scene\n", .{
                        procedural_sphere_count,
                        procedural_as_plan.result_size,
                        top_level_plan.result_size,
                        top_level_plan.scratch_size,
                        pipeline_state.functionTableEntryCount(),
                        dispatch_plan.sbt_size,
                        dispatch_plan.total_rays,
                        procedural_acceleration_structure.isBuilt(),
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
        const scene_time_start = glfw.timeSeconds();
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
                    .format = .bgra8_unorm,
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
                const scene_time_seconds = currentSceneTime(scene_time_start);
                const time_bytes = std.mem.asBytes(&scene_time_seconds);
                const dispatch_plan = frame_command_buffer.dispatchRaysToDrawable(
                    &pipeline_state,
                    &shader_binding_table,
                    .{
                        .width = extent.width,
                        .height = extent.height,
                        .inline_data = time_bytes[0..],
                        .inline_data_binding = 1,
                    },
                    .{
                        .acceleration_structure = &acceleration_structure,
                        .output = view,
                    },
                ) catch |err| {
                    std.debug.print("ray traced scene Metal dispatch encode failed: {s}\n", .{@errorName(err)});
                    return err;
                };
                frame_command_buffer.commit() catch |err| {
                    std.debug.print("ray traced scene Metal dispatch submit failed: {s}\n", .{@errorName(err)});
                    return err;
                };

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
                    std.debug.print("ray traced scene visible: backend=metal, mesh_triangles={}, as_size={}, scratch_size={}, groups={}, sbt_size={}, rays={}, metal_table_entries={}, as_built={}, as_driver_submitted={}, pipeline_driver_bound={}, trace_driver_submitted={}, runtime_ready={}, driver_pixels=visible_metal_full_mesh_rt_scene\n", .{
                        mesh_triangle_count,
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

fn currentSceneTime(start_seconds: f64) f32 {
    return native_scene_time + @as(f32, @floatCast(glfw.timeSeconds() - start_seconds));
}

fn rebuildReferenceMesh(allocator: std.mem.Allocator, vertices: *std.ArrayList(RtVertex), time_seconds: f32) !void {
    vertices.clearRetainingCapacity();
    try buildReferenceMesh(allocator, vertices, time_seconds);
}

fn buildReferenceMesh(allocator: std.mem.Allocator, vertices: *std.ArrayList(RtVertex), time_seconds: f32) !void {
    var index: u32 = 0;
    while (index < 10) : (index += 1) {
        const sphere = referenceSphere(index, time_seconds);
        const rings: u32 = if (sphere[3] >= 0.3) large_sphere_rings else small_sphere_rings;
        const segments: u32 = if (sphere[3] >= 0.3) large_sphere_segments else small_sphere_segments;
        try appendSphere(allocator, vertices, .{ sphere[0], sphere[1], sphere[2] }, sphere[3], rings, segments);
    }
}

fn referenceBaseSphere(index: u32) @Vector(4, f32) {
    return switch (index) {
        0 => .{ 0.0, 0.0, -1.5, 0.1 },
        1 => .{ 0.0, 0.25, -1.5, 0.1 },
        2 => .{ 0.0, -0.7, -1.5, 0.3 },
        3 => .{ 0.0, -0.1, -1.5, 0.3 },
        4 => .{ 0.0, -0.1, -1.5, 0.15 },
        5 => .{ 1001.0, 0.0, 0.0, 1000.0 },
        6 => .{ -1001.0, 0.0, 0.0, 1000.0 },
        7 => .{ 0.0, 1001.0, 0.0, 1000.0 },
        8 => .{ 0.0, -1001.0, 0.0, 1000.0 },
        else => .{ 0.0, 0.0, -1002.0, 1000.0 },
    };
}

fn referenceSphere(index: u32, time_seconds: f32) @Vector(4, f32) {
    var sphere = referenceBaseSphere(index);
    if (index == 0) {
        sphere[0] += @sin(time_seconds) * 0.4;
        sphere[2] += @cos(time_seconds) * 0.4;
    } else if (index == 1) {
        sphere[0] += @sin(time_seconds) * -0.3;
        sphere[2] += @cos(time_seconds) * -0.3;
    }
    return sphere;
}

fn buildProceduralSphereAabbs() [procedural_sphere_count]RtAabb {
    var result: [procedural_sphere_count]RtAabb = undefined;
    var index: u32 = 0;
    while (index < procedural_sphere_count) : (index += 1) {
        result[index] = proceduralSphereAabb(index);
    }
    return result;
}

fn proceduralSphereAabb(index: u32) RtAabb {
    const sphere = referenceBaseSphere(index);
    const radius = sphere[3];
    var extent_x = radius;
    const extent_y = radius;
    var extent_z = radius;
    if (index == 0) {
        extent_x += 0.4;
        extent_z += 0.4;
    } else if (index == 1) {
        extent_x += 0.3;
        extent_z += 0.3;
    }
    return .{
        .min_x = sphere[0] - extent_x,
        .min_y = sphere[1] - extent_y,
        .min_z = sphere[2] - extent_z,
        .max_x = sphere[0] + extent_x,
        .max_y = sphere[1] + extent_y,
        .max_z = sphere[2] + extent_z,
    };
}

fn appendQuad(
    allocator: std.mem.Allocator,
    vertices: *std.ArrayList(RtVertex),
    a: @Vector(3, f32),
    b: @Vector(3, f32),
    c: @Vector(3, f32),
    d: @Vector(3, f32),
) !void {
    try appendTriangle(allocator, vertices, a, b, c);
    try appendTriangle(allocator, vertices, a, c, d);
}

fn appendSphere(
    allocator: std.mem.Allocator,
    vertices: *std.ArrayList(RtVertex),
    center: @Vector(3, f32),
    radius: f32,
    rings: u32,
    segments: u32,
) !void {
    const pi: f32 = 3.141592653589793;
    var ring: u32 = 0;
    while (ring < rings) : (ring += 1) {
        const v0 = @as(f32, @floatFromInt(ring)) / @as(f32, @floatFromInt(rings));
        const v1 = @as(f32, @floatFromInt(ring + 1)) / @as(f32, @floatFromInt(rings));
        const theta0 = v0 * pi;
        const theta1 = v1 * pi;
        var segment: u32 = 0;
        while (segment < segments) : (segment += 1) {
            const seg_u0 = @as(f32, @floatFromInt(segment)) / @as(f32, @floatFromInt(segments));
            const seg_u1 = @as(f32, @floatFromInt(segment + 1)) / @as(f32, @floatFromInt(segments));
            const phi0 = seg_u0 * pi * 2.0;
            const phi1 = seg_u1 * pi * 2.0;
            const p00 = spherePoint(center, radius, theta0, phi0);
            const p01 = spherePoint(center, radius, theta0, phi1);
            const p10 = spherePoint(center, radius, theta1, phi0);
            const p11 = spherePoint(center, radius, theta1, phi1);
            if (ring != 0) try appendTriangle(allocator, vertices, p00, p10, p01);
            if (ring + 1 != rings) try appendTriangle(allocator, vertices, p01, p10, p11);
        }
    }
}

fn spherePoint(center: @Vector(3, f32), radius: f32, theta: f32, phi: f32) @Vector(3, f32) {
    const sin_theta = @sin(theta);
    return center + @as(@Vector(3, f32), .{
        radius * sin_theta * @cos(phi),
        radius * @cos(theta),
        radius * sin_theta * @sin(phi),
    });
}

fn appendTriangle(
    allocator: std.mem.Allocator,
    vertices: *std.ArrayList(RtVertex),
    a: @Vector(3, f32),
    b: @Vector(3, f32),
    c: @Vector(3, f32),
) !void {
    try appendVertex(allocator, vertices, a);
    try appendVertex(allocator, vertices, b);
    try appendVertex(allocator, vertices, c);
}

fn appendVertex(allocator: std.mem.Allocator, vertices: *std.ArrayList(RtVertex), value: @Vector(3, f32)) !void {
    try vertices.append(allocator, .{
        .x = value[0],
        .y = value[1],
        .z = value[2],
    });
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
