const std = @import("std");
const vk = @import("vulkan");
const core = @import("../../core.zig");
const VulkanBuffer = @import("buffer.zig");
const VulkanSamplerState = @import("sampler.zig");
const VulkanTextureView = @import("texture_view.zig");
const GraphicsContext = @import("graphics_context.zig");

pub const VulkanBindGroupLayout = struct {
    gc: *const GraphicsContext,
    allocator: std.mem.Allocator,
    handle: vk.DescriptorSetLayout,
    entries: []core.BindGroupLayoutEntry,

    pub fn init(
        gc: *const GraphicsContext,
        allocator: std.mem.Allocator,
        descriptor: core.BindGroupLayoutDescriptor,
    ) !VulkanBindGroupLayout {
        try descriptor.validate();

        const layout_entries = try allocator.dupe(core.BindGroupLayoutEntry, descriptor.entries);
        errdefer allocator.free(layout_entries);

        const bindings = try allocator.alloc(vk.DescriptorSetLayoutBinding, descriptor.entries.len);
        defer allocator.free(bindings);

        for (descriptor.entries, bindings) |entry, *binding| {
            binding.* = .{
                .binding = entry.binding,
                .descriptor_type = descriptorTypeForLayoutEntry(entry),
                .descriptor_count = entry.array_count,
                .stage_flags = shaderStageFlags(entry.visibility),
            };
        }

        const handle = try gc.dev.createDescriptorSetLayout(&.{
            .binding_count = @intCast(bindings.len),
            .p_bindings = bindings.ptr,
        }, null);

        return .{
            .gc = gc,
            .allocator = allocator,
            .handle = handle,
            .entries = layout_entries,
        };
    }

    pub fn deinit(self: *VulkanBindGroupLayout) void {
        self.gc.dev.destroyDescriptorSetLayout(self.handle, null);
        self.allocator.free(self.entries);
    }
};

pub const VulkanBindGroup = struct {
    gc: *const GraphicsContext,
    allocator: std.mem.Allocator,
    pool: vk.DescriptorPool,
    set: vk.DescriptorSet,
    layout_entries: []core.BindGroupLayoutEntry,
    entries: []Entry,
    entry_resources: []Resource,

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

    pub const Entry = struct {
        binding: u32,
        resource: Resource,
        resources: []const Resource = &.{},

        pub fn resourceCount(self: Entry) usize {
            if (self.resources.len != 0) return self.resources.len;
            return 1;
        }

        pub fn resourceAt(self: Entry, index: usize) Resource {
            if (self.resources.len != 0) return self.resources[index];
            std.debug.assert(index == 0);
            return self.resource;
        }
    };

    pub fn init(
        gc: *const GraphicsContext,
        allocator: std.mem.Allocator,
        layout: *const VulkanBindGroupLayout,
        entries: []const Entry,
    ) !VulkanBindGroup {
        const pool = try createDescriptorPool(gc, layout.entries);
        errdefer gc.dev.destroyDescriptorPool(pool, null);

        const set_layouts = [_]vk.DescriptorSetLayout{layout.handle};
        var set: vk.DescriptorSet = undefined;
        try gc.dev.allocateDescriptorSets(&.{
            .descriptor_pool = pool,
            .descriptor_set_count = 1,
            .p_set_layouts = &set_layouts,
        }, @ptrCast(&set));

        try updateDescriptorSet(gc, allocator, set, layout.entries, entries);

        const stored_layout_entries = try allocator.dupe(core.BindGroupLayoutEntry, layout.entries);
        errdefer allocator.free(stored_layout_entries);
        const stored_entries = try allocator.alloc(Entry, entries.len);
        errdefer allocator.free(stored_entries);
        const stored_entry_resources = try copyEntryResourceArrays(allocator, entries, stored_entries);
        errdefer allocator.free(stored_entry_resources);

        return .{
            .gc = gc,
            .allocator = allocator,
            .pool = pool,
            .set = set,
            .layout_entries = stored_layout_entries,
            .entries = stored_entries,
            .entry_resources = stored_entry_resources,
        };
    }

    pub fn deinit(self: *VulkanBindGroup) void {
        self.gc.dev.destroyDescriptorPool(self.pool, null);
        self.allocator.free(self.entry_resources);
        self.allocator.free(self.layout_entries);
        self.allocator.free(self.entries);
    }

    pub fn dynamicOffsets(self: VulkanBindGroup, binding: core.BindGroupBinding) ![]u32 {
        var dynamic_count: usize = 0;
        for (self.layout_entries) |entry| {
            if (entry.dynamic_offset) dynamic_count += 1;
        }

        const offsets = try self.allocator.alloc(u32, dynamic_count);
        errdefer self.allocator.free(offsets);
        if (dynamic_count == 0) return offsets;

        const dynamic_entries = try self.allocator.alloc(core.BindGroupLayoutEntry, dynamic_count);
        defer self.allocator.free(dynamic_entries);

        var index: usize = 0;
        for (self.layout_entries) |entry| {
            if (!entry.dynamic_offset) continue;
            dynamic_entries[index] = entry;
            index += 1;
        }
        std.mem.sort(core.BindGroupLayoutEntry, dynamic_entries, {}, layoutEntryBindingLessThan);

        const offset_list = core.DynamicOffsetList{ .offsets = binding.dynamic_offsets };
        for (dynamic_entries, offsets) |entry, *out| {
            const dynamic_offset = offset_list.offsetForBinding(entry.binding) orelse {
                return core.BindingError.MissingDynamicOffset;
            };
            out.* = std.math.cast(u32, dynamic_offset) orelse {
                return core.BindingError.InvalidDynamicOffsetRange;
            };
        }

        return offsets;
    }
};

fn copyEntryResourceArrays(
    allocator: std.mem.Allocator,
    source_entries: []const VulkanBindGroup.Entry,
    stored_entries: []VulkanBindGroup.Entry,
) ![]VulkanBindGroup.Resource {
    var total_resource_count: usize = 0;
    for (source_entries) |entry| {
        if (entry.resources.len != 0) total_resource_count += entry.resources.len;
    }

    const resources = try allocator.alloc(VulkanBindGroup.Resource, total_resource_count);
    errdefer allocator.free(resources);

    var resource_index: usize = 0;
    for (source_entries, stored_entries) |entry, *stored| {
        stored.* = .{
            .binding = entry.binding,
            .resource = entry.resource,
        };
        if (entry.resources.len == 0) continue;

        const start = resource_index;
        for (entry.resources) |resource| {
            resources[resource_index] = resource;
            resource_index += 1;
        }
        stored.resources = resources[start..resource_index];
    }

    return resources;
}

fn createDescriptorPool(
    gc: *const GraphicsContext,
    layout_entries: []const core.BindGroupLayoutEntry,
) !vk.DescriptorPool {
    var uniform_buffers: u32 = 0;
    var dynamic_uniform_buffers: u32 = 0;
    var storage_buffers: u32 = 0;
    var dynamic_storage_buffers: u32 = 0;
    var storage_textures: u32 = 0;
    var sampled_textures: u32 = 0;
    var samplers: u32 = 0;

    for (layout_entries) |entry| {
        switch (entry.resource) {
            .uniform_buffer => {
                if (entry.dynamic_offset) dynamic_uniform_buffers += entry.array_count else uniform_buffers += entry.array_count;
            },
            .storage_buffer => {
                if (entry.dynamic_offset) dynamic_storage_buffers += entry.array_count else storage_buffers += entry.array_count;
            },
            .storage_texture => storage_textures += entry.array_count,
            .sampled_texture => sampled_textures += entry.array_count,
            .sampler, .compare_sampler => samplers += entry.array_count,
        }
    }

    var pool_sizes: [7]vk.DescriptorPoolSize = undefined;
    var pool_size_count: usize = 0;
    if (uniform_buffers != 0) {
        pool_sizes[pool_size_count] = .{
            .type = .uniform_buffer,
            .descriptor_count = uniform_buffers,
        };
        pool_size_count += 1;
    }
    if (dynamic_uniform_buffers != 0) {
        pool_sizes[pool_size_count] = .{
            .type = .uniform_buffer_dynamic,
            .descriptor_count = dynamic_uniform_buffers,
        };
        pool_size_count += 1;
    }
    if (storage_buffers != 0) {
        pool_sizes[pool_size_count] = .{
            .type = .storage_buffer,
            .descriptor_count = storage_buffers,
        };
        pool_size_count += 1;
    }
    if (dynamic_storage_buffers != 0) {
        pool_sizes[pool_size_count] = .{
            .type = .storage_buffer_dynamic,
            .descriptor_count = dynamic_storage_buffers,
        };
        pool_size_count += 1;
    }
    if (storage_textures != 0) {
        pool_sizes[pool_size_count] = .{
            .type = .storage_image,
            .descriptor_count = storage_textures,
        };
        pool_size_count += 1;
    }
    if (sampled_textures != 0) {
        pool_sizes[pool_size_count] = .{
            .type = .sampled_image,
            .descriptor_count = sampled_textures,
        };
        pool_size_count += 1;
    }
    if (samplers != 0) {
        pool_sizes[pool_size_count] = .{
            .type = .sampler,
            .descriptor_count = samplers,
        };
        pool_size_count += 1;
    }

    return try gc.dev.createDescriptorPool(&.{
        .max_sets = 1,
        .pool_size_count = @intCast(pool_size_count),
        .p_pool_sizes = pool_sizes[0..pool_size_count].ptr,
    }, null);
}

fn updateDescriptorSet(
    gc: *const GraphicsContext,
    allocator: std.mem.Allocator,
    set: vk.DescriptorSet,
    layout_entries: []const core.BindGroupLayoutEntry,
    entries: []const VulkanBindGroup.Entry,
) !void {
    const writes = try allocator.alloc(vk.WriteDescriptorSet, entries.len);
    defer allocator.free(writes);
    const total_resource_count = bindGroupResourceCount(entries);
    const buffer_infos = try allocator.alloc(vk.DescriptorBufferInfo, total_resource_count);
    defer allocator.free(buffer_infos);
    const image_infos = try allocator.alloc(vk.DescriptorImageInfo, total_resource_count);
    defer allocator.free(image_infos);

    var resource_info_index: usize = 0;
    for (entries, writes, 0..) |entry, *write, i| {
        _ = i;
        const layout_entry = layoutEntryForBinding(layout_entries, entry.binding) orelse {
            return core.BindingError.ExtraBindGroupEntry;
        };
        if (entry.resourceCount() != layout_entry.array_count) return core.BindingError.InvalidBindGroupResourceCount;
        const first_info_index = resource_info_index;
        write.* = .{
            .dst_set = set,
            .dst_binding = entry.binding,
            .dst_array_element = 0,
            .descriptor_count = @intCast(entry.resourceCount()),
            .descriptor_type = descriptorTypeForLayoutEntry(layout_entry),
            .p_image_info = undefined,
            .p_buffer_info = undefined,
            .p_texel_buffer_view = undefined,
        };

        for (0..entry.resourceCount()) |resource_index| {
            switch (entry.resourceAt(resource_index)) {
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
            .uniform_buffer, .storage_buffer => {
                write.p_buffer_info = @ptrCast(&buffer_infos[first_info_index]);
            },
            .storage_texture, .sampled_texture, .sampler, .compare_sampler => {
                write.p_image_info = @ptrCast(&image_infos[first_info_index]);
            },
        }
    }

    gc.dev.updateDescriptorSets(writes, null);
}

fn bindGroupResourceCount(entries: []const VulkanBindGroup.Entry) usize {
    var count: usize = 0;
    for (entries) |entry| count += entry.resourceCount();
    return count;
}

fn descriptorTypeForKind(kind: core.BindingResourceKind) vk.DescriptorType {
    return switch (kind) {
        .uniform_buffer => .uniform_buffer,
        .storage_buffer => .storage_buffer,
        .storage_texture => .storage_image,
        .sampled_texture => .sampled_image,
        .sampler, .compare_sampler => .sampler,
    };
}

fn descriptorTypeForLayoutEntry(entry: core.BindGroupLayoutEntry) vk.DescriptorType {
    return switch (entry.resource) {
        .uniform_buffer => if (entry.dynamic_offset) .uniform_buffer_dynamic else .uniform_buffer,
        .storage_buffer => if (entry.dynamic_offset) .storage_buffer_dynamic else .storage_buffer,
        .storage_texture => .storage_image,
        .sampled_texture => .sampled_image,
        .sampler, .compare_sampler => .sampler,
    };
}

fn descriptorTypeForResource(resource: VulkanBindGroup.Resource) vk.DescriptorType {
    return descriptorTypeForKind(switch (resource) {
        .uniform_buffer => core.BindingResourceKind.uniform_buffer,
        .storage_buffer => core.BindingResourceKind.storage_buffer,
        .storage_texture => core.BindingResourceKind.storage_texture,
        .sampled_texture => core.BindingResourceKind.sampled_texture,
        .sampler => core.BindingResourceKind.sampler,
        .compare_sampler => core.BindingResourceKind.compare_sampler,
    });
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

fn layoutEntryBindingLessThan(
    context: void,
    lhs: core.BindGroupLayoutEntry,
    rhs: core.BindGroupLayoutEntry,
) bool {
    _ = context;
    return lhs.binding < rhs.binding;
}

fn shaderStageFlags(visibility: core.ShaderVisibility) vk.ShaderStageFlags {
    return .{
        .vertex_bit = visibility.vertex,
        .fragment_bit = visibility.fragment,
        .compute_bit = visibility.compute,
    };
}
