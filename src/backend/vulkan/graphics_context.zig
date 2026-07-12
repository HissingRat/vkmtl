const builtin = @import("builtin");
const std = @import("std");
const vk = @import("vulkan");
const core = @import("../../core.zig");

const Allocator = std.mem.Allocator;
const GraphicsContext = @This();

const enable_validation_layers = builtin.mode == .Debug;
const enable_portability = builtin.os.tag == .macos;

const required_layer_names = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};
const required_device_extensions = if (enable_portability)
    [_][*:0]const u8{
        vk.extensions.khr_swapchain.name,
        vk.extensions.khr_portability_subset.name,
    }
else
    [_][*:0]const u8{vk.extensions.khr_swapchain.name};
const required_ray_tracing_device_extensions = [_][*:0]const u8{
    vk.extensions.khr_acceleration_structure.name,
    vk.extensions.khr_ray_tracing_pipeline.name,
    vk.extensions.khr_deferred_host_operations.name,
    vk.extensions.khr_buffer_device_address.name,
    vk.extensions.khr_spirv_1_4.name,
    vk.extensions.khr_shader_float_controls.name,
};

const BaseWrapper = vk.BaseWrapper;
const InstanceWrapper = vk.InstanceWrapper;
const DeviceWrapper = vk.DeviceWrapper;

const Instance = vk.InstanceProxy;
const Device = vk.DeviceProxy;

pub const CommandBuffer = vk.CommandBufferProxy;

allocator: Allocator,
vkb: BaseWrapper,
instance: Instance,
debug_messenger: vk.DebugUtilsMessengerEXT,
debug_utils_enabled: bool,
surface: vk.SurfaceKHR,
pdev: vk.PhysicalDevice,
props: vk.PhysicalDeviceProperties,
mem_props: vk.PhysicalDeviceMemoryProperties,
dev: Device,
graphics_queue: Queue,
present_queue: Queue,
features_value: core.DeviceFeatures,
native_features_value: core.DeviceFeatures,
limits_value: core.DeviceLimits,
ray_tracing_diagnostics_value: core.RayTracingCapabilityDiagnostics,
host_query_reset: bool,
native_timestamp_queries: bool,

pub fn init(allocator: Allocator, app_name: [*:0]const u8, surface_provider: core.VulkanSurfaceProvider) !GraphicsContext {
    var self: GraphicsContext = undefined;
    self.allocator = allocator;
    self.vkb = try loadBaseWrapper(surface_provider);
    try ensureBaseDispatchAvailable(self.vkb);
    self.debug_messenger = .null_handle;
    self.debug_utils_enabled = false;

    const use_validation_layers = enable_validation_layers and try checkLayerSupport(&self.vkb, allocator);

    var extension_names: std.ArrayList([*:0]const u8) = .empty;
    defer extension_names.deinit(allocator);

    if (use_validation_layers) {
        try extension_names.append(allocator, vk.extensions.ext_debug_utils.name);
    }
    if (enable_portability) {
        try extension_names.append(allocator, vk.extensions.khr_portability_enumeration.name);
        try extension_names.append(allocator, vk.extensions.khr_get_physical_device_properties_2.name);
    }

    var surface_exts_count: u32 = 0;
    const surface_exts = surface_provider.get_required_instance_extensions(surface_provider.context, &surface_exts_count) orelse {
        return error.MissingVulkanSurfaceExtensions;
    };
    try extension_names.appendSlice(allocator, surface_exts[0..surface_exts_count]);

    const enabled_layers: []const [*:0]const u8 = if (use_validation_layers) &required_layer_names else &.{};
    const instance = try self.vkb.createInstance(&.{
        .p_application_info = &.{
            .p_application_name = app_name,
            .application_version = vk.makeApiVersion(0, 0, 0, 0).toU32(),
            .p_engine_name = app_name,
            .engine_version = vk.makeApiVersion(0, 0, 0, 0).toU32(),
            .api_version = vk.API_VERSION_1_3.toU32(),
        },
        .enabled_layer_count = @intCast(enabled_layers.len),
        .pp_enabled_layer_names = enabled_layers.ptr,
        .enabled_extension_count = @intCast(extension_names.items.len),
        .pp_enabled_extension_names = extension_names.items.ptr,
        .flags = if (enable_portability) .{ .enumerate_portability_bit_khr = true } else .{},
    }, null);

    const vki = try allocator.create(InstanceWrapper);
    errdefer allocator.destroy(vki);
    const get_instance_proc_addr = self.vkb.dispatch.vkGetInstanceProcAddr orelse return error.VulkanUnavailable;
    vki.* = InstanceWrapper.load(instance, get_instance_proc_addr);
    try ensureInstanceDispatchAvailable(vki.*);
    self.instance = Instance.init(instance, vki);
    errdefer self.instance.destroyInstance(null);

    if (use_validation_layers) {
        self.debug_messenger = try self.instance.createDebugUtilsMessengerEXT(&.{
            .message_severity = .{
                .warning_bit_ext = true,
                .error_bit_ext = true,
            },
            .message_type = .{
                .general_bit_ext = true,
                .validation_bit_ext = true,
                .performance_bit_ext = true,
            },
            .pfn_user_callback = debugCallback,
        }, null);
        self.debug_utils_enabled = true;
    }

    self.surface = try createSurface(self.instance, surface_provider);
    errdefer self.instance.destroySurfaceKHR(self.surface, null);

    const candidate = try pickPhysicalDevice(self.instance, allocator, self.surface);
    self.pdev = candidate.pdev;
    self.props = candidate.props;

    const dev = try initializeCandidate(self.instance, allocator, candidate);

    const vkd = try allocator.create(DeviceWrapper);
    errdefer allocator.destroy(vkd);
    const get_device_proc_addr = self.instance.wrapper.dispatch.vkGetDeviceProcAddr orelse return error.VulkanUnavailable;
    vkd.* = DeviceWrapper.load(dev, get_device_proc_addr);
    try ensureDeviceDispatchAvailable(vkd.*);
    self.dev = Device.init(dev, vkd);
    errdefer self.dev.destroyDevice(null);

    self.graphics_queue = Queue.init(self.dev, candidate.queues.graphics_family);
    self.present_queue = Queue.init(self.dev, candidate.queues.present_family);
    self.host_query_reset = candidate.host_query_reset and self.dev.wrapper.dispatch.vkResetQueryPool != null;
    self.native_timestamp_queries = self.host_query_reset and candidate.queues.graphics_timestamp_valid_bits != 0;
    self.mem_props = self.instance.getPhysicalDeviceMemoryProperties(self.pdev);
    self.ray_tracing_diagnostics_value = try queryRayTracingCapabilityDiagnostics(
        self.instance,
        self.pdev,
        allocator,
        &self.dev.wrapper.dispatch,
    );
    self.native_features_value = try queryNativeFeatures(
        self.instance,
        self.pdev,
        allocator,
        self.ray_tracing_diagnostics_value,
        candidate.queues.graphics_timestamp_valid_bits != 0,
    );
    self.native_features_value.debug_labels = self.debug_utils_enabled;
    self.native_features_value.debug_markers = self.debug_utils_enabled;
    self.features_value = queryUsableFeatures(self.native_features_value, self.host_query_reset);
    self.limits_value = queryLimits(
        self.instance,
        self.pdev,
        self.props,
        self.features_value,
        self.ray_tracing_diagnostics_value,
    );
    self.limits_value.max_sample_count = self.maxSupportedSampleCount(.rgba8_unorm);

    return self;
}

pub fn deinit(self: GraphicsContext) void {
    self.dev.destroyDevice(null);
    self.instance.destroySurfaceKHR(self.surface, null);
    if (self.debug_messenger != .null_handle) {
        self.instance.destroyDebugUtilsMessengerEXT(self.debug_messenger, null);
    }
    self.instance.destroyInstance(null);
    self.allocator.destroy(self.dev.wrapper);
    self.allocator.destroy(self.instance.wrapper);
}

pub fn deviceName(self: *const GraphicsContext) []const u8 {
    return std.mem.sliceTo(&self.props.device_name, 0);
}

pub fn adapterInfo(self: *const GraphicsContext) core.AdapterInfo {
    return .{
        .backend = .vulkan,
        .name = self.deviceName(),
        .vendor = vendorName(self.props.vendor_id),
        .device_type = adapterDeviceType(self.props.device_type),
    };
}

pub fn features(self: GraphicsContext) core.DeviceFeatures {
    return self.features_value;
}

pub fn nativeFeatures(self: GraphicsContext) core.DeviceFeatures {
    return self.native_features_value;
}

pub fn limits(self: GraphicsContext) core.DeviceLimits {
    return self.limits_value;
}

pub fn rayTracingDiagnostics(self: GraphicsContext) core.RayTracingCapabilityDiagnostics {
    return self.ray_tracing_diagnostics_value;
}

pub fn supportsHostQueryReset(self: GraphicsContext) bool {
    return self.host_query_reset;
}

pub fn supportsNativeTimestampQueries(self: GraphicsContext) bool {
    return self.native_timestamp_queries;
}

pub fn formatCapabilities(self: GraphicsContext, format: core.TextureFormat) core.FormatCapabilities {
    if (format == .automatic) return .{};
    const props = self.instance.getPhysicalDeviceFormatProperties(self.pdev, imageFormat(format));
    var capabilities = formatCapabilitiesFromVulkanFeatures(format, props.optimal_tiling_features);
    capabilities.presentation = self.supportsPresentationFormat(imageFormat(format));
    return capabilities;
}

fn supportsPresentationFormat(self: GraphicsContext, format: vk.Format) bool {
    const formats = self.instance.getPhysicalDeviceSurfaceFormatsAllocKHR(
        self.pdev,
        self.surface,
        self.allocator,
    ) catch return false;
    defer self.allocator.free(formats);
    if (formats.len == 1 and formats[0].format == .undefined) return true;
    for (formats) |surface_format| {
        if (surface_format.format == format) return true;
    }
    return false;
}

pub fn setDebugName(self: GraphicsContext, object_type: vk.ObjectType, object_handle: u64, label_value: ?[]const u8) void {
    if (!self.debug_utils_enabled) return;
    if (self.dev.wrapper.dispatch.vkSetDebugUtilsObjectNameEXT == null) return;
    if (label_value) |label| {
        if (!validNativeDebugLabel(label)) return;
    }

    const label_z = if (label_value) |label|
        self.allocator.dupeZ(u8, label) catch return
    else
        null;
    defer if (label_z) |label| self.allocator.free(label);

    self.dev.setDebugUtilsObjectNameEXT(&.{
        .object_type = object_type,
        .object_handle = object_handle,
        .p_object_name = if (label_z) |label| label.ptr else null,
    }) catch {};
}

pub fn beginDebugLabel(self: GraphicsContext, cmdbuf: vk.CommandBuffer, label_value: []const u8) void {
    if (!self.debug_utils_enabled) return;
    if (self.dev.wrapper.dispatch.vkCmdBeginDebugUtilsLabelEXT == null) return;
    if (!validNativeDebugLabel(label_value)) return;

    const label_z = self.allocator.dupeZ(u8, label_value) catch return;
    defer self.allocator.free(label_z);
    const info = debugLabelInfo(label_z.ptr);
    self.dev.cmdBeginDebugUtilsLabelEXT(cmdbuf, &info);
}

pub fn endDebugLabel(self: GraphicsContext, cmdbuf: vk.CommandBuffer) void {
    if (!self.debug_utils_enabled) return;
    if (self.dev.wrapper.dispatch.vkCmdEndDebugUtilsLabelEXT == null) return;

    self.dev.cmdEndDebugUtilsLabelEXT(cmdbuf);
}

pub fn insertDebugLabel(self: GraphicsContext, cmdbuf: vk.CommandBuffer, label_value: []const u8) void {
    if (!self.debug_utils_enabled) return;
    if (self.dev.wrapper.dispatch.vkCmdInsertDebugUtilsLabelEXT == null) return;
    if (!validNativeDebugLabel(label_value)) return;

    const label_z = self.allocator.dupeZ(u8, label_value) catch return;
    defer self.allocator.free(label_z);
    const info = debugLabelInfo(label_z.ptr);
    self.dev.cmdInsertDebugUtilsLabelEXT(cmdbuf, &info);
}

pub fn debugObjectHandle(handle: anytype) u64 {
    return @intCast(@intFromEnum(handle));
}

fn debugLabelInfo(label: [*:0]const u8) vk.DebugUtilsLabelEXT {
    return .{
        .p_label_name = label,
        .color = .{ 0.2, 0.6, 1.0, 1.0 },
    };
}

fn validNativeDebugLabel(label: []const u8) bool {
    return std.mem.indexOfScalar(u8, label, 0) == null and std.unicode.utf8ValidateSlice(label);
}

pub fn findMemoryTypeIndex(self: GraphicsContext, memory_type_bits: u32, flags: vk.MemoryPropertyFlags) !u32 {
    for (self.mem_props.memory_types[0..self.mem_props.memory_type_count], 0..) |mem_type, i| {
        if (memory_type_bits & (@as(u32, 1) << @truncate(i)) != 0 and mem_type.property_flags.contains(flags)) {
            return @truncate(i);
        }
    }
    return error.NoSuitableMemoryType;
}

fn adapterDeviceType(device_type: vk.PhysicalDeviceType) core.AdapterDeviceType {
    return switch (device_type) {
        .integrated_gpu => .integrated_gpu,
        .discrete_gpu => .discrete_gpu,
        .virtual_gpu => .virtual_gpu,
        .cpu => .cpu,
        else => .unknown,
    };
}

fn vendorName(vendor_id: u32) []const u8 {
    return switch (vendor_id) {
        0x1002 => "AMD",
        0x1010 => "ImgTec",
        0x106b => "Apple",
        0x10de => "NVIDIA",
        0x13b5 => "ARM",
        0x5143 => "Qualcomm",
        0x8086 => "Intel",
        else => "",
    };
}

pub fn allocate(self: GraphicsContext, requirements: vk.MemoryRequirements, flags: vk.MemoryPropertyFlags) !vk.DeviceMemory {
    return try self.dev.allocateMemory(&.{
        .allocation_size = requirements.size,
        .memory_type_index = try self.findMemoryTypeIndex(requirements.memory_type_bits, flags),
    }, null);
}

pub fn allocateDeviceAddressable(self: GraphicsContext, requirements: vk.MemoryRequirements, flags: vk.MemoryPropertyFlags) !vk.DeviceMemory {
    const allocate_flags = vk.MemoryAllocateFlagsInfo{
        .flags = .{ .device_address_bit = true },
        .device_mask = 0,
    };
    return try self.dev.allocateMemory(&.{
        .p_next = &allocate_flags,
        .allocation_size = requirements.size,
        .memory_type_index = try self.findMemoryTypeIndex(requirements.memory_type_bits, flags),
    }, null);
}

pub fn supportsSampleCount(self: GraphicsContext, format: core.TextureFormat, sample_count: u32) bool {
    const flags = if (core.isDepthFormat(format))
        self.props.limits.framebuffer_depth_sample_counts
    else
        self.props.limits.framebuffer_color_sample_counts;

    return switch (sample_count) {
        1 => flags.@"1_bit",
        2 => flags.@"2_bit",
        4 => flags.@"4_bit",
        8 => flags.@"8_bit",
        else => false,
    };
}

fn maxSupportedSampleCount(self: GraphicsContext, format: core.TextureFormat) u32 {
    const candidates = [_]u32{ 8, 4, 2 };
    for (candidates) |sample_count| {
        if (self.supportsSampleCount(format, sample_count)) return sample_count;
    }
    return 1;
}

fn queryNativeFeatures(
    instance: Instance,
    pdev: vk.PhysicalDevice,
    allocator: Allocator,
    ray_tracing: core.RayTracingCapabilityDiagnostics,
    timestamp_query_capability: bool,
) !core.DeviceFeatures {
    var result = core.defaultDeviceFeatures(.vulkan);
    const native = instance.getPhysicalDeviceFeatures(pdev);
    const extensions = try queryExtensionSupport(instance, pdev, allocator);

    result.occlusion_queries = true;
    result.timestamp_queries = timestamp_query_capability;
    result.sampler_anisotropy = native.sampler_anisotropy == .true;
    result.independent_blend = native.independent_blend == .true;
    result.tessellation = native.tessellation_shader == .true;
    result.wireframe_fill_mode = native.fill_mode_non_solid == .true;
    result.multi_draw = native.multi_draw_indirect == .true;
    result.pipeline_statistics_queries = native.pipeline_statistics_query == .true;
    result.sparse_buffers = native.sparse_binding == .true and native.sparse_residency_buffer == .true;
    result.sparse_textures = native.sparse_binding == .true and
        (native.sparse_residency_image_2d == .true or native.sparse_residency_image_3d == .true);
    result.tiled_textures = result.sparse_textures;
    result.descriptor_indexing = extensions.descriptor_indexing;
    result.vertex_instance_step_rate = vertexAttributeDivisorFeatureSupported(instance, pdev, extensions);
    result.external_memory = extensions.external_memory;
    result.external_semaphores = extensions.external_semaphore;
    result.external_textures = extensions.external_memory;
    result.mesh_shaders = extensions.mesh_shader;
    result.task_shaders = extensions.mesh_shader;
    result.acceleration_structures = ray_tracing.supported;
    result.acceleration_structure_update = ray_tracing.supported;
    result.acceleration_structure_refit = ray_tracing.supported;
    result.acceleration_structure_compaction = ray_tracing.supported;
    result.ray_tracing = ray_tracing.supported;
    result.ray_query = ray_tracing.supported;
    result.ray_tracing_procedural_geometry = ray_tracing.supported;
    result.ray_tracing_custom_intersection = ray_tracing.supported;
    result.ray_tracing_callable_shaders = ray_tracing.supported;
    result.driver_pipeline_cache = true;
    result.buffer_gpu_address = bufferDeviceAddressSupported(instance, pdev);
    // 32-bit integer storage-buffer and workgroup atomics, plus workgroup
    // shared memory, are Vulkan core shader semantics. The queried shared
    // memory byte ceiling is reported separately through DeviceLimits.
    result.compute_atomics = true;
    result.compute_threadgroup_memory = true;
    return result;
}

fn queryUsableFeatures(native_features: core.DeviceFeatures, host_query_reset: bool) core.DeviceFeatures {
    var result = core.defaultDeviceFeatures(.vulkan);

    result.sampler_anisotropy = native_features.sampler_anisotropy;
    result.independent_blend = native_features.independent_blend;
    result.tessellation = false;
    result.occlusion_queries = native_features.occlusion_queries and host_query_reset;
    result.wireframe_fill_mode = native_features.wireframe_fill_mode;
    result.vertex_instance_step_rate = native_features.vertex_instance_step_rate;
    result.multi_draw = false;
    result.pipeline_statistics_queries = false;
    result.sparse_buffers = false;
    result.sparse_textures = false;
    result.tiled_textures = false;
    result.descriptor_indexing = false;
    result.external_memory = false;
    result.external_semaphores = false;
    result.external_textures = false;
    result.mesh_shaders = false;
    result.task_shaders = false;
    result.acceleration_structures = false;
    result.ray_tracing = false;
    result.driver_pipeline_cache = false;
    result.buffer_gpu_address = native_features.buffer_gpu_address;
    result.compute_atomics = native_features.compute_atomics;
    result.compute_threadgroup_memory = native_features.compute_threadgroup_memory;

    result.native_handles = native_features.native_handles;
    result.debug_labels = native_features.debug_labels;
    result.debug_markers = native_features.debug_markers;
    return result;
}

fn queryLimits(
    instance: Instance,
    pdev: vk.PhysicalDevice,
    props: vk.PhysicalDeviceProperties,
    queried_features: core.DeviceFeatures,
    ray_tracing: core.RayTracingCapabilityDiagnostics,
) core.DeviceLimits {
    _ = queried_features;
    var result = core.defaultDeviceLimits(.vulkan);
    var maintenance4 = vk.PhysicalDeviceMaintenance4Properties{
        .max_buffer_size = 0,
    };
    var properties2 = vk.PhysicalDeviceProperties2{
        .p_next = &maintenance4,
        .properties = undefined,
    };
    if (getPhysicalDeviceProperties2(instance, pdev, &properties2) and maintenance4.max_buffer_size != 0) {
        result.max_buffer_length = maintenance4.max_buffer_size;
    }
    result.max_texture_dimension_1d = props.limits.max_image_dimension_1d;
    result.max_texture_dimension_2d = props.limits.max_image_dimension_2d;
    result.max_texture_dimension_3d = props.limits.max_image_dimension_3d;
    result.max_texture_array_layers = props.limits.max_image_array_layers;
    result.max_vertex_buffer_slots = @min(props.limits.max_vertex_input_bindings, core.default_max_vertex_buffer_slots);
    result.max_color_attachments = @max(1, props.limits.max_fragment_output_attachments);
    result.max_sampler_anisotropy = props.limits.max_sampler_anisotropy;
    result.min_uniform_buffer_offset_alignment = props.limits.min_uniform_buffer_offset_alignment;
    result.min_storage_buffer_offset_alignment = props.limits.min_storage_buffer_offset_alignment;
    result.max_tessellation_control_points = props.limits.max_tessellation_patch_size;
    result.max_compute_threadgroups_per_grid_x = props.limits.max_compute_work_group_count[0];
    result.max_compute_threadgroups_per_grid_y = props.limits.max_compute_work_group_count[1];
    result.max_compute_threadgroups_per_grid_z = props.limits.max_compute_work_group_count[2];
    result.max_compute_threads_per_threadgroup_x = props.limits.max_compute_work_group_size[0];
    result.max_compute_threads_per_threadgroup_y = props.limits.max_compute_work_group_size[1];
    result.max_compute_threads_per_threadgroup_z = props.limits.max_compute_work_group_size[2];
    result.max_compute_total_threads_per_threadgroup = props.limits.max_compute_work_group_invocations;
    result.max_compute_threadgroup_memory_bytes = props.limits.max_compute_shared_memory_size;
    result.buffer_texture_copy_offset_alignment = props.limits.optimal_buffer_copy_offset_alignment;
    result.buffer_texture_copy_row_pitch_alignment = @intCast(@max(1, props.limits.optimal_buffer_copy_row_pitch_alignment));
    result.max_ray_tracing_recursion_depth = ray_tracing.max_recursion_depth;
    result.shader_binding_table_alignment = ray_tracing.shader_group_handle_alignment;
    result.max_driver_cache_identity_bytes = 4096;
    return result;
}

const VulkanExtensionSupport = struct {
    descriptor_indexing: bool = false,
    vertex_attribute_divisor_khr: bool = false,
    vertex_attribute_divisor_ext: bool = false,
    external_memory: bool = false,
    external_semaphore: bool = false,
    acceleration_structure: bool = false,
    ray_tracing_pipeline: bool = false,
    ray_tracing_nv: bool = false,
    deferred_host_operations: bool = false,
    buffer_device_address: bool = false,
    spirv_1_4: bool = false,
    shader_float_controls: bool = false,
    mesh_shader: bool = false,
};

fn queryExtensionSupport(instance: Instance, pdev: vk.PhysicalDevice, allocator: Allocator) !VulkanExtensionSupport {
    const props = try instance.enumerateDeviceExtensionPropertiesAlloc(pdev, null, allocator);
    defer allocator.free(props);

    var support: VulkanExtensionSupport = .{};
    for (props) |prop| {
        support = mergeExtensionSupport(support, std.mem.sliceTo(&prop.extension_name, 0));
    }
    return support;
}

fn mergeExtensionSupport(current: VulkanExtensionSupport, extension_name: []const u8) VulkanExtensionSupport {
    var result = current;
    if (std.mem.eql(u8, extension_name, vk.extensions.ext_descriptor_indexing.name)) result.descriptor_indexing = true;
    if (std.mem.eql(u8, extension_name, vk.extensions.khr_vertex_attribute_divisor.name)) result.vertex_attribute_divisor_khr = true;
    if (std.mem.eql(u8, extension_name, vk.extensions.ext_vertex_attribute_divisor.name)) result.vertex_attribute_divisor_ext = true;
    if (std.mem.eql(u8, extension_name, vk.extensions.khr_external_memory.name)) result.external_memory = true;
    if (std.mem.eql(u8, extension_name, vk.extensions.khr_external_semaphore.name)) result.external_semaphore = true;
    if (std.mem.eql(u8, extension_name, vk.extensions.khr_acceleration_structure.name)) result.acceleration_structure = true;
    if (std.mem.eql(u8, extension_name, vk.extensions.khr_ray_tracing_pipeline.name)) result.ray_tracing_pipeline = true;
    if (std.mem.eql(u8, extension_name, vk.extensions.nv_ray_tracing.name)) result.ray_tracing_nv = true;
    if (std.mem.eql(u8, extension_name, vk.extensions.khr_deferred_host_operations.name)) result.deferred_host_operations = true;
    if (std.mem.eql(u8, extension_name, vk.extensions.khr_buffer_device_address.name)) result.buffer_device_address = true;
    if (std.mem.eql(u8, extension_name, vk.extensions.khr_spirv_1_4.name)) result.spirv_1_4 = true;
    if (std.mem.eql(u8, extension_name, vk.extensions.khr_shader_float_controls.name)) result.shader_float_controls = true;
    if (std.mem.eql(u8, extension_name, vk.extensions.ext_mesh_shader.name) or
        std.mem.eql(u8, extension_name, vk.extensions.nv_mesh_shader.name))
    {
        result.mesh_shader = true;
    }
    return result;
}

fn rayTracingExtensionSupported(support: VulkanExtensionSupport, extension_name: [*:0]const u8) bool {
    const name = std.mem.span(extension_name);
    if (std.mem.eql(u8, name, vk.extensions.khr_acceleration_structure.name)) return support.acceleration_structure;
    if (std.mem.eql(u8, name, vk.extensions.khr_ray_tracing_pipeline.name)) return support.ray_tracing_pipeline;
    if (std.mem.eql(u8, name, vk.extensions.khr_deferred_host_operations.name)) return support.deferred_host_operations;
    if (std.mem.eql(u8, name, vk.extensions.khr_buffer_device_address.name)) return support.buffer_device_address;
    if (std.mem.eql(u8, name, vk.extensions.khr_spirv_1_4.name)) return support.spirv_1_4;
    if (std.mem.eql(u8, name, vk.extensions.khr_shader_float_controls.name)) return support.shader_float_controls;
    return false;
}

fn missingRayTracingExtension(support: VulkanExtensionSupport) ?[*:0]const u8 {
    for (required_ray_tracing_device_extensions) |extension_name| {
        if (!rayTracingExtensionSupported(support, extension_name)) return extension_name;
    }
    return null;
}

fn getPhysicalDeviceFeatures2(instance: Instance, pdev: vk.PhysicalDevice, out_features: *vk.PhysicalDeviceFeatures2) bool {
    if (instance.wrapper.dispatch.vkGetPhysicalDeviceFeatures2) |get_features2| {
        get_features2(pdev, out_features);
        return true;
    }
    if (instance.wrapper.dispatch.vkGetPhysicalDeviceFeatures2KHR) |get_features2_khr| {
        get_features2_khr(pdev, out_features);
        return true;
    }
    return false;
}

fn getPhysicalDeviceProperties2(instance: Instance, pdev: vk.PhysicalDevice, properties: *vk.PhysicalDeviceProperties2) bool {
    if (instance.wrapper.dispatch.vkGetPhysicalDeviceProperties2) |get_properties2| {
        get_properties2(pdev, properties);
        return true;
    }
    if (instance.wrapper.dispatch.vkGetPhysicalDeviceProperties2KHR) |get_properties2_khr| {
        get_properties2_khr(pdev, properties);
        return true;
    }
    return false;
}

fn queryRayTracingCapabilityDiagnostics(
    instance: Instance,
    pdev: vk.PhysicalDevice,
    allocator: Allocator,
    device_dispatch: ?*const DeviceWrapper.Dispatch,
) !core.RayTracingCapabilityDiagnostics {
    const support = try queryExtensionSupport(instance, pdev, allocator);
    if (missingRayTracingExtension(support)) |missing| {
        return core.RayTracingCapabilityDiagnostics.unsupported(
            .vulkan,
            .missing_extension,
            std.mem.span(missing),
            "required for the Vulkan ray tracing runtime path",
        );
    }

    var buffer_device_address_features = vk.PhysicalDeviceBufferDeviceAddressFeatures{};
    var ray_tracing_pipeline_features = vk.PhysicalDeviceRayTracingPipelineFeaturesKHR{
        .p_next = &buffer_device_address_features,
    };
    var acceleration_structure_features = vk.PhysicalDeviceAccelerationStructureFeaturesKHR{
        .p_next = &ray_tracing_pipeline_features,
    };
    var features2 = vk.PhysicalDeviceFeatures2{
        .p_next = &acceleration_structure_features,
        .features = .{},
    };
    if (!getPhysicalDeviceFeatures2(instance, pdev, &features2)) {
        return core.RayTracingCapabilityDiagnostics.unsupported(
            .vulkan,
            .missing_device_proc,
            "vkGetPhysicalDeviceFeatures2",
            "required to query Vulkan ray tracing feature structs",
        );
    }

    if (acceleration_structure_features.acceleration_structure != .true) {
        return core.RayTracingCapabilityDiagnostics.unsupported(
            .vulkan,
            .missing_feature,
            "VkPhysicalDeviceAccelerationStructureFeaturesKHR.accelerationStructure",
            "device extension is present but the feature bit is disabled",
        );
    }
    if (ray_tracing_pipeline_features.ray_tracing_pipeline != .true) {
        return core.RayTracingCapabilityDiagnostics.unsupported(
            .vulkan,
            .missing_feature,
            "VkPhysicalDeviceRayTracingPipelineFeaturesKHR.rayTracingPipeline",
            "device extension is present but the feature bit is disabled",
        );
    }
    if (buffer_device_address_features.buffer_device_address != .true) {
        return core.RayTracingCapabilityDiagnostics.unsupported(
            .vulkan,
            .missing_feature,
            "VkPhysicalDeviceBufferDeviceAddressFeatures.bufferDeviceAddress",
            "ray tracing requires device addresses for geometry, AS, and SBT buffers",
        );
    }

    var ray_tracing_properties = std.mem.zeroes(vk.PhysicalDeviceRayTracingPipelinePropertiesKHR);
    ray_tracing_properties.s_type = .physical_device_ray_tracing_pipeline_properties_khr;
    var acceleration_structure_properties = std.mem.zeroes(vk.PhysicalDeviceAccelerationStructurePropertiesKHR);
    acceleration_structure_properties.s_type = .physical_device_acceleration_structure_properties_khr;
    acceleration_structure_properties.p_next = &ray_tracing_properties;
    var properties2 = vk.PhysicalDeviceProperties2{
        .p_next = &acceleration_structure_properties,
        .properties = undefined,
    };
    if (!getPhysicalDeviceProperties2(instance, pdev, &properties2)) {
        return core.RayTracingCapabilityDiagnostics.unsupported(
            .vulkan,
            .missing_device_proc,
            "vkGetPhysicalDeviceProperties2",
            "required to query Vulkan ray tracing limits",
        );
    }

    if (ray_tracing_properties.max_ray_recursion_depth == 0) {
        return core.RayTracingCapabilityDiagnostics.unsupported(
            .vulkan,
            .missing_limit,
            "VkPhysicalDeviceRayTracingPipelinePropertiesKHR.maxRayRecursionDepth",
            "must be non-zero for recursive ray tracing dispatch",
        );
    }
    if (ray_tracing_properties.shader_group_handle_size == 0) {
        return core.RayTracingCapabilityDiagnostics.unsupported(
            .vulkan,
            .missing_limit,
            "VkPhysicalDeviceRayTracingPipelinePropertiesKHR.shaderGroupHandleSize",
            "must be non-zero to materialize an SBT",
        );
    }
    if (ray_tracing_properties.shader_group_handle_alignment == 0 or ray_tracing_properties.shader_group_base_alignment == 0) {
        return core.RayTracingCapabilityDiagnostics.unsupported(
            .vulkan,
            .missing_limit,
            "VkPhysicalDeviceRayTracingPipelinePropertiesKHR.shaderGroup*Alignment",
            "must be non-zero to build valid SBT regions",
        );
    }
    if (acceleration_structure_properties.min_acceleration_structure_scratch_offset_alignment == 0) {
        return core.RayTracingCapabilityDiagnostics.unsupported(
            .vulkan,
            .missing_limit,
            "VkPhysicalDeviceAccelerationStructurePropertiesKHR.minAccelerationStructureScratchOffsetAlignment",
            "must be non-zero to build acceleration structures",
        );
    }

    if (device_dispatch) |dispatch| {
        if (dispatch.vkCreateAccelerationStructureKHR == null) return missingRayTracingDeviceProc("vkCreateAccelerationStructureKHR");
        if (dispatch.vkDestroyAccelerationStructureKHR == null) return missingRayTracingDeviceProc("vkDestroyAccelerationStructureKHR");
        if (dispatch.vkCmdBuildAccelerationStructuresKHR == null) return missingRayTracingDeviceProc("vkCmdBuildAccelerationStructuresKHR");
        if (dispatch.vkGetAccelerationStructureBuildSizesKHR == null) return missingRayTracingDeviceProc("vkGetAccelerationStructureBuildSizesKHR");
        if (dispatch.vkGetAccelerationStructureDeviceAddressKHR == null) return missingRayTracingDeviceProc("vkGetAccelerationStructureDeviceAddressKHR");
        if (dispatch.vkCreateRayTracingPipelinesKHR == null) return missingRayTracingDeviceProc("vkCreateRayTracingPipelinesKHR");
        if (dispatch.vkGetRayTracingShaderGroupHandlesKHR == null) return missingRayTracingDeviceProc("vkGetRayTracingShaderGroupHandlesKHR");
        if (dispatch.vkCmdTraceRaysKHR == null) return missingRayTracingDeviceProc("vkCmdTraceRaysKHR");
        if (dispatch.vkGetBufferDeviceAddressKHR == null and dispatch.vkGetBufferDeviceAddress == null) {
            return missingRayTracingDeviceProc("vkGetBufferDeviceAddressKHR");
        }
    }

    return core.RayTracingCapabilityDiagnostics.supportedVulkan(
        ray_tracing_properties.max_ray_recursion_depth,
        ray_tracing_properties.shader_group_handle_size,
        ray_tracing_properties.shader_group_handle_alignment,
        ray_tracing_properties.shader_group_base_alignment,
        acceleration_structure_properties.min_acceleration_structure_scratch_offset_alignment,
    );
}

fn missingRayTracingDeviceProc(proc_name: []const u8) core.RayTracingCapabilityDiagnostics {
    return core.RayTracingCapabilityDiagnostics.unsupported(
        .vulkan,
        .missing_device_proc,
        proc_name,
        "Vulkan loader or ICD did not expose a required Period32 ray tracing device command",
    );
}

fn vertexAttributeDivisorExtensionName(support: VulkanExtensionSupport) ?[*:0]const u8 {
    if (support.vertex_attribute_divisor_khr) return vk.extensions.khr_vertex_attribute_divisor.name;
    if (support.vertex_attribute_divisor_ext) return vk.extensions.ext_vertex_attribute_divisor.name;
    return null;
}

fn vertexAttributeDivisorFeatureSupported(
    instance: Instance,
    pdev: vk.PhysicalDevice,
    support: VulkanExtensionSupport,
) bool {
    if (vertexAttributeDivisorExtensionName(support) == null) return false;

    var divisor_features = vk.PhysicalDeviceVertexAttributeDivisorFeaturesEXT{};
    var features2 = vk.PhysicalDeviceFeatures2{
        .p_next = &divisor_features,
        .features = .{},
    };

    if (instance.wrapper.dispatch.vkGetPhysicalDeviceFeatures2) |get_features2| {
        get_features2(pdev, &features2);
    } else if (instance.wrapper.dispatch.vkGetPhysicalDeviceFeatures2KHR) |get_features2_khr| {
        get_features2_khr(pdev, &features2);
    } else {
        return false;
    }

    return divisor_features.vertex_attribute_instance_rate_divisor == .true;
}

fn formatCapabilitiesFromVulkanFeatures(format: core.TextureFormat, format_features: vk.FormatFeatureFlags) core.FormatCapabilities {
    const copy_source = format_features.transfer_src_bit;
    const copy_destination = format_features.transfer_dst_bit;
    return .{
        .sampled = format_features.sampled_image_bit,
        .storage = format_features.storage_image_bit,
        .color_attachment = format_features.color_attachment_bit,
        .depth_stencil_attachment = format_features.depth_stencil_attachment_bit,
        .filterable = format_features.sampled_image_bit,
        .linear_filter = format_features.sampled_image_filter_linear_bit,
        .mipmapped = format_features.blit_src_bit and format_features.blit_dst_bit,
        .mipmap_generation = format_features.blit_src_bit and format_features.blit_dst_bit,
        .blendable = format_features.color_attachment_blend_bit,
        .copy_source = copy_source,
        .copy_destination = copy_destination,
        .blit_source = format_features.blit_src_bit,
        .blit_destination = format_features.blit_dst_bit,
        .depth_copy = core.isDepthFormat(format) and copy_source and copy_destination,
        .stencil_copy = core.isStencilFormat(format) and copy_source and copy_destination,
        .color_resolve = core.isColorFormat(format) and format_features.color_attachment_bit,
    };
}

fn imageFormat(format: core.TextureFormat) vk.Format {
    return switch (format) {
        .automatic => unreachable,
        .r8_unorm => .r8_unorm,
        .rg8_unorm => .r8g8_unorm,
        .rgba8_uint => .r8g8b8a8_uint,
        .rgba8_sint => .r8g8b8a8_sint,
        .r16_float => .r16_sfloat,
        .rg16_float => .r16g16_sfloat,
        .rgba16_float => .r16g16b16a16_sfloat,
        .r32_float => .r32_sfloat,
        .rg32_float => .r32g32_sfloat,
        .rgba32_float => .r32g32b32a32_sfloat,
        .r32_uint => .r32_uint,
        .r32_sint => .r32_sint,
        .depth16_unorm => .d16_unorm,
        .stencil8 => .s8_uint,
        .bgra8_unorm => .b8g8r8a8_unorm,
        .bgra8_unorm_srgb => .b8g8r8a8_srgb,
        .rgba8_unorm => .r8g8b8a8_unorm,
        .rgba8_unorm_srgb => .r8g8b8a8_srgb,
        .depth32_float => .d32_sfloat,
        .depth32_float_stencil8 => .d32_sfloat_s8_uint,
    };
}

pub const Queue = struct {
    handle: vk.Queue,
    family: u32,

    fn init(device: Device, family: u32) Queue {
        return .{
            .handle = device.getDeviceQueue(family, 0),
            .family = family,
        };
    }
};

fn createSurface(instance: Instance, surface_provider: core.VulkanSurfaceProvider) !vk.SurfaceKHR {
    var surface_handle: usize = 0;
    const result: vk.Result = @enumFromInt(surface_provider.create_surface(
        surface_provider.context,
        @intFromEnum(instance.handle),
        null,
        &surface_handle,
    ));
    if (result != .success) return error.SurfaceInitFailed;
    return @enumFromInt(surface_handle);
}

fn initializeCandidate(instance: Instance, allocator: Allocator, candidate: DeviceCandidate) !vk.Device {
    const extensions = try queryExtensionSupport(instance, candidate.pdev, allocator);
    const enable_vertex_divisor = vertexAttributeDivisorFeatureSupported(instance, candidate.pdev, extensions);
    const ray_tracing_diagnostics = try queryRayTracingCapabilityDiagnostics(instance, candidate.pdev, allocator, null);
    const enable_ray_tracing = ray_tracing_diagnostics.supported;
    const enable_buffer_device_address = bufferDeviceAddressSupported(instance, candidate.pdev);
    const enable_host_query_reset = candidate.host_query_reset;

    var extension_names: std.ArrayList([*:0]const u8) = .empty;
    defer extension_names.deinit(allocator);
    try extension_names.appendSlice(allocator, &required_device_extensions);
    if (enable_ray_tracing) {
        try extension_names.appendSlice(allocator, &required_ray_tracing_device_extensions);
    } else if (enable_buffer_device_address and
        candidate.props.api_version < vk.API_VERSION_1_2.toU32() and
        extensions.buffer_device_address)
    {
        try extension_names.append(allocator, vk.extensions.khr_buffer_device_address.name);
    }
    if (enable_vertex_divisor) {
        if (vertexAttributeDivisorExtensionName(extensions)) |extension_name| {
            try extension_names.append(allocator, extension_name);
        }
    }

    const priority = [_]f32{1};
    const native_features = instance.getPhysicalDeviceFeatures(candidate.pdev);
    var enabled_features = vk.PhysicalDeviceFeatures{
        .sampler_anisotropy = native_features.sampler_anisotropy,
        .fill_mode_non_solid = native_features.fill_mode_non_solid,
        .depth_bias_clamp = native_features.depth_bias_clamp,
        .independent_blend = native_features.independent_blend,
    };
    var vertex_divisor_features = vk.PhysicalDeviceVertexAttributeDivisorFeaturesEXT{
        .vertex_attribute_instance_rate_divisor = if (enable_vertex_divisor) .true else .false,
    };
    var buffer_device_address_features = vk.PhysicalDeviceBufferDeviceAddressFeatures{
        .buffer_device_address = if (enable_buffer_device_address) .true else .false,
    };
    var ray_tracing_pipeline_features = vk.PhysicalDeviceRayTracingPipelineFeaturesKHR{
        .ray_tracing_pipeline = if (enable_ray_tracing) .true else .false,
    };
    var acceleration_structure_features = vk.PhysicalDeviceAccelerationStructureFeaturesKHR{
        .acceleration_structure = if (enable_ray_tracing) .true else .false,
    };
    var host_query_reset_features = vk.PhysicalDeviceHostQueryResetFeatures{
        .host_query_reset = if (enable_host_query_reset) .true else .false,
    };
    var device_p_next: ?*anyopaque = null;
    if (enable_host_query_reset) {
        host_query_reset_features.p_next = device_p_next;
        device_p_next = &host_query_reset_features;
    }
    if (enable_vertex_divisor) {
        vertex_divisor_features.p_next = device_p_next;
        device_p_next = &vertex_divisor_features;
    }
    if (enable_buffer_device_address) {
        buffer_device_address_features.p_next = device_p_next;
        device_p_next = &buffer_device_address_features;
    }
    if (enable_ray_tracing) {
        ray_tracing_pipeline_features.p_next = device_p_next;
        acceleration_structure_features.p_next = &ray_tracing_pipeline_features;
        device_p_next = &acceleration_structure_features;
    }
    const qci = [_]vk.DeviceQueueCreateInfo{
        .{
            .queue_family_index = candidate.queues.graphics_family,
            .queue_count = 1,
            .p_queue_priorities = &priority,
        },
        .{
            .queue_family_index = candidate.queues.present_family,
            .queue_count = 1,
            .p_queue_priorities = &priority,
        },
    };
    const queue_count: u32 = if (candidate.queues.graphics_family == candidate.queues.present_family) 1 else 2;

    return try instance.createDevice(candidate.pdev, &.{
        .p_next = device_p_next,
        .queue_create_info_count = queue_count,
        .p_queue_create_infos = &qci,
        .enabled_extension_count = @intCast(extension_names.items.len),
        .pp_enabled_extension_names = extension_names.items.ptr,
        .p_enabled_features = &enabled_features,
    }, null);
}

const DeviceCandidate = struct {
    pdev: vk.PhysicalDevice,
    props: vk.PhysicalDeviceProperties,
    queues: QueueAllocation,
    host_query_reset: bool,
};

const QueueAllocation = struct {
    graphics_family: u32,
    present_family: u32,
    graphics_timestamp_valid_bits: u32,
};

fn pickPhysicalDevice(instance: Instance, allocator: Allocator, surface: vk.SurfaceKHR) !DeviceCandidate {
    const pdevs = try instance.enumeratePhysicalDevicesAlloc(allocator);
    defer allocator.free(pdevs);

    for (pdevs) |pdev| {
        if (try checkSuitable(instance, pdev, allocator, surface)) |candidate| {
            return candidate;
        }
    }
    return error.NoSuitableDevice;
}

fn checkSuitable(instance: Instance, pdev: vk.PhysicalDevice, allocator: Allocator, surface: vk.SurfaceKHR) !?DeviceCandidate {
    if (!try checkExtensionSupport(instance, pdev, allocator)) return null;
    if (!try checkSurfaceSupport(instance, pdev, surface)) return null;

    if (try allocateQueues(instance, pdev, allocator, surface)) |allocation| {
        return .{
            .pdev = pdev,
            .props = instance.getPhysicalDeviceProperties(pdev),
            .queues = allocation,
            .host_query_reset = hostQueryResetSupported(instance, pdev),
        };
    }
    return null;
}

fn allocateQueues(instance: Instance, pdev: vk.PhysicalDevice, allocator: Allocator, surface: vk.SurfaceKHR) !?QueueAllocation {
    const families = try instance.getPhysicalDeviceQueueFamilyPropertiesAlloc(pdev, allocator);
    defer allocator.free(families);

    var graphics_family: ?u32 = null;
    var graphics_timestamp_valid_bits: u32 = 0;
    var present_family: ?u32 = null;

    for (families, 0..) |properties, i| {
        const family: u32 = @intCast(i);
        if (graphics_family == null and properties.queue_flags.graphics_bit) {
            graphics_family = family;
            graphics_timestamp_valid_bits = properties.timestamp_valid_bits;
        }
        if (present_family == null and (try instance.getPhysicalDeviceSurfaceSupportKHR(pdev, family, surface)) == .true) {
            present_family = family;
        }
    }

    if (graphics_family != null and present_family != null) {
        return .{
            .graphics_family = graphics_family.?,
            .present_family = present_family.?,
            .graphics_timestamp_valid_bits = graphics_timestamp_valid_bits,
        };
    }
    return null;
}

fn hostQueryResetSupported(instance: Instance, pdev: vk.PhysicalDevice) bool {
    var host_query_reset = vk.PhysicalDeviceHostQueryResetFeatures{};
    var features2 = vk.PhysicalDeviceFeatures2{
        .p_next = &host_query_reset,
        .features = .{},
    };
    return getPhysicalDeviceFeatures2(instance, pdev, &features2) and host_query_reset.host_query_reset == .true;
}

fn bufferDeviceAddressSupported(instance: Instance, pdev: vk.PhysicalDevice) bool {
    var buffer_device_address = vk.PhysicalDeviceBufferDeviceAddressFeatures{};
    var features2 = vk.PhysicalDeviceFeatures2{
        .p_next = &buffer_device_address,
        .features = .{},
    };
    return getPhysicalDeviceFeatures2(instance, pdev, &features2) and
        buffer_device_address.buffer_device_address == .true;
}

fn checkSurfaceSupport(instance: Instance, pdev: vk.PhysicalDevice, surface: vk.SurfaceKHR) !bool {
    var format_count: u32 = undefined;
    _ = try instance.getPhysicalDeviceSurfaceFormatsKHR(pdev, surface, &format_count, null);

    var present_mode_count: u32 = undefined;
    _ = try instance.getPhysicalDeviceSurfacePresentModesKHR(pdev, surface, &present_mode_count, null);

    return format_count > 0 and present_mode_count > 0;
}

fn checkExtensionSupport(instance: Instance, pdev: vk.PhysicalDevice, allocator: Allocator) !bool {
    const props = try instance.enumerateDeviceExtensionPropertiesAlloc(pdev, null, allocator);
    defer allocator.free(props);

    for (required_device_extensions) |required| {
        for (props) |prop| {
            if (std.mem.eql(u8, std.mem.span(required), std.mem.sliceTo(&prop.extension_name, 0))) {
                break;
            }
        } else {
            return false;
        }
    }
    return true;
}

fn checkLayerSupport(vkb: *const BaseWrapper, allocator: Allocator) !bool {
    const available_layers = try vkb.enumerateInstanceLayerPropertiesAlloc(allocator);
    defer allocator.free(available_layers);

    for (required_layer_names) |required| {
        for (available_layers) |layer| {
            if (std.mem.eql(u8, std.mem.span(required), std.mem.sliceTo(&layer.layer_name, 0))) {
                break;
            }
        } else {
            return false;
        }
    }
    return true;
}

fn loadBaseWrapper(surface_provider: core.VulkanSurfaceProvider) !BaseWrapper {
    var dispatch: BaseWrapper.Dispatch = .{};
    dispatch.vkCreateInstance = castProc(BaseWrapper.Dispatch, "vkCreateInstance", surface_provider.get_instance_proc_addr(
        surface_provider.context,
        0,
        "vkCreateInstance",
    ) orelse return error.VulkanUnavailable);
    dispatch.vkGetInstanceProcAddr = castProc(BaseWrapper.Dispatch, "vkGetInstanceProcAddr", surface_provider.get_instance_proc_addr(
        surface_provider.context,
        0,
        "vkGetInstanceProcAddr",
    ) orelse return error.VulkanUnavailable);
    dispatch.vkEnumerateInstanceLayerProperties = castProc(BaseWrapper.Dispatch, "vkEnumerateInstanceLayerProperties", surface_provider.get_instance_proc_addr(
        surface_provider.context,
        0,
        "vkEnumerateInstanceLayerProperties",
    ) orelse return error.VulkanUnavailable);
    if (surface_provider.get_instance_proc_addr(surface_provider.context, 0, "vkEnumerateInstanceVersion")) |proc| {
        dispatch.vkEnumerateInstanceVersion = castProc(BaseWrapper.Dispatch, "vkEnumerateInstanceVersion", proc);
    }
    if (surface_provider.get_instance_proc_addr(surface_provider.context, 0, "vkEnumerateInstanceExtensionProperties")) |proc| {
        dispatch.vkEnumerateInstanceExtensionProperties = castProc(BaseWrapper.Dispatch, "vkEnumerateInstanceExtensionProperties", proc);
    }
    return .{ .dispatch = dispatch };
}

fn castProc(comptime Dispatch: type, comptime field_name: []const u8, proc: *const anyopaque) @TypeOf(@field(@as(Dispatch, .{}), field_name)) {
    return @ptrCast(@alignCast(proc));
}

fn ensureBaseDispatchAvailable(vkb: BaseWrapper) !void {
    if (vkb.dispatch.vkCreateInstance == null) return error.VulkanUnavailable;
    if (vkb.dispatch.vkGetInstanceProcAddr == null) return error.VulkanUnavailable;
    if (vkb.dispatch.vkEnumerateInstanceLayerProperties == null) return error.VulkanUnavailable;
}

fn ensureInstanceDispatchAvailable(vki: InstanceWrapper) !void {
    if (vki.dispatch.vkDestroyInstance == null) return error.VulkanUnavailable;
    if (vki.dispatch.vkEnumeratePhysicalDevices == null) return error.VulkanUnavailable;
    if (vki.dispatch.vkGetDeviceProcAddr == null) return error.VulkanUnavailable;
}

fn ensureDeviceDispatchAvailable(vkd: DeviceWrapper) !void {
    if (vkd.dispatch.vkDestroyDevice == null) return error.VulkanUnavailable;
    if (vkd.dispatch.vkGetDeviceQueue == null) return error.VulkanUnavailable;
}

test "missing Vulkan base dispatch reports VulkanUnavailable" {
    try std.testing.expectError(error.VulkanUnavailable, ensureBaseDispatchAvailable(.{ .dispatch = .{} }));
}

test "Vulkan extension support maps optional backend capabilities" {
    var support = VulkanExtensionSupport{};
    support = mergeExtensionSupport(support, vk.extensions.ext_descriptor_indexing.name);
    support = mergeExtensionSupport(support, vk.extensions.khr_vertex_attribute_divisor.name);
    support = mergeExtensionSupport(support, vk.extensions.khr_external_memory.name);
    support = mergeExtensionSupport(support, vk.extensions.khr_external_semaphore.name);
    support = mergeExtensionSupport(support, vk.extensions.khr_acceleration_structure.name);
    support = mergeExtensionSupport(support, vk.extensions.khr_ray_tracing_pipeline.name);
    support = mergeExtensionSupport(support, vk.extensions.ext_mesh_shader.name);

    try std.testing.expect(support.descriptor_indexing);
    try std.testing.expect(support.vertex_attribute_divisor_khr);
    try std.testing.expectEqualStrings(
        vk.extensions.khr_vertex_attribute_divisor.name,
        std.mem.span(vertexAttributeDivisorExtensionName(support).?),
    );
    try std.testing.expect(support.external_memory);
    try std.testing.expect(support.external_semaphore);
    try std.testing.expect(support.acceleration_structure);
    try std.testing.expect(support.ray_tracing_pipeline);
    try std.testing.expect(support.mesh_shader);
}

test "Vulkan ray tracing extension gate reports the first missing KHR dependency" {
    var support = VulkanExtensionSupport{};
    support = mergeExtensionSupport(support, vk.extensions.khr_acceleration_structure.name);
    support = mergeExtensionSupport(support, vk.extensions.khr_ray_tracing_pipeline.name);
    support = mergeExtensionSupport(support, vk.extensions.khr_deferred_host_operations.name);
    support = mergeExtensionSupport(support, vk.extensions.khr_buffer_device_address.name);
    support = mergeExtensionSupport(support, vk.extensions.khr_spirv_1_4.name);

    try std.testing.expectEqualStrings(
        vk.extensions.khr_shader_float_controls.name,
        std.mem.span(missingRayTracingExtension(support).?),
    );

    support = mergeExtensionSupport(support, vk.extensions.khr_shader_float_controls.name);
    try std.testing.expect(missingRayTracingExtension(support) == null);
}

test "Vulkan usable features stay conservative before backend lowering" {
    const native = core.DeviceFeatures{
        .wireframe_fill_mode = true,
        .independent_blend = true,
        .vertex_instance_step_rate = true,
        .descriptor_indexing = true,
        .sparse_buffers = true,
        .external_textures = true,
        .tessellation = true,
        .mesh_shaders = true,
        .ray_tracing = true,
        .driver_pipeline_cache = true,
        .native_handles = true,
        .debug_labels = true,
        .occlusion_queries = true,
        .buffer_gpu_address = true,
        .compute_atomics = true,
        .compute_threadgroup_memory = true,
    };
    const usable = queryUsableFeatures(native, true);
    try std.testing.expect(!usable.descriptor_indexing);
    try std.testing.expect(usable.wireframe_fill_mode);
    try std.testing.expect(usable.independent_blend);
    try std.testing.expect(usable.vertex_instance_step_rate);
    try std.testing.expect(!usable.sparse_buffers);
    try std.testing.expect(!usable.external_textures);
    try std.testing.expect(!usable.tessellation);
    try std.testing.expect(!usable.mesh_shaders);
    try std.testing.expect(!usable.ray_tracing);
    try std.testing.expect(!usable.driver_pipeline_cache);
    try std.testing.expect(usable.occlusion_queries);
    try std.testing.expect(usable.buffer_gpu_address);
    try std.testing.expect(usable.compute_atomics);
    try std.testing.expect(usable.compute_threadgroup_memory);
    try std.testing.expect(!queryUsableFeatures(native, false).occlusion_queries);
    try std.testing.expect(native.occlusion_queries);
    try std.testing.expect(usable.native_handles);
    try std.testing.expect(usable.debug_labels);
}

test "Vulkan format feature mapping keeps copy and attachment caps separate" {
    const caps = formatCapabilitiesFromVulkanFeatures(.rgba8_unorm, .{
        .sampled_image_bit = true,
        .storage_image_bit = true,
        .color_attachment_bit = true,
        .color_attachment_blend_bit = true,
        .transfer_src_bit = true,
        .transfer_dst_bit = true,
    });
    try std.testing.expect(caps.sampled);
    try std.testing.expect(caps.storage);
    try std.testing.expect(caps.color_attachment);
    try std.testing.expect(caps.blendable);
    try std.testing.expect(caps.copy_source);
    try std.testing.expect(caps.copy_destination);
    try std.testing.expect(!caps.blit_source);
    try std.testing.expect(!caps.blit_destination);
    try std.testing.expect(caps.color_resolve);
    try std.testing.expect(!caps.depth_stencil_attachment);

    const blit_only = formatCapabilitiesFromVulkanFeatures(.rgba8_unorm, .{
        .blit_src_bit = true,
        .blit_dst_bit = true,
    });
    try std.testing.expect(!blit_only.copy_source);
    try std.testing.expect(!blit_only.copy_destination);
    try std.testing.expect(blit_only.blit_source);
    try std.testing.expect(blit_only.blit_destination);
}

test "Vulkan native debug labels reject invalid encoding and embedded NUL" {
    const invalid_utf8 = [_]u8{0xff};
    try std.testing.expect(validNativeDebugLabel("frame:main-pass"));
    try std.testing.expect(!validNativeDebugLabel(invalid_utf8[0..]));
    try std.testing.expect(!validNativeDebugLabel("frame\x00hidden"));
}

fn debugCallback(
    message_severity: vk.DebugUtilsMessageSeverityFlagsEXT,
    message_types: vk.DebugUtilsMessageTypeFlagsEXT,
    p_callback_data: ?*const vk.DebugUtilsMessengerCallbackDataEXT,
    p_user_data: ?*anyopaque,
) callconv(vk.vulkan_call_conv) vk.Bool32 {
    _ = message_severity;
    _ = message_types;
    _ = p_user_data;

    if (p_callback_data) |callback_data| {
        if (callback_data.p_message) |message| {
            std.log.scoped(.validation).warn("{s}", .{message});
        }
    }
    return .false;
}
