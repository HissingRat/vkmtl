const std = @import("std");
const vk = @import("vulkan");
const core = @import("../../core.zig");
const GraphicsContext = @import("graphics_context.zig");
const VulkanBuffer = @import("buffer.zig");
const VulkanShaderModule = @import("shader_module.zig");
const VulkanAccelerationStructure = @import("acceleration_structure.zig");
const VulkanTextureView = @import("texture_view.zig");

const VulkanRayTracingPipelineState = @This();

gc: *const GraphicsContext,
allocator: std.mem.Allocator,
handle: vk.Pipeline,
layout: vk.PipelineLayout,
descriptor_set_layout: vk.DescriptorSetLayout,
descriptor_pool: vk.DescriptorPool,
descriptor_set: vk.DescriptorSet,
inline_data_buffer: VulkanBuffer,
sbt_buffer: VulkanBuffer,
raygen_region: vk.StridedDeviceAddressRegionKHR,
miss_region: vk.StridedDeviceAddressRegionKHR,
hit_region: vk.StridedDeviceAddressRegionKHR,
callable_region: vk.StridedDeviceAddressRegionKHR,
shader_group_count: u32,
sbt_stride: u64,
sbt_size: u64,

pub fn init(
    gc: *const GraphicsContext,
    allocator: std.mem.Allocator,
    descriptor: core.RayTracingPipelineDescriptor,
) !VulkanRayTracingPipelineState {
    if (!descriptor.hasNativeShaderStages()) return core.AdvancedFeatureError.InvalidRayTracingPipeline;
    const diagnostics = gc.rayTracingDiagnostics();
    if (!diagnostics.supported) return core.AdvancedFeatureError.UnsupportedRayTracing;
    if (diagnostics.shader_group_handle_size == 0 or diagnostics.shader_group_handle_alignment == 0) {
        return core.AdvancedFeatureError.InvalidShaderBindingTable;
    }

    var raygen_module = try VulkanShaderModule.init(gc, allocator, descriptor.ray_generation.?.module);
    defer raygen_module.deinit();
    var miss_module = try VulkanShaderModule.init(gc, allocator, descriptor.miss.?.module);
    defer miss_module.deinit();
    var closest_hit_module = try VulkanShaderModule.init(gc, allocator, descriptor.closest_hit.?.module);
    defer closest_hit_module.deinit();
    var any_hit_module: ?VulkanShaderModule = if (descriptor.any_hit) |stage|
        try VulkanShaderModule.init(gc, allocator, stage.module)
    else
        null;
    defer if (any_hit_module) |*module| module.deinit();
    var intersection_module: ?VulkanShaderModule = if (descriptor.intersection) |stage|
        try VulkanShaderModule.init(gc, allocator, stage.module)
    else
        null;
    defer if (intersection_module) |*module| module.deinit();

    const raygen_entry = try allocator.dupeZ(u8, descriptor.ray_generation.?.entry_point);
    defer allocator.free(raygen_entry);
    const miss_entry = try allocator.dupeZ(u8, descriptor.miss.?.entry_point);
    defer allocator.free(miss_entry);
    const closest_hit_entry = try allocator.dupeZ(u8, descriptor.closest_hit.?.entry_point);
    defer allocator.free(closest_hit_entry);
    const any_hit_entry = if (descriptor.any_hit) |stage|
        try allocator.dupeZ(u8, stage.entry_point)
    else
        null;
    defer if (any_hit_entry) |entry| allocator.free(entry);
    const intersection_entry = if (descriptor.intersection) |stage|
        try allocator.dupeZ(u8, stage.entry_point)
    else
        null;
    defer if (intersection_entry) |entry| allocator.free(entry);

    var stages_buffer: [5]vk.PipelineShaderStageCreateInfo = undefined;
    stages_buffer[0] = .{
        .stage = .{ .raygen_bit_khr = true },
        .module = raygen_module.handle,
        .p_name = raygen_entry,
    };
    stages_buffer[1] = .{
        .stage = .{ .miss_bit_khr = true },
        .module = miss_module.handle,
        .p_name = miss_entry,
    };
    stages_buffer[2] = .{
        .stage = .{ .closest_hit_bit_khr = true },
        .module = closest_hit_module.handle,
        .p_name = closest_hit_entry,
    };
    var stage_count: u32 = 3;
    const any_hit_stage_index: ?u32 = if (any_hit_module) |module| index: {
        const entry = any_hit_entry orelse unreachable;
        stages_buffer[stage_count] = .{
            .stage = .{ .any_hit_bit_khr = true },
            .module = module.handle,
            .p_name = entry,
        };
        const current = stage_count;
        stage_count += 1;
        break :index current;
    } else null;
    const intersection_stage_index: ?u32 = if (intersection_module) |module| index: {
        const entry = intersection_entry orelse unreachable;
        stages_buffer[stage_count] = .{
            .stage = .{ .intersection_bit_khr = true },
            .module = module.handle,
            .p_name = entry,
        };
        const current = stage_count;
        stage_count += 1;
        break :index current;
    } else null;
    const stages = stages_buffer[0..stage_count];

    const unused = vk.SHADER_UNUSED_KHR;
    const hit_group_kind = findHitGroupKind(descriptor);
    if (hit_group_kind == .procedural and intersection_stage_index == null) {
        return core.AdvancedFeatureError.InvalidRayTracingPipeline;
    }
    const groups = [_]vk.RayTracingShaderGroupCreateInfoKHR{
        .{
            .type = .general_khr,
            .general_shader = 0,
            .closest_hit_shader = unused,
            .any_hit_shader = unused,
            .intersection_shader = unused,
        },
        .{
            .type = .general_khr,
            .general_shader = 1,
            .closest_hit_shader = unused,
            .any_hit_shader = unused,
            .intersection_shader = unused,
        },
        .{
            .type = switch (hit_group_kind) {
                .triangles => .triangles_hit_group_khr,
                .procedural => .procedural_hit_group_khr,
            },
            .general_shader = unused,
            .closest_hit_shader = 2,
            .any_hit_shader = any_hit_stage_index orelse unused,
            .intersection_shader = intersection_stage_index orelse unused,
        },
    };

    const descriptor_set_layout = try createDescriptorSetLayout(gc);
    errdefer gc.dev.destroyDescriptorSetLayout(descriptor_set_layout, null);

    const set_layouts = [_]vk.DescriptorSetLayout{descriptor_set_layout};
    const layout = try gc.dev.createPipelineLayout(&.{
        .set_layout_count = set_layouts.len,
        .p_set_layouts = &set_layouts,
        .push_constant_range_count = 0,
        .p_push_constant_ranges = null,
    }, null);
    errdefer gc.dev.destroyPipelineLayout(layout, null);

    const descriptor_pool = try createDescriptorPool(gc);
    errdefer gc.dev.destroyDescriptorPool(descriptor_pool, null);
    var descriptor_set: vk.DescriptorSet = undefined;
    try gc.dev.allocateDescriptorSets(&.{
        .descriptor_pool = descriptor_pool,
        .descriptor_set_count = 1,
        .p_set_layouts = &set_layouts,
    }, @ptrCast(&descriptor_set));

    var inline_data_bytes = [_]u8{0} ** 4096;
    var inline_data_buffer = try VulkanBuffer.init(gc, .{
        .label = "vkmtl ray tracing inline data",
        .length = inline_data_bytes.len,
        .bytes = inline_data_bytes[0..],
        .usage = .{ .uniform = true },
        .storage_mode = .shared,
    });
    errdefer inline_data_buffer.deinit();

    const pipeline_info = vk.RayTracingPipelineCreateInfoKHR{
        .stage_count = @intCast(stages.len),
        .p_stages = stages.ptr,
        .group_count = groups.len,
        .p_groups = &groups,
        .max_pipeline_ray_recursion_depth = descriptor.max_recursion_depth,
        .layout = layout,
        .base_pipeline_handle = .null_handle,
        .base_pipeline_index = -1,
    };

    var pipeline: vk.Pipeline = undefined;
    _ = try gc.dev.createRayTracingPipelinesKHR(
        .null_handle,
        .null_handle,
        &.{pipeline_info},
        null,
        (&pipeline)[0..1],
    );
    errdefer gc.dev.destroyPipeline(pipeline, null);

    const sbt_stride = alignForwardU64(
        diagnostics.shader_group_handle_size,
        diagnostics.shader_group_handle_alignment,
    );
    const shader_group_count: u32 = @intCast(groups.len);
    const handle_bytes_len: usize = @intCast(@as(u64, diagnostics.shader_group_handle_size) * shader_group_count);
    const handle_bytes = try allocator.alloc(u8, handle_bytes_len);
    defer allocator.free(handle_bytes);
    try gc.dev.getRayTracingShaderGroupHandlesKHR(
        pipeline,
        0,
        shader_group_count,
        handle_bytes.len,
        handle_bytes.ptr,
    );

    const sbt_size = sbt_stride * shader_group_count;
    const sbt_bytes = try allocator.alloc(u8, @intCast(sbt_size));
    defer allocator.free(sbt_bytes);
    @memset(sbt_bytes, 0);
    for (0..shader_group_count) |group_index| {
        const handle_src_offset = group_index * diagnostics.shader_group_handle_size;
        const sbt_dst_offset = group_index * @as(usize, @intCast(sbt_stride));
        @memcpy(
            sbt_bytes[sbt_dst_offset .. sbt_dst_offset + diagnostics.shader_group_handle_size],
            handle_bytes[handle_src_offset .. handle_src_offset + diagnostics.shader_group_handle_size],
        );
    }

    var sbt_buffer = try VulkanBuffer.init(gc, .{
        .label = "vkmtl ray tracing shader binding table",
        .length = sbt_bytes.len,
        .bytes = sbt_bytes,
        .usage = .{ .shader_binding_table = true },
        .storage_mode = .shared,
    });
    errdefer sbt_buffer.deinit();

    const base_address = try sbt_buffer.deviceAddress();
    if (base_address == 0) return core.AdvancedFeatureError.InvalidShaderBindingTable;

    return .{
        .gc = gc,
        .allocator = allocator,
        .handle = pipeline,
        .layout = layout,
        .descriptor_set_layout = descriptor_set_layout,
        .descriptor_pool = descriptor_pool,
        .descriptor_set = descriptor_set,
        .inline_data_buffer = inline_data_buffer,
        .sbt_buffer = sbt_buffer,
        .raygen_region = .{
            .device_address = base_address,
            .stride = sbt_stride,
            .size = sbt_stride,
        },
        .miss_region = .{
            .device_address = base_address + sbt_stride,
            .stride = sbt_stride,
            .size = sbt_stride,
        },
        .hit_region = .{
            .device_address = base_address + sbt_stride * 2,
            .stride = sbt_stride,
            .size = sbt_stride,
        },
        .callable_region = .{
            .device_address = 0,
            .stride = 0,
            .size = 0,
        },
        .shader_group_count = shader_group_count,
        .sbt_stride = sbt_stride,
        .sbt_size = sbt_size,
    };
}

pub fn deinit(self: *VulkanRayTracingPipelineState) void {
    self.sbt_buffer.deinit();
    self.inline_data_buffer.deinit();
    self.gc.dev.destroyDescriptorPool(self.descriptor_pool, null);
    self.gc.dev.destroyPipeline(self.handle, null);
    self.gc.dev.destroyPipelineLayout(self.layout, null);
    self.gc.dev.destroyDescriptorSetLayout(self.descriptor_set_layout, null);
}

pub fn setLabel(self: *VulkanRayTracingPipelineState, label_value: ?[]const u8) void {
    self.gc.setDebugName(.pipeline, GraphicsContext.debugObjectHandle(self.handle), label_value);
    self.inline_data_buffer.setLabel(label_value);
    self.sbt_buffer.setLabel(label_value);
}

pub fn updateDescriptorSet(
    self: *VulkanRayTracingPipelineState,
    top_level: *const VulkanAccelerationStructure,
    output: *const VulkanTextureView,
    dispatch: core.RayDispatchDescriptor,
) core.AdvancedFeatureError!void {
    if (top_level.kind != .top_level or !top_level.built_value or top_level.handle == .null_handle) {
        return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
    }
    if (dispatch.inline_data.len > self.inline_data_buffer.length()) {
        return core.AdvancedFeatureError.InvalidRayTracingPipeline;
    }
    if (dispatch.inline_data.len != 0) {
        self.inline_data_buffer.replaceBytes(0, dispatch.inline_data) catch {
            return core.AdvancedFeatureError.InvalidRayTracingPipeline;
        };
    }

    const acceleration_structures = [_]vk.AccelerationStructureKHR{top_level.handle};
    const acceleration_structure_info = vk.WriteDescriptorSetAccelerationStructureKHR{
        .acceleration_structure_count = acceleration_structures.len,
        .p_acceleration_structures = &acceleration_structures,
    };
    const output_info = vk.DescriptorImageInfo{
        .sampler = .null_handle,
        .image_view = output.handle,
        .image_layout = .general,
    };
    const inline_data_info = vk.DescriptorBufferInfo{
        .buffer = self.inline_data_buffer.handle,
        .offset = 0,
        .range = @intCast(self.inline_data_buffer.length()),
    };
    const writes = [_]vk.WriteDescriptorSet{
        .{
            .p_next = &acceleration_structure_info,
            .dst_set = self.descriptor_set,
            .dst_binding = 0,
            .dst_array_element = 0,
            .descriptor_count = 1,
            .descriptor_type = .acceleration_structure_khr,
            .p_image_info = undefined,
            .p_buffer_info = undefined,
            .p_texel_buffer_view = undefined,
        },
        .{
            .dst_set = self.descriptor_set,
            .dst_binding = 1,
            .dst_array_element = 0,
            .descriptor_count = 1,
            .descriptor_type = .storage_image,
            .p_image_info = @ptrCast(&output_info),
            .p_buffer_info = undefined,
            .p_texel_buffer_view = undefined,
        },
        .{
            .dst_set = self.descriptor_set,
            .dst_binding = 2,
            .dst_array_element = 0,
            .descriptor_count = 1,
            .descriptor_type = .uniform_buffer,
            .p_image_info = undefined,
            .p_buffer_info = @ptrCast(&inline_data_info),
            .p_texel_buffer_view = undefined,
        },
    };
    self.gc.dev.updateDescriptorSets(&writes, null);
}

fn createDescriptorSetLayout(gc: *const GraphicsContext) !vk.DescriptorSetLayout {
    const bindings = [_]vk.DescriptorSetLayoutBinding{
        .{
            .binding = 0,
            .descriptor_type = .acceleration_structure_khr,
            .descriptor_count = 1,
            .stage_flags = .{ .raygen_bit_khr = true },
        },
        .{
            .binding = 1,
            .descriptor_type = .storage_image,
            .descriptor_count = 1,
            .stage_flags = .{ .raygen_bit_khr = true },
        },
        .{
            .binding = 2,
            .descriptor_type = .uniform_buffer,
            .descriptor_count = 1,
            .stage_flags = .{
                .raygen_bit_khr = true,
                .closest_hit_bit_khr = true,
                .intersection_bit_khr = true,
            },
        },
    };
    return try gc.dev.createDescriptorSetLayout(&.{
        .binding_count = bindings.len,
        .p_bindings = &bindings,
    }, null);
}

fn createDescriptorPool(gc: *const GraphicsContext) !vk.DescriptorPool {
    const pool_sizes = [_]vk.DescriptorPoolSize{
        .{ .type = .acceleration_structure_khr, .descriptor_count = 1 },
        .{ .type = .storage_image, .descriptor_count = 1 },
        .{ .type = .uniform_buffer, .descriptor_count = 1 },
    };
    return try gc.dev.createDescriptorPool(&.{
        .max_sets = 1,
        .pool_size_count = pool_sizes.len,
        .p_pool_sizes = &pool_sizes,
    }, null);
}

fn alignForwardU64(value: u64, alignment: u32) u64 {
    const alignment_value = @as(u64, @max(alignment, 1));
    return std.mem.alignForward(u64, value, alignment_value);
}

fn findHitGroupKind(descriptor: core.RayTracingPipelineDescriptor) core.RayTracingHitGroupKind {
    for (descriptor.shader_groups) |group| {
        if (group.kind == .hit) return group.hit_group_kind;
    }
    return .triangles;
}
