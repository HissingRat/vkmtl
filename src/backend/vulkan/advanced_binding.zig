const std = @import("std");
const vk = @import("vulkan");
const core = @import("../../core.zig");
const GraphicsContext = @import("graphics_context.zig");
const VulkanBuffer = @import("buffer.zig");
const VulkanSamplerState = @import("sampler.zig");
const VulkanTextureView = @import("texture_view.zig");

const VulkanAdvancedBindGroupLayout = @This();

gc: *const GraphicsContext,
allocator: std.mem.Allocator,
handle: vk.DescriptorSetLayout,
ranges: []core.DescriptorIndexingRange,
uses_partially_bound_ranges: bool,
uses_update_after_bind_ranges: bool,

pub fn init(
    gc: *const GraphicsContext,
    allocator: std.mem.Allocator,
    descriptor: core.DescriptorIndexingLayoutDescriptor,
) !VulkanAdvancedBindGroupLayout {
    if (descriptor.model != .descriptor_indexing) return core.AdvancedFeatureError.UnsupportedDescriptorIndexing;

    const ranges = try allocator.dupe(core.DescriptorIndexingRange, descriptor.ranges);
    errdefer allocator.free(ranges);
    const bindings = try allocator.alloc(vk.DescriptorSetLayoutBinding, ranges.len);
    defer allocator.free(bindings);
    const binding_flags = try allocator.alloc(vk.DescriptorBindingFlags, ranges.len);
    defer allocator.free(binding_flags);

    var uses_partially_bound_ranges = false;
    var uses_update_after_bind_ranges = false;
    for (ranges, bindings, binding_flags) |range, *binding, *flags| {
        uses_partially_bound_ranges = uses_partially_bound_ranges or range.partially_bound;
        uses_update_after_bind_ranges = uses_update_after_bind_ranges or range.update_after_bind;
        binding.* = .{
            .binding = range.binding,
            .descriptor_type = descriptorType(range.resource),
            .descriptor_count = range.descriptor_count,
            .stage_flags = shaderStageFlags(range.visibility),
        };
        flags.* = .{
            .partially_bound_bit = range.partially_bound,
            .update_after_bind_bit = range.update_after_bind,
            .update_unused_while_pending_bit = range.update_after_bind,
        };
    }

    const flags_info = vk.DescriptorSetLayoutBindingFlagsCreateInfo{
        .binding_count = @intCast(binding_flags.len),
        .p_binding_flags = if (binding_flags.len == 0) null else binding_flags.ptr,
    };
    const handle = try gc.dev.createDescriptorSetLayout(&.{
        .p_next = &flags_info,
        .flags = .{ .update_after_bind_pool_bit = uses_update_after_bind_ranges },
        .binding_count = @intCast(bindings.len),
        .p_bindings = if (bindings.len == 0) null else bindings.ptr,
    }, null);

    return .{
        .gc = gc,
        .allocator = allocator,
        .handle = handle,
        .ranges = ranges,
        .uses_partially_bound_ranges = uses_partially_bound_ranges,
        .uses_update_after_bind_ranges = uses_update_after_bind_ranges,
    };
}

pub fn deinit(self: *VulkanAdvancedBindGroupLayout) void {
    self.gc.dev.destroyDescriptorSetLayout(self.handle, null);
    self.allocator.free(self.ranges);
}

pub const ResourceTable = struct {
    gc: *const GraphicsContext,
    allocator: std.mem.Allocator,
    layout: vk.DescriptorSetLayout,
    pool: vk.DescriptorPool,
    set: vk.DescriptorSet,
    ranges: []core.DescriptorIndexingRange,
    resources: []?Resource,
    update_after_bind: bool,

    pub const BufferBinding = struct {
        buffer: *const VulkanBuffer,
        offset: u64 = 0,
        size: ?u64 = null,
    };

    pub const Resource = union(core.BindingResourceKind) {
        uniform_buffer: BufferBinding,
        storage_buffer: BufferBinding,
        storage_texture: *const VulkanTextureView,
        sampled_texture: *const VulkanTextureView,
        sampler: *const VulkanSamplerState,
        compare_sampler: *const VulkanSamplerState,
    };

    pub fn init(layout: *const VulkanAdvancedBindGroupLayout) !ResourceTable {
        const ranges = try layout.allocator.dupe(core.DescriptorIndexingRange, layout.ranges);
        errdefer layout.allocator.free(ranges);
        const resources = try layout.allocator.alloc(?Resource, totalDescriptorCount(ranges));
        errdefer layout.allocator.free(resources);
        @memset(resources, null);

        const pool = try createPool(layout.gc, ranges, layout.uses_update_after_bind_ranges);
        errdefer layout.gc.dev.destroyDescriptorPool(pool, null);
        const set = try allocateSet(layout.gc, pool, layout.handle);
        return .{
            .gc = layout.gc,
            .allocator = layout.allocator,
            .layout = layout.handle,
            .pool = pool,
            .set = set,
            .ranges = ranges,
            .resources = resources,
            .update_after_bind = layout.uses_update_after_bind_ranges,
        };
    }

    pub fn deinit(self: *ResourceTable) void {
        self.gc.dev.destroyDescriptorPool(self.pool, null);
        self.allocator.free(self.resources);
        self.allocator.free(self.ranges);
    }

    pub fn update(self: *ResourceTable, slot: core.ResourceTableSlot, resource: Resource) !void {
        const index = try self.resolveIndex(slot);
        self.resources[index] = resource;
        self.write(slot, resource);
    }

    pub fn clear(self: *ResourceTable, slot: core.ResourceTableSlot) !void {
        const index = try self.resolveIndex(slot);
        self.resources[index] = null;
        try self.rebuildSet();
    }

    pub fn transitionStorageTextures(self: *const ResourceTable, cmdbuf: vk.CommandBuffer) void {
        for (self.resources) |resource| {
            if (resource) |value| switch (value) {
                .storage_texture => |view| view.transitionLayout(cmdbuf, .general),
                else => {},
            };
        }
    }

    fn rebuildSet(self: *ResourceTable) !void {
        const new_pool = try createPool(self.gc, self.ranges, self.update_after_bind);
        errdefer self.gc.dev.destroyDescriptorPool(new_pool, null);
        const new_set = try allocateSet(self.gc, new_pool, self.layout);
        self.gc.dev.destroyDescriptorPool(self.pool, null);
        self.pool = new_pool;
        self.set = new_set;
        var base: usize = 0;
        for (self.ranges) |range| {
            for (0..range.descriptor_count) |element| {
                if (self.resources[base + element]) |resource| {
                    self.write(.{ .binding = range.binding, .array_element = @intCast(element) }, resource);
                }
            }
            base += range.descriptor_count;
        }
    }

    fn write(self: *ResourceTable, slot: core.ResourceTableSlot, resource: Resource) void {
        var buffer_info: vk.DescriptorBufferInfo = undefined;
        var image_info: vk.DescriptorImageInfo = undefined;
        var write_info = vk.WriteDescriptorSet{
            .dst_set = self.set,
            .dst_binding = slot.binding,
            .dst_array_element = slot.array_element,
            .descriptor_count = 1,
            .descriptor_type = descriptorType(@as(core.BindingResourceKind, resource)),
            .p_image_info = undefined,
            .p_buffer_info = undefined,
            .p_texel_buffer_view = undefined,
        };
        switch (resource) {
            .uniform_buffer, .storage_buffer => |binding| {
                buffer_info = .{
                    .buffer = binding.buffer.handle,
                    .offset = binding.offset,
                    .range = binding.size orelse vk.WHOLE_SIZE,
                };
                write_info.p_buffer_info = @ptrCast(&buffer_info);
            },
            .sampled_texture => |view| {
                image_info = .{
                    .sampler = .null_handle,
                    .image_view = view.handle,
                    .image_layout = .shader_read_only_optimal,
                };
                write_info.p_image_info = @ptrCast(&image_info);
            },
            .storage_texture => |view| {
                image_info = .{
                    .sampler = .null_handle,
                    .image_view = view.handle,
                    .image_layout = .general,
                };
                write_info.p_image_info = @ptrCast(&image_info);
            },
            .sampler, .compare_sampler => |sampler| {
                image_info = .{
                    .sampler = sampler.handle,
                    .image_view = .null_handle,
                    .image_layout = .undefined,
                };
                write_info.p_image_info = @ptrCast(&image_info);
            },
        }
        self.gc.dev.updateDescriptorSets(&.{write_info}, null);
    }

    fn resolveIndex(self: ResourceTable, slot: core.ResourceTableSlot) core.BindingError!usize {
        var base: usize = 0;
        for (self.ranges) |range| {
            if (range.binding == slot.binding) {
                if (slot.array_element >= range.descriptor_count) return core.BindingError.InvalidResourceTableSlot;
                return base + slot.array_element;
            }
            base += range.descriptor_count;
        }
        return core.BindingError.InvalidResourceTableSlot;
    }
};

fn createPool(
    gc: *const GraphicsContext,
    ranges: []const core.DescriptorIndexingRange,
    update_after_bind: bool,
) !vk.DescriptorPool {
    var counts = [_]u32{0} ** 5;
    for (ranges) |range| counts[descriptorTypeIndex(range.resource)] +|= range.descriptor_count;
    const types = [_]vk.DescriptorType{ .uniform_buffer, .storage_buffer, .storage_image, .sampled_image, .sampler };
    var sizes: [types.len]vk.DescriptorPoolSize = undefined;
    var count: usize = 0;
    for (types, counts) |descriptor_type, descriptor_count| {
        if (descriptor_count == 0) continue;
        sizes[count] = .{ .type = descriptor_type, .descriptor_count = descriptor_count };
        count += 1;
    }
    return try gc.dev.createDescriptorPool(&.{
        .flags = .{ .update_after_bind_bit = update_after_bind },
        .max_sets = 1,
        .pool_size_count = @intCast(count),
        .p_pool_sizes = sizes[0..count].ptr,
    }, null);
}

fn allocateSet(gc: *const GraphicsContext, pool: vk.DescriptorPool, layout: vk.DescriptorSetLayout) !vk.DescriptorSet {
    var set: vk.DescriptorSet = undefined;
    try gc.dev.allocateDescriptorSets(&.{
        .descriptor_pool = pool,
        .descriptor_set_count = 1,
        .p_set_layouts = &.{layout},
    }, @ptrCast(&set));
    return set;
}

fn totalDescriptorCount(ranges: []const core.DescriptorIndexingRange) usize {
    var result: usize = 0;
    for (ranges) |range| result += range.descriptor_count;
    return result;
}

fn descriptorTypeIndex(kind: core.BindingResourceKind) usize {
    return switch (kind) {
        .uniform_buffer => 0,
        .storage_buffer => 1,
        .storage_texture => 2,
        .sampled_texture => 3,
        .sampler, .compare_sampler => 4,
    };
}

fn descriptorType(kind: core.BindingResourceKind) vk.DescriptorType {
    return switch (kind) {
        .uniform_buffer => .uniform_buffer,
        .storage_buffer => .storage_buffer,
        .storage_texture => .storage_image,
        .sampled_texture => .sampled_image,
        .sampler, .compare_sampler => .sampler,
    };
}

fn shaderStageFlags(visibility: core.ShaderVisibility) vk.ShaderStageFlags {
    return .{
        .vertex_bit = visibility.vertex,
        .fragment_bit = visibility.fragment,
        .compute_bit = visibility.compute,
        .raygen_bit_khr = visibility.ray_tracing,
        .any_hit_bit_khr = visibility.ray_tracing,
        .closest_hit_bit_khr = visibility.ray_tracing,
        .miss_bit_khr = visibility.ray_tracing,
        .intersection_bit_khr = visibility.ray_tracing,
        .callable_bit_khr = visibility.ray_tracing,
    };
}

test "Vulkan advanced binding metadata captures descriptor indexing requirements" {
    const ranges = [_]core.DescriptorIndexingRange{
        .{ .binding = 0, .resource = .sampled_texture, .visibility = .{ .fragment = true }, .descriptor_count = 4, .partially_bound = true },
        .{ .binding = 1, .resource = .storage_buffer, .visibility = .{ .compute = true }, .descriptor_count = 2, .update_after_bind = true },
    };
    try std.testing.expectEqual(@as(usize, 6), totalDescriptorCount(&ranges));
    try std.testing.expectEqual(vk.DescriptorType.sampled_image, descriptorType(.sampled_texture));
}
