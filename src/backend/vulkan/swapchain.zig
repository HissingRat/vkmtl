const std = @import("std");
const vk = @import("vulkan");
const core = @import("../../core.zig");
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
requested_format: core.TextureFormat,
selected_format: core.TextureFormat,
present_mode: vk.PresentModeKHR,
requested_extent: vk.Extent2D,
extent: vk.Extent2D,
image_count: u32,
pre_transform: vk.SurfaceTransformFlagsKHR,
recreation_required: bool,
handle: vk.SwapchainKHR,
swap_images: []SwapImage,
image_index: u32,
next_image_acquired: vk.Semaphore,

pub fn init(
    gc: *const GraphicsContext,
    allocator: Allocator,
    extent: vk.Extent2D,
    requested_format: core.TextureFormat,
) !Swapchain {
    return try initRecycle(gc, allocator, extent, requested_format, .null_handle);
}

pub fn initRecycle(
    gc: *const GraphicsContext,
    allocator: Allocator,
    extent: vk.Extent2D,
    requested_format: core.TextureFormat,
    old_handle: vk.SwapchainKHR,
) !Swapchain {
    const resolved = try resolveSurfaceConfiguration(gc, allocator, extent, requested_format);

    const qfi = [_]u32{ gc.graphics_queue.family, gc.present_queue.family };
    const sharing_mode: vk.SharingMode = if (gc.graphics_queue.family != gc.present_queue.family) .concurrent else .exclusive;

    const handle = gc.dev.createSwapchainKHR(&.{
        .surface = gc.surface,
        .min_image_count = resolved.image_count,
        .image_format = resolved.surface_format.format,
        .image_color_space = resolved.surface_format.color_space,
        .image_extent = resolved.extent,
        .image_array_layers = 1,
        .image_usage = .{ .color_attachment_bit = true, .transfer_dst_bit = true },
        .image_sharing_mode = sharing_mode,
        .queue_family_index_count = qfi.len,
        .p_queue_family_indices = &qfi,
        .pre_transform = resolved.pre_transform,
        .composite_alpha = .{ .opaque_bit_khr = true },
        .present_mode = resolved.present_mode,
        .clipped = .true,
        .old_swapchain = old_handle,
    }, null) catch {
        return error.SwapchainCreationFailed;
    };
    errdefer gc.dev.destroySwapchainKHR(handle, null);

    const swap_images = try initSwapchainImages(gc, handle, resolved.surface_format.format, allocator);
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
    const swapchain = Swapchain{
        .gc = gc,
        .allocator = allocator,
        .surface_format = resolved.surface_format,
        .requested_format = requested_format,
        .selected_format = resolved.selected_format,
        .present_mode = resolved.present_mode,
        .requested_extent = extent,
        .extent = resolved.extent,
        .image_count = resolved.image_count,
        .pre_transform = resolved.pre_transform,
        .recreation_required = result.result == .suboptimal_khr,
        .handle = handle,
        .swap_images = swap_images,
        .image_index = result.image_index,
        .next_image_acquired = next_image_acquired,
    };
    if (old_handle != .null_handle) gc.dev.destroySwapchainKHR(old_handle, null);
    return swapchain;
}

fn deinitImageResources(self: *Swapchain) void {
    for (self.swap_images) |si| si.deinit(self.gc);
    if (self.swap_images.len != 0) self.allocator.free(self.swap_images);
    self.swap_images = &.{};
    if (self.next_image_acquired != .null_handle) {
        self.gc.dev.destroySemaphore(self.next_image_acquired, null);
        self.next_image_acquired = .null_handle;
    }
    self.image_index = 0;
}

pub fn waitForAllFences(self: *Swapchain) !void {
    for (self.swap_images) |*si| try si.waitForFence(self.gc);
}

pub fn deinit(self: *Swapchain) void {
    self.waitForAllFences() catch {};
    // A graphics fence only proves that rendering signaled its semaphore. The
    // present queue may still be consuming that semaphore and swapchain image.
    self.gc.dev.queueWaitIdle(self.gc.present_queue.handle) catch {};
    self.deinitImageResources();
    if (self.handle != .null_handle) {
        self.gc.dev.destroySwapchainKHR(self.handle, null);
        self.handle = .null_handle;
    }
}

pub fn recreate(self: *Swapchain, new_extent: vk.Extent2D) !void {
    const gc = self.gc;
    const allocator = self.allocator;
    const old_handle = self.handle;
    const requested_format = self.requested_format;

    try self.gc.dev.queueWaitIdle(self.gc.present_queue.handle);
    self.deinitImageResources();
    self.handle = .null_handle;

    self.* = initRecycle(gc, allocator, new_extent, requested_format, old_handle) catch |err| {
        gc.dev.destroySwapchainKHR(old_handle, null);
        self.handle = .null_handle;
        self.swap_images = &.{};
        self.image_index = 0;
        self.next_image_acquired = .null_handle;
        return err;
    };
}

pub fn recreationNeeded(self: Swapchain, new_extent: vk.Extent2D) !bool {
    if (canReuseWithoutSurfaceQuery(
        self.recreation_required,
        self.requested_extent,
        new_extent,
    )) return false;

    const resolved = try resolveSurfaceConfiguration(
        self.gc,
        self.allocator,
        new_extent,
        self.requested_format,
    );
    return shouldRecreatePresentation(
        self.recreation_required,
        self.nativePresentationState(),
        resolved.nativePresentationState(),
    );
}

pub fn recordRequestedExtent(self: *Swapchain, requested_extent: vk.Extent2D) void {
    self.requested_extent = requested_extent;
}

pub fn selectedPresentationFormat(self: Swapchain) core.TextureFormat {
    return self.selected_format;
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
    const current = &self.swap_images[self.image_index];
    try current.waitForFence(self.gc);

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
    try self.gc.dev.resetFences(&.{current.frame_fence});
    self.gc.dev.queueSubmit(self.gc.graphics_queue.handle, &.{.{
        .p_next = if (timeline_waits.len != 0 or timeline_signals.len != 0) &timeline_info else null,
        .wait_semaphore_count = @intCast(wait_semaphores.len),
        .p_wait_semaphores = wait_semaphores.ptr,
        .p_wait_dst_stage_mask = wait_stages.ptr,
        .command_buffer_count = 1,
        .p_command_buffers = @ptrCast(&cmdbuf),
        .signal_semaphore_count = @intCast(signal_semaphores.len),
        .p_signal_semaphores = signal_semaphores.ptr,
    }}, current.frame_fence) catch |err| {
        current.frame_fence_lifecycle.recordSubmitFailure();
        return err;
    };
    current.frame_fence_lifecycle.recordSubmitSuccess();

    const queue_present_result = self.gc.dev.queuePresentKHR(self.gc.present_queue.handle, &.{
        .wait_semaphore_count = 1,
        .p_wait_semaphores = @ptrCast(&current.render_finished),
        .swapchain_count = 1,
        .p_swapchains = @ptrCast(&self.handle),
        .p_image_indices = @ptrCast(&self.image_index),
    }) catch |err| {
        if (err == error.OutOfDateKHR) self.recreation_required = true;
        return err;
    };

    const result = self.gc.dev.acquireNextImageKHR(
        self.handle,
        std.math.maxInt(u64),
        self.next_image_acquired,
        .null_handle,
    ) catch |err| {
        if (err == error.OutOfDateKHR) self.recreation_required = true;
        return err;
    };

    std.mem.swap(vk.Semaphore, &self.swap_images[result.image_index].image_acquired, &self.next_image_acquired);
    self.image_index = result.image_index;

    const present_state = combinedPresentState(queue_present_result, result.result);
    if (present_state == .suboptimal) self.recreation_required = true;
    return present_state;
}

const SwapImage = struct {
    image: vk.Image,
    view: vk.ImageView,
    image_acquired: vk.Semaphore,
    render_finished: vk.Semaphore,
    frame_fence: vk.Fence,
    frame_fence_lifecycle: FrameFenceLifecycle = .{},

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
            .frame_fence_lifecycle = .{},
        };
    }

    fn deinit(self: SwapImage, gc: *const GraphicsContext) void {
        gc.dev.destroyImageView(self.view, null);
        gc.dev.destroySemaphore(self.image_acquired, null);
        gc.dev.destroySemaphore(self.render_finished, null);
        gc.dev.destroyFence(self.frame_fence, null);
    }

    fn waitForFence(self: *SwapImage, gc: *const GraphicsContext) !void {
        if (!self.frame_fence_lifecycle.waitRequired()) return;
        _ = try gc.dev.waitForFences(&.{self.frame_fence}, .true, std.math.maxInt(u64));
        self.frame_fence_lifecycle.recordWaitSuccess();
    }
};

const FrameFenceLifecycle = struct {
    submission_pending: bool = false,

    fn waitRequired(self: FrameFenceLifecycle) bool {
        return self.submission_pending;
    }

    fn recordSubmitSuccess(self: *FrameFenceLifecycle) void {
        self.submission_pending = true;
    }

    fn recordSubmitFailure(self: *FrameFenceLifecycle) void {
        self.submission_pending = false;
    }

    fn recordWaitSuccess(self: *FrameFenceLifecycle) void {
        self.submission_pending = false;
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

fn findSurfaceFormat(
    gc: *const GraphicsContext,
    allocator: Allocator,
    requested_format: core.TextureFormat,
) !GraphicsContext.PresentationSurfaceFormatSelection {
    const surface_formats = try gc.instance.getPhysicalDeviceSurfaceFormatsAllocKHR(gc.pdev, gc.surface, allocator);
    defer allocator.free(surface_formats);

    return GraphicsContext.selectPresentationSurfaceFormat(surface_formats, requested_format) orelse
        core.SurfaceError.UnsupportedPresentationFormat;
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

const ResolvedSurfaceConfiguration = struct {
    surface_format: vk.SurfaceFormatKHR,
    selected_format: core.TextureFormat,
    present_mode: vk.PresentModeKHR,
    extent: vk.Extent2D,
    image_count: u32,
    pre_transform: vk.SurfaceTransformFlagsKHR,

    fn nativePresentationState(self: ResolvedSurfaceConfiguration) NativePresentationState {
        return .{
            .surface_format = self.surface_format,
            .present_mode = self.present_mode,
            .extent = self.extent,
            .image_count = self.image_count,
            .pre_transform = self.pre_transform,
        };
    }
};

const NativePresentationState = struct {
    surface_format: vk.SurfaceFormatKHR,
    present_mode: vk.PresentModeKHR,
    extent: vk.Extent2D,
    image_count: u32,
    pre_transform: vk.SurfaceTransformFlagsKHR,
};

fn nativePresentationState(self: Swapchain) NativePresentationState {
    return .{
        .surface_format = self.surface_format,
        .present_mode = self.present_mode,
        .extent = self.extent,
        .image_count = self.image_count,
        .pre_transform = self.pre_transform,
    };
}

fn resolveSurfaceConfiguration(
    gc: *const GraphicsContext,
    allocator: Allocator,
    requested_extent: vk.Extent2D,
    requested_format: core.TextureFormat,
) !ResolvedSurfaceConfiguration {
    const caps = try gc.instance.getPhysicalDeviceSurfaceCapabilitiesKHR(gc.pdev, gc.surface);
    const actual_extent = findActualExtent(caps, requested_extent);
    if (actual_extent.width == 0 or actual_extent.height == 0) {
        return error.InvalidSurfaceDimensions;
    }

    const format_selection = try findSurfaceFormat(gc, allocator, requested_format);
    const present_mode = try findPresentMode(gc, allocator);
    var image_count = caps.min_image_count + 1;
    if (caps.max_image_count > 0) {
        image_count = @min(image_count, caps.max_image_count);
    }

    return .{
        .surface_format = format_selection.surface_format,
        .selected_format = format_selection.portable_format,
        .present_mode = present_mode,
        .extent = actual_extent,
        .image_count = image_count,
        .pre_transform = caps.current_transform,
    };
}

fn shouldRecreatePresentation(
    recreation_required: bool,
    cached: NativePresentationState,
    current: NativePresentationState,
) bool {
    if (recreation_required) return true;
    return cached.surface_format.format != current.surface_format.format or
        cached.surface_format.color_space != current.surface_format.color_space or
        cached.present_mode != current.present_mode or
        cached.extent.width != current.extent.width or
        cached.extent.height != current.extent.height or
        cached.image_count != current.image_count or
        cached.pre_transform.toInt() != current.pre_transform.toInt();
}

fn canReuseWithoutSurfaceQuery(
    recreation_required: bool,
    cached_requested_extent: vk.Extent2D,
    new_requested_extent: vk.Extent2D,
) bool {
    return !recreation_required and
        cached_requested_extent.width == new_requested_extent.width and
        cached_requested_extent.height == new_requested_extent.height;
}

fn combinedPresentState(queue_present_result: vk.Result, acquire_result: vk.Result) PresentState {
    if (queue_present_result == .suboptimal_khr or acquire_result == .suboptimal_khr) {
        return .suboptimal;
    }
    return .optimal;
}

test "Vulkan presentation requery recreates only for changed or invalidated native state" {
    const cached = NativePresentationState{
        .surface_format = .{
            .format = .b8g8r8a8_srgb,
            .color_space = .srgb_nonlinear_khr,
        },
        .present_mode = .mailbox_khr,
        .extent = .{ .width = 1280, .height = 720 },
        .image_count = 3,
        .pre_transform = .{ .identity_bit_khr = true },
    };

    try std.testing.expect(!shouldRecreatePresentation(false, cached, cached));
    try std.testing.expect(shouldRecreatePresentation(true, cached, cached));

    var changed_extent = cached;
    changed_extent.extent.width = 1920;
    try std.testing.expect(shouldRecreatePresentation(false, cached, changed_extent));

    var changed_pair = cached;
    changed_pair.surface_format.format = .b8g8r8a8_unorm;
    try std.testing.expect(shouldRecreatePresentation(false, cached, changed_pair));

    var changed_mode = cached;
    changed_mode.present_mode = .fifo_khr;
    try std.testing.expect(shouldRecreatePresentation(false, cached, changed_mode));
}

test "Vulkan unchanged requested extent uses fast path unless recovery is required" {
    const cached = vk.Extent2D{ .width = 1280, .height = 720 };
    try std.testing.expect(canReuseWithoutSurfaceQuery(false, cached, cached));
    try std.testing.expect(!canReuseWithoutSurfaceQuery(true, cached, cached));
    try std.testing.expect(!canReuseWithoutSurfaceQuery(
        false,
        cached,
        .{ .width = 1920, .height = 1080 },
    ));
}

test "Vulkan queue-present suboptimal state is not hidden by a successful acquire" {
    try std.testing.expectEqual(PresentState.optimal, combinedPresentState(.success, .success));
    try std.testing.expectEqual(PresentState.suboptimal, combinedPresentState(.suboptimal_khr, .success));
    try std.testing.expectEqual(PresentState.suboptimal, combinedPresentState(.success, .suboptimal_khr));
}

test "Vulkan frame fence waits only track successful queue submissions" {
    var lifecycle = FrameFenceLifecycle{};
    try std.testing.expect(!lifecycle.waitRequired());

    lifecycle.recordSubmitFailure();
    try std.testing.expect(!lifecycle.waitRequired());

    lifecycle.recordSubmitSuccess();
    try std.testing.expect(lifecycle.waitRequired());

    lifecycle.recordWaitSuccess();
    try std.testing.expect(!lifecycle.waitRequired());
}
