const std = @import("std");
const core = @import("../../core.zig");
const MetalAccelerationStructure = @import("acceleration_structure.zig");
const MetalBuffer = @import("buffer.zig");
const MetalCommand = @import("command.zig");
const MetalComputePipelineState = @import("compute_pipeline.zig");
const MetalQuerySet = @import("query_set.zig");
const MetalRayTracingPipelineState = @import("ray_tracing_pipeline.zig");
const MetalRenderPipelineState = @import("render_pipeline.zig");
const MetalSamplerState = @import("sampler.zig");
const MetalShaderModule = @import("shader_module.zig");
const MetalTexture = @import("texture.zig");
const metal = @import("metal_bridge");

const MetalClearScreen = @This();

handle: *metal.vkmtl_metal_clear_screen,
extent: core.Extent2D,
capture_active: bool = false,

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
        .capture_active = false,
    };
}

pub fn deinit(self: *MetalClearScreen) void {
    if (self.capture_active) {
        _ = metal.vkmtl_metal_clear_screen_end_capture(self.handle);
        self.capture_active = false;
    }
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

pub fn limits(self: *const MetalClearScreen) core.DeviceLimits {
    return limitsFromMetalCapabilities(self.queryCapabilities());
}

pub fn features(self: *const MetalClearScreen) core.DeviceFeatures {
    return usableFeaturesFromMetalCapabilities(self.queryCapabilities());
}

pub fn nativeFeatures(self: *const MetalClearScreen) core.DeviceFeatures {
    return nativeFeaturesFromMetalCapabilities(self.queryCapabilities());
}

pub fn formatCapabilities(self: *const MetalClearScreen, format: core.TextureFormat) core.FormatCapabilities {
    _ = self;
    var capabilities = core.defaultFormatCapabilities(format);
    capabilities.blit_source = false;
    capabilities.blit_destination = false;
    capabilities.presentation = format == .bgra8_unorm;
    capabilities.depth_resolve = false;
    capabilities.stencil_resolve = false;
    if (format == .depth32_float_stencil8) {
        capabilities.copy_source = false;
        capabilities.copy_destination = false;
        capabilities.depth_copy = false;
        capabilities.stencil_copy = false;
    }
    return capabilities;
}

pub fn nativeHandles(self: *const MetalClearScreen) !core.NativeHandles {
    var handles: metal.vkmtl_metal_native_handles = undefined;
    try check(metal.vkmtl_metal_clear_screen_get_native_handles(
        self.handle,
        &handles,
    ));

    return .{
        .metal = .{
            .device = handles.device orelse return Error.InvalidSurface,
            .command_queue = handles.command_queue orelse return Error.InvalidSurface,
            .layer = handles.layer orelse return Error.InvalidSurface,
            .view = handles.view orelse return Error.InvalidSurface,
        },
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

pub fn makeQuerySet(self: *MetalClearScreen, descriptor: core.QuerySetDescriptor) !?MetalQuerySet {
    if (descriptor.query_type == .timestamp and !self.supportsNativeTimestampQueries()) return null;
    return try MetalQuerySet.init(self, descriptor);
}

pub fn supportsNativeTimestampQueries(self: *const MetalClearScreen) bool {
    return self.queryCapabilities().timestamp_queries != 0;
}

pub fn accelerationStructureBuildSizes(
    self: *MetalClearScreen,
    descriptor: core.AccelerationStructureDescriptor,
) core.AdvancedFeatureError!core.AccelerationStructureBuildSizes {
    return try MetalAccelerationStructure.queryBuildSizes(self, descriptor);
}

pub fn makeAccelerationStructure(
    self: *MetalClearScreen,
    descriptor: core.AccelerationStructureDescriptor,
) core.AdvancedFeatureError!MetalAccelerationStructure {
    return try MetalAccelerationStructure.init(self, descriptor);
}

pub fn makeRayTracingPipelineState(
    self: *MetalClearScreen,
    allocator: std.mem.Allocator,
    descriptor: core.RayTracingPipelineDescriptor,
) core.AdvancedFeatureError!MetalRayTracingPipelineState {
    return try MetalRayTracingPipelineState.init(self, allocator, descriptor);
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

pub fn beginCapture(self: *MetalClearScreen) core.CaptureError!void {
    if (self.capture_active) return core.CaptureError.CaptureAlreadyActive;
    switch (metal.vkmtl_metal_clear_screen_begin_capture(self.handle)) {
        metal.VKMTL_METAL_STATUS_OK => self.capture_active = true,
        metal.VKMTL_METAL_STATUS_UNSUPPORTED => return core.CaptureError.UnsupportedCapture,
        else => return core.CaptureError.CaptureFailed,
    }
}

pub fn endCapture(self: *MetalClearScreen) core.CaptureError!void {
    if (!self.capture_active) return core.CaptureError.CaptureNotActive;
    switch (metal.vkmtl_metal_clear_screen_end_capture(self.handle)) {
        metal.VKMTL_METAL_STATUS_OK => self.capture_active = false,
        metal.VKMTL_METAL_STATUS_UNSUPPORTED => return core.CaptureError.UnsupportedCapture,
        else => return core.CaptureError.CaptureFailed,
    }
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

fn queryCapabilities(self: *const MetalClearScreen) metal.vkmtl_metal_device_capabilities {
    var capabilities: metal.vkmtl_metal_device_capabilities = undefined;
    const status = metal.vkmtl_metal_clear_screen_copy_capabilities(self.handle, &capabilities);
    if (status != metal.VKMTL_METAL_STATUS_OK) {
        return zeroCapabilities();
    }
    return capabilities;
}

fn zeroCapabilities() metal.vkmtl_metal_device_capabilities {
    return .{
        .argument_buffers = 0,
        .argument_buffer_tier = 0,
        .ray_tracing = 0,
        .sparse_textures = 0,
        .binary_archive = 0,
        .function_constants = 0,
        .timestamp_counter_set = 0,
        .timestamp_draw_boundary = 0,
        .timestamp_dispatch_boundary = 0,
        .timestamp_blit_boundary = 0,
        .timestamp_queries = 0,
        .max_threads_per_threadgroup_width = 0,
        .max_threads_per_threadgroup_height = 0,
        .max_threads_per_threadgroup_depth = 0,
        .max_threads_per_threadgroup_total = 0,
        .max_buffer_argument_table_entries = 0,
        .max_texture_argument_table_entries = 0,
        .max_sampler_argument_table_entries = 0,
        .max_buffer_length = 0,
        .max_threadgroup_memory_length = 0,
        .max_texture_dimension_1d = 0,
        .max_texture_dimension_2d = 0,
        .max_texture_dimension_3d = 0,
        .max_texture_array_layers = 0,
        .buffer_gpu_address = 0,
    };
}

fn nativeFeaturesFromMetalCapabilities(capabilities: metal.vkmtl_metal_device_capabilities) core.DeviceFeatures {
    var result = core.defaultDeviceFeatures(.metal);
    result.occlusion_queries = true;
    result.timestamp_queries = capabilities.timestamp_queries != 0;
    result.shader_specialization = capabilities.function_constants != 0;
    result.debug_markers = true;
    result.sampler_anisotropy = true;
    result.argument_buffers = capabilities.argument_buffers != 0;
    result.descriptor_indexing = false;
    result.sparse_textures = capabilities.sparse_textures != 0;
    result.tiled_textures = capabilities.sparse_textures != 0;
    result.acceleration_structures = capabilities.ray_tracing != 0;
    result.acceleration_structure_update = capabilities.ray_tracing != 0;
    result.acceleration_structure_refit = capabilities.ray_tracing != 0;
    result.acceleration_structure_compaction = capabilities.ray_tracing != 0;
    result.ray_tracing = capabilities.ray_tracing != 0;
    result.ray_query = false;
    result.ray_tracing_procedural_geometry = capabilities.ray_tracing != 0;
    result.ray_tracing_custom_intersection = capabilities.ray_tracing != 0;
    result.ray_tracing_callable_shaders = false;
    result.metal_binary_archive = capabilities.binary_archive != 0;
    result.buffer_gpu_address = capabilities.buffer_gpu_address != 0;
    return result;
}

fn usableFeaturesFromMetalCapabilities(capabilities: metal.vkmtl_metal_device_capabilities) core.DeviceFeatures {
    var result = core.defaultDeviceFeatures(.metal);
    result.occlusion_queries = true;
    result.shader_specialization = capabilities.function_constants != 0;
    result.debug_markers = true;
    result.sampler_anisotropy = true;
    result.buffer_gpu_address = capabilities.buffer_gpu_address != 0;
    return result;
}

fn limitsFromMetalCapabilities(capabilities: metal.vkmtl_metal_device_capabilities) core.DeviceLimits {
    var result = core.defaultDeviceLimits(.metal);
    if (capabilities.max_buffer_length != 0) {
        result.max_buffer_length = capabilities.max_buffer_length;
    }
    if (capabilities.max_texture_dimension_1d != 0) {
        result.max_texture_dimension_1d = capabilities.max_texture_dimension_1d;
        result.max_texture_dimension_2d = capabilities.max_texture_dimension_2d;
        result.max_texture_dimension_3d = capabilities.max_texture_dimension_3d;
        result.max_texture_array_layers = capabilities.max_texture_array_layers;
    }
    if (capabilities.max_threadgroup_memory_length != 0) {
        result.max_compute_threadgroup_memory_bytes = @intCast(capabilities.max_threadgroup_memory_length);
    }
    result.max_sampler_anisotropy = 16;
    if (capabilities.max_threads_per_threadgroup_total != 0) {
        result.max_compute_threads_per_threadgroup_x = capabilities.max_threads_per_threadgroup_width;
        result.max_compute_threads_per_threadgroup_y = capabilities.max_threads_per_threadgroup_height;
        result.max_compute_threads_per_threadgroup_z = capabilities.max_threads_per_threadgroup_depth;
        result.max_compute_total_threads_per_threadgroup = capabilities.max_threads_per_threadgroup_total;
    }
    if (capabilities.max_texture_argument_table_entries != 0) {
        result.max_bindless_descriptors_per_range = capabilities.max_texture_argument_table_entries;
        result.max_bindless_ranges_per_layout = 1;
    }
    if (capabilities.binary_archive != 0) {
        result.max_driver_cache_identity_bytes = 4096;
    }
    return result;
}

test "Metal native capabilities map argument buffers and ray tracing conservatively" {
    const capabilities = metal.vkmtl_metal_device_capabilities{
        .argument_buffers = 1,
        .argument_buffer_tier = 2,
        .ray_tracing = 1,
        .sparse_textures = 1,
        .binary_archive = 1,
        .function_constants = 1,
        .timestamp_counter_set = 1,
        .timestamp_draw_boundary = 1,
        .timestamp_dispatch_boundary = 1,
        .timestamp_blit_boundary = 1,
        .timestamp_queries = 1,
        .max_threads_per_threadgroup_width = 1024,
        .max_threads_per_threadgroup_height = 1024,
        .max_threads_per_threadgroup_depth = 64,
        .max_threads_per_threadgroup_total = 1024,
        .max_buffer_argument_table_entries = 128,
        .max_texture_argument_table_entries = 128,
        .max_sampler_argument_table_entries = 16,
        .max_buffer_length = 8 * 1024 * 1024 * 1024,
        .max_threadgroup_memory_length = 32 * 1024,
        .max_texture_dimension_1d = 16384,
        .max_texture_dimension_2d = 16384,
        .max_texture_dimension_3d = 2048,
        .max_texture_array_layers = 2048,
        .buffer_gpu_address = 1,
    };

    const native = nativeFeaturesFromMetalCapabilities(capabilities);
    const usable = usableFeaturesFromMetalCapabilities(capabilities);
    const queried_limits = limitsFromMetalCapabilities(capabilities);

    try std.testing.expect(native.argument_buffers);
    try std.testing.expect(native.ray_tracing);
    try std.testing.expect(native.metal_binary_archive);
    try std.testing.expect(native.occlusion_queries);
    try std.testing.expect(native.timestamp_queries);
    try std.testing.expect(native.shader_specialization);
    try std.testing.expect(native.buffer_gpu_address);
    try std.testing.expect(usable.occlusion_queries);
    try std.testing.expect(usable.shader_specialization);
    try std.testing.expect(usable.buffer_gpu_address);
    try std.testing.expect(!usable.argument_buffers);
    try std.testing.expect(!usable.ray_tracing);
    try std.testing.expectEqual(@as(u32, 1024), queried_limits.max_compute_total_threads_per_threadgroup);
    try std.testing.expectEqual(@as(u64, 8 * 1024 * 1024 * 1024), queried_limits.max_buffer_length);
    try std.testing.expectEqual(@as(u32, 16384), queried_limits.max_texture_dimension_2d);
    try std.testing.expectEqual(@as(u32, 32 * 1024), queried_limits.max_compute_threadgroup_memory_bytes);
    try std.testing.expectEqual(@as(u32, 128), queried_limits.max_bindless_descriptors_per_range);
}

test "Metal format capabilities keep presentation and scaled blit truthful" {
    const screen = MetalClearScreen{
        .handle = undefined,
        .extent = .{ .width = 1, .height = 1 },
    };
    const presentable = screen.formatCapabilities(.bgra8_unorm);
    try std.testing.expect(presentable.presentation);
    try std.testing.expect(!presentable.blit_source);
    try std.testing.expect(!presentable.blit_destination);
    try std.testing.expect(presentable.color_resolve);

    const srgb = screen.formatCapabilities(.bgra8_unorm_srgb);
    try std.testing.expect(!srgb.presentation);
    const depth = screen.formatCapabilities(.depth32_float);
    try std.testing.expect(depth.depth_copy);
    try std.testing.expect(!depth.depth_resolve);
    const depth_stencil = screen.formatCapabilities(.depth32_float_stencil8);
    try std.testing.expect(!depth_stencil.copy_source);
    try std.testing.expect(!depth_stencil.stencil_copy);

    const half_float = screen.formatCapabilities(.rgba16_float);
    try std.testing.expect(half_float.sampled);
    try std.testing.expect(half_float.filterable);
    try std.testing.expect(half_float.color_attachment);
    const integer = screen.formatCapabilities(.r32_uint);
    try std.testing.expect(integer.storage);
    try std.testing.expect(!integer.filterable);
    const stencil = screen.formatCapabilities(.stencil8);
    try std.testing.expect(stencil.depth_stencil_attachment);
    try std.testing.expect(!stencil.stencil_copy);
}
