const std = @import("std");
const core = @import("../../core.zig");
const MetalBuffer = @import("buffer.zig");
const MetalSamplerState = @import("sampler.zig");
const MetalTextureView = @import("texture_view.zig");

pub const MetalBindGroupLayout = struct {
    allocator: std.mem.Allocator,
    entries: []core.BindGroupLayoutEntry,

    pub fn init(
        allocator: std.mem.Allocator,
        descriptor: core.BindGroupLayoutDescriptor,
    ) !MetalBindGroupLayout {
        try descriptor.validate();

        return .{
            .allocator = allocator,
            .entries = try allocator.dupe(core.BindGroupLayoutEntry, descriptor.entries),
        };
    }

    pub fn deinit(self: *MetalBindGroupLayout) void {
        self.allocator.free(self.entries);
    }
};

pub const MetalBindGroup = struct {
    allocator: std.mem.Allocator,
    layout_entries: []core.BindGroupLayoutEntry,
    entries: []Entry,
    entry_resources: []Resource,

    pub const BufferBinding = struct {
        buffer: *const MetalBuffer,
        offset: u64 = 0,
        size: ?u64 = null,
    };

    pub const Resource = union(core.BindingResourceKind) {
        uniform_buffer: BufferBinding,
        storage_buffer: BufferBinding,
        storage_texture: *const MetalTextureView,
        sampled_texture: *const MetalTextureView,
        sampler: *const MetalSamplerState,
        compare_sampler: *const MetalSamplerState,
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
        allocator: std.mem.Allocator,
        layout: *const MetalBindGroupLayout,
        entries: []const Entry,
    ) !MetalBindGroup {
        const layout_entries = try allocator.dupe(core.BindGroupLayoutEntry, layout.entries);
        errdefer allocator.free(layout_entries);
        const stored_entries = try allocator.alloc(Entry, entries.len);
        errdefer allocator.free(stored_entries);
        const stored_entry_resources = try copyEntryResourceArrays(allocator, entries, stored_entries);
        errdefer allocator.free(stored_entry_resources);

        return .{
            .allocator = allocator,
            .layout_entries = layout_entries,
            .entries = stored_entries,
            .entry_resources = stored_entry_resources,
        };
    }

    pub fn deinit(self: *MetalBindGroup) void {
        self.allocator.free(self.entry_resources);
        self.allocator.free(self.entries);
        self.allocator.free(self.layout_entries);
    }

    pub fn layoutEntryForBinding(self: MetalBindGroup, binding: u32) ?core.BindGroupLayoutEntry {
        for (self.layout_entries) |entry| {
            if (entry.binding == binding) return entry;
        }
        return null;
    }
};

fn copyEntryResourceArrays(
    allocator: std.mem.Allocator,
    source_entries: []const MetalBindGroup.Entry,
    stored_entries: []MetalBindGroup.Entry,
) ![]MetalBindGroup.Resource {
    var total_resource_count: usize = 0;
    for (source_entries) |entry| {
        if (entry.resources.len != 0) total_resource_count += entry.resources.len;
    }

    const resources = try allocator.alloc(MetalBindGroup.Resource, total_resource_count);
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
