const vk = @import("vulkan");
const core = @import("../../core.zig");
const GraphicsContext = @import("graphics_context.zig");
const VulkanTexture = @import("texture.zig");

const VulkanTextureView = @This();

gc: *const GraphicsContext,
image: vk.Image,
handle: vk.ImageView,
format: core.TextureFormat,
width: u32,
height: u32,
sample_count: u32,
layout: *vk.ImageLayout,
subresource_range: vk.ImageSubresourceRange,

pub fn init(texture: *VulkanTexture, descriptor: core.TextureViewDescriptor) !VulkanTextureView {
    const resolved = try descriptor.resolveForTexture(texture.descriptor);
    const subresource_range = vk.ImageSubresourceRange{
        .aspect_mask = aspectMask(resolved.format),
        .base_mip_level = resolved.base_mip_level,
        .level_count = resolved.mip_level_count,
        .base_array_layer = resolved.base_array_layer,
        .layer_count = resolved.array_layer_count,
    };

    const handle = try texture.gc.dev.createImageView(&.{
        .image = texture.handle,
        .view_type = viewType(resolved.dimension),
        .format = VulkanTexture.imageFormat(resolved.format),
        .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
        .subresource_range = subresource_range,
    }, null);

    return .{
        .gc = texture.gc,
        .image = texture.handle,
        .handle = handle,
        .format = resolved.format,
        .width = mipDimension(texture.width_value, resolved.base_mip_level),
        .height = mipDimension(texture.height_value, resolved.base_mip_level),
        .sample_count = texture.sampleCount(),
        .layout = &texture.layout,
        .subresource_range = subresource_range,
    };
}

pub fn deinit(self: *VulkanTextureView) void {
    self.gc.dev.destroyImageView(self.handle, null);
}

pub fn setLabel(self: *VulkanTextureView, label_value: ?[]const u8) void {
    self.gc.setDebugName(.image_view, GraphicsContext.debugObjectHandle(self.handle), label_value);
}

pub fn transitionLayout(self: *const VulkanTextureView, cmdbuf: vk.CommandBuffer, new_layout: vk.ImageLayout) void {
    const old_layout = self.layout.*;
    if (old_layout == new_layout) return;

    const barrier = vk.ImageMemoryBarrier{
        .src_access_mask = accessMaskForOldLayout(old_layout),
        .dst_access_mask = accessMaskForNewLayout(new_layout),
        .old_layout = old_layout,
        .new_layout = new_layout,
        .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .image = self.image,
        .subresource_range = self.subresource_range,
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

    self.layout.* = new_layout;
}

fn viewType(dimension: core.TextureViewDimension) vk.ImageViewType {
    return switch (dimension) {
        .automatic => unreachable,
        .one_d => .@"1d",
        .one_d_array => .@"1d_array",
        .two_d => .@"2d",
        .two_d_array => .@"2d_array",
        .three_d => .@"3d",
    };
}

fn aspectMask(format: core.TextureFormat) vk.ImageAspectFlags {
    if (core.isDepthFormat(format)) return .{ .depth_bit = true };
    return .{ .color_bit = true };
}

fn mipDimension(base: u32, level: u32) u32 {
    var value = base;
    var i: u32 = 0;
    while (i < level and value > 1) : (i += 1) {
        value /= 2;
    }
    return value;
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
