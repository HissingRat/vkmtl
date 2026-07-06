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
surface: vk.SurfaceKHR,
pdev: vk.PhysicalDevice,
props: vk.PhysicalDeviceProperties,
mem_props: vk.PhysicalDeviceMemoryProperties,
dev: Device,
graphics_queue: Queue,
present_queue: Queue,

pub fn init(allocator: Allocator, app_name: [*:0]const u8, surface_provider: core.VulkanSurfaceProvider) !GraphicsContext {
    var self: GraphicsContext = undefined;
    self.allocator = allocator;
    self.vkb = try loadBaseWrapper(surface_provider);
    try ensureBaseDispatchAvailable(self.vkb);
    self.debug_messenger = .null_handle;

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
    }

    self.surface = try createSurface(self.instance, surface_provider);
    errdefer self.instance.destroySurfaceKHR(self.surface, null);

    const candidate = try pickPhysicalDevice(self.instance, allocator, self.surface);
    self.pdev = candidate.pdev;
    self.props = candidate.props;

    const dev = try initializeCandidate(self.instance, candidate);

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

pub fn findMemoryTypeIndex(self: GraphicsContext, memory_type_bits: u32, flags: vk.MemoryPropertyFlags) !u32 {
    for (self.mem_props.memory_types[0..self.mem_props.memory_type_count], 0..) |mem_type, i| {
        if (memory_type_bits & (@as(u32, 1) << @truncate(i)) != 0 and mem_type.property_flags.contains(flags)) {
            return @truncate(i);
        }
    }
    return error.NoSuitableMemoryType;
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

fn initializeCandidate(instance: Instance, candidate: DeviceCandidate) !vk.Device {
    const priority = [_]f32{1};
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
        .queue_create_info_count = queue_count,
        .p_queue_create_infos = &qci,
        .enabled_extension_count = required_device_extensions.len,
        .pp_enabled_extension_names = @ptrCast(&required_device_extensions),
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
