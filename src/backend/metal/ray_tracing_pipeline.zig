const std = @import("std");
const core = @import("../../core.zig");
const debug = @import("debug.zig");
const metal = @import("metal_bridge");
const MetalClearScreen = @import("clear_screen.zig");
const MetalShaderModule = @import("shader_module.zig");

const MetalRayTracingPipelineState = @This();

handle: *metal.vkmtl_metal_ray_tracing_pipeline_state,

pub fn init(
    owner: *MetalClearScreen,
    allocator: std.mem.Allocator,
    descriptor: core.RayTracingPipelineDescriptor,
) core.AdvancedFeatureError!MetalRayTracingPipelineState {
    const ray_generation = descriptor.ray_generation orelse return core.AdvancedFeatureError.InvalidRayTracingPipeline;
    var ray_generation_module = MetalShaderModule.init(owner, allocator, ray_generation.module) catch {
        return core.AdvancedFeatureError.InvalidRayTracingPipeline;
    };
    defer ray_generation_module.deinit();

    var handle: ?*metal.vkmtl_metal_ray_tracing_pipeline_state = null;
    try checkRayTracingPipeline(metal.vkmtl_metal_ray_tracing_pipeline_state_create(
        owner.handle,
        ray_generation_module.handle,
        ray_generation.entry_point.ptr,
        ray_generation.entry_point.len,
        &handle,
    ));
    return .{
        .handle = handle orelse return core.AdvancedFeatureError.InvalidRayTracingPipeline,
    };
}

pub fn deinit(self: *MetalRayTracingPipelineState) void {
    metal.vkmtl_metal_ray_tracing_pipeline_state_destroy(self.handle);
}

pub fn setLabel(self: *MetalRayTracingPipelineState, label_value: ?[]const u8) void {
    debug.ignore(metal.vkmtl_metal_ray_tracing_pipeline_state_set_label(
        self.handle,
        debug.labelPtr(label_value),
        debug.labelLen(label_value),
    ));
}

pub fn hasDriverHandle(self: MetalRayTracingPipelineState) bool {
    return metal.vkmtl_metal_ray_tracing_pipeline_state_has_driver_handle(self.handle) != 0;
}

fn checkRayTracingPipeline(status: metal.vkmtl_metal_status) core.AdvancedFeatureError!void {
    return switch (status) {
        metal.VKMTL_METAL_STATUS_OK => {},
        metal.VKMTL_METAL_STATUS_UNSUPPORTED,
        metal.VKMTL_METAL_STATUS_NO_DEVICE,
        => core.AdvancedFeatureError.UnsupportedRayTracing,
        metal.VKMTL_METAL_STATUS_INVALID_SHADER,
        metal.VKMTL_METAL_STATUS_INVALID_PIPELINE,
        metal.VKMTL_METAL_STATUS_COMMAND_FAILED,
        => core.AdvancedFeatureError.InvalidRayTracingPipeline,
        else => core.AdvancedFeatureError.UnsupportedRayTracing,
    };
}
