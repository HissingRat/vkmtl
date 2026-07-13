const std = @import("std");
const builtin = @import("builtin");
const core = @import("../../core.zig");
const metal = @import("metal_bridge");
const debug = @import("debug.zig");
const MetalBuffer = @import("buffer.zig");
const MetalClearScreen = @import("clear_screen.zig");
const MetalSamplerState = @import("sampler.zig");
const MetalTextureView = @import("texture_view.zig");

const MetalAdvancedBindGroupLayout = @This();

owner: *MetalClearScreen,
allocator: std.mem.Allocator,
ranges: []core.DescriptorIndexingRange,

pub fn init(
    owner: *MetalClearScreen,
    allocator: std.mem.Allocator,
    descriptor: core.DescriptorIndexingLayoutDescriptor,
) !MetalAdvancedBindGroupLayout {
    if (descriptor.model != .argument_buffer) return core.AdvancedFeatureError.UnsupportedArgumentBuffers;
    return .{
        .owner = owner,
        .allocator = allocator,
        .ranges = try allocator.dupe(core.DescriptorIndexingRange, descriptor.ranges),
    };
}

pub fn deinit(self: *MetalAdvancedBindGroupLayout) void {
    self.allocator.free(self.ranges);
}

pub const ResourceTable = struct {
    handle: ?*metal.vkmtl_metal_resource_table,
    allocator: std.mem.Allocator,
    ranges: []core.DescriptorIndexingRange,

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

    pub fn init(layout: *const MetalAdvancedBindGroupLayout) !ResourceTable {
        const native_ranges = try layout.allocator.alloc(metal.vkmtl_metal_resource_table_range, layout.ranges.len);
        defer layout.allocator.free(native_ranges);
        for (layout.ranges, native_ranges) |range, *native| {
            native.* = .{
                .binding = nativeBaseForBinding(layout.ranges, range.binding),
                .resource_kind = @intFromEnum(range.resource),
                .descriptor_count = range.descriptor_count,
                .visibility = visibilityBits(range.visibility),
                .writable = @intFromBool(range.resource.isWritable()),
            };
        }
        var handle: ?*metal.vkmtl_metal_resource_table = null;
        const status = metal.vkmtl_metal_resource_table_create(
            layout.owner.handle,
            native_ranges.ptr,
            native_ranges.len,
            &handle,
        );
        if (status != metal.VKMTL_METAL_STATUS_OK and !builtin.is_test) {
            try check(status);
        }
        const ranges = try layout.allocator.dupe(core.DescriptorIndexingRange, layout.ranges);
        errdefer if (handle) |raw_handle| metal.vkmtl_metal_resource_table_destroy(raw_handle);
        return .{
            .handle = handle,
            .allocator = layout.allocator,
            .ranges = ranges,
        };
    }

    pub fn deinit(self: *ResourceTable) void {
        if (self.handle) |handle| metal.vkmtl_metal_resource_table_destroy(handle);
        self.allocator.free(self.ranges);
    }

    pub fn setLabel(self: *ResourceTable, label: ?[]const u8) void {
        const handle = self.handle orelse return;
        debug.ignore(metal.vkmtl_metal_resource_table_set_label(
            handle,
            debug.labelPtr(label),
            debug.labelLen(label),
        ));
    }

    pub fn update(self: *ResourceTable, slot: core.ResourceTableSlot, resource: Resource) !void {
        const handle = self.handle orelse return;
        const native_index = try self.nativeIndexForSlot(slot);
        switch (resource) {
            .uniform_buffer => |binding| try check(metal.vkmtl_metal_resource_table_set_buffer(
                handle,
                native_index,
                binding.buffer.handle,
                binding.offset,
                0,
            )),
            .storage_buffer => |binding| try check(metal.vkmtl_metal_resource_table_set_buffer(
                handle,
                native_index,
                binding.buffer.handle,
                binding.offset,
                1,
            )),
            .sampled_texture => |view| try check(metal.vkmtl_metal_resource_table_set_texture(
                handle,
                native_index,
                view.handle,
                0,
            )),
            .storage_texture => |view| try check(metal.vkmtl_metal_resource_table_set_texture(
                handle,
                native_index,
                view.handle,
                1,
            )),
            .sampler, .compare_sampler => |sampler| try check(metal.vkmtl_metal_resource_table_set_sampler(
                handle,
                native_index,
                sampler.handle,
            )),
        }
    }

    pub fn clear(self: *ResourceTable, slot: core.ResourceTableSlot) !void {
        const range = try self.rangeForSlot(slot);
        const handle = self.handle orelse return;
        try check(metal.vkmtl_metal_resource_table_clear(
            handle,
            try self.nativeIndexForSlot(slot),
            @intFromEnum(range.resource),
        ));
    }

    pub fn visibility(self: ResourceTable) core.ShaderVisibility {
        var result = core.ShaderVisibility{};
        for (self.ranges) |range| {
            result.vertex = result.vertex or range.visibility.vertex;
            result.fragment = result.fragment or range.visibility.fragment;
            result.compute = result.compute or range.visibility.compute;
        }
        return result;
    }

    fn rangeForSlot(self: ResourceTable, slot: core.ResourceTableSlot) core.BindingError!core.DescriptorIndexingRange {
        for (self.ranges) |range| {
            if (range.binding != slot.binding) continue;
            if (slot.array_element >= range.descriptor_count) return core.BindingError.InvalidResourceTableSlot;
            return range;
        }
        return core.BindingError.InvalidResourceTableSlot;
    }

    fn nativeIndexForSlot(self: ResourceTable, slot: core.ResourceTableSlot) core.BindingError!u32 {
        for (self.ranges) |range| {
            if (range.binding == slot.binding) {
                if (slot.array_element >= range.descriptor_count) return core.BindingError.InvalidResourceTableSlot;
                return nativeBaseForBinding(self.ranges, range.binding) + slot.array_element;
            }
        }
        return core.BindingError.InvalidResourceTableSlot;
    }
};

fn nativeBaseForBinding(ranges: []const core.DescriptorIndexingRange, binding: u32) u32 {
    var base: u32 = 0;
    for (ranges) |range| {
        if (range.binding < binding) base += range.descriptor_count;
    }
    return base;
}

const Error = error{
    MetalUnsupported,
    InvalidResourceTable,
    CommandFailed,
    UnexpectedMetalStatus,
};

fn visibilityBits(visibility: core.ShaderVisibility) u32 {
    return @as(u32, @intFromBool(visibility.vertex)) |
        (@as(u32, @intFromBool(visibility.fragment)) << 1) |
        (@as(u32, @intFromBool(visibility.compute)) << 2);
}

fn check(status: metal.vkmtl_metal_status) Error!void {
    return switch (status) {
        metal.VKMTL_METAL_STATUS_OK => {},
        metal.VKMTL_METAL_STATUS_UNSUPPORTED => Error.MetalUnsupported,
        metal.VKMTL_METAL_STATUS_COMMAND_FAILED => Error.CommandFailed,
        metal.VKMTL_METAL_STATUS_INVALID_BUFFER,
        metal.VKMTL_METAL_STATUS_INVALID_TEXTURE_VIEW,
        metal.VKMTL_METAL_STATUS_INVALID_SAMPLER,
        => Error.InvalidResourceTable,
        else => Error.UnexpectedMetalStatus,
    };
}

test "Metal advanced binding visibility is encoded for native stages" {
    try std.testing.expectEqual(@as(u32, 3), visibilityBits(.{ .vertex = true, .fragment = true }));
    try std.testing.expectEqual(@as(u32, 4), visibilityBits(.{ .compute = true }));
}

test "Metal argument table ranges use dense native indices" {
    const ranges = [_]core.DescriptorIndexingRange{
        .{ .binding = 9, .resource = .sampler, .visibility = .{ .fragment = true } },
        .{ .binding = 3, .resource = .sampled_texture, .visibility = .{ .fragment = true }, .descriptor_count = 64 },
    };
    const table = ResourceTable{
        .handle = null,
        .allocator = std.testing.allocator,
        .ranges = @constCast(&ranges),
    };
    try std.testing.expectEqual(@as(u32, 0), try table.nativeIndexForSlot(.{ .binding = 3 }));
    try std.testing.expectEqual(@as(u32, 63), try table.nativeIndexForSlot(.{ .binding = 3, .array_element = 63 }));
    try std.testing.expectEqual(@as(u32, 64), try table.nativeIndexForSlot(.{ .binding = 9 }));
}
