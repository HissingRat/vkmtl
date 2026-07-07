const core = @import("../../core.zig");

const MetalAdvancedBindGroupLayout = @This();

range_count: usize,
total_arguments: u32,
texture_argument_count: u32,
buffer_argument_count: u32,
sampler_argument_count: u32,

pub fn init(descriptor: core.DescriptorIndexingLayoutDescriptor) core.AdvancedFeatureError!MetalAdvancedBindGroupLayout {
    if (descriptor.model != .argument_buffer) return core.AdvancedFeatureError.UnsupportedArgumentBuffers;

    var total_arguments: u32 = 0;
    var texture_argument_count: u32 = 0;
    var buffer_argument_count: u32 = 0;
    var sampler_argument_count: u32 = 0;
    for (descriptor.ranges) |range| {
        total_arguments +|= range.descriptor_count;
        switch (range.resource) {
            .sampled_texture, .storage_texture => texture_argument_count +|= range.descriptor_count,
            .uniform_buffer, .storage_buffer => buffer_argument_count +|= range.descriptor_count,
            .sampler, .compare_sampler => sampler_argument_count +|= range.descriptor_count,
        }
    }

    return .{
        .range_count = descriptor.ranges.len,
        .total_arguments = total_arguments,
        .texture_argument_count = texture_argument_count,
        .buffer_argument_count = buffer_argument_count,
        .sampler_argument_count = sampler_argument_count,
    };
}

pub fn deinit(self: *MetalAdvancedBindGroupLayout) void {
    self.* = undefined;
}

test "Metal advanced binding metadata groups argument resources" {
    const ranges = [_]core.DescriptorIndexingRange{
        .{
            .binding = 0,
            .resource = .sampled_texture,
            .visibility = .{ .fragment = true },
            .descriptor_count = 4,
        },
        .{
            .binding = 1,
            .resource = .storage_buffer,
            .visibility = .{ .compute = true },
            .descriptor_count = 2,
        },
        .{
            .binding = 2,
            .resource = .sampler,
            .visibility = .{ .fragment = true },
            .descriptor_count = 1,
        },
    };

    const layout = try init(.{
        .model = .argument_buffer,
        .ranges = &ranges,
    });

    try @import("std").testing.expectEqual(@as(usize, 3), layout.range_count);
    try @import("std").testing.expectEqual(@as(u32, 7), layout.total_arguments);
    try @import("std").testing.expectEqual(@as(u32, 4), layout.texture_argument_count);
    try @import("std").testing.expectEqual(@as(u32, 2), layout.buffer_argument_count);
    try @import("std").testing.expectEqual(@as(u32, 1), layout.sampler_argument_count);
}
