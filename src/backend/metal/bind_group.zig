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
    };

    pub const Entry = struct {
        binding: u32,
        resource: Resource,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        layout: *const MetalBindGroupLayout,
        entries: []const Entry,
    ) !MetalBindGroup {
        const layout_entries = try allocator.dupe(core.BindGroupLayoutEntry, layout.entries);
        errdefer allocator.free(layout_entries);

        return .{
            .allocator = allocator,
            .layout_entries = layout_entries,
            .entries = try allocator.dupe(Entry, entries),
        };
    }

    pub fn deinit(self: *MetalBindGroup) void {
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
