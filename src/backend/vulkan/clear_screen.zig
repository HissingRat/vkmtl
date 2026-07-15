const std = @import("std");
const vk = @import("vulkan");
const core = @import("../../core.zig");
const VulkanBuffer = @import("buffer.zig");
const VulkanHeap = @import("heap.zig");
const VulkanAccelerationStructure = @import("acceleration_structure.zig");
const VulkanCommand = @import("command.zig");
const VulkanComputePipelineState = @import("compute_pipeline.zig");
const VulkanRayTracingPipelineState = @import("ray_tracing_pipeline.zig");
const VulkanRenderPipelineState = @import("render_pipeline.zig");
const VulkanQuerySet = @import("query_set.zig");
const VulkanSamplerState = @import("sampler.zig");
const VulkanShaderModule = @import("shader_module.zig");
const VulkanTexture = @import("texture.zig");
const VulkanSync = @import("sync.zig");
const GraphicsContext = @import("graphics_context.zig");
const Swapchain = @import("swapchain.zig");

const VulkanClearScreen = @This();

allocator: std.mem.Allocator,
gc: *GraphicsContext,
swapchain: ?Swapchain,
color_render_pass: vk.RenderPass,
depth_render_pass: vk.RenderPass,
color_framebuffers: []vk.Framebuffer,
depth_framebuffers: []vk.Framebuffer,
depth_resources: ?DepthResources,
clear_pool: vk.CommandPool,
pool: vk.CommandPool,
compute_pool: vk.CommandPool,
transfer_pool: vk.CommandPool,
cmdbufs: []vk.CommandBuffer,
clear_color: core.ClearColorLike,
presentation_lifecycle: PresentationLifecycle = .{},
active_command_buffer_count: usize = 0,

const PresentationLifecycle = struct {
    lost: bool = false,
    generation: u64 = 1,

    fn ensureAvailable(self: PresentationLifecycle) core.SurfaceError!void {
        if (self.lost) return core.SurfaceError.SurfaceLost;
    }

    fn recordSuccessfulResize(self: *PresentationLifecycle) void {
        self.generation +%= 1;
    }

    fn poison(self: *PresentationLifecycle) void {
        if (self.lost) return;
        self.lost = true;
        self.generation +%= 1;
    }
};

pub const AdapterInfoResult = struct {
    info: core.AdapterInfo,
    owned_name: ?[]u8 = null,
};

pub fn init(
    allocator: std.mem.Allocator,
    app_name: [*:0]const u8,
    surface: core.SurfaceDescriptor,
    presentation: core.PresentationDescriptor,
) !VulkanClearScreen {
    const source = surface.source orelse return core.SurfaceError.MissingSurfaceSource;
    const surface_provider = source.vulkan orelse return error.UnsupportedSurfaceProvider;
    const extent = vkExtent(presentation.extent);
    if (extent.width == 0 or extent.height == 0) return core.SurfaceError.InvalidSurfaceExtent;

    const gc = try allocator.create(GraphicsContext);
    errdefer allocator.destroy(gc);
    gc.* = try GraphicsContext.init(allocator, app_name, surface_provider);
    errdefer gc.deinit();

    var swapchain = try Swapchain.init(gc, allocator, extent, presentation.format);
    errdefer swapchain.deinit();

    const color_render_pass = try createColorRenderPass(gc, swapchain);
    errdefer gc.dev.destroyRenderPass(color_render_pass, null);

    const depth_render_pass = try createDepthRenderPass(gc, swapchain);
    errdefer gc.dev.destroyRenderPass(depth_render_pass, null);

    var depth_resources = try DepthResources.init(gc, swapchain.extent);
    errdefer depth_resources.deinit(gc);

    const color_framebuffers = try createColorFramebuffers(gc, allocator, color_render_pass, swapchain);
    errdefer destroyFramebuffers(gc, allocator, color_framebuffers);

    const depth_framebuffers = try createDepthFramebuffers(gc, allocator, depth_render_pass, swapchain, depth_resources.view);
    errdefer destroyFramebuffers(gc, allocator, depth_framebuffers);

    const clear_pool = try gc.dev.createCommandPool(&.{
        .queue_family_index = gc.graphics_queue.family,
    }, null);
    errdefer gc.dev.destroyCommandPool(clear_pool, null);
    const pool = try gc.dev.createCommandPool(&.{
        .queue_family_index = gc.graphics_queue.family,
    }, null);
    errdefer gc.dev.destroyCommandPool(pool, null);
    const compute_pool = try gc.dev.createCommandPool(&.{
        .queue_family_index = gc.compute_queue.family,
    }, null);
    errdefer gc.dev.destroyCommandPool(compute_pool, null);
    const transfer_pool = try gc.dev.createCommandPool(&.{
        .queue_family_index = gc.transfer_queue.family,
    }, null);
    errdefer gc.dev.destroyCommandPool(transfer_pool, null);

    var self = VulkanClearScreen{
        .allocator = allocator,
        .gc = gc,
        .swapchain = swapchain,
        .color_render_pass = color_render_pass,
        .depth_render_pass = depth_render_pass,
        .color_framebuffers = color_framebuffers,
        .depth_framebuffers = depth_framebuffers,
        .depth_resources = depth_resources,
        .clear_pool = clear_pool,
        .pool = pool,
        .compute_pool = compute_pool,
        .transfer_pool = transfer_pool,
        .cmdbufs = &.{},
        .clear_color = .{},
    };

    self.cmdbufs = try self.createCommandBuffers();
    return self;
}

pub fn initHeadless(
    allocator: std.mem.Allocator,
    app_name: [*:0]const u8,
) !VulkanClearScreen {
    const gc = try allocator.create(GraphicsContext);
    errdefer allocator.destroy(gc);
    gc.* = try GraphicsContext.initHeadless(allocator, app_name);
    errdefer gc.deinit();

    const pool = try gc.dev.createCommandPool(&.{
        .queue_family_index = gc.graphics_queue.family,
    }, null);
    errdefer gc.dev.destroyCommandPool(pool, null);
    const compute_pool = try gc.dev.createCommandPool(&.{
        .queue_family_index = gc.compute_queue.family,
    }, null);
    errdefer gc.dev.destroyCommandPool(compute_pool, null);
    const transfer_pool = try gc.dev.createCommandPool(&.{
        .queue_family_index = gc.transfer_queue.family,
    }, null);
    errdefer gc.dev.destroyCommandPool(transfer_pool, null);

    return .{
        .allocator = allocator,
        .gc = gc,
        .swapchain = null,
        .color_render_pass = .null_handle,
        .depth_render_pass = .null_handle,
        .color_framebuffers = &.{},
        .depth_framebuffers = &.{},
        .depth_resources = null,
        .clear_pool = .null_handle,
        .pool = pool,
        .compute_pool = compute_pool,
        .transfer_pool = transfer_pool,
        .cmdbufs = &.{},
        .clear_color = .{},
    };
}

pub fn adapterInfo(self: *const VulkanClearScreen) AdapterInfoResult {
    return .{ .info = self.gc.adapterInfo() };
}

pub fn deviceTopology(self: *const VulkanClearScreen) core.DeviceTopologyReport {
    return self.gc.deviceTopology();
}

pub fn limits(self: *const VulkanClearScreen) core.DeviceLimits {
    return self.gc.limits();
}

pub fn features(self: *const VulkanClearScreen) core.DeviceFeatures {
    return self.gc.features();
}

pub fn nativeFeatures(self: *const VulkanClearScreen) core.DeviceFeatures {
    return self.gc.nativeFeatures();
}

pub fn rayTracingDiagnostics(self: *const VulkanClearScreen) core.RayTracingCapabilityDiagnostics {
    return self.gc.rayTracingDiagnostics();
}

pub fn formatCapabilities(self: *const VulkanClearScreen, format: core.TextureFormat) core.FormatCapabilities {
    var capabilities = self.gc.formatCapabilities(format);
    capabilities.presentation = if (self.swapchain) |swapchain|
        format == swapchain.selectedPresentationFormat()
    else
        false;
    return capabilities;
}

pub fn selectedPresentationFormat(self: *const VulkanClearScreen) ?core.TextureFormat {
    return if (self.swapchain) |swapchain| swapchain.selectedPresentationFormat() else null;
}

pub fn presentationExtent(self: *const VulkanClearScreen) ?core.Extent2D {
    if (self.presentation_lifecycle.lost) return null;
    const swapchain = self.swapchain orelse return null;
    return .{
        .width = swapchain.extent.width,
        .height = swapchain.extent.height,
    };
}

pub fn nativeHandles(self: *const VulkanClearScreen) core.NativeHandles {
    return .{
        .vulkan = .{
            .instance = @intFromEnum(self.gc.instance.handle),
            .physical_device = @intFromEnum(self.gc.pdev),
            .device = @intFromEnum(self.gc.dev.handle),
            .surface = @intFromEnum(self.gc.surface),
            .graphics_queue = @intFromEnum(self.gc.graphics_queue.handle),
            .present_queue = @intFromEnum(self.gc.present_queue.handle),
        },
    };
}

pub fn deinit(self: *VulkanClearScreen) void {
    self.destroyPresentationResources();
    if (self.clear_pool != .null_handle) {
        self.gc.dev.destroyCommandPool(self.clear_pool, null);
        self.clear_pool = .null_handle;
    }
    self.gc.dev.destroyCommandPool(self.pool, null);
    self.gc.dev.destroyCommandPool(self.compute_pool, null);
    self.gc.dev.destroyCommandPool(self.transfer_pool, null);
    self.gc.deinit();
    self.allocator.destroy(self.gc);
}

fn destroyResizeDependents(self: *VulkanClearScreen) void {
    if (self.cmdbufs.len != 0) {
        self.gc.dev.freeCommandBuffers(self.clear_pool, self.cmdbufs);
        self.allocator.free(self.cmdbufs);
        self.cmdbufs = &.{};
    }
    if (self.depth_framebuffers.len != 0) {
        destroyFramebuffers(self.gc, self.allocator, self.depth_framebuffers);
        self.depth_framebuffers = &.{};
    }
    if (self.color_framebuffers.len != 0) {
        destroyFramebuffers(self.gc, self.allocator, self.color_framebuffers);
        self.color_framebuffers = &.{};
    }
    if (self.depth_resources) |*depth_resources| depth_resources.deinit(self.gc);
    self.depth_resources = null;
}

fn destroyPresentationResources(self: *VulkanClearScreen) void {
    if (self.swapchain) |*swapchain| swapchain.waitForAllFences() catch {};
    self.destroyResizeDependents();
    if (self.depth_render_pass != .null_handle) {
        self.gc.dev.destroyRenderPass(self.depth_render_pass, null);
        self.depth_render_pass = .null_handle;
    }
    if (self.color_render_pass != .null_handle) {
        self.gc.dev.destroyRenderPass(self.color_render_pass, null);
        self.color_render_pass = .null_handle;
    }
    if (self.swapchain) |*swapchain| swapchain.deinit();
    self.swapchain = null;
}

fn poisonPresentation(self: *VulkanClearScreen) void {
    self.presentation_lifecycle.poison();
    self.destroyPresentationResources();
}

fn ensureNoActiveCommandBuffers(active_count: usize) core.CommandEncodingError!void {
    if (active_count != 0) return core.CommandEncodingError.InvalidCommandBufferState;
}

pub fn resize(self: *VulkanClearScreen, extent: core.Extent2D) !void {
    try self.presentation_lifecycle.ensureAvailable();
    if (extent.isZero()) return;
    try ensureNoActiveCommandBuffers(self.active_command_buffer_count);
    const swapchain = if (self.swapchain) |*value| value else return error.UnsupportedBackendForPresentation;
    const requested_extent = vkExtent(extent);
    if (!try swapchain.recreationNeeded(requested_extent)) {
        swapchain.recordRequestedExtent(requested_extent);
        return;
    }

    self.resizePresentation(extent) catch |err| {
        self.poisonPresentation();
        return err;
    };
    self.presentation_lifecycle.recordSuccessfulResize();
}

fn resizePresentation(self: *VulkanClearScreen, extent: core.Extent2D) !void {
    const swapchain = if (self.swapchain) |*value| value else return error.UnsupportedBackendForPresentation;

    try swapchain.waitForAllFences();
    self.destroyResizeDependents();

    const previous_format = swapchain.selectedPresentationFormat();
    try swapchain.recreate(vkExtent(extent));
    if (presentationRenderPassNeedsRebuild(previous_format, swapchain.selectedPresentationFormat())) {
        self.gc.dev.destroyRenderPass(self.depth_render_pass, null);
        self.depth_render_pass = .null_handle;
        self.gc.dev.destroyRenderPass(self.color_render_pass, null);
        self.color_render_pass = .null_handle;

        self.color_render_pass = try createColorRenderPass(self.gc, swapchain.*);
        self.depth_render_pass = try createDepthRenderPass(self.gc, swapchain.*);
    }

    self.depth_resources = try DepthResources.init(self.gc, swapchain.extent);
    self.color_framebuffers = try createColorFramebuffers(self.gc, self.allocator, self.color_render_pass, swapchain.*);
    self.depth_framebuffers = try createDepthFramebuffers(
        self.gc,
        self.allocator,
        self.depth_render_pass,
        swapchain.*,
        self.depth_resources.?.view,
    );

    self.cmdbufs = try self.createCommandBuffers();
}

fn presentationRenderPassNeedsRebuild(
    previous: core.TextureFormat,
    selected: core.TextureFormat,
) bool {
    return previous != selected;
}

pub fn clear(self: *VulkanClearScreen, color: core.ClearColorLike) !void {
    try self.presentation_lifecycle.ensureAvailable();
    try ensureNoActiveCommandBuffers(self.active_command_buffer_count);
    const swapchain = if (self.swapchain) |*value| value else return error.UnsupportedBackendForPresentation;
    self.clear_color = color;
    try self.recordCommandBuffers();

    const cmdbuf = self.cmdbufs[swapchain.image_index];
    _ = try swapchain.present(cmdbuf, &.{}, &.{});
}

pub fn makeBuffer(self: *VulkanClearScreen, descriptor: core.BufferDescriptor) !VulkanBuffer {
    return try VulkanBuffer.init(self.gc, descriptor);
}

pub fn makeHeap(self: *VulkanClearScreen, descriptor: core.HeapDescriptor) !VulkanHeap {
    return try VulkanHeap.init(self.gc, descriptor);
}

pub fn makeAccelerationStructure(self: *VulkanClearScreen, descriptor: core.AccelerationStructureDescriptor) core.AdvancedFeatureError!VulkanAccelerationStructure {
    return try VulkanAccelerationStructure.init(self.gc, descriptor);
}

pub fn accelerationStructureBuildSizes(
    self: *VulkanClearScreen,
    descriptor: core.AccelerationStructureDescriptor,
    flags: core.AccelerationStructureBuildFlags,
) core.AdvancedFeatureError!core.AccelerationStructureBuildSizes {
    return VulkanAccelerationStructure.queryBuildSizes(self.gc, descriptor, flags) catch {
        return core.AdvancedFeatureError.UnsupportedAccelerationStructures;
    };
}

pub fn makeShaderModule(self: *VulkanClearScreen, descriptor: core.ShaderModuleDescriptor) !VulkanShaderModule {
    return try VulkanShaderModule.init(self.gc, self.allocator, descriptor);
}

pub fn makeRenderPipelineState(self: *VulkanClearScreen, descriptor: core.RenderPipelineDescriptor) !VulkanRenderPipelineState {
    return try VulkanRenderPipelineState.init(self.gc, self.allocator, descriptor);
}

pub fn makeTessellationRenderPipelineState(
    self: *VulkanClearScreen,
    descriptor: core.TessellationRenderPipelineDescriptor,
) !VulkanRenderPipelineState {
    return VulkanRenderPipelineState.initTessellation(self.gc, self.allocator, descriptor);
}

pub fn makeMeshRenderPipelineState(
    self: *VulkanClearScreen,
    descriptor: core.MeshRenderPipelineDescriptor,
) !VulkanRenderPipelineState {
    return VulkanRenderPipelineState.initMesh(self.gc, self.allocator, descriptor);
}

pub fn makeComputePipelineState(self: *VulkanClearScreen, descriptor: core.ComputePipelineDescriptor) !VulkanComputePipelineState {
    return try VulkanComputePipelineState.init(self.gc, self.allocator, descriptor);
}

pub fn makeQuerySet(self: *VulkanClearScreen, descriptor: core.QuerySetDescriptor) !?VulkanQuerySet {
    if (descriptor.query_type == .timestamp and !self.gc.supportsNativeTimestampQueries()) return null;
    return try VulkanQuerySet.init(self.gc, descriptor);
}

pub fn supportsNativeTimestampQueries(self: *const VulkanClearScreen) bool {
    return self.gc.supportsNativeTimestampQueries();
}

pub fn makeRayTracingPipelineState(self: *VulkanClearScreen, descriptor: core.RayTracingPipelineDescriptor) !VulkanRayTracingPipelineState {
    return try VulkanRayTracingPipelineState.init(self.gc, self.allocator, descriptor);
}

pub fn makeCommandBuffer(self: *VulkanClearScreen, queue_kind: core.QueueKind) !VulkanCommand.CommandBuffer {
    try self.presentation_lifecycle.ensureAvailable();
    const pool = switch (queue_kind) {
        .graphics => self.pool,
        .compute => self.compute_pool,
        .transfer => self.transfer_pool,
    };
    const swapchain = if (self.swapchain) |*value| value else null;
    return try VulkanCommand.CommandBuffer.init(
        self.gc,
        pool,
        queue_kind,
        swapchain,
        self.color_render_pass,
        self.depth_render_pass,
        self.color_framebuffers,
        self.depth_framebuffers,
        &self.presentation_lifecycle.generation,
        &self.active_command_buffer_count,
    );
}

pub fn makeTimelineSemaphore(self: *VulkanClearScreen, initial_value: u64) !VulkanSync.TimelineSemaphore {
    return try VulkanSync.TimelineSemaphore.init(self.gc, initial_value);
}

pub fn makeTexture(self: *VulkanClearScreen, descriptor: core.TextureDescriptor) !VulkanTexture {
    return try VulkanTexture.init(self.gc, descriptor);
}

pub fn makeSamplerState(self: *VulkanClearScreen, descriptor: core.SamplerDescriptor) !VulkanSamplerState {
    return try VulkanSamplerState.init(self.gc, descriptor);
}

fn createCommandBuffers(self: *VulkanClearScreen) ![]vk.CommandBuffer {
    std.debug.assert(self.clear_pool != .null_handle);
    const cmdbufs = try self.allocator.alloc(vk.CommandBuffer, self.color_framebuffers.len);
    errdefer self.allocator.free(cmdbufs);

    try self.gc.dev.allocateCommandBuffers(&.{
        .command_pool = self.clear_pool,
        .level = .primary,
        .command_buffer_count = @intCast(cmdbufs.len),
    }, cmdbufs.ptr);
    errdefer self.gc.dev.freeCommandBuffers(self.clear_pool, cmdbufs);

    return cmdbufs;
}

fn recordCommandBuffers(self: *VulkanClearScreen) !void {
    const swapchain = if (self.swapchain) |*value| value else return error.UnsupportedBackendForPresentation;
    try swapchain.waitForAllFences();
    try self.gc.dev.resetCommandPool(self.clear_pool, .{});

    const clear_value = vk.ClearValue{
        .color = .{ .float_32 = .{
            self.clear_color.red,
            self.clear_color.green,
            self.clear_color.blue,
            self.clear_color.alpha,
        } },
    };

    for (self.cmdbufs, self.color_framebuffers) |cmdbuf, framebuffer| {
        try self.gc.dev.beginCommandBuffer(cmdbuf, &.{});

        self.gc.dev.cmdBeginRenderPass(cmdbuf, &.{
            .render_pass = self.color_render_pass,
            .framebuffer = framebuffer,
            .render_area = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = swapchain.extent,
            },
            .clear_value_count = 1,
            .p_clear_values = @ptrCast(&clear_value),
        }, .@"inline");

        self.gc.dev.cmdEndRenderPass(cmdbuf);
        try self.gc.dev.endCommandBuffer(cmdbuf);
    }
}

fn createColorRenderPass(gc: *const GraphicsContext, swapchain: Swapchain) !vk.RenderPass {
    const color_attachment = vk.AttachmentDescription{
        .format = swapchain.surface_format.format,
        .samples = .{ .@"1_bit" = true },
        .load_op = .clear,
        .store_op = .store,
        .stencil_load_op = .dont_care,
        .stencil_store_op = .dont_care,
        .initial_layout = .undefined,
        .final_layout = .present_src_khr,
    };

    const color_attachment_ref = vk.AttachmentReference{
        .attachment = 0,
        .layout = .color_attachment_optimal,
    };

    const subpass = vk.SubpassDescription{
        .pipeline_bind_point = .graphics,
        .color_attachment_count = 1,
        .p_color_attachments = @ptrCast(&color_attachment_ref),
    };

    return try gc.dev.createRenderPass(&.{
        .attachment_count = 1,
        .p_attachments = @ptrCast(&color_attachment),
        .subpass_count = 1,
        .p_subpasses = @ptrCast(&subpass),
    }, null);
}

fn createDepthRenderPass(gc: *const GraphicsContext, swapchain: Swapchain) !vk.RenderPass {
    const attachments = [_]vk.AttachmentDescription{
        .{
            .format = swapchain.surface_format.format,
            .samples = .{ .@"1_bit" = true },
            .load_op = .clear,
            .store_op = .store,
            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,
            .initial_layout = .undefined,
            .final_layout = .present_src_khr,
        },
        .{
            .format = depth_format,
            .samples = .{ .@"1_bit" = true },
            .load_op = .clear,
            .store_op = .dont_care,
            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,
            .initial_layout = .undefined,
            .final_layout = .depth_stencil_attachment_optimal,
        },
    };

    const color_attachment_ref = vk.AttachmentReference{
        .attachment = 0,
        .layout = .color_attachment_optimal,
    };
    const depth_attachment_ref = vk.AttachmentReference{
        .attachment = 1,
        .layout = .depth_stencil_attachment_optimal,
    };

    const subpass = vk.SubpassDescription{
        .pipeline_bind_point = .graphics,
        .color_attachment_count = 1,
        .p_color_attachments = @ptrCast(&color_attachment_ref),
        .p_depth_stencil_attachment = &depth_attachment_ref,
    };

    return try gc.dev.createRenderPass(&.{
        .attachment_count = attachments.len,
        .p_attachments = &attachments,
        .subpass_count = 1,
        .p_subpasses = @ptrCast(&subpass),
    }, null);
}

fn createColorFramebuffers(gc: *const GraphicsContext, allocator: std.mem.Allocator, render_pass: vk.RenderPass, swapchain: Swapchain) ![]vk.Framebuffer {
    const framebuffers = try allocator.alloc(vk.Framebuffer, swapchain.swap_images.len);
    errdefer allocator.free(framebuffers);

    var i: usize = 0;
    errdefer for (framebuffers[0..i]) |fb| gc.dev.destroyFramebuffer(fb, null);

    for (framebuffers) |*fb| {
        fb.* = try gc.dev.createFramebuffer(&.{
            .render_pass = render_pass,
            .attachment_count = 1,
            .p_attachments = @ptrCast(&swapchain.swap_images[i].view),
            .width = swapchain.extent.width,
            .height = swapchain.extent.height,
            .layers = 1,
        }, null);
        i += 1;
    }

    return framebuffers;
}

fn createDepthFramebuffers(
    gc: *const GraphicsContext,
    allocator: std.mem.Allocator,
    render_pass: vk.RenderPass,
    swapchain: Swapchain,
    depth_view: vk.ImageView,
) ![]vk.Framebuffer {
    const framebuffers = try allocator.alloc(vk.Framebuffer, swapchain.swap_images.len);
    errdefer allocator.free(framebuffers);

    var i: usize = 0;
    errdefer for (framebuffers[0..i]) |fb| gc.dev.destroyFramebuffer(fb, null);

    for (framebuffers) |*fb| {
        const attachments = [_]vk.ImageView{
            swapchain.swap_images[i].view,
            depth_view,
        };
        fb.* = try gc.dev.createFramebuffer(&.{
            .render_pass = render_pass,
            .attachment_count = attachments.len,
            .p_attachments = &attachments,
            .width = swapchain.extent.width,
            .height = swapchain.extent.height,
            .layers = 1,
        }, null);
        i += 1;
    }

    return framebuffers;
}

fn destroyFramebuffers(gc: *const GraphicsContext, allocator: std.mem.Allocator, framebuffers: []const vk.Framebuffer) void {
    for (framebuffers) |fb| gc.dev.destroyFramebuffer(fb, null);
    allocator.free(framebuffers);
}

const depth_format = vk.Format.d32_sfloat;

const DepthResources = struct {
    image: vk.Image,
    memory: vk.DeviceMemory,
    view: vk.ImageView,

    fn init(gc: *const GraphicsContext, extent: vk.Extent2D) !DepthResources {
        const image = try gc.dev.createImage(&.{
            .image_type = .@"2d",
            .format = depth_format,
            .extent = .{
                .width = extent.width,
                .height = extent.height,
                .depth = 1,
            },
            .mip_levels = 1,
            .array_layers = 1,
            .samples = .{ .@"1_bit" = true },
            .tiling = .optimal,
            .usage = .{ .depth_stencil_attachment_bit = true },
            .sharing_mode = .exclusive,
            .initial_layout = .undefined,
        }, null);
        errdefer gc.dev.destroyImage(image, null);

        const mem_reqs = gc.dev.getImageMemoryRequirements(image);
        const memory = try gc.allocate(mem_reqs, .{ .device_local_bit = true });
        errdefer gc.dev.freeMemory(memory, null);

        try gc.dev.bindImageMemory(image, memory, 0);

        const view = try gc.dev.createImageView(&.{
            .image = image,
            .view_type = .@"2d",
            .format = depth_format,
            .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
            .subresource_range = .{
                .aspect_mask = .{ .depth_bit = true },
                .base_mip_level = 0,
                .level_count = 1,
                .base_array_layer = 0,
                .layer_count = 1,
            },
        }, null);
        errdefer gc.dev.destroyImageView(view, null);

        return .{
            .image = image,
            .memory = memory,
            .view = view,
        };
    }

    fn deinit(self: *DepthResources, gc: *const GraphicsContext) void {
        gc.dev.destroyImageView(self.view, null);
        gc.dev.destroyImage(self.image, null);
        gc.dev.freeMemory(self.memory, null);
        self.* = undefined;
    }
};

fn vkExtent(extent: core.Extent2D) vk.Extent2D {
    return .{
        .width = extent.width,
        .height = extent.height,
    };
}

test "Vulkan presentation render passes rebuild only when selection changes" {
    try std.testing.expect(!presentationRenderPassNeedsRebuild(
        .bgra8_unorm_srgb,
        .bgra8_unorm_srgb,
    ));
    try std.testing.expect(!presentationRenderPassNeedsRebuild(
        .bgra8_unorm,
        .bgra8_unorm,
    ));
    try std.testing.expect(presentationRenderPassNeedsRebuild(
        .bgra8_unorm_srgb,
        .bgra8_unorm,
    ));
    try std.testing.expect(presentationRenderPassNeedsRebuild(
        .bgra8_unorm,
        .bgra8_unorm_srgb,
    ));
}

test "Vulkan presentation lifecycle poisons once and rejects later work" {
    var lifecycle = PresentationLifecycle{};
    try lifecycle.ensureAvailable();
    const initial_generation = lifecycle.generation;

    lifecycle.recordSuccessfulResize();
    try std.testing.expectEqual(initial_generation +% 1, lifecycle.generation);
    try lifecycle.ensureAvailable();

    lifecycle.poison();
    const poisoned_generation = lifecycle.generation;
    try std.testing.expectError(core.SurfaceError.SurfaceLost, lifecycle.ensureAvailable());
    lifecycle.poison();
    try std.testing.expectEqual(poisoned_generation, lifecycle.generation);
}

test "Vulkan presentation mutation gate rejects active backend command buffers" {
    try ensureNoActiveCommandBuffers(0);
    try std.testing.expectError(
        core.CommandEncodingError.InvalidCommandBufferState,
        ensureNoActiveCommandBuffers(1),
    );
}
