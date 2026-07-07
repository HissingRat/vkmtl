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
    self.mem_props = self.instance.getPhysicalDeviceMemoryProperties(self.pdev);
    self.native_features_value = try queryNativeFeatures(self.instance, self.pdev, allocator);
    self.native_features_value.debug_labels = self.debug_utils_enabled;
    self.native_features_value.debug_markers = self.debug_utils_enabled;
    self.features_value = queryUsableFeatures(self.native_features_value);
    self.limits_value = queryLimits(self.props, self.features_value);
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

pub fn formatCapabilities(self: GraphicsContext, format: core.TextureFormat) core.FormatCapabilities {
    if (format == .automatic) return .{};
    const props = self.instance.getPhysicalDeviceFormatProperties(self.pdev, imageFormat(format));
    return formatCapabilitiesFromVulkanFeatures(props.optimal_tiling_features);
}

pub fn setDebugName(self: GraphicsContext, object_type: vk.ObjectType, object_handle: u64, label_value: ?[]const u8) void {
    if (!self.debug_utils_enabled) return;
    if (self.dev.wrapper.dispatch.vkSetDebugUtilsObjectNameEXT == null) return;

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

fn queryNativeFeatures(instance: Instance, pdev: vk.PhysicalDevice, allocator: Allocator) !core.DeviceFeatures {
    var result = core.defaultDeviceFeatures(.vulkan);
    const native = instance.getPhysicalDeviceFeatures(pdev);
    const extensions = try queryExtensionSupport(instance, pdev, allocator);

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
    result.acceleration_structures = extensions.acceleration_structure or extensions.ray_tracing_nv;
    result.ray_tracing = (extensions.acceleration_structure and extensions.ray_tracing_pipeline) or extensions.ray_tracing_nv;
    result.driver_pipeline_cache = true;
    return result;
}

fn queryUsableFeatures(native_features: core.DeviceFeatures) core.DeviceFeatures {
    var result = core.defaultDeviceFeatures(.vulkan);

    result.sampler_anisotropy = native_features.sampler_anisotropy;
    result.independent_blend = false;
    result.tessellation = false;
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

    result.native_handles = native_features.native_handles;
    result.debug_labels = native_features.debug_labels;
    result.debug_markers = native_features.debug_markers;
    return result;
}

fn queryLimits(props: vk.PhysicalDeviceProperties, queried_features: core.DeviceFeatures) core.DeviceLimits {
    _ = queried_features;
    var result = core.defaultDeviceLimits(.vulkan);
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
    if (std.mem.eql(u8, extension_name, vk.extensions.ext_mesh_shader.name) or
        std.mem.eql(u8, extension_name, vk.extensions.nv_mesh_shader.name))
    {
        result.mesh_shader = true;
    }
    return result;
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

fn formatCapabilitiesFromVulkanFeatures(format_features: vk.FormatFeatureFlags) core.FormatCapabilities {
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
        .copy_source = format_features.transfer_src_bit or format_features.blit_src_bit,
        .copy_destination = format_features.transfer_dst_bit or format_features.blit_dst_bit,
    };
}

fn imageFormat(format: core.TextureFormat) vk.Format {
    return switch (format) {
        .automatic => unreachable,
        .bgra8_unorm => .b8g8r8a8_unorm,
        .bgra8_unorm_srgb => .b8g8r8a8_srgb,
        .rgba8_unorm => .r8g8b8a8_unorm,
        .rgba8_unorm_srgb => .r8g8b8a8_srgb,
        .depth32_float => .d32_sfloat,
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

    var extension_names: std.ArrayList([*:0]const u8) = .empty;
    defer extension_names.deinit(allocator);
    try extension_names.appendSlice(allocator, &required_device_extensions);
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
    };
    var vertex_divisor_features = vk.PhysicalDeviceVertexAttributeDivisorFeaturesEXT{
        .vertex_attribute_instance_rate_divisor = if (enable_vertex_divisor) .true else .false,
    };
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
        .p_next = if (enable_vertex_divisor) &vertex_divisor_features else null,
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
};

const QueueAllocation = struct {
    graphics_family: u32,
    present_family: u32,
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
        };
    }
    return null;
}

fn allocateQueues(instance: Instance, pdev: vk.PhysicalDevice, allocator: Allocator, surface: vk.SurfaceKHR) !?QueueAllocation {
    const families = try instance.getPhysicalDeviceQueueFamilyPropertiesAlloc(pdev, allocator);
    defer allocator.free(families);

    var graphics_family: ?u32 = null;
    var present_family: ?u32 = null;

    for (families, 0..) |properties, i| {
        const family: u32 = @intCast(i);
        if (graphics_family == null and properties.queue_flags.graphics_bit) {
            graphics_family = family;
        }
        if (present_family == null and (try instance.getPhysicalDeviceSurfaceSupportKHR(pdev, family, surface)) == .true) {
            present_family = family;
        }
    }

    if (graphics_family != null and present_family != null) {
        return .{
            .graphics_family = graphics_family.?,
            .present_family = present_family.?,
        };
    }
    return null;
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

test "Vulkan usable features stay conservative before backend lowering" {
    const native = core.DeviceFeatures{
        .wireframe_fill_mode = true,
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
    };
    const usable = queryUsableFeatures(native);
    try std.testing.expect(!usable.descriptor_indexing);
    try std.testing.expect(usable.wireframe_fill_mode);
    try std.testing.expect(usable.vertex_instance_step_rate);
    try std.testing.expect(!usable.sparse_buffers);
    try std.testing.expect(!usable.external_textures);
    try std.testing.expect(!usable.tessellation);
    try std.testing.expect(!usable.mesh_shaders);
    try std.testing.expect(!usable.ray_tracing);
    try std.testing.expect(!usable.driver_pipeline_cache);
    try std.testing.expect(usable.native_handles);
    try std.testing.expect(usable.debug_labels);
}

test "Vulkan format feature mapping keeps copy and attachment caps separate" {
    const caps = formatCapabilitiesFromVulkanFeatures(.{
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
    try std.testing.expect(!caps.depth_stencil_attachment);
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
