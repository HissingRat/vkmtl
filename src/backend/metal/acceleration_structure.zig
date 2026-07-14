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

pub fn queryBuildSizes(
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
    return .{
        .result_size = sizes.result_size,
        .scratch_size = sizes.scratch_size,
        .update_scratch_size = sizes.update_scratch_size,
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
    ));
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
