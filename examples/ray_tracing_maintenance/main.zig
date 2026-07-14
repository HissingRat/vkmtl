const std = @import("std");
const vkmtl = @import("vkmtl");

extern fn getenv(name: [*:0]const u8) ?[*:0]u8;

const Vertex = extern struct {
    x: f32,
    y: f32,
    z: f32,
};

const Bounds = extern struct {
    min: [3]f32,
    max: [3]f32,
};

const vertices = [_]Vertex{
    .{ .x = -0.5, .y = -0.5, .z = 0.0 },
    .{ .x = 0.5, .y = -0.5, .z = 0.0 },
    .{ .x = 0.0, .y = 0.5, .z = 0.0 },
};
const maintenance_iterations: u32 = 32;
const bounds = Bounds{
    .min = .{ -0.5, -0.5, -0.5 },
    .max = .{ 0.5, 0.5, 0.5 },
};

pub fn main(_: std.process.Init.Minimal) !void {
    var debug_allocator = std.heap.DebugAllocator(.{}){};
    defer _ = debug_allocator.deinit();

    var context = try vkmtl.HeadlessContext.init(debug_allocator.allocator(), .{
        .app_name = "vkmtl ray tracing maintenance",
        .backend = .auto,
        .debug_backend_override = backendOverrideFromEnv(),
    });
    defer context.deinit();

    var device = context.device();
    var queue = context.queue();
    const features = device.features();
    if (!features.acceleration_structures or
        !features.acceleration_structure_update or
        !features.acceleration_structure_refit or
        !features.acceleration_structure_compaction or
        !features.ray_tracing_procedural_geometry)
    {
        std.debug.print("ray tracing maintenance unsupported: backend={}\n", .{device.selectedBackend()});
        return;
    }

    var vertex_buffer = try device.makeBuffer(.{
        .label = "maintenance triangle vertices",
        .bytes = std.mem.sliceAsBytes(vertices[0..]),
        .usage = .{ .acceleration_structure_build_input = true },
        .storage_mode = .shared,
    });
    defer vertex_buffer.deinit();

    const as_descriptor = vkmtl.ray_tracing.AccelerationStructureDescriptor{
        .label = "maintenance source",
        .kind = .bottom_level,
        .primitive_count = 1,
        .allow_update = true,
    };
    const geometry = vkmtl.ray_tracing.AccelerationStructureGeometryDescriptor{
        .kind = .triangles,
        .primitive_count = 1,
        .vertex_count = vertices.len,
        .vertex_stride = @sizeOf(Vertex),
    };
    const build_plan = try vkmtl.ray_tracing.planAccelerationStructureBuild(device, .{
        .acceleration_structure = as_descriptor,
        .geometries = &.{geometry},
        .flags = .{
            .allow_update = true,
            .allow_compaction = true,
        },
    });

    var source = try device.makeAccelerationStructure(as_descriptor);
    defer source.deinit();
    var compacted = try device.makeAccelerationStructure(.{
        .label = "maintenance compacted destination",
        .kind = as_descriptor.kind,
        .primitive_count = as_descriptor.primitive_count,
    });
    defer compacted.deinit();

    var scratch = try device.makeBuffer(.{
        .label = "maintenance scratch",
        .length = @intCast(@max(build_plan.scratch_size, build_plan.update_scratch_size)),
        .usage = .{ .acceleration_structure_scratch = true },
        .storage_mode = .private,
    });
    defer scratch.deinit();

    var build_command = try queue.makeCommandBuffer();
    try build_command.encodeAccelerationStructureBuild(build_plan, .{
        .result = &source,
        .scratch = &scratch,
        .geometries = &.{.{
            .triangles = .{
                .descriptor = geometry,
                .vertex_buffer = &vertex_buffer,
            },
        }},
    });
    try build_command.commit();

    const update_plan = try vkmtl.ray_tracing.planAccelerationStructureMaintenance(device, .{
        .acceleration_structure = as_descriptor,
        .operation = .update,
    });
    const refit_plan = try vkmtl.ray_tracing.planAccelerationStructureMaintenance(device, .{
        .acceleration_structure = as_descriptor,
        .operation = .refit,
    });
    for (0..maintenance_iterations) |iteration| {
        var maintenance_command = try queue.makeCommandBuffer();
        try maintenance_command.encodeAccelerationStructureMaintenance(
            if (iteration % 2 == 0) update_plan else refit_plan,
            .{
                .source = &source,
                .scratch = &scratch,
            },
        );
        try maintenance_command.commit();
    }

    const compact_plan = try vkmtl.ray_tracing.planAccelerationStructureMaintenance(device, .{
        .acceleration_structure = as_descriptor,
        .operation = .compact,
        .source_result_size = source.resultSize(),
        .compacted_size_hint = compacted.resultSize(),
    });
    var compact_command = try queue.makeCommandBuffer();
    try compact_command.encodeAccelerationStructureMaintenance(compact_plan, .{
        .source = &source,
        .destination = &compacted,
    });
    try compact_command.commit();

    var aabb_buffer = try device.makeBuffer(.{
        .label = "maintenance AABB",
        .bytes = std.mem.asBytes(&bounds),
        .usage = .{ .acceleration_structure_build_input = true },
        .storage_mode = .shared,
    });
    defer aabb_buffer.deinit();
    const aabb_as_descriptor = vkmtl.ray_tracing.AccelerationStructureDescriptor{
        .label = "maintenance AABB BLAS",
        .kind = .bottom_level,
        .primitive_count = 1,
    };
    const aabb_geometry = vkmtl.ray_tracing.AccelerationStructureGeometryDescriptor{
        .kind = .aabbs,
        .primitive_count = 1,
        .aabb_stride = @sizeOf(Bounds),
        .is_opaque = false,
    };
    const aabb_plan = try vkmtl.ray_tracing.planAccelerationStructureBuild(device, .{
        .acceleration_structure = aabb_as_descriptor,
        .geometries = &.{aabb_geometry},
    });
    var aabb_as = try device.makeAccelerationStructure(aabb_as_descriptor);
    defer aabb_as.deinit();
    var aabb_scratch = try device.makeBuffer(.{
        .label = "maintenance AABB scratch",
        .length = @intCast(aabb_plan.scratch_size),
        .usage = .{ .acceleration_structure_scratch = true },
        .storage_mode = .private,
    });
    defer aabb_scratch.deinit();
    var aabb_command = try queue.makeCommandBuffer();
    try aabb_command.encodeAccelerationStructureBuild(aabb_plan, .{
        .result = &aabb_as,
        .scratch = &aabb_scratch,
        .geometries = &.{.{
            .aabbs = .{
                .descriptor = aabb_geometry,
                .buffer = &aabb_buffer,
            },
        }},
    });
    try aabb_command.commit();

    const tlas_descriptor = vkmtl.ray_tracing.AccelerationStructureDescriptor{
        .label = "maintenance multi-instance TLAS",
        .kind = .top_level,
        .primitive_count = 2,
    };
    const tlas_plan = try vkmtl.ray_tracing.planAccelerationStructureBuild(device, .{
        .acceleration_structure = tlas_descriptor,
    });
    var tlas = try device.makeAccelerationStructure(tlas_descriptor);
    defer tlas.deinit();
    var tlas_scratch = try device.makeBuffer(.{
        .label = "maintenance TLAS scratch",
        .length = @intCast(tlas_plan.scratch_size),
        .usage = .{ .acceleration_structure_scratch = true },
        .storage_mode = .private,
    });
    defer tlas_scratch.deinit();
    const instance_sources = [_]*vkmtl.ray_tracing.AccelerationStructure{ &source, &aabb_as };
    var tlas_command = try queue.makeCommandBuffer();
    try tlas_command.encodeAccelerationStructureBuild(tlas_plan, .{
        .result = &tlas,
        .scratch = &tlas_scratch,
        .instance_sources = instance_sources[0..],
    });
    try tlas_command.commit();

    if (!source.lastBuildSubmittedToDriver() or
        !source.lastMaintenanceSubmittedToDriver() or
        !compacted.isBuilt() or
        !aabb_as.lastBuildSubmittedToDriver() or
        !tlas.lastBuildSubmittedToDriver())
    {
        return error.RayTracingMaintenanceNotSubmitted;
    }
    std.debug.print(
        "ray tracing maintenance ok: backend={} build_count={} maintenance_count={} iterations={} compacted_built={} aabb_built={} tlas_instances={}\n",
        .{
            device.selectedBackend(),
            source.backendPrivateBuildCount(),
            source.backendPrivateMaintenanceCount(),
            maintenance_iterations,
            compacted.isBuilt(),
            aabb_as.isBuilt(),
            tlas.descriptor().primitive_count,
        },
    );
}

fn backendOverrideFromEnv() ?vkmtl.Backend {
    const value = std.mem.span(getenv("VKMTL_BACKEND") orelse return null);
    if (std.ascii.eqlIgnoreCase(value, "vulkan")) return .vulkan;
    if (std.ascii.eqlIgnoreCase(value, "metal")) return .metal;
    return null;
}
