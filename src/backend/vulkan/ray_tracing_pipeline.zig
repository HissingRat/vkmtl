const std = @import("std");
const vk = @import("vulkan");
const core = @import("../../core.zig");
const GraphicsContext = @import("graphics_context.zig");
const VulkanBindGroupBackend = @import("bind_group.zig");
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
bind_group_layout_entries: []core.BindGroupLayoutEntry,
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

    const application_layout = descriptor.bind_group_layout;
    const bind_group_layout_entries = try allocator.dupe(
        core.BindGroupLayoutEntry,
        if (application_layout) |layout_descriptor| layout_descriptor.entries else &.{},
    );
    errdefer allocator.free(bind_group_layout_entries);

    const descriptor_set_layout = try createDescriptorSetLayout(gc, allocator, bind_group_layout_entries);
    errdefer gc.dev.destroyDescriptorSetLayout(descriptor_set_layout, null);

    const set_layouts = [_]vk.DescriptorSetLayout{descriptor_set_layout};
    const layout = try gc.dev.createPipelineLayout(&.{
        .set_layout_count = set_layouts.len,
        .p_set_layouts = &set_layouts,
        .push_constant_range_count = 0,
        .p_push_constant_ranges = null,
    }, null);
    errdefer gc.dev.destroyPipelineLayout(layout, null);

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
        .bind_group_layout_entries = bind_group_layout_entries,
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
    self.gc.dev.destroyPipeline(self.handle, null);
    self.gc.dev.destroyPipelineLayout(self.layout, null);
    self.gc.dev.destroyDescriptorSetLayout(self.descriptor_set_layout, null);
    self.allocator.free(self.bind_group_layout_entries);
}

pub fn setLabel(self: *VulkanRayTracingPipelineState, label_value: ?[]const u8) void {
    self.gc.setDebugName(.pipeline, GraphicsContext.debugObjectHandle(self.handle), label_value);
    self.sbt_buffer.setLabel(label_value);
}

pub const DispatchResources = struct {
    gc: *const GraphicsContext,
    descriptor_pool: vk.DescriptorPool,
    descriptor_set: vk.DescriptorSet,
    inline_data_buffer: VulkanBuffer,

    pub fn deinit(self: *DispatchResources) void {
        self.inline_data_buffer.deinit();
        self.gc.dev.destroyDescriptorPool(self.descriptor_pool, null);
        self.descriptor_pool = .null_handle;
        self.descriptor_set = .null_handle;
    }
};

pub fn makeDispatchResources(
    self: *VulkanRayTracingPipelineState,
    top_level: *const VulkanAccelerationStructure,
    output: *const VulkanTextureView,
    dispatch: core.RayDispatchDescriptor,
    bind_group: ?*const VulkanBindGroupBackend.VulkanBindGroup,
) core.AdvancedFeatureError!DispatchResources {
    if (top_level.kind != .top_level or !top_level.built_value or top_level.handle == .null_handle) {
        return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
    }
    const inline_data_capacity = 4096;
    if (dispatch.inline_data.len > inline_data_capacity) {
        return core.AdvancedFeatureError.InvalidRayTracingPipeline;
    }

    if (!bindGroupMatchesLayout(self.bind_group_layout_entries, bind_group) or
        !bindGroupResourcesMatchLayout(self.bind_group_layout_entries, bind_group) or
        bindGroupSamplesOutput(output, bind_group))
    {
        return core.AdvancedFeatureError.InvalidRayTracingPipeline;
    }

    const descriptor_pool = createDescriptorPool(self.gc, self.bind_group_layout_entries) catch {
        return core.AdvancedFeatureError.InvalidRayTracingPipeline;
    };
    errdefer self.gc.dev.destroyDescriptorPool(descriptor_pool, null);

    const set_layouts = [_]vk.DescriptorSetLayout{self.descriptor_set_layout};
    var descriptor_set: vk.DescriptorSet = undefined;
    self.gc.dev.allocateDescriptorSets(&.{
        .descriptor_pool = descriptor_pool,
        .descriptor_set_count = 1,
        .p_set_layouts = &set_layouts,
    }, @ptrCast(&descriptor_set)) catch {
        return core.AdvancedFeatureError.InvalidRayTracingPipeline;
    };

    var inline_data_bytes = [_]u8{0} ** inline_data_capacity;
    var inline_data_buffer = VulkanBuffer.init(self.gc, .{
        .label = "vkmtl ray tracing dispatch inline data",
        .length = inline_data_bytes.len,
        .bytes = inline_data_bytes[0..],
        .usage = .{ .uniform = true },
        .storage_mode = .shared,
    }) catch {
        return core.AdvancedFeatureError.InvalidRayTracingPipeline;
    };
    errdefer inline_data_buffer.deinit();

    if (dispatch.inline_data.len != 0) {
        inline_data_buffer.replaceBytes(0, dispatch.inline_data) catch {
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
        .buffer = inline_data_buffer.handle,
        .offset = 0,
        .range = @intCast(inline_data_buffer.length()),
    };
    const application_entries = if (bind_group) |group| group.entries else &.{};
    const writes = self.allocator.alloc(vk.WriteDescriptorSet, 3 + application_entries.len) catch {
        return core.AdvancedFeatureError.InvalidRayTracingPipeline;
    };
    defer self.allocator.free(writes);
    const application_resource_count = bindGroupResourceCount(application_entries);
    const buffer_infos = self.allocator.alloc(vk.DescriptorBufferInfo, application_resource_count) catch {
        return core.AdvancedFeatureError.InvalidRayTracingPipeline;
    };
    defer self.allocator.free(buffer_infos);
    const image_infos = self.allocator.alloc(vk.DescriptorImageInfo, application_resource_count) catch {
        return core.AdvancedFeatureError.InvalidRayTracingPipeline;
    };
    defer self.allocator.free(image_infos);

    writes[0] = .{
        .p_next = &acceleration_structure_info,
        .dst_set = descriptor_set,
        .dst_binding = 0,
        .dst_array_element = 0,
        .descriptor_count = 1,
        .descriptor_type = .acceleration_structure_khr,
        .p_image_info = undefined,
        .p_buffer_info = undefined,
        .p_texel_buffer_view = undefined,
    };
    writes[1] = .{
        .dst_set = descriptor_set,
        .dst_binding = 1,
        .dst_array_element = 0,
        .descriptor_count = 1,
        .descriptor_type = .storage_image,
        .p_image_info = @ptrCast(&output_info),
        .p_buffer_info = undefined,
        .p_texel_buffer_view = undefined,
    };
    writes[2] = .{
        .dst_set = descriptor_set,
        .dst_binding = 2,
        .dst_array_element = 0,
        .descriptor_count = 1,
        .descriptor_type = .uniform_buffer,
        .p_image_info = undefined,
        .p_buffer_info = @ptrCast(&inline_data_info),
        .p_texel_buffer_view = undefined,
    };

    var resource_info_index: usize = 0;
    for (application_entries, writes[3..]) |entry, *write| {
        const layout_entry = layoutEntryForBinding(self.bind_group_layout_entries, entry.binding) orelse {
            return core.AdvancedFeatureError.InvalidRayTracingPipeline;
        };
        if (entry.resourceCount() != layout_entry.array_count) {
            return core.AdvancedFeatureError.InvalidRayTracingPipeline;
        }
        const first_info_index = resource_info_index;
        write.* = .{
            .dst_set = descriptor_set,
            .dst_binding = entry.binding,
            .dst_array_element = 0,
            .descriptor_count = @intCast(entry.resourceCount()),
            .descriptor_type = descriptorTypeForLayoutEntry(layout_entry),
            .p_image_info = undefined,
            .p_buffer_info = undefined,
            .p_texel_buffer_view = undefined,
        };

        for (0..entry.resourceCount()) |array_index| {
            const resource = entry.resourceAt(array_index);
            if (std.meta.activeTag(resource) != layout_entry.resource) {
                return core.AdvancedFeatureError.InvalidRayTracingPipeline;
            }
            switch (resource) {
                .uniform_buffer, .storage_buffer => |binding| {
                    buffer_infos[resource_info_index] = .{
                        .buffer = binding.buffer.handle,
                        .offset = binding.offset,
                        .range = binding.size orelse vk.WHOLE_SIZE,
                    };
                },
                .sampled_texture => |texture_view| {
                    image_infos[resource_info_index] = .{
                        .sampler = .null_handle,
                        .image_view = texture_view.handle,
                        .image_layout = .shader_read_only_optimal,
                    };
                },
                .storage_texture => |texture_view| {
                    image_infos[resource_info_index] = .{
                        .sampler = .null_handle,
                        .image_view = texture_view.handle,
                        .image_layout = .general,
                    };
                },
                .sampler, .compare_sampler => |sampler_state| {
                    image_infos[resource_info_index] = .{
                        .sampler = sampler_state.handle,
                        .image_view = .null_handle,
                        .image_layout = .undefined,
                    };
                },
            }
            resource_info_index += 1;
        }

        switch (layout_entry.resource) {
            .uniform_buffer, .storage_buffer => write.p_buffer_info = @ptrCast(&buffer_infos[first_info_index]),
            .storage_texture, .sampled_texture, .sampler, .compare_sampler => {
                write.p_image_info = @ptrCast(&image_infos[first_info_index]);
            },
        }
    }

    self.gc.dev.updateDescriptorSets(writes, null);
    return .{
        .gc = self.gc,
        .descriptor_pool = descriptor_pool,
        .descriptor_set = descriptor_set,
        .inline_data_buffer = inline_data_buffer,
    };
}

fn createDescriptorSetLayout(
    gc: *const GraphicsContext,
    allocator: std.mem.Allocator,
    application_entries: []const core.BindGroupLayoutEntry,
) !vk.DescriptorSetLayout {
    const bindings = try allocator.alloc(vk.DescriptorSetLayoutBinding, 3 + application_entries.len);
    defer allocator.free(bindings);
    bindings[0] = .{
        .binding = 0,
        .descriptor_type = .acceleration_structure_khr,
        .descriptor_count = 1,
        .stage_flags = .{ .raygen_bit_khr = true },
    };
    bindings[1] = .{
        .binding = 1,
        .descriptor_type = .storage_image,
        .descriptor_count = 1,
        .stage_flags = .{ .raygen_bit_khr = true },
    };
    bindings[2] = .{
        .binding = 2,
        .descriptor_type = .uniform_buffer,
        .descriptor_count = 1,
        .stage_flags = .{
            .raygen_bit_khr = true,
            .closest_hit_bit_khr = true,
            .intersection_bit_khr = true,
        },
    };
    if (!applicationBindingsValid(application_entries)) {
        return core.AdvancedFeatureError.InvalidRayTracingPipeline;
    }
    for (application_entries, bindings[3..]) |entry, *binding| {
        binding.* = .{
            .binding = entry.binding,
            .descriptor_type = descriptorTypeForLayoutEntry(entry),
            .descriptor_count = entry.array_count,
            .stage_flags = rayTracingShaderStageFlags(),
        };
    }
    return try gc.dev.createDescriptorSetLayout(&.{
        .binding_count = @intCast(bindings.len),
        .p_bindings = bindings.ptr,
    }, null);
}

fn createDescriptorPool(
    gc: *const GraphicsContext,
    application_entries: []const core.BindGroupLayoutEntry,
) !vk.DescriptorPool {
    const counts = descriptorPoolCounts(application_entries);
    var pool_sizes: [6]vk.DescriptorPoolSize = undefined;
    var pool_size_count: usize = 0;
    appendPoolSize(&pool_sizes, &pool_size_count, .acceleration_structure_khr, 1);
    appendPoolSize(&pool_sizes, &pool_size_count, .storage_image, counts.storage_images +| 1);
    appendPoolSize(&pool_sizes, &pool_size_count, .uniform_buffer, counts.uniform_buffers +| 1);
    appendPoolSize(&pool_sizes, &pool_size_count, .storage_buffer, counts.storage_buffers);
    appendPoolSize(&pool_sizes, &pool_size_count, .sampled_image, counts.sampled_images);
    appendPoolSize(&pool_sizes, &pool_size_count, .sampler, counts.samplers);
    return try gc.dev.createDescriptorPool(&.{
        .max_sets = 1,
        .pool_size_count = @intCast(pool_size_count),
        .p_pool_sizes = pool_sizes[0..pool_size_count].ptr,
    }, null);
}

const DescriptorPoolCounts = struct {
    uniform_buffers: u32 = 0,
    storage_buffers: u32 = 0,
    storage_images: u32 = 0,
    sampled_images: u32 = 0,
    samplers: u32 = 0,
};

fn descriptorPoolCounts(entries: []const core.BindGroupLayoutEntry) DescriptorPoolCounts {
    var result = DescriptorPoolCounts{};
    for (entries) |entry| switch (entry.resource) {
        .uniform_buffer => result.uniform_buffers +|= entry.array_count,
        .storage_buffer => result.storage_buffers +|= entry.array_count,
        .storage_texture => result.storage_images +|= entry.array_count,
        .sampled_texture => result.sampled_images +|= entry.array_count,
        .sampler, .compare_sampler => result.samplers +|= entry.array_count,
    };
    return result;
}

fn appendPoolSize(
    pool_sizes: *[6]vk.DescriptorPoolSize,
    count: *usize,
    descriptor_type: vk.DescriptorType,
    descriptor_count: u32,
) void {
    if (descriptor_count == 0) return;
    pool_sizes[count.*] = .{
        .type = descriptor_type,
        .descriptor_count = descriptor_count,
    };
    count.* += 1;
}

fn descriptorTypeForLayoutEntry(entry: core.BindGroupLayoutEntry) vk.DescriptorType {
    return switch (entry.resource) {
        .uniform_buffer => .uniform_buffer,
        .storage_buffer => .storage_buffer,
        .storage_texture => .storage_image,
        .sampled_texture => .sampled_image,
        .sampler, .compare_sampler => .sampler,
    };
}

fn rayTracingShaderStageFlags() vk.ShaderStageFlags {
    return .{
        .raygen_bit_khr = true,
        .any_hit_bit_khr = true,
        .closest_hit_bit_khr = true,
        .miss_bit_khr = true,
        .intersection_bit_khr = true,
        .callable_bit_khr = true,
    };
}

fn applicationBindingValid(entry: core.BindGroupLayoutEntry) bool {
    if (entry.array_count == 0 or entry.binding < 3 or entry.binding > 14) return false;
    return @as(u64, entry.binding) + @as(u64, entry.array_count) <= 15;
}

fn applicationBindingsValid(entries: []const core.BindGroupLayoutEntry) bool {
    for (entries, 0..) |entry, i| {
        if (!applicationBindingValid(entry) or entry.dynamic_offset or !entry.visibility.ray_tracing) {
            return false;
        }
        const entry_end = entry.binding + entry.array_count;
        for (entries[i + 1 ..]) |other| {
            if (!applicationBindingValid(other)) return false;
            const other_end = other.binding + other.array_count;
            if (entry.binding < other_end and other.binding < entry_end) return false;
        }
    }
    return true;
}

fn bindGroupMatchesLayout(
    expected: []const core.BindGroupLayoutEntry,
    bind_group: ?*const VulkanBindGroupBackend.VulkanBindGroup,
) bool {
    const group = bind_group orelse return expected.len == 0;
    if (expected.len == 0 or group.layout_entries.len != expected.len) return false;
    for (expected) |expected_entry| {
        const actual_entry = layoutEntryForBinding(group.layout_entries, expected_entry.binding) orelse return false;
        if (!std.meta.eql(expected_entry, actual_entry)) return false;
    }
    return true;
}

fn bindGroupResourcesMatchLayout(
    expected: []const core.BindGroupLayoutEntry,
    bind_group: ?*const VulkanBindGroupBackend.VulkanBindGroup,
) bool {
    const group = bind_group orelse return expected.len == 0;
    if (group.entries.len != expected.len) return false;
    for (expected) |layout_entry| {
        const entry = bindGroupEntryForBinding(group.entries, layout_entry.binding) orelse return false;
        if (entry.resourceCount() != layout_entry.array_count) return false;
        for (0..entry.resourceCount()) |resource_index| {
            if (std.meta.activeTag(entry.resourceAt(resource_index)) != layout_entry.resource) return false;
        }
    }
    return true;
}

fn bindGroupSamplesOutput(
    output: *const VulkanTextureView,
    bind_group: ?*const VulkanBindGroupBackend.VulkanBindGroup,
) bool {
    const group = bind_group orelse return false;
    for (group.entries) |entry| {
        for (0..entry.resourceCount()) |resource_index| switch (entry.resourceAt(resource_index)) {
            .sampled_texture => |texture_view| if (texture_view.image == output.image) return true,
            .uniform_buffer, .storage_buffer, .storage_texture, .sampler, .compare_sampler => {},
        };
    }
    return false;
}

fn bindGroupEntryForBinding(
    entries: []const VulkanBindGroupBackend.VulkanBindGroup.Entry,
    binding: u32,
) ?VulkanBindGroupBackend.VulkanBindGroup.Entry {
    for (entries) |entry| {
        if (entry.binding == binding) return entry;
    }
    return null;
}

fn layoutEntryForBinding(
    entries: []const core.BindGroupLayoutEntry,
    binding: u32,
) ?core.BindGroupLayoutEntry {
    for (entries) |entry| {
        if (entry.binding == binding) return entry;
    }
    return null;
}

fn bindGroupResourceCount(entries: []const VulkanBindGroupBackend.VulkanBindGroup.Entry) usize {
    var count: usize = 0;
    for (entries) |entry| count += entry.resourceCount();
    return count;
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

test "Vulkan ray tracing dispatch state is not shared by pipeline instances" {
    try std.testing.expect(!@hasField(VulkanRayTracingPipelineState, "descriptor_set"));
    try std.testing.expect(!@hasField(VulkanRayTracingPipelineState, "inline_data_buffer"));
    try std.testing.expect(@hasField(DispatchResources, "descriptor_set"));
    try std.testing.expect(@hasField(DispatchResources, "inline_data_buffer"));
}

test "Vulkan ray tracing dispatch resource lowering compiles with optional bind groups" {
    var pipeline: VulkanRayTracingPipelineState = undefined;
    var top_level: VulkanAccelerationStructure = undefined;
    var output: VulkanTextureView = undefined;
    top_level.kind = .bottom_level;

    try std.testing.expectError(
        core.AdvancedFeatureError.InvalidAccelerationStructureResources,
        pipeline.makeDispatchResources(&top_level, &output, .{ .width = 1 }, null),
    );
}

test "Vulkan ray tracing application descriptor counts include arrays" {
    const counts = descriptorPoolCounts(&.{
        .{
            .binding = 3,
            .resource = .sampled_texture,
            .visibility = .{ .ray_tracing = true },
            .array_count = 2,
        },
        .{
            .binding = 5,
            .resource = .storage_buffer,
            .visibility = .{ .ray_tracing = true },
            .array_count = 3,
        },
        .{
            .binding = 8,
            .resource = .compare_sampler,
            .visibility = .{ .ray_tracing = true },
        },
    });
    try std.testing.expectEqual(@as(u32, 2), counts.sampled_images);
    try std.testing.expectEqual(@as(u32, 3), counts.storage_buffers);
    try std.testing.expectEqual(@as(u32, 1), counts.samplers);
}

test "Vulkan ray tracing application bindings reject flattened array overlap" {
    try std.testing.expect(applicationBindingsValid(&.{
        .{
            .binding = 3,
            .resource = .sampled_texture,
            .visibility = .{ .ray_tracing = true },
            .array_count = 2,
        },
        .{
            .binding = 5,
            .resource = .sampler,
            .visibility = .{ .ray_tracing = true },
        },
    }));
    try std.testing.expect(!applicationBindingsValid(&.{
        .{
            .binding = 3,
            .resource = .sampled_texture,
            .visibility = .{ .ray_tracing = true },
            .array_count = 2,
        },
        .{
            .binding = 4,
            .resource = .sampler,
            .visibility = .{ .ray_tracing = true },
        },
    }));
}
