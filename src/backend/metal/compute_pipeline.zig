const std = @import("std");
const core = @import("../../core.zig");
const debug = @import("debug.zig");
const metal = @import("metal_bridge");
const MetalClearScreen = @import("clear_screen.zig");
const MetalShaderModule = @import("shader_module.zig");
const specialization = @import("specialization.zig");
const cache_identity = @import("../pipeline_cache_identity.zig");

const MetalComputePipelineState = @This();

handle: *metal.vkmtl_metal_compute_pipeline_state,
supports_indirect_command_buffers: bool,

const Error = error{
    MetalUnsupported,
    InvalidShader,
    InvalidPipeline,
    CommandFailed,
    UnexpectedMetalStatus,
};

pub fn init(
    owner: *MetalClearScreen,
    allocator: std.mem.Allocator,
    descriptor: core.ComputePipelineDescriptor,
) !MetalComputePipelineState {
    try descriptor.validate();

    var compute_module = try MetalShaderModule.init(owner, allocator, descriptor.compute.module);
    defer compute_module.deinit();

    const constants = try specialization.translate(allocator, descriptor.compute.specialization);
    defer allocator.free(constants);

    var handle: ?*metal.vkmtl_metal_compute_pipeline_state = null;
    var supports_indirect_command_buffers = true;
    var status = createNativePipeline(owner.handle, compute_module.handle, descriptor, constants, true, &handle);
    if (shouldRetryWithoutIndirectCommands(status)) {
        supports_indirect_command_buffers = false;
        handle = null;
        status = createNativePipeline(owner.handle, compute_module.handle, descriptor, constants, false, &handle);
    }
    try check(status);

    return .{
        .handle = handle orelse return Error.InvalidPipeline,
        .supports_indirect_command_buffers = supports_indirect_command_buffers,
    };
}

fn createNativePipeline(
    owner: *metal.vkmtl_metal_clear_screen,
    compute_module: *metal.vkmtl_metal_shader_module,
    descriptor: core.ComputePipelineDescriptor,
    constants: []const metal.vkmtl_metal_function_constant,
    support_indirect_command_buffers: bool,
    out_handle: *?*metal.vkmtl_metal_compute_pipeline_state,
) metal.vkmtl_metal_status {
    return metal.vkmtl_metal_compute_pipeline_state_create(
        owner,
        compute_module,
        descriptor.compute.entry_point.ptr,
        descriptor.compute.entry_point.len,
        if (constants.len == 0) null else constants.ptr,
        constants.len,
        @intFromBool(support_indirect_command_buffers),
        if (descriptor.driver_cache) |cache| cache.path.ptr else null,
        if (descriptor.driver_cache) |cache| cache.path.len else 0,
        if (descriptor.driver_cache) |cache| cache_identity.hash(cache.identity) else 0,
        if (descriptor.driver_cache) |cache| @intFromBool(cache.read_only) else 0,
        out_handle,
    );
}

fn shouldRetryWithoutIndirectCommands(status: metal.vkmtl_metal_status) bool {
    return status == metal.VKMTL_METAL_STATUS_INVALID_PIPELINE;
}

pub fn deinit(self: *MetalComputePipelineState) void {
    metal.vkmtl_metal_compute_pipeline_state_destroy(self.handle);
}

pub fn setLabel(self: *MetalComputePipelineState, label_value: ?[]const u8) void {
    debug.ignore(metal.vkmtl_metal_compute_pipeline_state_set_label(
        self.handle,
        debug.labelPtr(label_value),
        debug.labelLen(label_value),
    ));
}

fn check(status: metal.vkmtl_metal_status) Error!void {
    return switch (status) {
        metal.VKMTL_METAL_STATUS_OK => {},
        metal.VKMTL_METAL_STATUS_UNSUPPORTED => Error.MetalUnsupported,
        metal.VKMTL_METAL_STATUS_INVALID_SHADER => Error.InvalidShader,
        metal.VKMTL_METAL_STATUS_INVALID_PIPELINE => Error.InvalidPipeline,
        metal.VKMTL_METAL_STATUS_COMMAND_FAILED => Error.CommandFailed,
        else => Error.UnexpectedMetalStatus,
    };
}

test "invalid ICB-capable compute pipeline retries without indirect commands" {
    try std.testing.expect(shouldRetryWithoutIndirectCommands(metal.VKMTL_METAL_STATUS_INVALID_PIPELINE));
    try std.testing.expect(!shouldRetryWithoutIndirectCommands(metal.VKMTL_METAL_STATUS_INVALID_SHADER));
}
