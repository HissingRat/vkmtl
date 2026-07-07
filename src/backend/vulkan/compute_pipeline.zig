const std = @import("std");
const vk = @import("vulkan");
const core = @import("../../core.zig");
const VulkanBindGroupLayout = @import("bind_group.zig").VulkanBindGroupLayout;
const GraphicsContext = @import("graphics_context.zig");
const VulkanShaderModule = @import("shader_module.zig");

const VulkanComputePipelineState = @This();

gc: *const GraphicsContext,
allocator: std.mem.Allocator,
handle: vk.Pipeline,
layout: vk.PipelineLayout,
bind_group_layouts: []VulkanBindGroupLayout,

pub fn init(
    gc: *const GraphicsContext,
    allocator: std.mem.Allocator,
    descriptor: core.ComputePipelineDescriptor,
) !VulkanComputePipelineState {
    try descriptor.validate();

    var compute_module = try VulkanShaderModule.init(gc, allocator, descriptor.compute.module);
    defer compute_module.deinit();

    const compute_entry = try allocator.dupeZ(u8, descriptor.compute.entry_point);
    defer allocator.free(compute_entry);

    var compute_specialization = try SpecializationState.init(allocator, descriptor.compute.specialization);
    defer compute_specialization.deinit();

    const bind_group_layouts = try makeBindGroupLayouts(gc, allocator, descriptor.bind_group_layouts);
    errdefer destroyBindGroupLayouts(allocator, bind_group_layouts);

    const set_layout_handles = try makeDescriptorSetLayoutHandles(allocator, bind_group_layouts);
    defer allocator.free(set_layout_handles);
    const push_constant_ranges = try makePushConstantRanges(allocator, descriptor.root_constant_layout);
    defer allocator.free(push_constant_ranges);

    const layout = try gc.dev.createPipelineLayout(&.{
        .flags = .{},
        .set_layout_count = @intCast(set_layout_handles.len),
        .p_set_layouts = if (set_layout_handles.len == 0) null else set_layout_handles.ptr,
        .push_constant_range_count = @intCast(push_constant_ranges.len),
        .p_push_constant_ranges = if (push_constant_ranges.len == 0) null else push_constant_ranges.ptr,
    }, null);
    errdefer gc.dev.destroyPipelineLayout(layout, null);

    const pipeline_info = vk.ComputePipelineCreateInfo{
        .flags = .{},
        .stage = .{
            .stage = .{ .compute_bit = true },
            .module = compute_module.handle,
            .p_name = compute_entry,
            .p_specialization_info = compute_specialization.infoPtr(),
        },
        .layout = layout,
        .base_pipeline_handle = .null_handle,
        .base_pipeline_index = -1,
    };

    var pipeline: vk.Pipeline = undefined;
    _ = try gc.dev.createComputePipelines(.null_handle, &.{pipeline_info}, null, (&pipeline)[0..1]);

    return .{
        .gc = gc,
        .allocator = allocator,
        .handle = pipeline,
        .layout = layout,
        .bind_group_layouts = bind_group_layouts,
    };
}

pub fn deinit(self: *VulkanComputePipelineState) void {
    self.gc.dev.destroyPipeline(self.handle, null);
    self.gc.dev.destroyPipelineLayout(self.layout, null);
    destroyBindGroupLayouts(self.allocator, self.bind_group_layouts);
}

pub fn setLabel(self: *VulkanComputePipelineState, label_value: ?[]const u8) void {
    self.gc.setDebugName(.pipeline, GraphicsContext.debugObjectHandle(self.handle), label_value);
}

fn makeBindGroupLayouts(
    gc: *const GraphicsContext,
    allocator: std.mem.Allocator,
    descriptors: []const core.BindGroupLayoutDescriptor,
) ![]VulkanBindGroupLayout {
    const layouts = try allocator.alloc(VulkanBindGroupLayout, descriptors.len);
    errdefer allocator.free(layouts);

    var initialized: usize = 0;
    errdefer {
        for (layouts[0..initialized]) |*layout| {
            layout.deinit();
        }
    }

    for (descriptors, layouts) |descriptor, *layout| {
        layout.* = try VulkanBindGroupLayout.init(gc, allocator, descriptor);
        initialized += 1;
    }

    return layouts;
}

fn makeDescriptorSetLayoutHandles(
    allocator: std.mem.Allocator,
    layouts: []const VulkanBindGroupLayout,
) ![]vk.DescriptorSetLayout {
    const handles = try allocator.alloc(vk.DescriptorSetLayout, layouts.len);
    for (layouts, handles) |layout, *handle| {
        handle.* = layout.handle;
    }
    return handles;
}

fn makePushConstantRanges(
    allocator: std.mem.Allocator,
    layout: ?core.RootConstantLayoutDescriptor,
) ![]vk.PushConstantRange {
    const root_layout = layout orelse return &.{};
    const ranges = try allocator.alloc(vk.PushConstantRange, root_layout.ranges.len);
    for (root_layout.ranges, ranges) |range, *out| {
        out.* = .{
            .stage_flags = shaderStageFlags(range.visibility),
            .offset = range.offset,
            .size = range.size,
        };
    }
    return ranges;
}

fn destroyBindGroupLayouts(
    allocator: std.mem.Allocator,
    layouts: []VulkanBindGroupLayout,
) void {
    for (layouts) |*layout| {
        layout.deinit();
    }
    allocator.free(layouts);
}

fn shaderStageFlags(visibility: core.ShaderVisibility) vk.ShaderStageFlags {
    return .{
        .vertex_bit = visibility.vertex,
        .fragment_bit = visibility.fragment,
        .compute_bit = visibility.compute,
    };
}

const SpecializationState = struct {
    allocator: ?std.mem.Allocator = null,
    entries: []vk.SpecializationMapEntry = &.{},
    data: []u8 = &.{},
    info: vk.SpecializationInfo = .{},

    fn empty() SpecializationState {
        return .{};
    }

    fn init(
        allocator: std.mem.Allocator,
        descriptor: core.ShaderSpecializationDescriptor,
    ) !SpecializationState {
        if (descriptor.constants.len == 0) return empty();

        const entries = try allocator.alloc(vk.SpecializationMapEntry, descriptor.constants.len);
        errdefer allocator.free(entries);
        const data = try allocator.alloc(u8, descriptor.constants.len * 4);
        errdefer allocator.free(data);

        var offset: u32 = 0;
        for (descriptor.constants, entries) |constant, *entry| {
            entry.* = .{
                .constant_id = constant.id,
                .offset = offset,
                .size = 4,
            };
            writeSpecializationValue(data[offset..][0..4], constant.value);
            offset += 4;
        }

        return .{
            .allocator = allocator,
            .entries = entries,
            .data = data,
            .info = .{
                .map_entry_count = @intCast(entries.len),
                .p_map_entries = entries.ptr,
                .data_size = data.len,
                .p_data = data.ptr,
            },
        };
    }

    fn deinit(self: *SpecializationState) void {
        if (self.allocator) |allocator| {
            allocator.free(self.entries);
            allocator.free(self.data);
        }
        self.* = undefined;
    }

    fn infoPtr(self: *const SpecializationState) ?*const vk.SpecializationInfo {
        if (self.entries.len == 0) return null;
        return &self.info;
    }
};

fn writeSpecializationValue(out: []u8, value: core.ShaderSpecializationValue) void {
    const bits: u32 = switch (value) {
        .bool => |v| if (v) 1 else 0,
        .i32 => |v| @bitCast(v),
        .u32 => |v| v,
        .f32 => |v| @bitCast(v),
    };
    std.mem.writeInt(u32, out[0..4], bits, .little);
}
