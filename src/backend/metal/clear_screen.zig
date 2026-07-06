const std = @import("std");
const core = @import("../../core.zig");
const MetalBuffer = @import("buffer.zig");
const MetalCommand = @import("command.zig");
const MetalComputePipelineState = @import("compute_pipeline.zig");
const MetalRenderPipelineState = @import("render_pipeline.zig");
const MetalSamplerState = @import("sampler.zig");
const MetalShaderModule = @import("shader_module.zig");
const MetalTexture = @import("texture.zig");
const metal = @import("metal_bridge");

const MetalClearScreen = @This();

handle: *metal.vkmtl_metal_clear_screen,
extent: core.Extent2D,

pub const AdapterInfoResult = struct {
    info: core.AdapterInfo,
    owned_name: ?[]u8 = null,
};

const Error = error{
    MetalUnsupported,
    NoMetalDevice,
    InvalidSurface,
    NoDrawable,
    CommandFailed,
    UnexpectedMetalStatus,
};

const adapter_name_buffer_len = 256;

pub fn init(
    surface: core.SurfaceDescriptor,
    presentation: core.PresentationDescriptor,
) !MetalClearScreen {
    const source = surface.source orelse return core.SurfaceError.MissingSurfaceSource;
    const cocoa_window = source.display orelse return Error.InvalidSurface;
    if (presentation.extent.isZero()) return core.SurfaceError.InvalidSurfaceExtent;

    var handle: ?*metal.vkmtl_metal_clear_screen = null;
    try check(metal.vkmtl_metal_clear_screen_create(
        &handle,
        cocoa_window,
        presentation.extent.width,
        presentation.extent.height,
    ));

    return .{
        .handle = handle orelse return Error.InvalidSurface,
        .extent = presentation.extent,
    };
}

pub fn deinit(self: *MetalClearScreen) void {
    metal.vkmtl_metal_clear_screen_destroy(self.handle);
}

pub fn adapterInfo(self: *const MetalClearScreen, allocator: std.mem.Allocator) !AdapterInfoResult {
    var buffer: [adapter_name_buffer_len]u8 = undefined;
    const status = metal.vkmtl_metal_clear_screen_copy_device_name(
        self.handle,
        &buffer,
        buffer.len,
    );
    if (status != metal.VKMTL_METAL_STATUS_OK) {
        return .{ .info = core.defaultAdapterInfo(.metal) };
    }

    const name_len = std.mem.indexOfScalar(u8, buffer[0..], 0) orelse buffer.len;
    const name = try allocator.dupe(u8, buffer[0..name_len]);
    return .{
        .info = .{
            .backend = .metal,
            .name = name,
            .vendor = "Apple",
            .device_type = .integrated_gpu,
        },
        .owned_name = name,
    };
}

pub fn resize(self: *MetalClearScreen, extent: core.Extent2D) !void {
    if (extent.isZero()) return;
    if (self.extent.width == extent.width and self.extent.height == extent.height) return;

    try check(metal.vkmtl_metal_clear_screen_resize(
        self.handle,
        extent.width,
        extent.height,
    ));
    self.extent = extent;
}

pub fn clear(self: *MetalClearScreen, color: core.ClearColorLike) !void {
    try check(metal.vkmtl_metal_clear_screen_draw(
        self.handle,
        color.red,
        color.green,
        color.blue,
        color.alpha,
    ));
}

pub fn makeBuffer(self: *MetalClearScreen, descriptor: core.BufferDescriptor) !MetalBuffer {
    return try MetalBuffer.init(self, descriptor);
}

pub fn makeShaderModule(
    self: *MetalClearScreen,
    allocator: std.mem.Allocator,
    descriptor: core.ShaderModuleDescriptor,
) !MetalShaderModule {
    return try MetalShaderModule.init(self, allocator, descriptor);
}

pub fn makeRenderPipelineState(
    self: *MetalClearScreen,
    allocator: std.mem.Allocator,
    descriptor: core.RenderPipelineDescriptor,
) !MetalRenderPipelineState {
    return try MetalRenderPipelineState.init(self, allocator, descriptor);
}

pub fn makeComputePipelineState(
    self: *MetalClearScreen,
    allocator: std.mem.Allocator,
    descriptor: core.ComputePipelineDescriptor,
) !MetalComputePipelineState {
    return try MetalComputePipelineState.init(self, allocator, descriptor);
}

pub fn makeCommandBuffer(self: *MetalClearScreen) !MetalCommand.CommandBuffer {
    return try MetalCommand.CommandBuffer.init(self);
}

pub fn makeTexture(self: *MetalClearScreen, descriptor: core.TextureDescriptor) !MetalTexture {
    return try MetalTexture.init(self, descriptor);
}

pub fn makeSamplerState(self: *MetalClearScreen, descriptor: core.SamplerDescriptor) !MetalSamplerState {
    return try MetalSamplerState.init(self, descriptor);
}

fn check(status: metal.vkmtl_metal_status) Error!void {
    return switch (status) {
        metal.VKMTL_METAL_STATUS_OK => {},
        metal.VKMTL_METAL_STATUS_UNSUPPORTED => Error.MetalUnsupported,
        metal.VKMTL_METAL_STATUS_NO_DEVICE => Error.NoMetalDevice,
        metal.VKMTL_METAL_STATUS_INVALID_SURFACE => Error.InvalidSurface,
        metal.VKMTL_METAL_STATUS_NO_DRAWABLE => Error.NoDrawable,
        metal.VKMTL_METAL_STATUS_COMMAND_FAILED => Error.CommandFailed,
        else => Error.UnexpectedMetalStatus,
    };
}
