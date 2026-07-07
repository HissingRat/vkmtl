const std = @import("std");
const core = @import("../../core.zig");
const debug = @import("debug.zig");
const metal = @import("metal_bridge");
const MetalClearScreen = @import("clear_screen.zig");
const MetalShaderModule = @import("shader_module.zig");

const MetalComputePipelineState = @This();

handle: *metal.vkmtl_metal_compute_pipeline_state,

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

    var handle: ?*metal.vkmtl_metal_compute_pipeline_state = null;
    try check(metal.vkmtl_metal_compute_pipeline_state_create(
        owner.handle,
        compute_module.handle,
        descriptor.compute.entry_point.ptr,
        descriptor.compute.entry_point.len,
        &handle,
    ));

    return .{
        .handle = handle orelse return Error.InvalidPipeline,
    };
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
