const core = @import("../../core.zig");
const GraphicsContext = @import("graphics_context.zig");

const VulkanAdvancedBindGroupLayout = @This();

range_count: usize,
total_descriptors: u32,
uses_partially_bound_ranges: bool,
uses_update_after_bind_ranges: bool,

pub fn init(gc: *const GraphicsContext, descriptor: core.DescriptorIndexingLayoutDescriptor) core.AdvancedFeatureError!VulkanAdvancedBindGroupLayout {
    _ = gc;
    if (descriptor.model != .descriptor_indexing) return core.AdvancedFeatureError.UnsupportedDescriptorIndexing;

    var total_descriptors: u32 = 0;
    var uses_partially_bound_ranges = false;
    var uses_update_after_bind_ranges = false;
    for (descriptor.ranges) |range| {
        total_descriptors +|= range.descriptor_count;
        uses_partially_bound_ranges = uses_partially_bound_ranges or range.partially_bound;
        uses_update_after_bind_ranges = uses_update_after_bind_ranges or range.update_after_bind;
    }

    return .{
        .range_count = descriptor.ranges.len,
        .total_descriptors = total_descriptors,
        .uses_partially_bound_ranges = uses_partially_bound_ranges,
        .uses_update_after_bind_ranges = uses_update_after_bind_ranges,
    };
}

pub fn deinit(self: *VulkanAdvancedBindGroupLayout) void {
    self.* = undefined;
}

test "Vulkan advanced binding metadata captures descriptor indexing requirements" {
    const ranges = [_]core.DescriptorIndexingRange{
        .{
            .binding = 0,
            .resource = .sampled_texture,
            .visibility = .{ .fragment = true },
            .descriptor_count = 4,
            .partially_bound = true,
        },
        .{
            .binding = 1,
            .resource = .storage_buffer,
            .visibility = .{ .compute = true },
            .descriptor_count = 2,
            .update_after_bind = true,
        },
    };

    const layout = try init(undefined, .{
        .model = .descriptor_indexing,
        .ranges = &ranges,
    });

    try @import("std").testing.expectEqual(@as(usize, 2), layout.range_count);
    try @import("std").testing.expectEqual(@as(u32, 6), layout.total_descriptors);
    try @import("std").testing.expect(layout.uses_partially_bound_ranges);
    try @import("std").testing.expect(layout.uses_update_after_bind_ranges);
}
