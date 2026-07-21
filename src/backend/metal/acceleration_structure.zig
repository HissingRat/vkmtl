const std = @import("std");
const core = @import("../../core.zig");
const debug = @import("debug.zig");
const metal = @import("metal_bridge");
const MetalClearScreen = @import("clear_screen.zig");
const MetalBuffer = @import("buffer.zig");

const MetalAccelerationStructure = @This();

handle: *metal.vkmtl_metal_acceleration_structure,
kind_value: core.AccelerationStructureKind,
sizes_value: core.AccelerationStructureBuildSizes,

pub const GeometryInput = union(core.AccelerationStructureGeometryKind) {
    triangles: TriangleGeometryInput,
    aabbs: AabbGeometryInput,
    instances: void,
};

pub const TriangleGeometryInput = struct {
    descriptor: core.AccelerationStructureGeometryDescriptor,
    vertex_buffer: *MetalBuffer,
    index_buffer: ?*MetalBuffer = null,
};

pub const AabbGeometryInput = struct {
    descriptor: core.AccelerationStructureGeometryDescriptor,
    buffer: *MetalBuffer,
};

const BuildSizeQuery = union(enum) {
    conservative,
    triangles: core.AccelerationStructureGeometryDescriptor,
    aabbs: core.AccelerationStructureGeometryDescriptor,
};

pub fn init(
    owner: *MetalClearScreen,
    descriptor: core.AccelerationStructureDescriptor,
) core.AdvancedFeatureError!MetalAccelerationStructure {
    var handle: ?*metal.vkmtl_metal_acceleration_structure = null;
    try checkAccelerationStructure(metal.vkmtl_metal_acceleration_structure_create(
        owner.handle,
        accelerationStructureKind(descriptor.kind),
        descriptor.primitive_count,
        @intFromBool(descriptor.allow_update),
        &handle,
    ));

    const raw_handle = handle orelse return core.AdvancedFeatureError.UnsupportedAccelerationStructures;
    return .{
        .handle = raw_handle,
        .kind_value = descriptor.kind,
        .sizes_value = .{
            .result_size = metal.vkmtl_metal_acceleration_structure_result_size(raw_handle),
            .scratch_size = metal.vkmtl_metal_acceleration_structure_scratch_size(raw_handle),
            .update_scratch_size = metal.vkmtl_metal_acceleration_structure_update_scratch_size(raw_handle),
        },
    };
}

pub fn queryConservativeBuildSizes(
    owner: *MetalClearScreen,
    descriptor: core.AccelerationStructureDescriptor,
) core.AdvancedFeatureError!core.AccelerationStructureBuildSizes {
    var sizes: metal.vkmtl_metal_acceleration_structure_build_sizes = undefined;
    try checkAccelerationStructure(metal.vkmtl_metal_acceleration_structure_query_sizes(
        owner.handle,
        accelerationStructureKind(descriptor.kind),
        descriptor.primitive_count,
        @intFromBool(descriptor.allow_update),
        &sizes,
    ));
    return buildSizesFromNative(sizes);
}

pub fn queryBuildSizes(
    owner: *MetalClearScreen,
    descriptor: core.AccelerationStructureBuildDescriptor,
) core.AdvancedFeatureError!core.AccelerationStructureBuildSizes {
    var sizes: metal.vkmtl_metal_acceleration_structure_build_sizes = undefined;
    switch (try buildSizeQuery(descriptor)) {
        .conservative => return queryConservativeBuildSizes(owner, descriptor.acceleration_structure),
        .triangles => |geometry| try checkAccelerationStructure(
            metal.vkmtl_metal_acceleration_structure_query_triangle_sizes(
                owner.handle,
                geometry.primitive_count,
                geometry.resolvedVertexStride(),
                geometry.resolvedVertexCount(),
                metalIndexType(geometry.index_type),
                @intFromBool(geometry.is_opaque),
                @intFromBool(descriptor.acceleration_structure.allow_update),
                &sizes,
            ),
        ),
        .aabbs => |geometry| try checkAccelerationStructure(
            metal.vkmtl_metal_acceleration_structure_query_aabb_sizes(
                owner.handle,
                geometry.primitive_count,
                geometry.aabb_stride,
                @intFromBool(geometry.is_opaque),
                @intFromBool(descriptor.acceleration_structure.allow_update),
                &sizes,
            ),
        ),
    }
    return buildSizesFromNative(sizes);
}

fn buildSizeQuery(
    descriptor: core.AccelerationStructureBuildDescriptor,
) core.AdvancedFeatureError!BuildSizeQuery {
    if (descriptor.geometries.len == 0 or descriptor.acceleration_structure.kind == .top_level) {
        return .conservative;
    }
    if (descriptor.geometries.len != 1) {
        return core.AdvancedFeatureError.InvalidAccelerationStructureDescriptor;
    }
    return switch (descriptor.geometries[0].kind) {
        .triangles => .{ .triangles = descriptor.geometries[0] },
        .aabbs => .{ .aabbs = descriptor.geometries[0] },
        .instances => core.AdvancedFeatureError.InvalidAccelerationStructureDescriptor,
    };
}

pub fn deinit(self: *MetalAccelerationStructure) void {
    metal.vkmtl_metal_acceleration_structure_destroy(self.handle);
}

pub fn setLabel(self: *MetalAccelerationStructure, label_value: ?[]const u8) void {
    debug.ignore(metal.vkmtl_metal_acceleration_structure_set_label(
        self.handle,
        debug.labelPtr(label_value),
        debug.labelLen(label_value),
    ));
}

pub fn buildSizes(self: MetalAccelerationStructure) core.AccelerationStructureBuildSizes {
    return self.sizes_value;
}

pub fn hasDriverHandle(self: MetalAccelerationStructure) bool {
    return metal.vkmtl_metal_acceleration_structure_has_driver_handle(self.handle) != 0;
}

pub fn kind(self: MetalAccelerationStructure) core.AccelerationStructureKind {
    return self.kind_value;
}

pub fn setTriangleGeometry(
    self: *MetalAccelerationStructure,
    input: TriangleGeometryInput,
) core.AdvancedFeatureError!void {
    const descriptor = input.descriptor;
    if (descriptor.kind != .triangles) return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
    try checkAccelerationStructure(metal.vkmtl_metal_acceleration_structure_set_triangle_geometry(
        self.handle,
        input.vertex_buffer.handle,
        descriptor.vertex_buffer_offset,
        descriptor.resolvedVertexStride(),
        descriptor.resolvedVertexCount(),
        if (input.index_buffer) |index_buffer| index_buffer.handle else null,
        descriptor.index_buffer_offset,
        metalIndexType(descriptor.index_type),
        descriptor.primitive_count,
        @intFromBool(descriptor.is_opaque),
    ));
    self.refreshBuildSizes();
}

pub fn setAabbGeometry(
    self: *MetalAccelerationStructure,
    input: AabbGeometryInput,
) core.AdvancedFeatureError!void {
    const descriptor = input.descriptor;
    if (descriptor.kind != .aabbs) return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
    try checkAccelerationStructure(metal.vkmtl_metal_acceleration_structure_set_aabb_geometry(
        self.handle,
        input.buffer.handle,
        descriptor.aabb_buffer_offset,
        descriptor.aabb_stride,
        descriptor.primitive_count,
        @intFromBool(descriptor.is_opaque),
    ));
    self.refreshBuildSizes();
}

pub fn refreshBuildSizes(self: *MetalAccelerationStructure) void {
    self.sizes_value = .{
        .result_size = metal.vkmtl_metal_acceleration_structure_result_size(self.handle),
        .scratch_size = metal.vkmtl_metal_acceleration_structure_scratch_size(self.handle),
        .update_scratch_size = metal.vkmtl_metal_acceleration_structure_update_scratch_size(self.handle),
    };
}

fn accelerationStructureKind(
    kind_value: core.AccelerationStructureKind,
) metal.vkmtl_metal_acceleration_structure_kind {
    return switch (kind_value) {
        .bottom_level => metal.VKMTL_METAL_ACCELERATION_STRUCTURE_KIND_BOTTOM_LEVEL,
        .top_level => metal.VKMTL_METAL_ACCELERATION_STRUCTURE_KIND_TOP_LEVEL,
    };
}

fn metalIndexType(index_type: core.AccelerationStructureIndexType) c_uint {
    return switch (index_type) {
        .none => 0,
        .uint16 => 1,
        .uint32 => 2,
    };
}

fn buildSizesFromNative(
    sizes: metal.vkmtl_metal_acceleration_structure_build_sizes,
) core.AccelerationStructureBuildSizes {
    return .{
        .result_size = sizes.result_size,
        .scratch_size = sizes.scratch_size,
        .update_scratch_size = sizes.update_scratch_size,
    };
}

fn checkAccelerationStructure(status: metal.vkmtl_metal_status) core.AdvancedFeatureError!void {
    return switch (status) {
        metal.VKMTL_METAL_STATUS_OK => {},
        metal.VKMTL_METAL_STATUS_UNSUPPORTED,
        metal.VKMTL_METAL_STATUS_NO_DEVICE,
        => core.AdvancedFeatureError.UnsupportedAccelerationStructures,
        metal.VKMTL_METAL_STATUS_INVALID_COMMAND,
        metal.VKMTL_METAL_STATUS_INVALID_BUFFER,
        metal.VKMTL_METAL_STATUS_COMMAND_FAILED,
        => core.AdvancedFeatureError.InvalidAccelerationStructureResources,
        else => core.AdvancedFeatureError.UnsupportedAccelerationStructures,
    };
}

test "Metal AS size queries preserve concrete BLAS geometry" {
    const indexed_triangle = core.AccelerationStructureGeometryDescriptor{
        .kind = .triangles,
        .primitive_count = 32,
        .vertex_count = 24,
        .vertex_stride = 36,
        .index_type = .uint32,
        .index_count = 96,
        .is_opaque = false,
    };
    const triangle_query = try buildSizeQuery(.{
        .acceleration_structure = .{ .kind = .bottom_level, .primitive_count = 32 },
        .geometries = &.{indexed_triangle},
    });
    try std.testing.expectEqual(core.AccelerationStructureIndexType.uint32, triangle_query.triangles.index_type);
    try std.testing.expectEqual(@as(u32, 36), triangle_query.triangles.resolvedVertexStride());
    try std.testing.expect(!triangle_query.triangles.is_opaque);

    const aabb_query = try buildSizeQuery(.{
        .acceleration_structure = .{ .kind = .bottom_level, .primitive_count = 7 },
        .geometries = &.{.{
            .kind = .aabbs,
            .primitive_count = 7,
            .aabb_stride = 32,
            .is_opaque = true,
        }},
    });
    try std.testing.expectEqual(@as(u32, 32), aabb_query.aabbs.aabb_stride);
    try std.testing.expect(aabb_query.aabbs.is_opaque);
}

test "Metal AS size queries reserve conservative TLAS capacity" {
    const query = try buildSizeQuery(.{
        .acceleration_structure = .{ .kind = .top_level, .primitive_count = 4 },
        .geometries = &.{.{ .kind = .instances, .primitive_count = 4 }},
    });
    try std.testing.expect(query == .conservative);
}
