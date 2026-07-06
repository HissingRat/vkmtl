const std = @import("std");
const vk = @import("vulkan");
const core = @import("../../core.zig");
const VulkanBuffer = @import("buffer.zig");
const VulkanCommand = @import("command.zig");
const VulkanComputePipelineState = @import("compute_pipeline.zig");
const VulkanRenderPipelineState = @import("render_pipeline.zig");
const VulkanSamplerState = @import("sampler.zig");
const VulkanShaderModule = @import("shader_module.zig");
const VulkanTexture = @import("texture.zig");
const GraphicsContext = @import("graphics_context.zig");
const Swapchain = @import("swapchain.zig");

const VulkanClearScreen = @This();

allocator: std.mem.Allocator,
gc: *GraphicsContext,
swapchain: Swapchain,
color_render_pass: vk.RenderPass,
depth_render_pass: vk.RenderPass,
color_framebuffers: []vk.Framebuffer,
depth_framebuffers: []vk.Framebuffer,
depth_resources: DepthResources,
pool: vk.CommandPool,
cmdbufs: []vk.CommandBuffer,
clear_color: core.ClearColorLike,

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

    var swapchain = try Swapchain.init(gc, allocator, extent);
    errdefer swapchain.deinit();

    const color_render_pass = try createColorRenderPass(gc, swapchain);
    errdefer gc.dev.destroyRenderPass(color_render_pass, null);

    const depth_render_pass = try createDepthRenderPass(gc, swapchain);
    errdefer gc.dev.destroyRenderPass(depth_render_pass, null);

    var depth_resources = try DepthResources.init(gc, extent);
    errdefer depth_resources.deinit(gc);

    const color_framebuffers = try createColorFramebuffers(gc, allocator, color_render_pass, swapchain);
    errdefer destroyFramebuffers(gc, allocator, color_framebuffers);

    const depth_framebuffers = try createDepthFramebuffers(gc, allocator, depth_render_pass, swapchain, depth_resources.view);
    errdefer destroyFramebuffers(gc, allocator, depth_framebuffers);

    const pool = try gc.dev.createCommandPool(&.{
        .queue_family_index = gc.graphics_queue.family,
    }, null);
    errdefer gc.dev.destroyCommandPool(pool, null);

    var self = VulkanClearScreen{
        .allocator = allocator,
        .gc = gc,
        .swapchain = swapchain,
        .color_render_pass = color_render_pass,
        .depth_render_pass = depth_render_pass,
        .color_framebuffers = color_framebuffers,
        .depth_framebuffers = depth_framebuffers,
        .depth_resources = depth_resources,
        .pool = pool,
        .cmdbufs = &.{},
        .clear_color = .{},
    };

    self.cmdbufs = try self.createCommandBuffers();
    return self;
}

pub fn adapterInfo(self: *const VulkanClearScreen) AdapterInfoResult {
    return .{ .info = self.gc.adapterInfo() };
}

pub fn deinit(self: *VulkanClearScreen) void {
    if (self.cmdbufs.len != 0) {
        self.gc.dev.freeCommandBuffers(self.pool, self.cmdbufs);
        self.allocator.free(self.cmdbufs);
        self.cmdbufs = &.{};
    }
    self.gc.dev.destroyCommandPool(self.pool, null);
    destroyFramebuffers(self.gc, self.allocator, self.depth_framebuffers);
    destroyFramebuffers(self.gc, self.allocator, self.color_framebuffers);
    self.depth_resources.deinit(self.gc);
    self.gc.dev.destroyRenderPass(self.depth_render_pass, null);
    self.gc.dev.destroyRenderPass(self.color_render_pass, null);
    self.swapchain.deinit();
    self.gc.deinit();
    self.allocator.destroy(self.gc);
}

pub fn resize(self: *VulkanClearScreen, extent: core.Extent2D) !void {
    if (extent.isZero()) return;
    if (self.swapchain.extent.width == extent.width and self.swapchain.extent.height == extent.height) return;

    try self.swapchain.recreate(vkExtent(extent));

    self.gc.dev.freeCommandBuffers(self.pool, self.cmdbufs);
    self.allocator.free(self.cmdbufs);
    self.cmdbufs = &.{};

    destroyFramebuffers(self.gc, self.allocator, self.depth_framebuffers);
    destroyFramebuffers(self.gc, self.allocator, self.color_framebuffers);
    self.depth_resources.deinit(self.gc);

    self.depth_resources = try DepthResources.init(self.gc, self.swapchain.extent);
    errdefer self.depth_resources.deinit(self.gc);
    self.color_framebuffers = try createColorFramebuffers(self.gc, self.allocator, self.color_render_pass, self.swapchain);
    errdefer destroyFramebuffers(self.gc, self.allocator, self.color_framebuffers);
    self.depth_framebuffers = try createDepthFramebuffers(
        self.gc,
        self.allocator,
        self.depth_render_pass,
        self.swapchain,
        self.depth_resources.view,
    );

    self.cmdbufs = try self.createCommandBuffers();
}

pub fn clear(self: *VulkanClearScreen, color: core.ClearColorLike) !void {
    self.clear_color = color;
    try self.recordCommandBuffers();

    const cmdbuf = self.cmdbufs[self.swapchain.image_index];
    _ = try self.swapchain.present(cmdbuf);
}

pub fn makeBuffer(self: *VulkanClearScreen, descriptor: core.BufferDescriptor) !VulkanBuffer {
    return try VulkanBuffer.init(self.gc, descriptor);
}

pub fn makeShaderModule(self: *VulkanClearScreen, descriptor: core.ShaderModuleDescriptor) !VulkanShaderModule {
    return try VulkanShaderModule.init(self.gc, self.allocator, descriptor);
}

pub fn makeRenderPipelineState(self: *VulkanClearScreen, descriptor: core.RenderPipelineDescriptor) !VulkanRenderPipelineState {
    return try VulkanRenderPipelineState.init(self.gc, self.allocator, descriptor);
}

pub fn makeComputePipelineState(self: *VulkanClearScreen, descriptor: core.ComputePipelineDescriptor) !VulkanComputePipelineState {
    return try VulkanComputePipelineState.init(self.gc, self.allocator, descriptor);
}

pub fn makeCommandBuffer(self: *VulkanClearScreen) !VulkanCommand.CommandBuffer {
    return try VulkanCommand.CommandBuffer.init(
        self.gc,
        self.pool,
        &self.swapchain,
        self.color_render_pass,
        self.depth_render_pass,
        self.color_framebuffers,
        self.depth_framebuffers,
    );
}

pub fn makeTexture(self: *VulkanClearScreen, descriptor: core.TextureDescriptor) !VulkanTexture {
    return try VulkanTexture.init(self.gc, descriptor);
}

pub fn makeSamplerState(self: *VulkanClearScreen, descriptor: core.SamplerDescriptor) !VulkanSamplerState {
    return try VulkanSamplerState.init(self.gc, descriptor);
}

fn createCommandBuffers(self: *VulkanClearScreen) ![]vk.CommandBuffer {
    const cmdbufs = try self.allocator.alloc(vk.CommandBuffer, self.color_framebuffers.len);
    errdefer self.allocator.free(cmdbufs);

    try self.gc.dev.allocateCommandBuffers(&.{
        .command_pool = self.pool,
        .level = .primary,
        .command_buffer_count = @intCast(cmdbufs.len),
    }, cmdbufs.ptr);
    errdefer self.gc.dev.freeCommandBuffers(self.pool, cmdbufs);

    return cmdbufs;
}

fn recordCommandBuffers(self: *VulkanClearScreen) !void {
    try self.swapchain.waitForAllFences();
    try self.gc.dev.resetCommandPool(self.pool, .{});

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
                .extent = self.swapchain.extent,
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
