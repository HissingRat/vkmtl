const std = @import("std");
const vk = @import("vulkan");
const core = @import("../../core.zig");
const GraphicsContext = @import("graphics_context.zig");
const VulkanBuffer = @import("buffer.zig");

const VulkanQuerySet = @This();

gc: *const GraphicsContext,
pool: vk.QueryPool,
query_type: core.QueryType,
count: u32,
occlusion_mode: core.OcclusionQueryMode,

pub fn init(gc: *const GraphicsContext, descriptor: core.QuerySetDescriptor) !VulkanQuerySet {
    const query_type: vk.QueryType = switch (descriptor.query_type) {
        .occlusion => if (gc.supportsHostQueryReset()) .occlusion else return core.QueryError.UnsupportedOcclusionQueries,
        .timestamp => if (gc.supportsNativeTimestampQueries()) .timestamp else return core.QueryError.UnsupportedGpuTimestamps,
        .pipeline_statistics => return core.QueryError.UnsupportedPipelineStatisticsQueries,
    };
    const pool = try gc.dev.createQueryPool(&.{
        .query_type = query_type,
        .query_count = descriptor.count,
    }, null);
    errdefer gc.dev.destroyQueryPool(pool, null);
    gc.dev.resetQueryPool(pool, 0, descriptor.count);
    return .{
        .gc = gc,
        .pool = pool,
        .query_type = descriptor.query_type,
        .count = descriptor.count,
        .occlusion_mode = descriptor.occlusion_mode,
    };
}

pub fn deinit(self: *VulkanQuerySet) void {
    if (self.pool == .null_handle) return;
    self.gc.dev.destroyQueryPool(self.pool, null);
    self.pool = .null_handle;
}

pub fn setLabel(self: *VulkanQuerySet, label: ?[]const u8) void {
    self.gc.setDebugName(.query_pool, GraphicsContext.debugObjectHandle(self.pool), label);
}

pub fn reset(self: *VulkanQuerySet) void {
    self.gc.dev.resetQueryPool(self.pool, 0, self.count);
}

pub fn beginOcclusion(self: *VulkanQuerySet, command_buffer: vk.CommandBuffer, index: u32) void {
    self.gc.dev.cmdBeginQuery(command_buffer, self.pool, index, occlusionControlFlags(self.occlusion_mode));
}

fn occlusionControlFlags(mode: core.OcclusionQueryMode) vk.QueryControlFlags {
    return .{ .precise_bit = mode == .counting };
}

pub fn endOcclusion(self: *VulkanQuerySet, command_buffer: vk.CommandBuffer, index: u32) void {
    self.gc.dev.cmdEndQuery(command_buffer, self.pool, index);
}

pub fn writeTimestamp(self: *VulkanQuerySet, command_buffer: vk.CommandBuffer, index: u32) void {
    self.gc.dev.cmdWriteTimestamp(
        command_buffer,
        .{ .all_commands_bit = true },
        self.pool,
        index,
    );
}

pub fn readback(
    self: *VulkanQuerySet,
    first_query: u32,
    query_count: u32,
    destination: []u64,
) core.QueryError!void {
    std.debug.assert(destination.len >= @as(usize, @intCast(query_count)));
    const data_size = std.math.mul(usize, @sizeOf(u64), @as(usize, @intCast(query_count))) catch {
        return core.QueryError.InvalidQueryRange;
    };
    const result = self.gc.dev.getQueryPoolResults(
        self.pool,
        first_query,
        query_count,
        data_size,
        destination.ptr,
        @sizeOf(u64),
        .{ .@"64_bit" = true },
    ) catch return core.QueryError.QueryBackendFailure;
    if (result == .not_ready) return core.QueryError.QueryNotReady;
}

pub fn resolve(
    self: *VulkanQuerySet,
    command_buffer: vk.CommandBuffer,
    destination: *const VulkanBuffer,
    descriptor: core.QueryResolveDescriptor,
) void {
    self.gc.dev.cmdCopyQueryPoolResults(
        command_buffer,
        self.pool,
        descriptor.first_query,
        descriptor.query_count,
        destination.handle,
        descriptor.destination_offset,
        @sizeOf(u64),
        .{ .@"64_bit" = true, .wait_bit = true },
    );
}

test "Vulkan query kind contract keeps pipeline statistics closed" {
    try std.testing.expectEqual(vk.QueryType.occlusion, @as(vk.QueryType, .occlusion));
    try std.testing.expectEqual(vk.QueryType.timestamp, @as(vk.QueryType, .timestamp));
    try std.testing.expect(!occlusionControlFlags(.boolean).precise_bit);
    try std.testing.expect(occlusionControlFlags(.counting).precise_bit);
}
