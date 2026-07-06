const vk = @import("vulkan");
const core = @import("../../core.zig");
const VulkanBindGroup = @import("bind_group.zig").VulkanBindGroup;
const VulkanBuffer = @import("buffer.zig");
const VulkanComputePipelineState = @import("compute_pipeline.zig");
const VulkanRenderPipelineState = @import("render_pipeline.zig");
const VulkanTexture = @import("texture.zig");
const VulkanTextureView = @import("texture_view.zig");
const GraphicsContext = @import("graphics_context.zig");
const Swapchain = @import("swapchain.zig");

pub const RenderPassColorAttachmentTarget = union(enum) {
    current_drawable,
    texture_view: *const VulkanTextureView,
};

pub const RenderPassColorAttachmentDescriptor = struct {
    target: RenderPassColorAttachmentTarget = .current_drawable,
    resolve_target: ?*const VulkanTextureView = null,
    load_action: core.LoadAction = .clear,
    store_action: core.StoreAction = .store,
    clear_color: core.ClearColorLike = .{},
};

pub const RenderPassDepthAttachmentTarget = union(enum) {
    current_drawable,
    texture_view: *const VulkanTextureView,
};

pub const RenderPassDepthAttachmentDescriptor = struct {
    target: RenderPassDepthAttachmentTarget = .current_drawable,
    load_action: core.LoadAction = .clear,
    store_action: core.StoreAction = .dont_care,
    clear_depth: f32 = 1.0,
};

pub const RenderPassDescriptor = struct {
    label: ?[]const u8 = null,
    color_attachment: RenderPassColorAttachmentDescriptor,
    depth_attachment: ?RenderPassDepthAttachmentDescriptor = null,
};

pub const CommandBuffer = struct {
    gc: *const GraphicsContext,
    pool: vk.CommandPool,
    swapchain: *Swapchain,
    color_render_pass: vk.RenderPass,
    depth_render_pass: vk.RenderPass,
    color_framebuffers: []const vk.Framebuffer,
    depth_framebuffers: []const vk.Framebuffer,
    cmdbuf: vk.CommandBuffer,
    present_requested: bool = false,
    uses_current_drawable: bool = false,
    temporary_render_pass: vk.RenderPass = .null_handle,
    temporary_framebuffer: vk.Framebuffer = .null_handle,

    pub fn init(
        gc: *const GraphicsContext,
        pool: vk.CommandPool,
        swapchain: *Swapchain,
        color_render_pass: vk.RenderPass,
        depth_render_pass: vk.RenderPass,
        color_framebuffers: []const vk.Framebuffer,
        depth_framebuffers: []const vk.Framebuffer,
    ) !CommandBuffer {
        var cmdbuf: vk.CommandBuffer = undefined;
        try gc.dev.allocateCommandBuffers(&.{
            .command_pool = pool,
            .level = .primary,
            .command_buffer_count = 1,
        }, @ptrCast(&cmdbuf));

        return .{
            .gc = gc,
            .pool = pool,
            .swapchain = swapchain,
            .color_render_pass = color_render_pass,
            .depth_render_pass = depth_render_pass,
            .color_framebuffers = color_framebuffers,
            .depth_framebuffers = depth_framebuffers,
            .cmdbuf = cmdbuf,
        };
    }

    pub fn deinit(self: *CommandBuffer) void {
        if (self.cmdbuf == .null_handle) return;
        self.destroyTemporaryRenderPassResources();
        self.gc.dev.freeCommandBuffers(self.pool, &.{self.cmdbuf});
        self.cmdbuf = .null_handle;
    }

    pub fn makeRenderCommandEncoder(
        self: *CommandBuffer,
        descriptor: RenderPassDescriptor,
    ) !RenderCommandEncoder {
        try self.swapchain.waitForAllFences();

        const cmdbuf = self.cmdbuf;
        try self.gc.dev.beginCommandBuffer(cmdbuf, &.{});

        const clear_color = descriptor.color_attachment.clear_color;
        var clear_values: [2]vk.ClearValue = undefined;
        clear_values[0] = vk.ClearValue{
            .color = .{ .float_32 = .{
                clear_color.red,
                clear_color.green,
                clear_color.blue,
                clear_color.alpha,
            } },
        };
        var clear_value_count: u32 = 1;
        if (descriptor.depth_attachment) |depth_attachment| {
            clear_values[1] = vk.ClearValue{
                .depth_stencil = .{
                    .depth = depth_attachment.clear_depth,
                    .stencil = 0,
                },
            };
            clear_value_count = 2;
        }

        const uses_depth = descriptor.depth_attachment != null;
        const pass = try self.renderPassSetup(descriptor);
        self.uses_current_drawable = pass.uses_current_drawable;

        self.gc.dev.cmdBeginRenderPass(cmdbuf, &.{
            .render_pass = pass.render_pass,
            .framebuffer = pass.framebuffer,
            .render_area = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = pass.extent,
            },
            .clear_value_count = clear_value_count,
            .p_clear_values = &clear_values,
        }, .@"inline");

        const viewport = vk.Viewport{
            .x = 0,
            .y = 0,
            .width = @floatFromInt(pass.extent.width),
            .height = @floatFromInt(pass.extent.height),
            .min_depth = 0,
            .max_depth = 1,
        };
        const scissor = vk.Rect2D{
            .offset = .{ .x = 0, .y = 0 },
            .extent = pass.extent,
        };
        self.gc.dev.cmdSetViewport(cmdbuf, 0, &.{viewport});
        self.gc.dev.cmdSetScissor(cmdbuf, 0, &.{scissor});

        return .{
            .gc = self.gc,
            .cmdbuf = cmdbuf,
            .uses_depth_pass = uses_depth,
            .color_layout = pass.color_layout,
            .color_final_layout = pass.color_final_layout,
            .resolve_layout = pass.resolve_layout,
            .depth_layout = pass.depth_layout,
            .sample_count = pass.sample_count,
        };
    }

    pub fn makeBlitCommandEncoder(self: *CommandBuffer) !BlitCommandEncoder {
        try self.swapchain.waitForAllFences();
        try self.gc.dev.beginCommandBuffer(self.cmdbuf, &.{
            .flags = .{ .one_time_submit_bit = true },
        });
        return .{
            .gc = self.gc,
            .cmdbuf = self.cmdbuf,
        };
    }

    pub fn makeComputeCommandEncoder(self: *CommandBuffer) !ComputeCommandEncoder {
        try self.swapchain.waitForAllFences();
        try self.gc.dev.beginCommandBuffer(self.cmdbuf, &.{
            .flags = .{ .one_time_submit_bit = true },
        });
        return .{
            .gc = self.gc,
            .cmdbuf = self.cmdbuf,
        };
    }

    pub fn presentDrawable(self: *CommandBuffer) !void {
        if (!self.uses_current_drawable) return error.PresentRequiresCurrentDrawable;
        self.present_requested = true;
    }

    pub fn commit(self: *CommandBuffer) !void {
        defer self.destroyTemporaryRenderPassResources();
        if (self.present_requested) {
            _ = try self.swapchain.present(self.cmdbuf);
        } else {
            try self.gc.dev.queueSubmit(self.gc.graphics_queue.handle, &.{.{
                .command_buffer_count = 1,
                .p_command_buffers = @ptrCast(&self.cmdbuf),
            }}, .null_handle);
        }
        try self.gc.dev.queueWaitIdle(self.gc.graphics_queue.handle);
    }

    fn renderPassSetup(self: *CommandBuffer, descriptor: RenderPassDescriptor) !RenderPassSetup {
        const uses_current_drawable = switch (descriptor.color_attachment.target) {
            .current_drawable => true,
            .texture_view => false,
        };
        if (uses_current_drawable) {
            if (descriptor.color_attachment.resolve_target != null) return error.InvalidRenderPassAttachment;
            if (descriptor.depth_attachment) |depth_attachment| {
                switch (depth_attachment.target) {
                    .current_drawable => {},
                    .texture_view => return error.InvalidRenderPassAttachment,
                }
            }
            const framebuffers = if (descriptor.depth_attachment != null) self.depth_framebuffers else self.color_framebuffers;
            return .{
                .render_pass = if (descriptor.depth_attachment != null) self.depth_render_pass else self.color_render_pass,
                .framebuffer = framebuffers[self.swapchain.image_index],
                .extent = self.swapchain.extent,
                .uses_current_drawable = true,
                .sample_count = 1,
            };
        }

        const color_view = switch (descriptor.color_attachment.target) {
            .current_drawable => unreachable,
            .texture_view => |texture_view| texture_view,
        };
        const resolve_view = descriptor.color_attachment.resolve_target;
        if (color_view.sample_count != 1 and resolve_view == null) {
            return error.InvalidRenderPassAttachment;
        }
        if (resolve_view) |view| {
            if (color_view.sample_count == 1 or
                view.sample_count != 1 or
                view.format != color_view.format or
                view.width != color_view.width or
                view.height != color_view.height)
            {
                return error.InvalidRenderPassAttachment;
            }
        }

        var attachments: [3]vk.ImageView = undefined;
        attachments[0] = color_view.handle;
        var attachment_count: u32 = 1;
        if (resolve_view) |view| {
            attachments[attachment_count] = view.handle;
            attachment_count += 1;
        }
        var depth_format: ?vk.Format = null;
        if (descriptor.depth_attachment) |depth_attachment| {
            const depth_view = switch (depth_attachment.target) {
                .current_drawable => return error.InvalidRenderPassAttachment,
                .texture_view => |texture_view| texture_view,
            };
            if (depth_view.width != color_view.width or depth_view.height != color_view.height) {
                return error.InvalidRenderPassAttachment;
            }
            if (depth_view.sample_count != color_view.sample_count) {
                return error.InvalidRenderPassAttachment;
            }
            attachments[attachment_count] = depth_view.handle;
            attachment_count += 1;
            depth_format = VulkanTexture.imageFormat(depth_view.format);
        }

        self.temporary_render_pass = try createTextureRenderPass(
            self.gc,
            VulkanTexture.imageFormat(color_view.format),
            color_view.layout.*,
            color_view.sample_count,
            resolve_view != null,
            if (resolve_view) |view| view.layout.* else .undefined,
            descriptor.depth_attachment != null,
            depth_format,
            if (descriptor.depth_attachment) |depth_attachment| switch (depth_attachment.target) {
                .current_drawable => .undefined,
                .texture_view => |depth_view| depth_view.layout.*,
            } else .undefined,
        );
        errdefer self.destroyTemporaryRenderPassResources();

        self.temporary_framebuffer = try self.gc.dev.createFramebuffer(&.{
            .render_pass = self.temporary_render_pass,
            .attachment_count = attachment_count,
            .p_attachments = &attachments,
            .width = color_view.width,
            .height = color_view.height,
            .layers = 1,
        }, null);

        return .{
            .render_pass = self.temporary_render_pass,
            .framebuffer = self.temporary_framebuffer,
            .extent = .{ .width = color_view.width, .height = color_view.height },
            .uses_current_drawable = false,
            .sample_count = color_view.sample_count,
            .color_layout = color_view.layout,
            .color_final_layout = if (resolve_view != null) .color_attachment_optimal else .shader_read_only_optimal,
            .resolve_layout = if (resolve_view) |view| view.layout else null,
            .depth_layout = if (descriptor.depth_attachment) |depth_attachment| switch (depth_attachment.target) {
                .current_drawable => null,
                .texture_view => |depth_view| depth_view.layout,
            } else null,
        };
    }

    fn destroyTemporaryRenderPassResources(self: *CommandBuffer) void {
        if (self.temporary_framebuffer != .null_handle) {
            self.gc.dev.destroyFramebuffer(self.temporary_framebuffer, null);
            self.temporary_framebuffer = .null_handle;
        }
        if (self.temporary_render_pass != .null_handle) {
            self.gc.dev.destroyRenderPass(self.temporary_render_pass, null);
            self.temporary_render_pass = .null_handle;
        }
    }
};

const RenderPassSetup = struct {
    render_pass: vk.RenderPass,
    framebuffer: vk.Framebuffer,
    extent: vk.Extent2D,
    uses_current_drawable: bool,
    sample_count: u32,
    color_layout: ?*vk.ImageLayout = null,
    color_final_layout: vk.ImageLayout = .shader_read_only_optimal,
    resolve_layout: ?*vk.ImageLayout = null,
    depth_layout: ?*vk.ImageLayout = null,
};

fn createTextureRenderPass(
    gc: *const GraphicsContext,
    color_format: vk.Format,
    color_initial_layout: vk.ImageLayout,
    color_sample_count: u32,
    uses_resolve: bool,
    resolve_initial_layout: vk.ImageLayout,
    uses_depth: bool,
    depth_format: ?vk.Format,
    depth_initial_layout: vk.ImageLayout,
) !vk.RenderPass {
    var attachments: [3]vk.AttachmentDescription = undefined;
    attachments[0] = .{
        .format = color_format,
        .samples = VulkanTexture.sampleCountFlags(color_sample_count),
        .load_op = .clear,
        .store_op = .store,
        .stencil_load_op = .dont_care,
        .stencil_store_op = .dont_care,
        .initial_layout = color_initial_layout,
        .final_layout = if (uses_resolve) .color_attachment_optimal else .shader_read_only_optimal,
    };

    var attachment_count: u32 = 1;
    var resolve_attachment_ref: vk.AttachmentReference = undefined;
    if (uses_resolve) {
        attachments[attachment_count] = .{
            .format = color_format,
            .samples = .{ .@"1_bit" = true },
            .load_op = .dont_care,
            .store_op = .store,
            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,
            .initial_layout = resolve_initial_layout,
            .final_layout = .shader_read_only_optimal,
        };
        resolve_attachment_ref = .{
            .attachment = attachment_count,
            .layout = .color_attachment_optimal,
        };
        attachment_count += 1;
    }

    var depth_attachment_ref: vk.AttachmentReference = undefined;
    if (uses_depth) {
        attachments[attachment_count] = .{
            .format = depth_format orelse return error.InvalidRenderPassAttachment,
            .samples = VulkanTexture.sampleCountFlags(color_sample_count),
            .load_op = .clear,
            .store_op = .dont_care,
            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,
            .initial_layout = depth_initial_layout,
            .final_layout = .depth_stencil_attachment_optimal,
        };
        depth_attachment_ref = .{
            .attachment = attachment_count,
            .layout = .depth_stencil_attachment_optimal,
        };
        attachment_count += 1;
    }

    const color_attachment_ref = vk.AttachmentReference{
        .attachment = 0,
        .layout = .color_attachment_optimal,
    };
    const subpass = vk.SubpassDescription{
        .pipeline_bind_point = .graphics,
        .color_attachment_count = 1,
        .p_color_attachments = @ptrCast(&color_attachment_ref),
        .p_resolve_attachments = if (uses_resolve) @ptrCast(&resolve_attachment_ref) else null,
        .p_depth_stencil_attachment = if (uses_depth) &depth_attachment_ref else null,
    };

    return try gc.dev.createRenderPass(&.{
        .attachment_count = attachment_count,
        .p_attachments = &attachments,
        .subpass_count = 1,
        .p_subpasses = @ptrCast(&subpass),
    }, null);
}

pub const RenderCommandEncoder = struct {
    gc: *const GraphicsContext,
    cmdbuf: vk.CommandBuffer,
    uses_depth_pass: bool,
    color_layout: ?*vk.ImageLayout = null,
    color_final_layout: vk.ImageLayout = .shader_read_only_optimal,
    resolve_layout: ?*vk.ImageLayout = null,
    depth_layout: ?*vk.ImageLayout = null,
    sample_count: u32 = 1,
    index_buffer: vk.Buffer = .null_handle,
    pipeline_layout: vk.PipelineLayout = .null_handle,

    pub fn setRenderPipelineState(self: *RenderCommandEncoder, pipeline: *VulkanRenderPipelineState) !void {
        if (pipeline.uses_depth != self.uses_depth_pass) return core.CommandEncodingError.DepthStateRenderPassMismatch;
        if (pipeline.sample_count != self.sample_count) return core.CommandEncodingError.SampleCountRenderPassMismatch;
        self.gc.dev.cmdBindPipeline(self.cmdbuf, .graphics, pipeline.handle);
        self.pipeline_layout = pipeline.layout;
    }

    pub fn setVertexBuffer(
        self: *RenderCommandEncoder,
        buffer: *VulkanBuffer,
        binding: core.VertexBufferBinding,
    ) !void {
        try binding.validate();
        const buffers = [_]vk.Buffer{buffer.handle};
        const offsets = [_]vk.DeviceSize{binding.offset};
        self.gc.dev.cmdBindVertexBuffers(self.cmdbuf, binding.index, &buffers, &offsets);
    }

    pub fn setIndexBuffer(self: *RenderCommandEncoder, buffer: *VulkanBuffer) !void {
        self.index_buffer = buffer.handle;
    }

    pub fn setBindGroup(
        self: *RenderCommandEncoder,
        bind_group: *const VulkanBindGroup,
        binding: core.BindGroupBinding,
    ) !void {
        try binding.validate();
        if (self.pipeline_layout == .null_handle) return core.CommandEncodingError.MissingRenderPipelineState;

        self.gc.dev.cmdBindDescriptorSets(
            self.cmdbuf,
            .graphics,
            self.pipeline_layout,
            binding.index,
            &.{bind_group.set},
            null,
        );
    }

    pub fn drawPrimitives(
        self: *RenderCommandEncoder,
        descriptor: core.DrawPrimitivesDescriptor,
    ) !void {
        try descriptor.validate();
        self.gc.dev.cmdDraw(
            self.cmdbuf,
            descriptor.vertex_count,
            descriptor.instance_count,
            descriptor.vertex_start,
            0,
        );
    }

    pub fn drawIndexedPrimitives(
        self: *RenderCommandEncoder,
        descriptor: core.DrawIndexedPrimitivesDescriptor,
    ) !void {
        try descriptor.validate();
        self.gc.dev.cmdBindIndexBuffer(
            self.cmdbuf,
            self.index_buffer,
            descriptor.index_buffer_offset,
            indexType(descriptor.index_type),
        );
        self.gc.dev.cmdDrawIndexed(
            self.cmdbuf,
            descriptor.index_count,
            descriptor.instance_count,
            0,
            0,
            0,
        );
    }

    pub fn endEncoding(self: *RenderCommandEncoder) !void {
        self.gc.dev.cmdEndRenderPass(self.cmdbuf);
        if (self.color_layout) |layout| layout.* = self.color_final_layout;
        if (self.resolve_layout) |layout| layout.* = .shader_read_only_optimal;
        if (self.depth_layout) |layout| layout.* = .depth_stencil_attachment_optimal;
        try self.gc.dev.endCommandBuffer(self.cmdbuf);
    }
};

pub const BlitCommandEncoder = struct {
    gc: *const GraphicsContext,
    cmdbuf: vk.CommandBuffer,

    pub fn copyBufferToBuffer(
        self: *BlitCommandEncoder,
        source: *const VulkanBuffer,
        destination: *const VulkanBuffer,
        descriptor: core.CopyBufferToBufferDescriptor,
    ) !void {
        const copy = vk.BufferCopy{
            .src_offset = descriptor.source_offset,
            .dst_offset = descriptor.destination_offset,
            .size = descriptor.size,
        };
        self.gc.dev.cmdCopyBuffer(self.cmdbuf, source.handle, destination.handle, &.{copy});
    }

    pub fn copyBufferToTexture(
        self: *BlitCommandEncoder,
        source: *const VulkanBuffer,
        destination: *VulkanTexture,
        resolved: core.ResolvedBufferTextureCopy,
    ) !void {
        destination.transitionLayout(self.cmdbuf, destination.layout, .transfer_dst_optimal);
        self.gc.dev.cmdCopyBufferToImage(
            self.cmdbuf,
            source.handle,
            destination.handle,
            .transfer_dst_optimal,
            &.{bufferImageCopy(destination, resolved)},
        );
        destination.transitionLayout(self.cmdbuf, .transfer_dst_optimal, .shader_read_only_optimal);
        destination.layout = .shader_read_only_optimal;
    }

    pub fn copyTextureToBuffer(
        self: *BlitCommandEncoder,
        source: *VulkanTexture,
        destination: *const VulkanBuffer,
        resolved: core.ResolvedBufferTextureCopy,
    ) !void {
        const old_layout = source.layout;
        source.transitionLayout(self.cmdbuf, old_layout, .transfer_src_optimal);
        self.gc.dev.cmdCopyImageToBuffer(
            self.cmdbuf,
            source.handle,
            .transfer_src_optimal,
            destination.handle,
            &.{bufferImageCopy(source, resolved)},
        );
        source.transitionLayout(self.cmdbuf, .transfer_src_optimal, old_layout);
        source.layout = old_layout;
    }

    pub fn endEncoding(self: *BlitCommandEncoder) !void {
        try self.gc.dev.endCommandBuffer(self.cmdbuf);
    }
};

pub const ComputeCommandEncoder = struct {
    gc: *const GraphicsContext,
    cmdbuf: vk.CommandBuffer,
    pipeline_layout: vk.PipelineLayout = .null_handle,

    pub fn setComputePipelineState(self: *ComputeCommandEncoder, pipeline: *VulkanComputePipelineState) !void {
        self.gc.dev.cmdBindPipeline(self.cmdbuf, .compute, pipeline.handle);
        self.pipeline_layout = pipeline.layout;
    }

    pub fn setBindGroup(
        self: *ComputeCommandEncoder,
        bind_group: *const VulkanBindGroup,
        binding: core.BindGroupBinding,
    ) !void {
        try binding.validate();
        if (self.pipeline_layout == .null_handle) return core.CommandEncodingError.MissingComputePipelineState;

        for (bind_group.entries) |entry| switch (entry.resource) {
            .storage_texture => |texture_view| texture_view.transitionLayout(self.cmdbuf, .general),
            else => {},
        };

        self.gc.dev.cmdBindDescriptorSets(
            self.cmdbuf,
            .compute,
            self.pipeline_layout,
            binding.index,
            &.{bind_group.set},
            null,
        );
    }

    pub fn dispatchThreadgroups(
        self: *ComputeCommandEncoder,
        descriptor: core.DispatchThreadgroupsDescriptor,
    ) !void {
        try descriptor.validate();
        self.gc.dev.cmdDispatch(
            self.cmdbuf,
            descriptor.threadgroup_count_x,
            descriptor.threadgroup_count_y,
            descriptor.threadgroup_count_z,
        );
    }

    pub fn endEncoding(self: *ComputeCommandEncoder) !void {
        try self.gc.dev.endCommandBuffer(self.cmdbuf);
    }
};

fn bufferImageCopy(texture: *const VulkanTexture, resolved: core.ResolvedBufferTextureCopy) vk.BufferImageCopy {
    return .{
        .buffer_offset = resolved.buffer_offset,
        .buffer_row_length = @intCast(resolved.bytes_per_row / resolved.bytes_per_pixel),
        .buffer_image_height = @intCast(resolved.bytes_per_image / resolved.bytes_per_row),
        .image_subresource = .{
            .aspect_mask = .{ .color_bit = true },
            .mip_level = resolved.mip_level,
            .base_array_layer = if (texture.descriptor.dimension == .three_d) 0 else resolved.slice,
            .layer_count = 1,
        },
        .image_offset = .{
            .x = @intCast(resolved.region.origin.x),
            .y = @intCast(resolved.region.origin.y),
            .z = if (texture.descriptor.dimension == .three_d) @intCast(resolved.region.origin.z) else 0,
        },
        .image_extent = .{
            .width = resolved.region.size.width,
            .height = resolved.region.size.height,
            .depth = if (texture.descriptor.dimension == .three_d) resolved.region.size.depth else 1,
        },
    };
}

fn indexType(index_type: core.IndexType) vk.IndexType {
    return switch (index_type) {
        .uint16 => .uint16,
        .uint32 => .uint32,
    };
}
