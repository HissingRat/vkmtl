const std = @import("std");
const vk = @import("vulkan");
const GraphicsContext = @import("graphics_context.zig");
const VulkanSync = @import("sync.zig");

const Allocator = std.mem.Allocator;
const Swapchain = @This();

pub const PresentState = enum {
    optimal,
    suboptimal,
};

gc: *const GraphicsContext,
allocator: Allocator,
surface_format: vk.SurfaceFormatKHR,
present_mode: vk.PresentModeKHR,
extent: vk.Extent2D,
handle: vk.SwapchainKHR,
swap_images: []SwapImage,
image_index: u32,
next_image_acquired: vk.Semaphore,

pub fn init(gc: *const GraphicsContext, allocator: Allocator, extent: vk.Extent2D) !Swapchain {
    return try initRecycle(gc, allocator, extent, .null_handle);
}

pub fn initRecycle(gc: *const GraphicsContext, allocator: Allocator, extent: vk.Extent2D, old_handle: vk.SwapchainKHR) !Swapchain {
    const caps = try gc.instance.getPhysicalDeviceSurfaceCapabilitiesKHR(gc.pdev, gc.surface);
    const actual_extent = findActualExtent(caps, extent);
    if (actual_extent.width == 0 or actual_extent.height == 0) {
        return error.InvalidSurfaceDimensions;
    }

    const surface_format = try findSurfaceFormat(gc, allocator);
    const present_mode = try findPresentMode(gc, allocator);

    var image_count = caps.min_image_count + 1;
    if (caps.max_image_count > 0) {
        image_count = @min(image_count, caps.max_image_count);
    }

    const qfi = [_]u32{ gc.graphics_queue.family, gc.present_queue.family };
    const sharing_mode: vk.SharingMode = if (gc.graphics_queue.family != gc.present_queue.family) .concurrent else .exclusive;

    const handle = gc.dev.createSwapchainKHR(&.{
        .surface = gc.surface,
        .min_image_count = image_count,
        .image_format = surface_format.format,
        .image_color_space = surface_format.color_space,
        .image_extent = actual_extent,
        .image_array_layers = 1,
        .image_usage = .{ .color_attachment_bit = true, .transfer_dst_bit = true },
        .image_sharing_mode = sharing_mode,
        .queue_family_index_count = qfi.len,
        .p_queue_family_indices = &qfi,
        .pre_transform = caps.current_transform,
        .composite_alpha = .{ .opaque_bit_khr = true },
        .present_mode = present_mode,
        .clipped = .true,
        .old_swapchain = old_handle,
    }, null) catch {
        return error.SwapchainCreationFailed;
    };
    errdefer gc.dev.destroySwapchainKHR(handle, null);

    if (old_handle != .null_handle) {
        gc.dev.destroySwapchainKHR(old_handle, null);
    }

    const swap_images = try initSwapchainImages(gc, handle, surface_format.format, allocator);
    errdefer {
        for (swap_images) |si| si.deinit(gc);
        allocator.free(swap_images);
    }

    var next_image_acquired = try gc.dev.createSemaphore(&.{}, null);
    errdefer gc.dev.destroySemaphore(next_image_acquired, null);

    const result = try gc.dev.acquireNextImageKHR(handle, std.math.maxInt(u64), next_image_acquired, .null_handle);
    if (result.result == .not_ready or result.result == .timeout) {
        return error.ImageAcquireFailed;
    }

    std.mem.swap(vk.Semaphore, &swap_images[result.image_index].image_acquired, &next_image_acquired);
    return .{
        .gc = gc,
        .allocator = allocator,
        .surface_format = surface_format,
        .present_mode = present_mode,
        .extent = actual_extent,
        .handle = handle,
        .swap_images = swap_images,
        .image_index = result.image_index,
        .next_image_acquired = next_image_acquired,
    };
}

fn deinitExceptSwapchain(self: Swapchain) void {
    for (self.swap_images) |si| si.deinit(self.gc);
    self.allocator.free(self.swap_images);
    self.gc.dev.destroySemaphore(self.next_image_acquired, null);
}

pub fn waitForAllFences(self: Swapchain) !void {
    for (self.swap_images) |si| try si.waitForFence(self.gc);
}

pub fn deinit(self: Swapchain) void {
    if (self.handle == .null_handle) return;
    self.deinitExceptSwapchain();
    self.gc.dev.destroySwapchainKHR(self.handle, null);
}

pub fn recreate(self: *Swapchain, new_extent: vk.Extent2D) !void {
    const gc = self.gc;
    const allocator = self.allocator;
    const old_handle = self.handle;

    try self.gc.dev.queueWaitIdle(self.gc.present_queue.handle);
    self.deinitExceptSwapchain();
    self.handle = .null_handle;

    self.* = initRecycle(gc, allocator, new_extent, old_handle) catch |err| switch (err) {
        error.SwapchainCreationFailed => {
            gc.dev.destroySwapchainKHR(old_handle, null);
            return err;
        },
        else => return err,
    };
}

pub fn currentSwapImage(self: Swapchain) *const SwapImage {
    return &self.swap_images[self.image_index];
}

pub fn currentImageHandle(self: Swapchain) vk.Image {
    return self.currentSwapImage().image;
}

pub fn present(
    self: *Swapchain,
    cmdbuf: vk.CommandBuffer,
    timeline_waits: []const VulkanSync.TimelinePoint,
    timeline_signals: []const VulkanSync.TimelinePoint,
) !PresentState {
    const current = self.currentSwapImage();
    try current.waitForFence(self.gc);
    try self.gc.dev.resetFences(&.{current.frame_fence});

    const wait_semaphores = try self.allocator.alloc(vk.Semaphore, timeline_waits.len + 1);
    defer self.allocator.free(wait_semaphores);
    const wait_values = try self.allocator.alloc(u64, timeline_waits.len + 1);
    defer self.allocator.free(wait_values);
    const wait_stages = try self.allocator.alloc(vk.PipelineStageFlags, timeline_waits.len + 1);
    defer self.allocator.free(wait_stages);
    wait_semaphores[0] = current.image_acquired;
    wait_values[0] = 0;
    wait_stages[0] = .{ .top_of_pipe_bit = true };
    for (timeline_waits, 0..) |point, index| {
        wait_semaphores[index + 1] = point.semaphore.handle;
        wait_values[index + 1] = point.value;
        wait_stages[index + 1] = .{ .all_commands_bit = true };
    }

    const signal_semaphores = try self.allocator.alloc(vk.Semaphore, timeline_signals.len + 1);
    defer self.allocator.free(signal_semaphores);
    const signal_values = try self.allocator.alloc(u64, timeline_signals.len + 1);
    defer self.allocator.free(signal_values);
    signal_semaphores[0] = current.render_finished;
    signal_values[0] = 0;
    for (timeline_signals, 0..) |point, index| {
        signal_semaphores[index + 1] = point.semaphore.handle;
        signal_values[index + 1] = point.value;
    }

    var timeline_info = vk.TimelineSemaphoreSubmitInfo{
        .wait_semaphore_value_count = @intCast(wait_values.len),
        .p_wait_semaphore_values = wait_values.ptr,
        .signal_semaphore_value_count = @intCast(signal_values.len),
        .p_signal_semaphore_values = signal_values.ptr,
    };
    try self.gc.dev.queueSubmit(self.gc.graphics_queue.handle, &.{.{
        .p_next = if (timeline_waits.len != 0 or timeline_signals.len != 0) &timeline_info else null,
        .wait_semaphore_count = @intCast(wait_semaphores.len),
        .p_wait_semaphores = wait_semaphores.ptr,
        .p_wait_dst_stage_mask = wait_stages.ptr,
        .command_buffer_count = 1,
        .p_command_buffers = @ptrCast(&cmdbuf),
        .signal_semaphore_count = @intCast(signal_semaphores.len),
        .p_signal_semaphores = signal_semaphores.ptr,
    }}, current.frame_fence);

    _ = try self.gc.dev.queuePresentKHR(self.gc.present_queue.handle, &.{
        .wait_semaphore_count = 1,
        .p_wait_semaphores = @ptrCast(&current.render_finished),
        .swapchain_count = 1,
        .p_swapchains = @ptrCast(&self.handle),
        .p_image_indices = @ptrCast(&self.image_index),
    });

    const result = try self.gc.dev.acquireNextImageKHR(
        self.handle,
        std.math.maxInt(u64),
        self.next_image_acquired,
        .null_handle,
    );

    std.mem.swap(vk.Semaphore, &self.swap_images[result.image_index].image_acquired, &self.next_image_acquired);
    self.image_index = result.image_index;

    return switch (result.result) {
        .success => .optimal,
        .suboptimal_khr => .suboptimal,
        else => unreachable,
    };
}

const SwapImage = struct {
    image: vk.Image,
    view: vk.ImageView,
    image_acquired: vk.Semaphore,
    render_finished: vk.Semaphore,
    frame_fence: vk.Fence,

    fn init(gc: *const GraphicsContext, image: vk.Image, format: vk.Format) !SwapImage {
        const view = try gc.dev.createImageView(&.{
            .image = image,
            .view_type = .@"2d",
            .format = format,
            .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
            .subresource_range = .{
                .aspect_mask = .{ .color_bit = true },
                .base_mip_level = 0,
                .level_count = 1,
                .base_array_layer = 0,
                .layer_count = 1,
            },
        }, null);
        errdefer gc.dev.destroyImageView(view, null);

        const image_acquired = try gc.dev.createSemaphore(&.{}, null);
        errdefer gc.dev.destroySemaphore(image_acquired, null);

        const render_finished = try gc.dev.createSemaphore(&.{}, null);
        errdefer gc.dev.destroySemaphore(render_finished, null);

        const frame_fence = try gc.dev.createFence(&.{ .flags = .{ .signaled_bit = true } }, null);
        errdefer gc.dev.destroyFence(frame_fence, null);

        return .{
            .image = image,
            .view = view,
            .image_acquired = image_acquired,
            .render_finished = render_finished,
            .frame_fence = frame_fence,
        };
    }

    fn deinit(self: SwapImage, gc: *const GraphicsContext) void {
        self.waitForFence(gc) catch return;
        gc.dev.destroyImageView(self.view, null);
        gc.dev.destroySemaphore(self.image_acquired, null);
        gc.dev.destroySemaphore(self.render_finished, null);
        gc.dev.destroyFence(self.frame_fence, null);
    }

    fn waitForFence(self: SwapImage, gc: *const GraphicsContext) !void {
        _ = try gc.dev.waitForFences(&.{self.frame_fence}, .true, std.math.maxInt(u64));
    }
};

fn initSwapchainImages(gc: *const GraphicsContext, swapchain: vk.SwapchainKHR, format: vk.Format, allocator: Allocator) ![]SwapImage {
    const images = try gc.dev.getSwapchainImagesAllocKHR(swapchain, allocator);
    defer allocator.free(images);

    const swap_images = try allocator.alloc(SwapImage, images.len);
    errdefer allocator.free(swap_images);

    var i: usize = 0;
    errdefer for (swap_images[0..i]) |si| si.deinit(gc);

    for (images) |image| {
        swap_images[i] = try SwapImage.init(gc, image, format);
        i += 1;
    }

    return swap_images;
}

fn findSurfaceFormat(gc: *const GraphicsContext, allocator: Allocator) !vk.SurfaceFormatKHR {
    const surface_formats = try gc.instance.getPhysicalDeviceSurfaceFormatsAllocKHR(gc.pdev, gc.surface, allocator);
    defer allocator.free(surface_formats);

    return GraphicsContext.selectPresentationSurfaceFormat(surface_formats) orelse error.SwapchainCreationFailed;
}

fn findPresentMode(gc: *const GraphicsContext, allocator: Allocator) !vk.PresentModeKHR {
    const present_modes = try gc.instance.getPhysicalDeviceSurfacePresentModesAllocKHR(gc.pdev, gc.surface, allocator);
    defer allocator.free(present_modes);

    const preferred = [_]vk.PresentModeKHR{ .mailbox_khr, .immediate_khr };
    for (preferred) |mode| {
        if (std.mem.indexOfScalar(vk.PresentModeKHR, present_modes, mode) != null) return mode;
    }
    return .fifo_khr;
}

fn findActualExtent(caps: vk.SurfaceCapabilitiesKHR, extent: vk.Extent2D) vk.Extent2D {
    if (caps.current_extent.width != 0xFFFF_FFFF) {
        return caps.current_extent;
    }
    return .{
        .width = std.math.clamp(extent.width, caps.min_image_extent.width, caps.max_image_extent.width),
        .height = std.math.clamp(extent.height, caps.min_image_extent.height, caps.max_image_extent.height),
    };
}
