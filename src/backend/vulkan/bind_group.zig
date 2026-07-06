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
                .descriptor_type = descriptorTypeForKind(entry.resource),
                .descriptor_count = 1,
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
    entries: []Entry,

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

        try updateDescriptorSet(gc, allocator, set, entries);

        const stored_entries = try allocator.dupe(Entry, entries);
        errdefer allocator.free(stored_entries);

        return .{
            .gc = gc,
            .allocator = allocator,
            .pool = pool,
            .set = set,
            .entries = stored_entries,
        };
    }

    pub fn deinit(self: *VulkanBindGroup) void {
        self.gc.dev.destroyDescriptorPool(self.pool, null);
        self.allocator.free(self.entries);
    }
};

fn createDescriptorPool(
    gc: *const GraphicsContext,
    layout_entries: []const core.BindGroupLayoutEntry,
) !vk.DescriptorPool {
    var uniform_buffers: u32 = 0;
    var storage_buffers: u32 = 0;
    var storage_textures: u32 = 0;
    var sampled_textures: u32 = 0;
    var samplers: u32 = 0;

    for (layout_entries) |entry| {
        switch (entry.resource) {
            .uniform_buffer => uniform_buffers += 1,
            .storage_buffer => storage_buffers += 1,
            .storage_texture => storage_textures += 1,
            .sampled_texture => sampled_textures += 1,
            .sampler, .compare_sampler => samplers += 1,
        }
    }

    var pool_sizes: [5]vk.DescriptorPoolSize = undefined;
    var pool_size_count: usize = 0;
    if (uniform_buffers != 0) {
        pool_sizes[pool_size_count] = .{
            .type = .uniform_buffer,
            .descriptor_count = uniform_buffers,
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
    entries: []const VulkanBindGroup.Entry,
) !void {
    const writes = try allocator.alloc(vk.WriteDescriptorSet, entries.len);
    defer allocator.free(writes);
    const buffer_infos = try allocator.alloc(vk.DescriptorBufferInfo, entries.len);
    defer allocator.free(buffer_infos);
    const image_infos = try allocator.alloc(vk.DescriptorImageInfo, entries.len);
    defer allocator.free(image_infos);

    for (entries, writes, 0..) |entry, *write, i| {
        write.* = .{
            .dst_set = set,
            .dst_binding = entry.binding,
            .dst_array_element = 0,
            .descriptor_count = 1,
            .descriptor_type = descriptorTypeForResource(entry.resource),
            .p_image_info = undefined,
            .p_buffer_info = undefined,
            .p_texel_buffer_view = undefined,
        };

        switch (entry.resource) {
            .uniform_buffer, .storage_buffer => |binding| {
                buffer_infos[i] = .{
                    .buffer = binding.buffer.handle,
                    .offset = binding.offset,
                    .range = binding.size orelse vk.WHOLE_SIZE,
                };
                write.p_buffer_info = @ptrCast(&buffer_infos[i]);
            },
            .sampled_texture => |texture_view| {
                image_infos[i] = .{
                    .sampler = .null_handle,
                    .image_view = texture_view.handle,
                    .image_layout = .shader_read_only_optimal,
                };
                write.p_image_info = @ptrCast(&image_infos[i]);
            },
            .storage_texture => |texture_view| {
                image_infos[i] = .{
                    .sampler = .null_handle,
                    .image_view = texture_view.handle,
                    .image_layout = .general,
                };
                write.p_image_info = @ptrCast(&image_infos[i]);
            },
            .sampler, .compare_sampler => |sampler_state| {
                image_infos[i] = .{
                    .sampler = sampler_state.handle,
                    .image_view = .null_handle,
                    .image_layout = .undefined,
                };
                write.p_image_info = @ptrCast(&image_infos[i]);
            },
        }
    }

    gc.dev.updateDescriptorSets(writes, null);
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

fn shaderStageFlags(visibility: core.ShaderVisibility) vk.ShaderStageFlags {
    return .{
        .vertex_bit = visibility.vertex,
        .fragment_bit = visibility.fragment,
        .compute_bit = visibility.compute,
    };
}
