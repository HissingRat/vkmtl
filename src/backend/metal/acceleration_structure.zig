const core = @import("../../core.zig");
const debug = @import("debug.zig");
const metal = @import("metal_bridge");
const MetalClearScreen = @import("clear_screen.zig");

const MetalAccelerationStructure = @This();

handle: *metal.vkmtl_metal_acceleration_structure,
kind_value: core.AccelerationStructureKind,
sizes_value: core.AccelerationStructureBuildSizes,

pub fn init(
    owner: *MetalClearScreen,
    descriptor: core.AccelerationStructureDescriptor,
) core.AdvancedFeatureError!MetalAccelerationStructure {
    var handle: ?*metal.vkmtl_metal_acceleration_structure = null;
    try checkAccelerationStructure(metal.vkmtl_metal_acceleration_structure_create(
        owner.handle,
        accelerationStructureKind(descriptor.kind),
        descriptor.primitive_count,
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

fn accelerationStructureKind(
    kind_value: core.AccelerationStructureKind,
) metal.vkmtl_metal_acceleration_structure_kind {
    return switch (kind_value) {
        .bottom_level => metal.VKMTL_METAL_ACCELERATION_STRUCTURE_KIND_BOTTOM_LEVEL,
        .top_level => metal.VKMTL_METAL_ACCELERATION_STRUCTURE_KIND_TOP_LEVEL,
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
