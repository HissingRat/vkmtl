const std = @import("std");
const core = @import("../../core.zig");
const debug = @import("debug.zig");
const metal = @import("metal_bridge");
const MetalClearScreen = @import("clear_screen.zig");

const MetalQuerySet = @This();

handle: *metal.vkmtl_metal_query_set,
query_type: core.QueryType,
count: u32,

pub fn init(owner: *MetalClearScreen, descriptor: core.QuerySetDescriptor) !MetalQuerySet {
    const native_type = try nativeQueryType(descriptor.query_type);
    var handle: ?*metal.vkmtl_metal_query_set = null;
    try checkCreate(
        descriptor.query_type,
        metal.vkmtl_metal_query_set_create(owner.handle, native_type, descriptor.count, &handle),
    );

    var result = MetalQuerySet{
        .handle = handle orelse return core.QueryError.QueryBackendFailure,
        .query_type = descriptor.query_type,
        .count = descriptor.count,
    };
    result.setLabel(descriptor.label);
    return result;
}

pub fn deinit(self: *MetalQuerySet) void {
    metal.vkmtl_metal_query_set_destroy(self.handle);
}

pub fn setLabel(self: *MetalQuerySet, label: ?[]const u8) void {
    debug.ignore(metal.vkmtl_metal_query_set_set_label(
        self.handle,
        debug.labelPtr(label),
        debug.labelLen(label),
    ));
}

pub fn reset(self: *MetalQuerySet) void {
    debug.ignore(metal.vkmtl_metal_query_set_reset(self.handle));
}

pub fn readback(
    self: *MetalQuerySet,
    first_query: u32,
    query_count: u32,
    destination: []u64,
) core.QueryError!void {
    if (query_count == 0 or destination.len < @as(usize, @intCast(query_count))) {
        return core.QueryError.InvalidQueryRange;
    }
    try checkQuery(metal.vkmtl_metal_query_set_read_values(
        self.handle,
        first_query,
        query_count,
        destination.ptr,
    ));
}

fn nativeQueryType(query_type: core.QueryType) core.QueryError!metal.vkmtl_metal_query_type {
    return switch (query_type) {
        .occlusion => metal.VKMTL_METAL_QUERY_TYPE_OCCLUSION,
        .timestamp => metal.VKMTL_METAL_QUERY_TYPE_TIMESTAMP,
        .pipeline_statistics => core.QueryError.UnsupportedPipelineStatisticsQueries,
    };
}

fn checkCreate(query_type: core.QueryType, status: metal.vkmtl_metal_status) core.QueryError!void {
    return switch (status) {
        metal.VKMTL_METAL_STATUS_OK => {},
        metal.VKMTL_METAL_STATUS_UNSUPPORTED => switch (query_type) {
            .occlusion => core.QueryError.UnsupportedOcclusionQueries,
            .timestamp => core.QueryError.UnsupportedGpuTimestamps,
            .pipeline_statistics => core.QueryError.UnsupportedPipelineStatisticsQueries,
        },
        metal.VKMTL_METAL_STATUS_INVALID_QUERY => core.QueryError.InvalidQueryRange,
        else => core.QueryError.QueryBackendFailure,
    };
}

fn checkQuery(status: metal.vkmtl_metal_status) core.QueryError!void {
    return switch (status) {
        metal.VKMTL_METAL_STATUS_OK => {},
        metal.VKMTL_METAL_STATUS_QUERY_NOT_READY => core.QueryError.QueryNotReady,
        metal.VKMTL_METAL_STATUS_UNSUPPORTED => core.QueryError.UnsupportedGpuTimestamps,
        metal.VKMTL_METAL_STATUS_INVALID_QUERY => core.QueryError.InvalidQueryRange,
        else => core.QueryError.QueryBackendFailure,
    };
}

test "Metal query kinds keep pipeline statistics closed" {
    try std.testing.expectEqual(
        @as(metal.vkmtl_metal_query_type, metal.VKMTL_METAL_QUERY_TYPE_OCCLUSION),
        try nativeQueryType(.occlusion),
    );
    try std.testing.expectEqual(
        @as(metal.vkmtl_metal_query_type, metal.VKMTL_METAL_QUERY_TYPE_TIMESTAMP),
        try nativeQueryType(.timestamp),
    );
    try std.testing.expectError(
        core.QueryError.UnsupportedPipelineStatisticsQueries,
        nativeQueryType(.pipeline_statistics),
    );
}

test "Metal query readback distinguishes pending from backend failure" {
    try std.testing.expectError(
        core.QueryError.QueryNotReady,
        checkQuery(metal.VKMTL_METAL_STATUS_QUERY_NOT_READY),
    );
    try std.testing.expectError(
        core.QueryError.QueryBackendFailure,
        checkQuery(metal.VKMTL_METAL_STATUS_COMMAND_FAILED),
    );
}
