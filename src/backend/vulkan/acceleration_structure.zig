const std = @import("std");
const vk = @import("vulkan");
const core = @import("../../core.zig");
const GraphicsContext = @import("graphics_context.zig");
const VulkanBuffer = @import("buffer.zig");

const VulkanAccelerationStructure = @This();

gc: *const GraphicsContext,
handle: vk.AccelerationStructureKHR,
kind: core.AccelerationStructureKind,
storage: BufferAllocation,
geometry: BufferAllocation,
sizes_value: core.AccelerationStructureBuildSizes,
device_address: vk.DeviceAddress = 0,
primitive_count: u32,
allow_update: bool,
allow_compaction: bool = false,
built_value: bool = false,
recorded_geometry_count: u32 = 0,
recorded_geometries: [32]vk.AccelerationStructureGeometryKHR = undefined,
recorded_ranges: [32]vk.AccelerationStructureBuildRangeInfoKHR = undefined,

pub const GeometryInput = union(core.AccelerationStructureGeometryKind) {
    triangles: TriangleGeometryInput,
    aabbs: AabbGeometryInput,
    instances: void,
};

pub const TriangleGeometryInput = struct {
    descriptor: core.AccelerationStructureGeometryDescriptor,
    vertex_buffer: *const VulkanBuffer,
    index_buffer: ?*const VulkanBuffer = null,
};

pub const AabbGeometryInput = struct {
    descriptor: core.AccelerationStructureGeometryDescriptor,
    buffer: *const VulkanBuffer,
};

const fallback_triangle_vertices = [_]f32{
    0.0,  -0.5, 0.0,
    0.5,  0.5,  0.0,
    -0.5, 0.5,  0.0,
};

const BufferAllocation = struct {
    buffer: vk.Buffer,
    memory: vk.DeviceMemory,
    size: u64,

    fn deinit(self: *BufferAllocation, gc: *const GraphicsContext) void {
        if (self.buffer != .null_handle) {
            gc.dev.destroyBuffer(self.buffer, null);
            self.buffer = .null_handle;
        }
        if (self.memory != .null_handle) {
            gc.dev.freeMemory(self.memory, null);
            self.memory = .null_handle;
        }
    }
};

pub fn init(
    gc: *const GraphicsContext,
    descriptor: core.AccelerationStructureDescriptor,
) core.AdvancedFeatureError!VulkanAccelerationStructure {
    // Geometry/build flags arrive later with command resources. Reserve the
    // update/compaction-capable upper bound so additive build flags cannot
    // outgrow the opaque AS storage allocated here.
    const sizes = queryBuildSizes(gc, descriptor, .{
        .allow_update = true,
        .allow_compaction = true,
    }) catch return core.AdvancedFeatureError.UnsupportedAccelerationStructures;
    var storage = createBuffer(
        gc,
        sizes.result_size,
        .{
            .acceleration_structure_storage_bit_khr = true,
            .shader_device_address_bit = true,
        },
        .{ .device_local_bit = true },
        null,
    ) catch return core.AdvancedFeatureError.UnsupportedAccelerationStructures;
    errdefer storage.deinit(gc);

    const triangle_bytes = std.mem.sliceAsBytes(fallback_triangle_vertices[0..]);
    const instance_bytes = zeroedInstanceBytes();
    const geometry_bytes = switch (descriptor.kind) {
        .bottom_level => triangle_bytes,
        .top_level => instance_bytes[0..@sizeOf(vk.AccelerationStructureInstanceKHR)],
    };
    var geometry = createBuffer(
        gc,
        geometry_bytes.len,
        .{
            .acceleration_structure_build_input_read_only_bit_khr = true,
            .shader_device_address_bit = true,
        },
        .{
            .host_visible_bit = true,
            .host_coherent_bit = true,
        },
        geometry_bytes,
    ) catch return core.AdvancedFeatureError.UnsupportedAccelerationStructures;
    errdefer geometry.deinit(gc);

    const handle = gc.dev.createAccelerationStructureKHR(&.{
        .buffer = storage.buffer,
        .offset = 0,
        .size = @intCast(sizes.result_size),
        .type = accelerationStructureType(descriptor.kind),
    }, null) catch return core.AdvancedFeatureError.UnsupportedAccelerationStructures;
    errdefer gc.dev.destroyAccelerationStructureKHR(handle, null);

    const device_address = gc.dev.getAccelerationStructureDeviceAddressKHR(&.{
        .acceleration_structure = handle,
    });

    return .{
        .gc = gc,
        .handle = handle,
        .kind = descriptor.kind,
        .storage = storage,
        .geometry = geometry,
        .sizes_value = sizes,
        .device_address = device_address,
        .primitive_count = descriptor.primitive_count,
        .allow_update = descriptor.allow_update,
    };
}

pub fn deinit(self: *VulkanAccelerationStructure) void {
    if (self.handle != .null_handle) {
        self.gc.dev.destroyAccelerationStructureKHR(self.handle, null);
        self.handle = .null_handle;
    }
    self.geometry.deinit(self.gc);
    self.storage.deinit(self.gc);
}

pub fn buildSizes(self: VulkanAccelerationStructure) core.AccelerationStructureBuildSizes {
    return self.sizes_value;
}

pub fn hasDriverHandle(self: VulkanAccelerationStructure) bool {
    return self.handle != .null_handle and self.device_address != 0;
}

pub fn markBuilt(self: *VulkanAccelerationStructure) void {
    self.built_value = true;
}

pub fn recordBuildInputs(
    self: *VulkanAccelerationStructure,
    geometries: []const vk.AccelerationStructureGeometryKHR,
    ranges: []const vk.AccelerationStructureBuildRangeInfoKHR,
) core.AdvancedFeatureError!void {
    if (geometries.len == 0 or geometries.len != ranges.len or geometries.len > self.recorded_geometries.len) {
        return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
    }
    @memcpy(self.recorded_geometries[0..geometries.len], geometries);
    @memcpy(self.recorded_ranges[0..ranges.len], ranges);
    self.recorded_geometry_count = @intCast(geometries.len);
}

pub fn geometryAddress(self: VulkanAccelerationStructure) core.AdvancedFeatureError!vk.DeviceAddress {
    const address = self.gc.dev.getBufferDeviceAddressKHR(&.{
        .buffer = self.geometry.buffer,
    });
    if (address == 0) return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
    return address;
}

pub fn scratchAddress(
    _: VulkanAccelerationStructure,
    scratch: *const VulkanBuffer,
    scratch_offset: u64,
) core.AdvancedFeatureError!vk.DeviceAddress {
    const address = scratch.deviceAddress() catch return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
    if (address == 0) return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
    return address + scratch_offset;
}

pub fn buildRange(self: VulkanAccelerationStructure) vk.AccelerationStructureBuildRangeInfoKHR {
    return .{
        .primitive_count = self.primitive_count,
        .primitive_offset = 0,
        .first_vertex = 0,
        .transform_offset = 0,
    };
}

pub fn buildGeometry(self: VulkanAccelerationStructure, geometry_address: vk.DeviceAddress) vk.AccelerationStructureGeometryKHR {
    return switch (self.kind) {
        .bottom_level => triangleGeometry(geometry_address),
        .top_level => instanceGeometry(geometry_address),
    };
}

pub fn buildGeometryFromInput(input: GeometryInput) core.AdvancedFeatureError!vk.AccelerationStructureGeometryKHR {
    return switch (input) {
        .triangles => |triangles| {
            const descriptor = triangles.descriptor;
            const vertex_address = (triangles.vertex_buffer.deviceAddress() catch {
                return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
            }) + descriptor.vertex_buffer_offset;
            const index_address = if (triangles.index_buffer) |index_buffer|
                (index_buffer.deviceAddress() catch return core.AdvancedFeatureError.InvalidAccelerationStructureResources) +
                    descriptor.index_buffer_offset
            else
                0;
            if (vertex_address == 0) return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
            if (descriptor.index_type != .none and index_address == 0) {
                return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
            }
            return .{
                .geometry_type = .triangles_khr,
                .geometry = .{ .triangles = .{
                    .vertex_format = vertexFormat(descriptor.vertex_format),
                    .vertex_data = .{ .device_address = vertex_address },
                    .vertex_stride = descriptor.resolvedVertexStride(),
                    .max_vertex = descriptor.resolvedVertexCount() - 1,
                    .index_type = indexType(descriptor.index_type),
                    .index_data = .{ .device_address = index_address },
                    .transform_data = .{ .device_address = 0 },
                } },
                .flags = .{ .opaque_bit_khr = descriptor.is_opaque },
            };
        },
        .aabbs => |aabbs| {
            const descriptor = aabbs.descriptor;
            const address = (aabbs.buffer.deviceAddress() catch {
                return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
            }) + descriptor.aabb_buffer_offset;
            if (address == 0) return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
            return .{
                .geometry_type = .aabbs_khr,
                .geometry = .{ .aabbs = .{
                    .data = .{ .device_address = address },
                    .stride = descriptor.aabb_stride,
                } },
                .flags = .{ .opaque_bit_khr = descriptor.is_opaque },
            };
        },
        .instances => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
    };
}

pub fn buildRangeFromInput(input: GeometryInput) vk.AccelerationStructureBuildRangeInfoKHR {
    const descriptor: core.AccelerationStructureGeometryDescriptor = switch (input) {
        .triangles => |triangles| triangles.descriptor,
        .aabbs => |aabbs| aabbs.descriptor,
        .instances => .{ .kind = .instances, .primitive_count = 1 },
    };
    return .{
        .primitive_count = descriptor.primitive_count,
        .primitive_offset = 0,
        .first_vertex = 0,
        .transform_offset = 0,
    };
}

pub fn structureType(self: VulkanAccelerationStructure) vk.AccelerationStructureTypeKHR {
    return accelerationStructureType(self.kind);
}

pub fn writeTopLevelInstance(
    self: *VulkanAccelerationStructure,
    source: *const VulkanAccelerationStructure,
) core.AdvancedFeatureError!void {
    try self.writeTopLevelInstances(&.{source});
}

pub fn writeTopLevelInstances(
    self: *VulkanAccelerationStructure,
    sources: []const *const VulkanAccelerationStructure,
) core.AdvancedFeatureError!void {
    if (sources.len == 0 or sources.len > self.primitive_count) {
        return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
    }
    if (self.kind != .top_level) {
        return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
    }
    const mapped = self.gc.dev.mapMemory(
        self.geometry.memory,
        0,
        @sizeOf(vk.AccelerationStructureInstanceKHR) * sources.len,
        .{},
    ) catch {
        return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
    };
    defer self.gc.dev.unmapMemory(self.geometry.memory);

    const dst: [*]vk.AccelerationStructureInstanceKHR = @ptrCast(@alignCast(mapped));
    for (sources, 0..) |source, i| {
        if (source.kind != .bottom_level or !source.built_value or source.device_address == 0) {
            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
        }
        dst[i] = vk.AccelerationStructureInstanceKHR{
            .transform = .{ .matrix = .{
                .{ 1, 0, 0, 0 },
                .{ 0, 1, 0, 0 },
                .{ 0, 0, 1, 0 },
            } },
            .instance_custom_index_and_mask = .{
                .instance_custom_index = @intCast(i),
                .mask = 0xff,
            },
            .instance_shader_binding_table_record_offset_and_flags = .{
                .instance_shader_binding_table_record_offset = 0,
                .flags = @truncate(vk.GeometryInstanceFlagsKHR.toInt(.{ .triangle_facing_cull_disable_bit_khr = true })),
            },
            .acceleration_structure_reference = source.device_address,
        };
    }
}

pub fn triangleGeometry(vertex_address: vk.DeviceAddress) vk.AccelerationStructureGeometryKHR {
    return .{
        .geometry_type = .triangles_khr,
        .geometry = .{ .triangles = .{
            .vertex_format = .r32g32b32_sfloat,
            .vertex_data = .{ .device_address = vertex_address },
            .vertex_stride = 12,
            .max_vertex = 2,
            .index_type = .none_khr,
            .index_data = .{ .device_address = 0 },
            .transform_data = .{ .device_address = 0 },
        } },
        .flags = .{ .opaque_bit_khr = true },
    };
}

pub fn aabbGeometry(aabb_address: vk.DeviceAddress, stride: u32) vk.AccelerationStructureGeometryKHR {
    return .{
        .geometry_type = .aabbs_khr,
        .geometry = .{ .aabbs = .{
            .data = .{ .device_address = aabb_address },
            .stride = stride,
        } },
        .flags = .{ .opaque_bit_khr = false },
    };
}

fn vertexFormat(format: core.AccelerationStructureVertexFormat) vk.Format {
    return switch (format) {
        .float3 => .r32g32b32_sfloat,
    };
}

fn indexType(index_type: core.AccelerationStructureIndexType) vk.IndexType {
    return switch (index_type) {
        .none => .none_khr,
        .uint16 => .uint16,
        .uint32 => .uint32,
    };
}

pub fn instanceGeometry(instance_address: vk.DeviceAddress) vk.AccelerationStructureGeometryKHR {
    return .{
        .geometry_type = .instances_khr,
        .geometry = .{ .instances = .{
            .array_of_pointers = .false,
            .data = .{ .device_address = instance_address },
        } },
        .flags = .{ .opaque_bit_khr = true },
    };
}

pub fn queryBuildSizes(
    gc: *const GraphicsContext,
    descriptor: core.AccelerationStructureDescriptor,
    flags: core.AccelerationStructureBuildFlags,
) !core.AccelerationStructureBuildSizes {
    if (descriptor.kind == .top_level) {
        var geometry = instanceGeometry(0);
        return queryBuildSizesForGeometry(gc, descriptor, flags, &geometry);
    }

    var triangle = triangleGeometry(0);
    var aabb = aabbGeometry(0, 24);
    const triangle_sizes = try queryBuildSizesForGeometry(gc, descriptor, flags, &triangle);
    const aabb_sizes = try queryBuildSizesForGeometry(gc, descriptor, flags, &aabb);
    return maxBuildSizes(triangle_sizes, aabb_sizes);
}

fn queryBuildSizesForGeometry(
    gc: *const GraphicsContext,
    descriptor: core.AccelerationStructureDescriptor,
    flags: core.AccelerationStructureBuildFlags,
    geometry: *vk.AccelerationStructureGeometryKHR,
) !core.AccelerationStructureBuildSizes {
    var build_info = vk.AccelerationStructureBuildGeometryInfoKHR{
        .type = accelerationStructureType(descriptor.kind),
        .flags = .{
            .allow_update_bit_khr = descriptor.allow_update or flags.allow_update,
            .allow_compaction_bit_khr = flags.allow_compaction,
            .prefer_fast_trace_bit_khr = true,
        },
        .mode = .build_khr,
        .geometry_count = 1,
        .p_geometries = @ptrCast(geometry),
        .scratch_data = .{ .device_address = 0 },
    };
    const primitive_counts = [_]u32{descriptor.primitive_count};
    var size_info = vk.AccelerationStructureBuildSizesInfoKHR{
        .acceleration_structure_size = 0,
        .update_scratch_size = 0,
        .build_scratch_size = 0,
    };
    gc.dev.getAccelerationStructureBuildSizesKHR(
        .device_khr,
        &build_info,
        &primitive_counts,
        &size_info,
    );
    return .{
        .result_size = @max(size_info.acceleration_structure_size, 1),
        .scratch_size = @max(size_info.build_scratch_size, 1),
        .update_scratch_size = size_info.update_scratch_size,
    };
}

fn maxBuildSizes(
    lhs: core.AccelerationStructureBuildSizes,
    rhs: core.AccelerationStructureBuildSizes,
) core.AccelerationStructureBuildSizes {
    return .{
        .result_size = @max(lhs.result_size, rhs.result_size),
        .scratch_size = @max(lhs.scratch_size, rhs.scratch_size),
        .update_scratch_size = @max(lhs.update_scratch_size, rhs.update_scratch_size),
    };
}

fn zeroedInstanceBytes() [@sizeOf(vk.AccelerationStructureInstanceKHR)]u8 {
    return [_]u8{0} ** @sizeOf(vk.AccelerationStructureInstanceKHR);
}

fn createBuffer(
    gc: *const GraphicsContext,
    size: u64,
    usage: vk.BufferUsageFlags,
    memory_flags: vk.MemoryPropertyFlags,
    initial_bytes: ?[]const u8,
) !BufferAllocation {
    const handle = try gc.dev.createBuffer(&.{
        .size = @intCast(size),
        .usage = usage,
        .sharing_mode = .exclusive,
    }, null);
    errdefer gc.dev.destroyBuffer(handle, null);

    const mem_reqs = gc.dev.getBufferMemoryRequirements(handle);
    const memory = if (usage.shader_device_address_bit)
        try gc.allocateDeviceAddressable(mem_reqs, memory_flags)
    else
        try gc.allocate(mem_reqs, memory_flags);
    errdefer gc.dev.freeMemory(memory, null);

    try gc.dev.bindBufferMemory(handle, memory, 0);

    if (initial_bytes) |bytes| {
        const mapped = try gc.dev.mapMemory(memory, 0, @intCast(bytes.len), .{});
        defer gc.dev.unmapMemory(memory);

        const dst: [*]u8 = @ptrCast(@alignCast(mapped));
        @memcpy(dst[0..bytes.len], bytes);
    }

    return .{
        .buffer = handle,
        .memory = memory,
        .size = size,
    };
}

fn accelerationStructureType(kind: core.AccelerationStructureKind) vk.AccelerationStructureTypeKHR {
    return switch (kind) {
        .bottom_level => .bottom_level_khr,
        .top_level => .top_level_khr,
    };
}
