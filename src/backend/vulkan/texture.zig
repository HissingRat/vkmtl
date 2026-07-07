const vk = @import("vulkan");
const core = @import("../../core.zig");
const VulkanBuffer = @import("buffer.zig");
const GraphicsContext = @import("graphics_context.zig");
const VulkanTextureView = @import("texture_view.zig");

const VulkanTexture = @This();

gc: *const GraphicsContext,
handle: vk.Image,
memory: vk.DeviceMemory,
descriptor: core.TextureDescriptor,
layout: vk.ImageLayout,
width_value: u32,
height_value: u32,
depth_or_array_layers_value: u32,
mip_level_count_value: u32,

pub fn init(gc: *const GraphicsContext, descriptor: core.TextureDescriptor) !VulkanTexture {
    try descriptor.validate();
    if (!gc.supportsSampleCount(descriptor.format, descriptor.sample_count)) {
        return core.TextureError.UnsupportedSampleCount;
    }

    const handle = try gc.dev.createImage(&.{
        .image_type = imageType(descriptor.dimension),
        .format = imageFormat(descriptor.format),
        .extent = .{
            .width = descriptor.width,
            .height = imageHeight(descriptor),
            .depth = imageDepth(descriptor),
        },
        .mip_levels = descriptor.mip_level_count,
        .array_layers = imageArrayLayers(descriptor),
        .samples = sampleCountFlags(descriptor.sample_count),
        .tiling = .optimal,
        .usage = usageFlags(descriptor.format, descriptor.usage),
        .sharing_mode = .exclusive,
        .initial_layout = .undefined,
    }, null);
    errdefer gc.dev.destroyImage(handle, null);

    const mem_reqs = gc.dev.getImageMemoryRequirements(handle);
    const memory = try gc.allocate(mem_reqs, memoryFlags(descriptor));
    errdefer gc.dev.freeMemory(memory, null);

    try gc.dev.bindImageMemory(handle, memory, 0);

    return .{
        .gc = gc,
        .handle = handle,
        .memory = memory,
        .descriptor = descriptor,
        .layout = .undefined,
        .width_value = descriptor.width,
        .height_value = descriptor.height,
        .depth_or_array_layers_value = descriptor.depth_or_array_layers,
        .mip_level_count_value = descriptor.mip_level_count,
    };
}

pub fn deinit(self: *VulkanTexture) void {
    self.gc.dev.destroyImage(self.handle, null);
    self.gc.dev.freeMemory(self.memory, null);
}

pub fn width(self: VulkanTexture) u32 {
    return self.width_value;
}

pub fn height(self: VulkanTexture) u32 {
    return self.height_value;
}

pub fn depthOrArrayLayers(self: VulkanTexture) u32 {
    return self.depth_or_array_layers_value;
}

pub fn mipLevelCount(self: VulkanTexture) u32 {
    return self.mip_level_count_value;
}

pub fn sampleCount(self: VulkanTexture) u32 {
    return self.descriptor.sample_count;
}

pub fn setLabel(self: *VulkanTexture, label_value: ?[]const u8) void {
    self.gc.setDebugName(.image, GraphicsContext.debugObjectHandle(self.handle), label_value);
}

pub fn makeTextureView(self: *VulkanTexture, descriptor: core.TextureViewDescriptor) !VulkanTextureView {
    return try VulkanTextureView.init(self, descriptor);
}

pub fn replaceRegion(
    self: *VulkanTexture,
    region: core.Region3D,
    descriptor: core.TextureReplaceRegionDescriptor,
) !void {
    const resolved = try descriptor.resolveForTexture(self.descriptor, region);

    var staging = try VulkanBuffer.init(self.gc, .{
        .length = resolved.required_bytes,
        .bytes = resolved.bytes[0..resolved.required_bytes],
        .usage = .{ .copy_source = true },
        .storage_mode = .shared,
    });
    defer staging.deinit();

    const pool = try self.gc.dev.createCommandPool(&.{
        .flags = .{ .transient_bit = true },
        .queue_family_index = self.gc.graphics_queue.family,
    }, null);
    defer self.gc.dev.destroyCommandPool(pool, null);

    var cmdbufs: [1]vk.CommandBuffer = undefined;
    try self.gc.dev.allocateCommandBuffers(&.{
        .command_pool = pool,
        .level = .primary,
        .command_buffer_count = 1,
    }, &cmdbufs);
    defer self.gc.dev.freeCommandBuffers(pool, &cmdbufs);

    const cmdbuf = cmdbufs[0];
    try self.gc.dev.beginCommandBuffer(cmdbuf, &.{
        .flags = .{ .one_time_submit_bit = true },
    });

    self.transitionLayout(cmdbuf, self.layout, .transfer_dst_optimal);
    self.copyFromStaging(cmdbuf, staging.handle, resolved);
    self.transitionLayout(cmdbuf, .transfer_dst_optimal, .shader_read_only_optimal);

    try self.gc.dev.endCommandBuffer(cmdbuf);

    try self.gc.dev.queueSubmit(self.gc.graphics_queue.handle, &.{.{
        .command_buffer_count = 1,
        .p_command_buffers = &cmdbufs,
    }}, .null_handle);
    try self.gc.dev.queueWaitIdle(self.gc.graphics_queue.handle);

    self.layout = .shader_read_only_optimal;
}

fn imageType(dimension: core.TextureDimension) vk.ImageType {
    return switch (dimension) {
        .one_d => .@"1d",
        .two_d => .@"2d",
        .three_d => .@"3d",
    };
}

pub fn imageFormat(format: core.TextureFormat) vk.Format {
    return switch (format) {
        .automatic => unreachable,
        .bgra8_unorm => .b8g8r8a8_unorm,
        .bgra8_unorm_srgb => .b8g8r8a8_srgb,
        .rgba8_unorm => .r8g8b8a8_unorm,
        .rgba8_unorm_srgb => .r8g8b8a8_srgb,
        .depth32_float => .d32_sfloat,
        .depth32_float_stencil8 => .d32_sfloat_s8_uint,
    };
}

pub fn sampleCountFlags(sample_count: u32) vk.SampleCountFlags {
    return switch (sample_count) {
        1 => .{ .@"1_bit" = true },
        2 => .{ .@"2_bit" = true },
        4 => .{ .@"4_bit" = true },
        8 => .{ .@"8_bit" = true },
        else => unreachable,
    };
}

fn imageHeight(descriptor: core.TextureDescriptor) u32 {
    return switch (descriptor.dimension) {
        .one_d => 1,
        .two_d, .three_d => descriptor.height,
    };
}

fn imageDepth(descriptor: core.TextureDescriptor) u32 {
    return switch (descriptor.dimension) {
        .one_d, .two_d => 1,
        .three_d => descriptor.depth_or_array_layers,
    };
}

fn imageArrayLayers(descriptor: core.TextureDescriptor) u32 {
    return switch (descriptor.dimension) {
        .one_d, .two_d => descriptor.depth_or_array_layers,
        .three_d => 1,
    };
}

fn usageFlags(format: core.TextureFormat, usage: core.TextureUsage) vk.ImageUsageFlags {
    var flags = vk.ImageUsageFlags{};

    if (usage.copy_source) flags.transfer_src_bit = true;
    flags.transfer_dst_bit = true;
    if (usage.shader_read) flags.sampled_bit = true;
    if (usage.shader_write) flags.storage_bit = true;
    if (usage.render_attachment) {
        if (core.isDepthFormat(format) or core.isStencilFormat(format)) {
            flags.depth_stencil_attachment_bit = true;
        } else {
            flags.color_attachment_bit = true;
        }
    }

    if (usage.isEmpty()) {
        flags.sampled_bit = true;
    }

    return flags;
}

fn memoryFlags(descriptor: core.TextureDescriptor) vk.MemoryPropertyFlags {
    _ = descriptor;
    return .{ .device_local_bit = true };
}

pub fn transitionLayout(self: *VulkanTexture, cmdbuf: vk.CommandBuffer, old_layout: vk.ImageLayout, new_layout: vk.ImageLayout) void {
    if (old_layout == new_layout) return;

    const barrier = vk.ImageMemoryBarrier{
        .src_access_mask = accessMaskForOldLayout(old_layout),
        .dst_access_mask = accessMaskForNewLayout(new_layout),
        .old_layout = old_layout,
        .new_layout = new_layout,
        .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .image = self.handle,
        .subresource_range = .{
            .aspect_mask = .{ .color_bit = true },
            .base_mip_level = 0,
            .level_count = self.descriptor.mip_level_count,
            .base_array_layer = 0,
            .layer_count = imageArrayLayers(self.descriptor),
        },
    };

    self.gc.dev.cmdPipelineBarrier(
        cmdbuf,
        stageMaskForOldLayout(old_layout),
        stageMaskForNewLayout(new_layout),
        .{},
        null,
        null,
        &.{barrier},
    );
}

fn copyFromStaging(self: *VulkanTexture, cmdbuf: vk.CommandBuffer, staging: vk.Buffer, upload: core.ResolvedTextureReplaceRegion) void {
    const copy = vk.BufferImageCopy{
        .buffer_offset = 0,
        .buffer_row_length = @intCast(upload.bytes_per_row / upload.bytes_per_pixel),
        .buffer_image_height = @intCast(upload.bytes_per_image / upload.bytes_per_row),
        .image_subresource = .{
            .aspect_mask = .{ .color_bit = true },
            .mip_level = upload.mip_level,
            .base_array_layer = if (self.descriptor.dimension == .three_d) 0 else upload.slice,
            .layer_count = 1,
        },
        .image_offset = .{
            .x = @intCast(upload.region.origin.x),
            .y = @intCast(upload.region.origin.y),
            .z = if (self.descriptor.dimension == .three_d) @intCast(upload.region.origin.z) else 0,
        },
        .image_extent = .{
            .width = upload.region.size.width,
            .height = upload.region.size.height,
            .depth = if (self.descriptor.dimension == .three_d) upload.region.size.depth else 1,
        },
    };

    self.gc.dev.cmdCopyBufferToImage(
        cmdbuf,
        staging,
        self.handle,
        .transfer_dst_optimal,
        &.{copy},
    );
}

fn accessMaskForOldLayout(layout: vk.ImageLayout) vk.AccessFlags {
    return switch (layout) {
        .undefined => .{},
        .transfer_src_optimal => .{ .transfer_read_bit = true },
        .transfer_dst_optimal => .{ .transfer_write_bit = true },
        .shader_read_only_optimal => .{ .shader_read_bit = true },
        .general => .{ .shader_read_bit = true, .shader_write_bit = true },
        else => .{},
    };
}

fn accessMaskForNewLayout(layout: vk.ImageLayout) vk.AccessFlags {
    return switch (layout) {
        .transfer_src_optimal => .{ .transfer_read_bit = true },
        .transfer_dst_optimal => .{ .transfer_write_bit = true },
        .shader_read_only_optimal => .{ .shader_read_bit = true },
        .general => .{ .shader_read_bit = true, .shader_write_bit = true },
        else => .{},
    };
}

fn stageMaskForOldLayout(layout: vk.ImageLayout) vk.PipelineStageFlags {
    return switch (layout) {
        .undefined => .{ .top_of_pipe_bit = true },
        .transfer_src_optimal => .{ .transfer_bit = true },
        .transfer_dst_optimal => .{ .transfer_bit = true },
        .shader_read_only_optimal => .{ .fragment_shader_bit = true },
        .general => .{ .compute_shader_bit = true },
        else => .{ .all_commands_bit = true },
    };
}

fn stageMaskForNewLayout(layout: vk.ImageLayout) vk.PipelineStageFlags {
    return switch (layout) {
        .transfer_src_optimal => .{ .transfer_bit = true },
        .transfer_dst_optimal => .{ .transfer_bit = true },
        .shader_read_only_optimal => .{ .fragment_shader_bit = true },
        .general => .{ .compute_shader_bit = true },
        else => .{ .all_commands_bit = true },
    };
}
