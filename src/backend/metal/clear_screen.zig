const std = @import("std");
const core = @import("../../core.zig");
const MetalAccelerationStructure = @import("acceleration_structure.zig");
const MetalBuffer = @import("buffer.zig");
const MetalHeap = @import("heap.zig");
const MetalCommand = @import("command.zig");
const MetalComputePipelineState = @import("compute_pipeline.zig");
const MetalQuerySet = @import("query_set.zig");
const MetalRayTracingPipelineState = @import("ray_tracing_pipeline.zig");
const MetalRenderPipelineState = @import("render_pipeline.zig");
const MetalSamplerState = @import("sampler.zig");
const MetalShaderModule = @import("shader_module.zig");
const MetalTexture = @import("texture.zig");
const MetalSync = @import("sync.zig");
const metal = @import("metal_bridge");

const MetalClearScreen = @This();

handle: *metal.vkmtl_metal_clear_screen,
extent: core.Extent2D,
selected_presentation_format: ?core.TextureFormat = null,
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
    const selected_format = try resolvePresentationFormat(presentation.format);

    var handle: ?*metal.vkmtl_metal_clear_screen = null;
    try check(metal.vkmtl_metal_clear_screen_create(
        &handle,
        cocoa_window,
        MetalTexture.textureFormat(selected_format),
        presentation.extent.width,
        presentation.extent.height,
    ));
    const clear_screen = handle orelse return Error.InvalidSurface;
    errdefer metal.vkmtl_metal_clear_screen_destroy(clear_screen);

    var native_format: metal.vkmtl_metal_texture_format = metal.VKMTL_METAL_TEXTURE_FORMAT_INVALID;
    if (metal.vkmtl_metal_clear_screen_get_presentation_format(clear_screen, &native_format) != metal.VKMTL_METAL_STATUS_OK) {
        return core.SurfaceError.UnsupportedPresentationFormat;
    }
    const actual_format = try confirmPresentationFormat(selected_format, native_format);

    return .{
        .handle = clear_screen,
        .extent = presentation.extent,
        .selected_presentation_format = actual_format,
        .capture_active = false,
    };
}

pub fn initHeadless() !MetalClearScreen {
    var handle: ?*metal.vkmtl_metal_clear_screen = null;
    try check(metal.vkmtl_metal_clear_screen_create_headless(&handle));
    return .{
        .handle = handle orelse return Error.NoMetalDevice,
        .extent = .{ .width = 0, .height = 0 },
        .selected_presentation_format = null,
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

pub fn deviceTopology(self: *const MetalClearScreen) !core.DeviceTopologyReport {
    var native: metal.vkmtl_metal_device_topology = undefined;
    try check(metal.vkmtl_metal_clear_screen_copy_device_topology(self.handle, &native));
    var result = core.DeviceTopologyReport{
        .backend = .metal,
        .peer_index = native.peer_index,
        .peer_count = @max(native.peer_count, 1),
    };
    if (native.has_registry_id != 0) {
        result.identity_kind = .metal_registry_id;
        result.identity_size = @sizeOf(u64);
        @memcpy(result.identity[0..@sizeOf(u64)], std.mem.asBytes(&native.registry_id));
    }
    if (native.has_peer_group != 0) {
        result.peer_group_kind = .metal_peer_group;
        result.peer_group_identity_size = @sizeOf(u64);
        @memcpy(result.peer_group_identity[0..@sizeOf(u64)], std.mem.asBytes(&native.peer_group_id));
    }
    return result;
}

pub fn limits(self: *const MetalClearScreen) core.DeviceLimits {
    return limitsFromMetalCapabilities(self.queryCapabilities());
}

pub fn features(self: *const MetalClearScreen) core.DeviceFeatures {
    var result = usableFeaturesFromMetalCapabilities(self.queryCapabilities());
    if (self.extent.isZero()) {
        result.scheduled_presentation = false;
        result.minimum_duration_presentation = false;
    }
    return result;
}

pub fn nativeFeatures(self: *const MetalClearScreen) core.DeviceFeatures {
    return nativeFeaturesFromMetalCapabilities(self.queryCapabilities());
}

pub const MemoryBudget = struct {
    budget_bytes: u64,
    used_bytes: u64,
};

pub fn memoryBudget(self: *const MetalClearScreen) ?MemoryBudget {
    const capabilities = self.queryCapabilities();
    if (capabilities.memory_budget == 0 or capabilities.recommended_working_set_size == 0) return null;
    return .{
        .budget_bytes = capabilities.recommended_working_set_size,
        .used_bytes = capabilities.current_allocated_size,
    };
}

pub fn formatCapabilities(self: *const MetalClearScreen, format: core.TextureFormat) core.FormatCapabilities {
    var capabilities = core.defaultFormatCapabilities(format);
    if (format == .rgba16_float or format == .bgra8_unorm) capabilities.storage = true;
    capabilities.blit_source = false;
    capabilities.blit_destination = false;
    capabilities.presentation = if (self.selected_presentation_format) |selected| selected == format else false;
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

pub fn selectedPresentationFormat(self: *const MetalClearScreen) ?core.TextureFormat {
    return self.selected_presentation_format;
}

pub fn presentationExtent(self: *const MetalClearScreen) ?core.Extent2D {
    if (self.selected_presentation_format == null) return null;
    return self.extent;
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

pub fn makeHeap(self: *MetalClearScreen, descriptor: core.HeapDescriptor) !MetalHeap {
    return try MetalHeap.init(self, descriptor);
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

pub fn makeMeshRenderPipelineState(
    self: *MetalClearScreen,
    allocator: std.mem.Allocator,
    descriptor: core.MeshRenderPipelineDescriptor,
) !MetalRenderPipelineState {
    return try MetalRenderPipelineState.initMesh(self, allocator, descriptor);
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

pub fn makeCommandBuffer(self: *MetalClearScreen, queue_kind: core.QueueKind) !MetalCommand.CommandBuffer {
    return try MetalCommand.CommandBuffer.init(self, queue_kind);
}

pub fn makeSharedEvent(self: *MetalClearScreen, initial_value: u64) !MetalSync.SharedEvent {
    return try MetalSync.SharedEvent.init(self.handle, initial_value);
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

fn resolvePresentationFormat(requested: core.TextureFormat) core.SurfaceError!core.TextureFormat {
    return switch (requested) {
        .automatic, .bgra8_unorm_srgb => .bgra8_unorm_srgb,
        .bgra8_unorm => .bgra8_unorm,
        else => core.SurfaceError.UnsupportedPresentationFormat,
    };
}

fn presentationFormatFromNative(format: metal.vkmtl_metal_texture_format) core.SurfaceError!core.TextureFormat {
    return switch (format) {
        metal.VKMTL_METAL_TEXTURE_FORMAT_BGRA8_UNORM => .bgra8_unorm,
        metal.VKMTL_METAL_TEXTURE_FORMAT_BGRA8_UNORM_SRGB => .bgra8_unorm_srgb,
        else => core.SurfaceError.UnsupportedPresentationFormat,
    };
}

fn confirmPresentationFormat(
    resolved: core.TextureFormat,
    native: metal.vkmtl_metal_texture_format,
) core.SurfaceError!core.TextureFormat {
    const actual = try presentationFormatFromNative(native);
    if (actual != resolved) return core.SurfaceError.UnsupportedPresentationFormat;
    return actual;
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
        .indirect_command_buffers = 0,
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
    result.occlusion_counting_queries = true;
    result.timestamp_queries = capabilities.timestamp_queries != 0;
    result.shader_specialization = capabilities.function_constants != 0;
    result.debug_markers = true;
    result.sampler_anisotropy = true;
    result.argument_buffers = capabilities.argument_buffers != 0;
    result.indirect_command_buffers = capabilities.indirect_command_buffers != 0;
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
    result.timeline_fences = capabilities.shared_events != 0;
    result.shared_events = capabilities.shared_events != 0;
    result.multi_queue = capabilities.shared_events != 0;
    result.queue_ownership_transfer = capabilities.shared_events != 0;
    result.scheduled_presentation = capabilities.scheduled_presentation != 0;
    result.minimum_duration_presentation = capabilities.minimum_duration_presentation != 0;
    result.heaps = capabilities.heaps != 0;
    result.memory_budget = capabilities.memory_budget != 0;
    result.memory_pressure = capabilities.memory_budget != 0;
    result.memoryless_attachments = capabilities.memoryless_attachments != 0;
    result.mesh_shaders = capabilities.mesh_shaders != 0;
    result.task_shaders = capabilities.task_shaders != 0;
    result.compute_atomics = true;
    result.compute_threadgroup_memory = capabilities.max_threadgroup_memory_length != 0;
    result.external_memory = true;
    result.external_textures = true;
    return result;
}

fn usableFeaturesFromMetalCapabilities(capabilities: metal.vkmtl_metal_device_capabilities) core.DeviceFeatures {
    var result = core.defaultDeviceFeatures(.metal);
    result.occlusion_queries = true;
    result.occlusion_counting_queries = true;
    result.shader_specialization = capabilities.function_constants != 0;
    result.debug_markers = true;
    result.sampler_anisotropy = true;
    result.argument_buffers = capabilities.argument_buffers != 0;
    result.indirect_command_buffers = true;
    result.metal_binary_archive = capabilities.binary_archive != 0;
    result.buffer_gpu_address = capabilities.buffer_gpu_address != 0;
    result.timeline_fences = capabilities.shared_events != 0;
    result.shared_events = capabilities.shared_events != 0;
    result.multi_queue = capabilities.shared_events != 0;
    result.queue_ownership_transfer = capabilities.shared_events != 0;
    result.scheduled_presentation = capabilities.scheduled_presentation != 0;
    result.minimum_duration_presentation = capabilities.minimum_duration_presentation != 0;
    result.heaps = capabilities.heaps != 0;
    result.memory_budget = capabilities.memory_budget != 0;
    result.memory_pressure = capabilities.memory_budget != 0;
    result.memoryless_attachments = capabilities.memoryless_attachments != 0;
    result.mesh_shaders = capabilities.mesh_shaders != 0;
    // The pinned Slang toolchain currently cannot produce a stable
    // task/object artifact, so native availability is not executable support.
    result.task_shaders = false;
    result.acceleration_structures = capabilities.ray_tracing != 0;
    result.acceleration_structure_update = capabilities.ray_tracing != 0;
    result.acceleration_structure_refit = capabilities.ray_tracing != 0;
    result.acceleration_structure_compaction = capabilities.ray_tracing != 0;
    result.ray_tracing = capabilities.ray_tracing != 0;
    result.ray_query = false;
    result.ray_tracing_procedural_geometry = capabilities.ray_tracing != 0;
    // AABB build is executable, but custom intersection dispatch still needs
    // an intersection-function-table artifact and binding contract.
    result.ray_tracing_custom_intersection = false;
    result.ray_tracing_callable_shaders = false;
    result.compute_atomics = true;
    result.compute_threadgroup_memory = capabilities.max_threadgroup_memory_length != 0;
    result.external_memory = true;
    result.external_textures = true;
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
        result.max_bindless_ranges_per_layout = @min(
            capabilities.max_buffer_argument_table_entries,
            @min(
                capabilities.max_texture_argument_table_entries,
                capabilities.max_sampler_argument_table_entries,
            ),
        );
    }
    if (capabilities.binary_archive != 0) {
        result.max_driver_cache_identity_bytes = 4096;
    }
    result.max_mesh_threads_per_threadgroup = capabilities.max_mesh_threads_per_threadgroup;
    result.max_task_threads_per_threadgroup = capabilities.max_task_threads_per_threadgroup;
    result.max_mesh_threadgroups_per_grid_x = capabilities.max_mesh_threadgroups_per_grid_x;
    result.max_mesh_threadgroups_per_grid_y = capabilities.max_mesh_threadgroups_per_grid_y;
    result.max_mesh_threadgroups_per_grid_z = capabilities.max_mesh_threadgroups_per_grid_z;
    return result;
}

test "Metal native capabilities map argument buffers and ray tracing conservatively" {
    const capabilities = metal.vkmtl_metal_device_capabilities{
        .argument_buffers = 1,
        .argument_buffer_tier = 2,
        .indirect_command_buffers = 1,
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
        .shared_events = 1,
        .scheduled_presentation = 1,
        .minimum_duration_presentation = 1,
        .heaps = 1,
        .memory_budget = 1,
        .memoryless_attachments = 1,
        .mesh_shaders = 1,
        .task_shaders = 1,
        .max_mesh_threads_per_threadgroup = 256,
        .max_task_threads_per_threadgroup = 128,
        .max_mesh_threadgroups_per_grid_x = 65_535,
        .max_mesh_threadgroups_per_grid_y = 65_535,
        .max_mesh_threadgroups_per_grid_z = 65_535,
        .recommended_working_set_size = 16 * 1024 * 1024 * 1024,
        .current_allocated_size = 1024 * 1024,
    };

    const native = nativeFeaturesFromMetalCapabilities(capabilities);
    const usable = usableFeaturesFromMetalCapabilities(capabilities);
    const queried_limits = limitsFromMetalCapabilities(capabilities);

    try std.testing.expect(native.argument_buffers);
    try std.testing.expect(native.ray_tracing);
    try std.testing.expect(native.metal_binary_archive);
    try std.testing.expect(native.occlusion_queries);
    try std.testing.expect(native.occlusion_counting_queries);
    try std.testing.expect(native.timestamp_queries);
    try std.testing.expect(native.shader_specialization);
    try std.testing.expect(native.buffer_gpu_address);
    try std.testing.expect(native.compute_atomics);
    try std.testing.expect(native.compute_threadgroup_memory);
    try std.testing.expect(native.timeline_fences);
    try std.testing.expect(native.shared_events);
    try std.testing.expect(native.heaps);
    try std.testing.expect(native.memory_budget);
    try std.testing.expect(native.memoryless_attachments);
    try std.testing.expect(native.scheduled_presentation);
    try std.testing.expect(native.minimum_duration_presentation);
    try std.testing.expect(native.mesh_shaders);
    try std.testing.expect(native.task_shaders);
    try std.testing.expect(usable.occlusion_queries);
    try std.testing.expect(usable.occlusion_counting_queries);
    try std.testing.expect(usable.shader_specialization);
    try std.testing.expect(usable.buffer_gpu_address);
    try std.testing.expect(usable.compute_atomics);
    try std.testing.expect(usable.compute_threadgroup_memory);
    try std.testing.expect(usable.timeline_fences);
    try std.testing.expect(usable.shared_events);
    try std.testing.expect(usable.heaps);
    try std.testing.expect(usable.memory_budget);
    try std.testing.expect(usable.memoryless_attachments);
    try std.testing.expect(usable.scheduled_presentation);
    try std.testing.expect(usable.minimum_duration_presentation);
    try std.testing.expect(usable.mesh_shaders);
    try std.testing.expect(!usable.task_shaders);
    try std.testing.expect(usable.argument_buffers);
    try std.testing.expect(usable.metal_binary_archive);
    try std.testing.expect(usable.acceleration_structures);
    try std.testing.expect(usable.acceleration_structure_update);
    try std.testing.expect(usable.acceleration_structure_refit);
    try std.testing.expect(usable.acceleration_structure_compaction);
    try std.testing.expect(usable.ray_tracing);
    try std.testing.expect(usable.ray_tracing_procedural_geometry);
    try std.testing.expect(!usable.ray_tracing_custom_intersection);
    try std.testing.expect(!usable.ray_query);
    try std.testing.expect(!usable.ray_tracing_callable_shaders);
    try std.testing.expectEqual(@as(u32, 1024), queried_limits.max_compute_total_threads_per_threadgroup);
    try std.testing.expectEqual(@as(u64, 8 * 1024 * 1024 * 1024), queried_limits.max_buffer_length);
    try std.testing.expectEqual(@as(u32, 16384), queried_limits.max_texture_dimension_2d);
    try std.testing.expectEqual(@as(u32, 32 * 1024), queried_limits.max_compute_threadgroup_memory_bytes);
    try std.testing.expectEqual(@as(u32, 128), queried_limits.max_bindless_descriptors_per_range);
    try std.testing.expectEqual(@as(u32, 16), queried_limits.max_bindless_ranges_per_layout);
    try std.testing.expectEqual(@as(u32, 256), queried_limits.max_mesh_threads_per_threadgroup);
    try std.testing.expectEqual(@as(u32, 128), queried_limits.max_task_threads_per_threadgroup);
    try std.testing.expectEqual(@as(u32, 65_535), queried_limits.max_mesh_threadgroups_per_grid_x);
}

test "Metal presentation resolver honors automatic and explicit BGRA8 requests" {
    try std.testing.expectEqual(
        core.TextureFormat.bgra8_unorm_srgb,
        try resolvePresentationFormat(.automatic),
    );
    try std.testing.expectEqual(
        core.TextureFormat.bgra8_unorm_srgb,
        try resolvePresentationFormat(.bgra8_unorm_srgb),
    );
    try std.testing.expectEqual(
        core.TextureFormat.bgra8_unorm,
        try resolvePresentationFormat(.bgra8_unorm),
    );
    try std.testing.expectError(
        core.SurfaceError.UnsupportedPresentationFormat,
        resolvePresentationFormat(.rgba16_float),
    );
}

test "Metal native presentation formats map back to the selected portable format" {
    try std.testing.expectEqual(
        core.TextureFormat.bgra8_unorm,
        try presentationFormatFromNative(metal.VKMTL_METAL_TEXTURE_FORMAT_BGRA8_UNORM),
    );
    try std.testing.expectEqual(
        core.TextureFormat.bgra8_unorm_srgb,
        try presentationFormatFromNative(metal.VKMTL_METAL_TEXTURE_FORMAT_BGRA8_UNORM_SRGB),
    );
    try std.testing.expectError(
        core.SurfaceError.UnsupportedPresentationFormat,
        presentationFormatFromNative(metal.VKMTL_METAL_TEXTURE_FORMAT_INVALID),
    );
    try std.testing.expectError(
        core.SurfaceError.UnsupportedPresentationFormat,
        presentationFormatFromNative(metal.VKMTL_METAL_TEXTURE_FORMAT_RGBA8_UNORM),
    );
    try std.testing.expectError(
        core.SurfaceError.UnsupportedPresentationFormat,
        confirmPresentationFormat(
            .bgra8_unorm_srgb,
            metal.VKMTL_METAL_TEXTURE_FORMAT_BGRA8_UNORM,
        ),
    );
}

test "Metal format capabilities expose only the selected drawable format" {
    const srgb_screen = MetalClearScreen{
        .handle = undefined,
        .extent = .{ .width = 1, .height = 1 },
        .selected_presentation_format = .bgra8_unorm_srgb,
    };
    try std.testing.expectEqual(core.TextureFormat.bgra8_unorm_srgb, srgb_screen.selectedPresentationFormat().?);
    const presentable = srgb_screen.formatCapabilities(.bgra8_unorm_srgb);
    try std.testing.expect(presentable.presentation);
    try std.testing.expect(!presentable.blit_source);
    try std.testing.expect(!presentable.blit_destination);
    try std.testing.expect(presentable.color_resolve);
    try std.testing.expect(!srgb_screen.formatCapabilities(.bgra8_unorm).presentation);

    const headless = MetalClearScreen{
        .handle = undefined,
        .extent = .{ .width = 0, .height = 0 },
        .selected_presentation_format = null,
    };
    try std.testing.expectEqual(@as(?core.TextureFormat, null), headless.selectedPresentationFormat());
    try std.testing.expect(!headless.formatCapabilities(.bgra8_unorm_srgb).presentation);
    try std.testing.expect(!headless.formatCapabilities(.bgra8_unorm).presentation);

    const linear_screen = MetalClearScreen{
        .handle = undefined,
        .extent = .{ .width = 1, .height = 1 },
        .selected_presentation_format = .bgra8_unorm,
    };
    const linear = linear_screen.formatCapabilities(.bgra8_unorm);
    try std.testing.expect(linear.presentation);
    try std.testing.expect(linear.storage);
    try std.testing.expect(!linear_screen.formatCapabilities(.bgra8_unorm_srgb).presentation);

    const depth = srgb_screen.formatCapabilities(.depth32_float);
    try std.testing.expect(depth.depth_copy);
    try std.testing.expect(!depth.depth_resolve);
    const depth_stencil = srgb_screen.formatCapabilities(.depth32_float_stencil8);
    try std.testing.expect(!depth_stencil.copy_source);
    try std.testing.expect(!depth_stencil.stencil_copy);

    const half_float = srgb_screen.formatCapabilities(.rgba16_float);
    try std.testing.expect(half_float.sampled);
    try std.testing.expect(half_float.filterable);
    try std.testing.expect(half_float.color_attachment);
    try std.testing.expect(half_float.storage);
    const integer = srgb_screen.formatCapabilities(.r32_uint);
    try std.testing.expect(integer.storage);
    try std.testing.expect(!integer.filterable);
    const stencil = srgb_screen.formatCapabilities(.stencil8);
    try std.testing.expect(stencil.depth_stencil_attachment);
    try std.testing.expect(!stencil.stencil_copy);
}
