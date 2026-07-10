const std = @import("std");
const vk = @import("vulkan");
const core = @import("../../core.zig");
const VulkanAdvancedBinding = @import("advanced_binding.zig");
const VulkanAccelerationStructure = @import("acceleration_structure.zig");
const VulkanBindGroup = @import("bind_group.zig").VulkanBindGroup;
const VulkanBuffer = @import("buffer.zig");
const VulkanComputePipelineState = @import("compute_pipeline.zig");
const VulkanRayTracingPipelineState = @import("ray_tracing_pipeline.zig");
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
    color_attachments: [core.default_max_color_attachments]RenderPassColorAttachmentDescriptor,
    color_attachment_count: usize,
    depth_attachment: ?RenderPassDepthAttachmentDescriptor = null,

    fn colorAttachmentSlice(self: *const RenderPassDescriptor) []const RenderPassColorAttachmentDescriptor {
        return self.color_attachments[0..self.color_attachment_count];
    }
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
    temporary_blit_buffers: std.ArrayList(VulkanBuffer) = .empty,

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
        self.destroyTemporaryBlitResources();
        self.temporary_blit_buffers.deinit(self.gc.allocator);
        self.gc.dev.freeCommandBuffers(self.pool, &.{self.cmdbuf});
        self.cmdbuf = .null_handle;
    }

    pub fn setLabel(self: *CommandBuffer, label_value: ?[]const u8) void {
        self.gc.setDebugName(.command_buffer, GraphicsContext.debugObjectHandle(self.cmdbuf), label_value);
    }

    pub fn pushDebugGroup(self: *CommandBuffer, label_value: []const u8) void {
        _ = self;
        _ = label_value;
    }

    pub fn popDebugGroup(self: *CommandBuffer) void {
        _ = self;
    }

    pub fn insertDebugSignpost(self: *CommandBuffer, label_value: []const u8) void {
        _ = self;
        _ = label_value;
    }

    pub fn makeRenderCommandEncoder(
        self: *CommandBuffer,
        descriptor: RenderPassDescriptor,
    ) !RenderCommandEncoder {
        try self.swapchain.waitForAllFences();

        const cmdbuf = self.cmdbuf;
        try self.gc.dev.beginCommandBuffer(cmdbuf, &.{});

        const color_attachments = descriptor.colorAttachmentSlice();
        var clear_values: [core.default_max_color_attachments + 1]vk.ClearValue = undefined;
        for (color_attachments, 0..) |color_attachment, i| {
            const clear_color = color_attachment.clear_color;
            clear_values[i] = vk.ClearValue{
                .color = .{ .float_32 = .{
                    clear_color.red,
                    clear_color.green,
                    clear_color.blue,
                    clear_color.alpha,
                } },
            };
        }
        var clear_value_count: u32 = @intCast(color_attachments.len);
        if (descriptor.depth_attachment) |depth_attachment| {
            clear_values[clear_value_count] = vk.ClearValue{
                .depth_stencil = .{
                    .depth = depth_attachment.clear_depth,
                    .stencil = 0,
                },
            };
            clear_value_count += 1;
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
            .color_layouts = pass.color_layouts,
            .color_final_layouts = pass.color_final_layouts,
            .color_layout_count = pass.color_layout_count,
            .resolve_layout = pass.resolve_layout,
            .resolve_layouts = pass.resolve_layouts,
            .resolve_layout_count = pass.resolve_layout_count,
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
            .temporary_buffers = &self.temporary_blit_buffers,
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

    pub fn encodeAccelerationStructureBuild(
        self: *CommandBuffer,
        plan: core.AccelerationStructureBuildPlan,
        acceleration_structure: *VulkanAccelerationStructure,
        scratch: *const VulkanBuffer,
        scratch_offset: u64,
        instance_source: ?*const VulkanAccelerationStructure,
        instance_sources: []const *const VulkanAccelerationStructure,
        geometries: []const VulkanAccelerationStructure.GeometryInput,
    ) core.AdvancedFeatureError!void {
        _ = plan;
        if (acceleration_structure.kind == .top_level) {
            if (instance_sources.len != 0) {
                try acceleration_structure.writeTopLevelInstances(instance_sources);
            } else {
                const source = instance_source orelse return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
                try acceleration_structure.writeTopLevelInstance(source);
            }
        }
        const scratch_address = try acceleration_structure.scratchAddress(scratch, scratch_offset);
        var geometry_buffer: [32]vk.AccelerationStructureGeometryKHR = undefined;
        var range_buffer: [32]vk.AccelerationStructureBuildRangeInfoKHR = undefined;
        if (geometries.len > geometry_buffer.len) {
            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
        }

        const geometry_count: u32 = if (geometries.len != 0) @intCast(geometries.len) else 1;
        if (geometries.len != 0) {
            if (acceleration_structure.kind != .bottom_level) {
                return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
            }
            for (geometries, 0..) |geometry_input, i| {
                geometry_buffer[i] = try VulkanAccelerationStructure.buildGeometryFromInput(geometry_input);
                range_buffer[i] = VulkanAccelerationStructure.buildRangeFromInput(geometry_input);
            }
        } else {
            const geometry_address = try acceleration_structure.geometryAddress();
            geometry_buffer[0] = acceleration_structure.buildGeometry(geometry_address);
            range_buffer[0] = acceleration_structure.buildRange();
        }

        const build_info = vk.AccelerationStructureBuildGeometryInfoKHR{
            .type = acceleration_structure.structureType(),
            .flags = .{ .prefer_fast_trace_bit_khr = true },
            .mode = .build_khr,
            .dst_acceleration_structure = acceleration_structure.handle,
            .geometry_count = geometry_count,
            .p_geometries = @ptrCast(&geometry_buffer),
            .scratch_data = .{ .device_address = scratch_address },
        };
        var range_ptrs_buffer: [32][*]const vk.AccelerationStructureBuildRangeInfoKHR = undefined;
        for (0..geometry_count) |i| {
            range_ptrs_buffer[i] = @ptrCast(&range_buffer[i]);
        }
        const range_ptrs = range_ptrs_buffer[0..geometry_count];

        self.swapchain.waitForAllFences() catch return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
        self.gc.dev.beginCommandBuffer(self.cmdbuf, &.{
            .flags = .{ .one_time_submit_bit = true },
        }) catch return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
        self.gc.dev.cmdBuildAccelerationStructuresKHR(self.cmdbuf, &.{build_info}, range_ptrs);
        self.gc.dev.endCommandBuffer(self.cmdbuf) catch return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
        acceleration_structure.markBuilt();
    }

    pub fn traceRays(
        self: *CommandBuffer,
        pipeline: *const VulkanRayTracingPipelineState,
        dispatch: core.RayDispatchDescriptor,
    ) core.AdvancedFeatureError!void {
        self.swapchain.waitForAllFences() catch return core.AdvancedFeatureError.InvalidRayTracingPipeline;
        self.gc.dev.beginCommandBuffer(self.cmdbuf, &.{
            .flags = .{ .one_time_submit_bit = true },
        }) catch return core.AdvancedFeatureError.InvalidRayTracingPipeline;
        self.gc.dev.cmdBindPipeline(self.cmdbuf, .ray_tracing_khr, pipeline.handle);
        self.gc.dev.cmdTraceRaysKHR(
            self.cmdbuf,
            &pipeline.raygen_region,
            &pipeline.miss_region,
            &pipeline.hit_region,
            &pipeline.callable_region,
            dispatch.width,
            dispatch.height,
            dispatch.depth,
        );
        self.gc.dev.endCommandBuffer(self.cmdbuf) catch return core.AdvancedFeatureError.InvalidRayTracingPipeline;
    }

    pub fn traceRaysToDrawable(
        self: *CommandBuffer,
        pipeline: *VulkanRayTracingPipelineState,
        top_level: *const VulkanAccelerationStructure,
        output: *const VulkanTextureView,
        dispatch: core.RayDispatchDescriptor,
    ) core.AdvancedFeatureError!void {
        self.swapchain.waitForAllFences() catch return core.AdvancedFeatureError.InvalidRayTracingPipeline;
        try pipeline.updateDescriptorSet(top_level, output, dispatch);

        self.gc.dev.beginCommandBuffer(self.cmdbuf, &.{
            .flags = .{ .one_time_submit_bit = true },
        }) catch return core.AdvancedFeatureError.InvalidRayTracingPipeline;

        output.transitionLayout(self.cmdbuf, .general);
        self.gc.dev.cmdBindPipeline(self.cmdbuf, .ray_tracing_khr, pipeline.handle);
        self.gc.dev.cmdBindDescriptorSets(
            self.cmdbuf,
            .ray_tracing_khr,
            pipeline.layout,
            0,
            &.{pipeline.descriptor_set},
            null,
        );
        self.gc.dev.cmdTraceRaysKHR(
            self.cmdbuf,
            &pipeline.raygen_region,
            &pipeline.miss_region,
            &pipeline.hit_region,
            &pipeline.callable_region,
            dispatch.width,
            dispatch.height,
            dispatch.depth,
        );

        output.transitionLayout(self.cmdbuf, .transfer_src_optimal);
        const swapchain_image = self.swapchain.currentImageHandle();
        transitionSwapchainImage(
            self.gc,
            self.cmdbuf,
            swapchain_image,
            .undefined,
            .transfer_dst_optimal,
            .{},
            .{ .transfer_write_bit = true },
            .{ .top_of_pipe_bit = true },
            .{ .transfer_bit = true },
        );
        const copy = vk.ImageCopy{
            .src_subresource = .{
                .aspect_mask = .{ .color_bit = true },
                .mip_level = 0,
                .base_array_layer = 0,
                .layer_count = 1,
            },
            .src_offset = .{ .x = 0, .y = 0, .z = 0 },
            .dst_subresource = .{
                .aspect_mask = .{ .color_bit = true },
                .mip_level = 0,
                .base_array_layer = 0,
                .layer_count = 1,
            },
            .dst_offset = .{ .x = 0, .y = 0, .z = 0 },
            .extent = .{
                .width = @min(output.width, self.swapchain.extent.width),
                .height = @min(output.height, self.swapchain.extent.height),
                .depth = 1,
            },
        };
        self.gc.dev.cmdCopyImage(
            self.cmdbuf,
            output.image,
            .transfer_src_optimal,
            swapchain_image,
            .transfer_dst_optimal,
            &.{copy},
        );
        transitionSwapchainImage(
            self.gc,
            self.cmdbuf,
            swapchain_image,
            .transfer_dst_optimal,
            .present_src_khr,
            .{ .transfer_write_bit = true },
            .{ .memory_read_bit = true },
            .{ .transfer_bit = true },
            .{ .bottom_of_pipe_bit = true },
        );

        self.gc.dev.endCommandBuffer(self.cmdbuf) catch return core.AdvancedFeatureError.InvalidRayTracingPipeline;
        self.present_requested = true;
        self.uses_current_drawable = true;
    }

    pub fn presentDrawable(self: *CommandBuffer) !void {
        if (!self.uses_current_drawable) return error.PresentRequiresCurrentDrawable;
        self.present_requested = true;
    }

    pub fn commit(self: *CommandBuffer) !void {
        defer self.destroyTemporaryRenderPassResources();
        defer self.destroyTemporaryBlitResources();
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
        const color_attachments = descriptor.colorAttachmentSlice();
        const first_color_attachment = color_attachments[0];
        const uses_current_drawable = switch (first_color_attachment.target) {
            .current_drawable => true,
            .texture_view => false,
        };
        if (uses_current_drawable) {
            if (color_attachments.len != 1) return error.InvalidRenderPassAttachment;
            if (first_color_attachment.resolve_target != null) return error.InvalidRenderPassAttachment;
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
                .color_layout_count = 0,
                .resolve_layout_count = 0,
            };
        }

        var color_views: [core.default_max_color_attachments]*const VulkanTextureView = undefined;
        var color_formats: [core.default_max_color_attachments]vk.Format = undefined;
        var color_initial_layouts: [core.default_max_color_attachments]vk.ImageLayout = undefined;
        var resolve_views: [core.default_max_color_attachments]?*const VulkanTextureView = undefined;
        var resolve_initial_layouts: [core.default_max_color_attachments]vk.ImageLayout = undefined;
        const color_view = switch (first_color_attachment.target) {
            .current_drawable => unreachable,
            .texture_view => |texture_view| texture_view,
        };
        for (color_attachments, 0..) |attachment, i| {
            const attachment_view = switch (attachment.target) {
                .current_drawable => return error.InvalidRenderPassAttachment,
                .texture_view => |texture_view| texture_view,
            };
            if (attachment_view.width != color_view.width or attachment_view.height != color_view.height) {
                return error.InvalidRenderPassAttachment;
            }
            if (attachment_view.sample_count != color_view.sample_count) {
                return error.InvalidRenderPassAttachment;
            }
            const resolve_view = attachment.resolve_target;
            if (attachment_view.sample_count != 1 and resolve_view == null) {
                return error.InvalidRenderPassAttachment;
            }
            if (resolve_view) |view| {
                if (attachment_view.sample_count == 1 or
                    view.sample_count != 1 or
                    view.format != attachment_view.format or
                    view.width != attachment_view.width or
                    view.height != attachment_view.height)
                {
                    return error.InvalidRenderPassAttachment;
                }
            }
            color_views[i] = attachment_view;
            color_formats[i] = VulkanTexture.imageFormat(attachment_view.format);
            color_initial_layouts[i] = attachment_view.layout.*;
            resolve_views[i] = resolve_view;
            resolve_initial_layouts[i] = if (resolve_view) |view| view.layout.* else .undefined;
        }
        const uses_resolve = color_view.sample_count != 1;

        var attachments: [core.default_max_color_attachments * 2 + 1]vk.ImageView = undefined;
        var attachment_count: u32 = 0;
        for (color_views[0..color_attachments.len]) |view| {
            attachments[attachment_count] = view.handle;
            attachment_count += 1;
        }
        if (uses_resolve) {
            for (resolve_views[0..color_attachments.len]) |maybe_view| {
                const view = maybe_view orelse return error.InvalidRenderPassAttachment;
                attachments[attachment_count] = view.handle;
                attachment_count += 1;
            }
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
            color_formats[0..color_attachments.len],
            color_initial_layouts[0..color_attachments.len],
            color_view.sample_count,
            uses_resolve,
            resolve_initial_layouts[0..color_attachments.len],
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

        var color_layouts_out: [core.default_max_color_attachments]?*vk.ImageLayout = .{null} ** core.default_max_color_attachments;
        var color_final_layouts_out: [core.default_max_color_attachments]vk.ImageLayout = .{.shader_read_only_optimal} ** core.default_max_color_attachments;
        var resolve_layouts_out: [core.default_max_color_attachments]?*vk.ImageLayout = .{null} ** core.default_max_color_attachments;
        for (color_views[0..color_attachments.len], 0..) |view, i| {
            color_layouts_out[i] = view.layout;
            color_final_layouts_out[i] = if (uses_resolve) .color_attachment_optimal else .shader_read_only_optimal;
        }
        if (uses_resolve) {
            for (resolve_views[0..color_attachments.len], 0..) |maybe_view, i| {
                resolve_layouts_out[i] = (maybe_view orelse return error.InvalidRenderPassAttachment).layout;
            }
        }

        return .{
            .render_pass = self.temporary_render_pass,
            .framebuffer = self.temporary_framebuffer,
            .extent = .{ .width = color_view.width, .height = color_view.height },
            .uses_current_drawable = false,
            .sample_count = color_view.sample_count,
            .color_layout = color_view.layout,
            .color_final_layout = if (uses_resolve) .color_attachment_optimal else .shader_read_only_optimal,
            .color_layouts = color_layouts_out,
            .color_final_layouts = color_final_layouts_out,
            .color_layout_count = color_attachments.len,
            .resolve_layout = if (uses_resolve) (resolve_views[0] orelse return error.InvalidRenderPassAttachment).layout else null,
            .resolve_layouts = resolve_layouts_out,
            .resolve_layout_count = if (uses_resolve) color_attachments.len else 0,
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

    fn destroyTemporaryBlitResources(self: *CommandBuffer) void {
        for (self.temporary_blit_buffers.items) |*buffer| {
            buffer.deinit();
        }
        self.temporary_blit_buffers.clearRetainingCapacity();
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
    color_layouts: [core.default_max_color_attachments]?*vk.ImageLayout = .{null} ** core.default_max_color_attachments,
    color_final_layouts: [core.default_max_color_attachments]vk.ImageLayout = .{.shader_read_only_optimal} ** core.default_max_color_attachments,
    color_layout_count: usize = 0,
    resolve_layout: ?*vk.ImageLayout = null,
    resolve_layouts: [core.default_max_color_attachments]?*vk.ImageLayout = .{null} ** core.default_max_color_attachments,
    resolve_layout_count: usize = 0,
    depth_layout: ?*vk.ImageLayout = null,
};

fn createTextureRenderPass(
    gc: *const GraphicsContext,
    color_formats: []const vk.Format,
    color_initial_layouts: []const vk.ImageLayout,
    color_sample_count: u32,
    uses_resolve: bool,
    resolve_initial_layouts: []const vk.ImageLayout,
    uses_depth: bool,
    depth_format: ?vk.Format,
    depth_initial_layout: vk.ImageLayout,
) !vk.RenderPass {
    var attachments: [core.default_max_color_attachments * 2 + 1]vk.AttachmentDescription = undefined;
    var color_attachment_refs: [core.default_max_color_attachments]vk.AttachmentReference = undefined;
    var resolve_attachment_refs: [core.default_max_color_attachments]vk.AttachmentReference = undefined;
    var attachment_count: u32 = 0;
    for (color_formats, color_initial_layouts, 0..) |color_format, color_initial_layout, i| {
        attachments[attachment_count] = .{
            .format = color_format,
            .samples = VulkanTexture.sampleCountFlags(color_sample_count),
            .load_op = .clear,
            .store_op = .store,
            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,
            .initial_layout = color_initial_layout,
            .final_layout = if (uses_resolve) .color_attachment_optimal else .shader_read_only_optimal,
        };
        color_attachment_refs[i] = .{
            .attachment = attachment_count,
            .layout = .color_attachment_optimal,
        };
        attachment_count += 1;
    }
    if (uses_resolve) {
        for (color_formats, resolve_initial_layouts, 0..) |color_format, resolve_initial_layout, i| {
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
            resolve_attachment_refs[i] = .{
                .attachment = attachment_count,
                .layout = .color_attachment_optimal,
            };
            attachment_count += 1;
        }
    }

    var depth_attachment_ref: vk.AttachmentReference = undefined;
    if (uses_depth) {
        attachments[attachment_count] = .{
            .format = depth_format orelse return error.InvalidRenderPassAttachment,
            .samples = VulkanTexture.sampleCountFlags(color_sample_count),
            .load_op = .clear,
            .store_op = .dont_care,
            .stencil_load_op = if (depth_format == .d32_sfloat_s8_uint) .clear else .dont_care,
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

    const color_attachment_ref_slice = color_attachment_refs[0..color_formats.len];
    const resolve_attachment_ref_slice = resolve_attachment_refs[0..color_formats.len];
    const subpass = vk.SubpassDescription{
        .pipeline_bind_point = .graphics,
        .color_attachment_count = @intCast(color_formats.len),
        .p_color_attachments = color_attachment_ref_slice.ptr,
        .p_resolve_attachments = if (uses_resolve) resolve_attachment_ref_slice.ptr else null,
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
    color_layouts: [core.default_max_color_attachments]?*vk.ImageLayout = .{null} ** core.default_max_color_attachments,
    color_final_layouts: [core.default_max_color_attachments]vk.ImageLayout = .{.shader_read_only_optimal} ** core.default_max_color_attachments,
    color_layout_count: usize = 0,
    resolve_layout: ?*vk.ImageLayout = null,
    resolve_layouts: [core.default_max_color_attachments]?*vk.ImageLayout = .{null} ** core.default_max_color_attachments,
    resolve_layout_count: usize = 0,
    depth_layout: ?*vk.ImageLayout = null,
    sample_count: u32 = 1,
    index_buffer: vk.Buffer = .null_handle,
    pipeline_layout: vk.PipelineLayout = .null_handle,

    pub fn setLabel(self: *RenderCommandEncoder, label_value: ?[]const u8) void {
        _ = self;
        _ = label_value;
    }

    pub fn pushDebugGroup(self: *RenderCommandEncoder, label_value: []const u8) void {
        self.gc.beginDebugLabel(self.cmdbuf, label_value);
    }

    pub fn popDebugGroup(self: *RenderCommandEncoder) void {
        self.gc.endDebugLabel(self.cmdbuf);
    }

    pub fn insertDebugSignpost(self: *RenderCommandEncoder, label_value: []const u8) void {
        self.gc.insertDebugLabel(self.cmdbuf, label_value);
    }

    pub fn setRenderPipelineState(self: *RenderCommandEncoder, pipeline: *VulkanRenderPipelineState) !void {
        if (pipeline.uses_depth != self.uses_depth_pass) return core.CommandEncodingError.DepthStateRenderPassMismatch;
        if (pipeline.sample_count != self.sample_count) return core.CommandEncodingError.SampleCountRenderPassMismatch;
        self.gc.dev.cmdBindPipeline(self.cmdbuf, .graphics, pipeline.handle);
        if (pipeline.depth_bias.enabled) {
            self.gc.dev.cmdSetDepthBias(
                self.cmdbuf,
                pipeline.depth_bias.constant,
                pipeline.depth_bias.clamp,
                pipeline.depth_bias.slope,
            );
        }
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
        const dynamic_offsets = try bind_group.dynamicOffsets(binding);
        defer bind_group.allocator.free(dynamic_offsets);

        self.gc.dev.cmdBindDescriptorSets(
            self.cmdbuf,
            .graphics,
            self.pipeline_layout,
            binding.index,
            &.{bind_group.set},
            if (dynamic_offsets.len == 0) null else dynamic_offsets,
        );
    }

    pub fn setResourceTable(
        self: *RenderCommandEncoder,
        table: *const VulkanAdvancedBinding.ResourceTable,
        binding: core.ResourceTableBinding,
    ) !void {
        try binding.validate();
        if (self.pipeline_layout == .null_handle) return core.CommandEncodingError.MissingRenderPipelineState;
        _ = table;
    }

    pub fn setRootConstants(
        self: *RenderCommandEncoder,
        descriptor: core.RootConstantWriteDescriptor,
        visibility: core.ShaderVisibility,
    ) !void {
        if (self.pipeline_layout == .null_handle) return core.CommandEncodingError.MissingRenderPipelineState;
        self.gc.dev.cmdPushConstants(
            self.cmdbuf,
            self.pipeline_layout,
            shaderStageFlags(visibility),
            descriptor.offset,
            @intCast(descriptor.bytes.len),
            descriptor.bytes.ptr,
        );
    }

    pub fn setViewport(self: *RenderCommandEncoder, viewport: core.Viewport) !void {
        try viewport.validate();
        self.gc.dev.cmdSetViewport(self.cmdbuf, 0, &.{.{
            .x = viewport.x,
            .y = viewport.y,
            .width = viewport.width,
            .height = viewport.height,
            .min_depth = viewport.min_depth,
            .max_depth = viewport.max_depth,
        }});
    }

    pub fn setScissorRect(self: *RenderCommandEncoder, rect: core.ScissorRect) !void {
        try rect.validate();
        self.gc.dev.cmdSetScissor(self.cmdbuf, 0, &.{.{
            .offset = .{
                .x = @intCast(rect.x),
                .y = @intCast(rect.y),
            },
            .extent = .{
                .width = rect.width,
                .height = rect.height,
            },
        }});
    }

    pub fn setBlendColor(self: *RenderCommandEncoder, color: core.BlendColor) !void {
        try color.validate();
        const constants = [4]f32{ color.red, color.green, color.blue, color.alpha };
        self.gc.dev.cmdSetBlendConstants(self.cmdbuf, &constants);
    }

    pub fn setStencilReference(self: *RenderCommandEncoder, reference: core.StencilReference) !void {
        try reference.validate();
        self.gc.dev.cmdSetStencilReference(
            self.cmdbuf,
            .{ .front_bit = true, .back_bit = true },
            reference.value,
        );
    }

    pub fn setDepthBias(self: *RenderCommandEncoder, descriptor: core.DepthBiasDescriptor) !void {
        try descriptor.validate();
        self.gc.dev.cmdSetDepthBias(
            self.cmdbuf,
            descriptor.constant,
            descriptor.clamp,
            descriptor.slope,
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
            descriptor.base_instance,
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
            descriptor.base_vertex,
            descriptor.base_instance,
        );
    }

    pub fn drawPrimitivesIndirect(
        self: *RenderCommandEncoder,
        indirect_buffer: *const VulkanBuffer,
        descriptor: core.DrawPrimitivesIndirectDescriptor,
    ) !void {
        try descriptor.validate();
        if (descriptor.draw_count != 1) return core.CommandEncodingError.UnsupportedMultiDraw;
        self.gc.dev.cmdDrawIndirect(
            self.cmdbuf,
            indirect_buffer.handle,
            descriptor.buffer_offset,
            descriptor.draw_count,
            indirectStride(descriptor.stride, 16),
        );
    }

    pub fn drawIndexedPrimitivesIndirect(
        self: *RenderCommandEncoder,
        indirect_buffer: *const VulkanBuffer,
        descriptor: core.DrawIndexedPrimitivesIndirectDescriptor,
    ) !void {
        try descriptor.validate();
        if (descriptor.draw_count != 1) return core.CommandEncodingError.UnsupportedMultiDraw;
        self.gc.dev.cmdBindIndexBuffer(
            self.cmdbuf,
            self.index_buffer,
            0,
            indexType(descriptor.index_type),
        );
        self.gc.dev.cmdDrawIndexedIndirect(
            self.cmdbuf,
            indirect_buffer.handle,
            descriptor.buffer_offset,
            descriptor.draw_count,
            indirectStride(descriptor.stride, 20),
        );
    }

    pub fn endEncoding(self: *RenderCommandEncoder) !void {
        self.gc.dev.cmdEndRenderPass(self.cmdbuf);
        for (self.color_layouts[0..self.color_layout_count], 0..) |maybe_layout, i| {
            if (maybe_layout) |layout| layout.* = self.color_final_layouts[i];
        }
        for (self.resolve_layouts[0..self.resolve_layout_count]) |maybe_layout| {
            if (maybe_layout) |layout| layout.* = .shader_read_only_optimal;
        }
        if (self.color_layout) |layout| layout.* = self.color_final_layout;
        if (self.resolve_layout) |layout| layout.* = .shader_read_only_optimal;
        if (self.depth_layout) |layout| layout.* = .depth_stencil_attachment_optimal;
        try self.gc.dev.endCommandBuffer(self.cmdbuf);
    }
};

pub const BlitCommandEncoder = struct {
    gc: *const GraphicsContext,
    cmdbuf: vk.CommandBuffer,
    temporary_buffers: *std.ArrayList(VulkanBuffer),

    pub fn setLabel(self: *BlitCommandEncoder, label_value: ?[]const u8) void {
        _ = self;
        _ = label_value;
    }

    pub fn pushDebugGroup(self: *BlitCommandEncoder, label_value: []const u8) void {
        self.gc.beginDebugLabel(self.cmdbuf, label_value);
    }

    pub fn popDebugGroup(self: *BlitCommandEncoder) void {
        self.gc.endDebugLabel(self.cmdbuf);
    }

    pub fn insertDebugSignpost(self: *BlitCommandEncoder, label_value: []const u8) void {
        self.gc.insertDebugLabel(self.cmdbuf, label_value);
    }

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

    pub fn copyTextureToTexture(
        self: *BlitCommandEncoder,
        source: *VulkanTexture,
        destination: *VulkanTexture,
        resolved: core.ResolvedTextureTextureCopy,
    ) !void {
        const old_source_layout = source.layout;
        const old_destination_layout = destination.layout;
        source.transitionLayout(self.cmdbuf, old_source_layout, .transfer_src_optimal);
        destination.transitionLayout(self.cmdbuf, old_destination_layout, .transfer_dst_optimal);
        self.gc.dev.cmdCopyImage(
            self.cmdbuf,
            source.handle,
            .transfer_src_optimal,
            destination.handle,
            .transfer_dst_optimal,
            &.{imageCopy(source, destination, resolved)},
        );
        source.transitionLayout(self.cmdbuf, .transfer_src_optimal, old_source_layout);
        destination.transitionLayout(self.cmdbuf, .transfer_dst_optimal, .shader_read_only_optimal);
        source.layout = old_source_layout;
        destination.layout = .shader_read_only_optimal;
    }

    pub fn blitTexture(
        self: *BlitCommandEncoder,
        source: *VulkanTexture,
        destination: *VulkanTexture,
        resolved: core.ResolvedBlitTexture,
    ) !void {
        const old_source_layout = source.layout;
        const old_destination_layout = destination.layout;
        source.transitionLayout(self.cmdbuf, old_source_layout, .transfer_src_optimal);
        destination.transitionLayout(self.cmdbuf, old_destination_layout, .transfer_dst_optimal);
        var slice_offset: u32 = 0;
        while (slice_offset < resolved.slice_count) : (slice_offset += 1) {
            const blit = textureBlit(source, destination, resolved, slice_offset);
            self.gc.dev.cmdBlitImage(
                self.cmdbuf,
                source.handle,
                .transfer_src_optimal,
                destination.handle,
                .transfer_dst_optimal,
                &.{blit},
                if (resolved.filter == .linear) .linear else .nearest,
            );
        }
        source.transitionLayout(self.cmdbuf, .transfer_src_optimal, old_source_layout);
        destination.transitionLayout(self.cmdbuf, .transfer_dst_optimal, .shader_read_only_optimal);
        source.layout = old_source_layout;
        destination.layout = .shader_read_only_optimal;
    }

    pub fn fillBuffer(
        self: *BlitCommandEncoder,
        buffer: *const VulkanBuffer,
        descriptor: core.FillBufferDescriptor,
    ) !void {
        if (fillBufferUsesStagingFallback(descriptor)) {
            return try self.fillBufferWithStaging(buffer, descriptor);
        }
        const repeated = @as(u32, descriptor.value) * 0x01010101;
        self.gc.dev.cmdFillBuffer(
            self.cmdbuf,
            buffer.handle,
            descriptor.offset,
            descriptor.size,
            repeated,
        );
    }

    fn fillBufferWithStaging(
        self: *BlitCommandEncoder,
        buffer: *const VulkanBuffer,
        descriptor: core.FillBufferDescriptor,
    ) !void {
        const byte_count = std.math.cast(usize, descriptor.size) orelse return core.CommandEncodingError.InvalidFillBufferRange;
        const bytes = try self.gc.allocator.alloc(u8, byte_count);
        defer self.gc.allocator.free(bytes);
        @memset(bytes, descriptor.value);

        var staging = try VulkanBuffer.init(self.gc, .{
            .length = byte_count,
            .bytes = bytes,
            .usage = .{ .copy_source = true },
            .storage_mode = .shared,
        });
        errdefer staging.deinit();
        try self.temporary_buffers.append(self.gc.allocator, staging);

        const copy = vk.BufferCopy{
            .src_offset = 0,
            .dst_offset = descriptor.offset,
            .size = descriptor.size,
        };
        self.gc.dev.cmdCopyBuffer(
            self.cmdbuf,
            self.temporary_buffers.items[self.temporary_buffers.items.len - 1].handle,
            buffer.handle,
            &.{copy},
        );
    }

    pub fn generateMipmaps(
        self: *BlitCommandEncoder,
        texture: *VulkanTexture,
        descriptor: core.ResolvedGenerateMipmapsDescriptor,
    ) !void {
        const old_layout = texture.layout;
        texture.transitionLayout(self.cmdbuf, old_layout, .transfer_dst_optimal);

        var layer_offset: u32 = 0;
        while (layer_offset < descriptor.array_layer_count) : (layer_offset += 1) {
            const layer = descriptor.base_array_layer + layer_offset;
            var level_offset: u32 = 1;
            while (level_offset < descriptor.mip_level_count) : (level_offset += 1) {
                const source_level = descriptor.base_mip_level + level_offset - 1;
                const destination_level = descriptor.base_mip_level + level_offset;

                imageMipBarrier(
                    self.gc,
                    self.cmdbuf,
                    texture,
                    source_level,
                    layer,
                    .transfer_dst_optimal,
                    .transfer_src_optimal,
                    .{ .transfer_write_bit = true },
                    .{ .transfer_read_bit = true },
                    .{ .transfer_bit = true },
                    .{ .transfer_bit = true },
                );
                self.gc.dev.cmdBlitImage(
                    self.cmdbuf,
                    texture.handle,
                    .transfer_src_optimal,
                    texture.handle,
                    .transfer_dst_optimal,
                    &.{imageBlit(texture.descriptor, source_level, destination_level, layer)},
                    .linear,
                );
                imageMipBarrier(
                    self.gc,
                    self.cmdbuf,
                    texture,
                    source_level,
                    layer,
                    .transfer_src_optimal,
                    .shader_read_only_optimal,
                    .{ .transfer_read_bit = true },
                    .{ .shader_read_bit = true },
                    .{ .transfer_bit = true },
                    .{
                        .vertex_shader_bit = true,
                        .fragment_shader_bit = true,
                        .compute_shader_bit = true,
                    },
                );
            }
            imageMipBarrier(
                self.gc,
                self.cmdbuf,
                texture,
                descriptor.base_mip_level + descriptor.mip_level_count - 1,
                layer,
                .transfer_dst_optimal,
                .shader_read_only_optimal,
                .{ .transfer_write_bit = true },
                .{ .shader_read_bit = true },
                .{ .transfer_bit = true },
                .{
                    .vertex_shader_bit = true,
                    .fragment_shader_bit = true,
                    .compute_shader_bit = true,
                },
            );
        }

        texture.layout = .shader_read_only_optimal;
    }

    pub fn bufferBarrier(
        self: *BlitCommandEncoder,
        buffer: *const VulkanBuffer,
        descriptor: core.BufferBarrierDescriptor,
    ) !void {
        applyBufferBarrier(self.gc, self.cmdbuf, buffer, descriptor);
    }

    pub fn textureBarrier(
        self: *BlitCommandEncoder,
        texture: *VulkanTexture,
        descriptor: core.TextureBarrierDescriptor,
    ) !void {
        applyTextureBarrier(self.gc, self.cmdbuf, texture, descriptor);
    }

    pub fn endEncoding(self: *BlitCommandEncoder) !void {
        try self.gc.dev.endCommandBuffer(self.cmdbuf);
    }
};

pub fn fillBufferUsesStagingFallback(descriptor: core.FillBufferDescriptor) bool {
    return descriptor.offset % 4 != 0 or descriptor.size % 4 != 0;
}

pub const FillBufferFallbackDiagnostics = struct {
    native_fills: u64 = 0,
    staging_fallbacks: u64 = 0,
    native_bytes: u64 = 0,
    staging_bytes: u64 = 0,

    pub fn totalFills(self: FillBufferFallbackDiagnostics) u64 {
        return self.native_fills + self.staging_fallbacks;
    }

    pub fn totalBytes(self: FillBufferFallbackDiagnostics) u64 {
        return self.native_bytes + self.staging_bytes;
    }
};

pub fn fillBufferFallbackDiagnostics(descriptors: []const core.FillBufferDescriptor) FillBufferFallbackDiagnostics {
    var diagnostics = FillBufferFallbackDiagnostics{};
    for (descriptors) |descriptor| {
        if (fillBufferUsesStagingFallback(descriptor)) {
            diagnostics.staging_fallbacks += 1;
            diagnostics.staging_bytes = diagnostics.staging_bytes +| descriptor.size;
        } else {
            diagnostics.native_fills += 1;
            diagnostics.native_bytes = diagnostics.native_bytes +| descriptor.size;
        }
    }
    return diagnostics;
}

pub const ComputeCommandEncoder = struct {
    gc: *const GraphicsContext,
    cmdbuf: vk.CommandBuffer,
    pipeline_layout: vk.PipelineLayout = .null_handle,

    pub fn setLabel(self: *ComputeCommandEncoder, label_value: ?[]const u8) void {
        _ = self;
        _ = label_value;
    }

    pub fn pushDebugGroup(self: *ComputeCommandEncoder, label_value: []const u8) void {
        self.gc.beginDebugLabel(self.cmdbuf, label_value);
    }

    pub fn popDebugGroup(self: *ComputeCommandEncoder) void {
        self.gc.endDebugLabel(self.cmdbuf);
    }

    pub fn insertDebugSignpost(self: *ComputeCommandEncoder, label_value: []const u8) void {
        self.gc.insertDebugLabel(self.cmdbuf, label_value);
    }

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

        for (bind_group.entries) |entry| {
            for (0..entry.resourceCount()) |resource_index| switch (entry.resourceAt(resource_index)) {
                .storage_texture => |texture_view| texture_view.transitionLayout(self.cmdbuf, .general),
                else => {},
            };
        }
        const dynamic_offsets = try bind_group.dynamicOffsets(binding);
        defer bind_group.allocator.free(dynamic_offsets);

        self.gc.dev.cmdBindDescriptorSets(
            self.cmdbuf,
            .compute,
            self.pipeline_layout,
            binding.index,
            &.{bind_group.set},
            if (dynamic_offsets.len == 0) null else dynamic_offsets,
        );
    }

    pub fn setResourceTable(
        self: *ComputeCommandEncoder,
        table: *const VulkanAdvancedBinding.ResourceTable,
        binding: core.ResourceTableBinding,
    ) !void {
        try binding.validate();
        if (self.pipeline_layout == .null_handle) return core.CommandEncodingError.MissingComputePipelineState;
        _ = table;
    }

    pub fn setRootConstants(
        self: *ComputeCommandEncoder,
        descriptor: core.RootConstantWriteDescriptor,
        visibility: core.ShaderVisibility,
    ) !void {
        if (self.pipeline_layout == .null_handle) return core.CommandEncodingError.MissingComputePipelineState;
        self.gc.dev.cmdPushConstants(
            self.cmdbuf,
            self.pipeline_layout,
            shaderStageFlags(visibility),
            descriptor.offset,
            @intCast(descriptor.bytes.len),
            descriptor.bytes.ptr,
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

    pub fn dispatchThreadgroupsIndirect(
        self: *ComputeCommandEncoder,
        indirect_buffer: *const VulkanBuffer,
        descriptor: core.DispatchThreadgroupsIndirectDescriptor,
    ) !void {
        self.gc.dev.cmdDispatchIndirect(
            self.cmdbuf,
            indirect_buffer.handle,
            descriptor.offset,
        );
    }

    pub fn bufferBarrier(
        self: *ComputeCommandEncoder,
        buffer: *const VulkanBuffer,
        descriptor: core.BufferBarrierDescriptor,
    ) !void {
        applyBufferBarrier(self.gc, self.cmdbuf, buffer, descriptor);
    }

    pub fn textureBarrier(
        self: *ComputeCommandEncoder,
        texture: *VulkanTexture,
        descriptor: core.TextureBarrierDescriptor,
    ) !void {
        applyTextureBarrier(self.gc, self.cmdbuf, texture, descriptor);
    }

    pub fn endEncoding(self: *ComputeCommandEncoder) !void {
        try self.gc.dev.endCommandBuffer(self.cmdbuf);
    }
};

fn applyBufferBarrier(
    gc: *const GraphicsContext,
    cmdbuf: vk.CommandBuffer,
    buffer: *const VulkanBuffer,
    descriptor: core.BufferBarrierDescriptor,
) void {
    const size = descriptor.size orelse @as(u64, @intCast(buffer.length_value)) - descriptor.offset;
    const barrier = vk.BufferMemoryBarrier{
        .src_access_mask = accessMaskForUsage(descriptor.before),
        .dst_access_mask = accessMaskForUsage(descriptor.after),
        .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .buffer = buffer.handle,
        .offset = descriptor.offset,
        .size = size,
    };

    gc.dev.cmdPipelineBarrier(
        cmdbuf,
        stageMaskForUsage(descriptor.before),
        stageMaskForUsage(descriptor.after),
        .{},
        null,
        &.{barrier},
        null,
    );
}

fn applyTextureBarrier(
    gc: *const GraphicsContext,
    cmdbuf: vk.CommandBuffer,
    texture: *VulkanTexture,
    descriptor: core.TextureBarrierDescriptor,
) void {
    const new_layout = imageLayoutForUsage(texture.descriptor.format, descriptor.after);
    const barrier = vk.ImageMemoryBarrier{
        .src_access_mask = accessMaskForUsage(descriptor.before),
        .dst_access_mask = accessMaskForUsage(descriptor.after),
        .old_layout = imageLayoutForUsage(texture.descriptor.format, descriptor.before),
        .new_layout = new_layout,
        .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .image = texture.handle,
        .subresource_range = .{
            .aspect_mask = imageAspectMask(texture.descriptor.format),
            .base_mip_level = descriptor.base_mip_level,
            .level_count = descriptor.mip_level_count,
            .base_array_layer = descriptor.base_array_layer,
            .layer_count = descriptor.array_layer_count,
        },
    };

    gc.dev.cmdPipelineBarrier(
        cmdbuf,
        stageMaskForUsage(descriptor.before),
        stageMaskForUsage(descriptor.after),
        .{},
        null,
        null,
        &.{barrier},
    );
    texture.layout = new_layout;
}

fn bufferImageCopy(texture: *const VulkanTexture, resolved: core.ResolvedBufferTextureCopy) vk.BufferImageCopy {
    return .{
        .buffer_offset = resolved.buffer_offset,
        .buffer_row_length = @intCast(resolved.bytes_per_row / resolved.bytes_per_pixel),
        .buffer_image_height = @intCast(resolved.bytes_per_image / resolved.bytes_per_row),
        .image_subresource = .{
            .aspect_mask = imageAspectMaskForAspect(resolved.aspect),
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

fn imageCopy(
    source: *const VulkanTexture,
    destination: *const VulkanTexture,
    resolved: core.ResolvedTextureTextureCopy,
) vk.ImageCopy {
    return .{
        .src_subresource = imageCopySubresource(source, resolved.source_mip_level, resolved.source_slice, resolved.slice_count, resolved.aspect),
        .src_offset = imageCopyOffset(source.descriptor.dimension, resolved.source_region.origin),
        .dst_subresource = imageCopySubresource(destination, resolved.destination_mip_level, resolved.destination_slice, resolved.slice_count, resolved.aspect),
        .dst_offset = imageCopyOffset(destination.descriptor.dimension, resolved.destination_origin),
        .extent = imageCopyExtent(source.descriptor.dimension, resolved.source_region.size),
    };
}

fn imageCopySubresource(
    texture: *const VulkanTexture,
    mip_level: u32,
    slice: u32,
    slice_count: u32,
    aspect: core.TextureAspect,
) vk.ImageSubresourceLayers {
    return .{
        .aspect_mask = imageAspectMaskForAspect(aspect),
        .mip_level = mip_level,
        .base_array_layer = if (texture.descriptor.dimension == .three_d) 0 else slice,
        .layer_count = if (texture.descriptor.dimension == .three_d) 1 else slice_count,
    };
}

fn imageCopyOffset(dimension: core.TextureDimension, origin: core.Origin3D) vk.Offset3D {
    return .{
        .x = @intCast(origin.x),
        .y = if (dimension == .one_d) 0 else @intCast(origin.y),
        .z = if (dimension == .three_d) @intCast(origin.z) else 0,
    };
}

fn imageCopyExtent(dimension: core.TextureDimension, size: core.Size3D) vk.Extent3D {
    return .{
        .width = size.width,
        .height = if (dimension == .one_d) 1 else size.height,
        .depth = if (dimension == .three_d) size.depth else 1,
    };
}

fn textureBlit(
    source: *const VulkanTexture,
    destination: *const VulkanTexture,
    resolved: core.ResolvedBlitTexture,
    slice_offset: u32,
) vk.ImageBlit {
    return .{
        .src_subresource = imageCopySubresource(
            source,
            resolved.source_mip_level,
            resolved.source_slice + slice_offset,
            1,
            .color,
        ),
        .src_offsets = .{
            imageCopyOffset(source.descriptor.dimension, resolved.source_region.origin),
            imageCopyOffset(source.descriptor.dimension, .{
                .x = resolved.source_region.origin.x + resolved.source_region.size.width,
                .y = resolved.source_region.origin.y + resolved.source_region.size.height,
                .z = resolved.source_region.origin.z + resolved.source_region.size.depth,
            }),
        },
        .dst_subresource = imageCopySubresource(
            destination,
            resolved.destination_mip_level,
            resolved.destination_slice + slice_offset,
            1,
            .color,
        ),
        .dst_offsets = .{
            imageCopyOffset(destination.descriptor.dimension, resolved.destination_region.origin),
            imageCopyOffset(destination.descriptor.dimension, .{
                .x = resolved.destination_region.origin.x + resolved.destination_region.size.width,
                .y = resolved.destination_region.origin.y + resolved.destination_region.size.height,
                .z = resolved.destination_region.origin.z + resolved.destination_region.size.depth,
            }),
        },
    };
}

fn imageBlit(
    descriptor: core.TextureDescriptor,
    source_level: u32,
    destination_level: u32,
    layer: u32,
) vk.ImageBlit {
    return .{
        .src_subresource = mipBlitSubresource(descriptor, source_level, layer),
        .src_offsets = .{
            .{ .x = 0, .y = 0, .z = 0 },
            mipBlitExtent(descriptor, source_level),
        },
        .dst_subresource = mipBlitSubresource(descriptor, destination_level, layer),
        .dst_offsets = .{
            .{ .x = 0, .y = 0, .z = 0 },
            mipBlitExtent(descriptor, destination_level),
        },
    };
}

fn mipBlitSubresource(descriptor: core.TextureDescriptor, mip_level: u32, layer: u32) vk.ImageSubresourceLayers {
    return .{
        .aspect_mask = imageAspectMask(descriptor.format),
        .mip_level = mip_level,
        .base_array_layer = if (descriptor.dimension == .three_d) 0 else layer,
        .layer_count = 1,
    };
}

fn mipBlitExtent(descriptor: core.TextureDescriptor, level: u32) vk.Offset3D {
    return .{
        .x = @intCast(core.mipDimension(descriptor.width, level)),
        .y = if (descriptor.dimension == .one_d) 1 else @intCast(core.mipDimension(descriptor.height, level)),
        .z = if (descriptor.dimension == .three_d) @intCast(core.mipDimension(descriptor.depth_or_array_layers, level)) else 1,
    };
}

fn imageMipBarrier(
    gc: *const GraphicsContext,
    cmdbuf: vk.CommandBuffer,
    texture: *const VulkanTexture,
    mip_level: u32,
    array_layer: u32,
    old_layout: vk.ImageLayout,
    new_layout: vk.ImageLayout,
    src_access_mask: vk.AccessFlags,
    dst_access_mask: vk.AccessFlags,
    src_stage_mask: vk.PipelineStageFlags,
    dst_stage_mask: vk.PipelineStageFlags,
) void {
    const barrier = vk.ImageMemoryBarrier{
        .src_access_mask = src_access_mask,
        .dst_access_mask = dst_access_mask,
        .old_layout = old_layout,
        .new_layout = new_layout,
        .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .image = texture.handle,
        .subresource_range = .{
            .aspect_mask = imageAspectMask(texture.descriptor.format),
            .base_mip_level = mip_level,
            .level_count = 1,
            .base_array_layer = if (texture.descriptor.dimension == .three_d) 0 else array_layer,
            .layer_count = 1,
        },
    };

    gc.dev.cmdPipelineBarrier(
        cmdbuf,
        src_stage_mask,
        dst_stage_mask,
        .{},
        null,
        null,
        &.{barrier},
    );
}

fn transitionSwapchainImage(
    gc: *const GraphicsContext,
    cmdbuf: vk.CommandBuffer,
    image: vk.Image,
    old_layout: vk.ImageLayout,
    new_layout: vk.ImageLayout,
    src_access_mask: vk.AccessFlags,
    dst_access_mask: vk.AccessFlags,
    src_stage_mask: vk.PipelineStageFlags,
    dst_stage_mask: vk.PipelineStageFlags,
) void {
    const barrier = vk.ImageMemoryBarrier{
        .src_access_mask = src_access_mask,
        .dst_access_mask = dst_access_mask,
        .old_layout = old_layout,
        .new_layout = new_layout,
        .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .image = image,
        .subresource_range = .{
            .aspect_mask = .{ .color_bit = true },
            .base_mip_level = 0,
            .level_count = 1,
            .base_array_layer = 0,
            .layer_count = 1,
        },
    };

    gc.dev.cmdPipelineBarrier(
        cmdbuf,
        src_stage_mask,
        dst_stage_mask,
        .{},
        null,
        null,
        &.{barrier},
    );
}

fn indirectStride(stride: u32, default_stride: u32) u32 {
    return if (stride == 0) default_stride else stride;
}

fn indexType(index_type: core.IndexType) vk.IndexType {
    return switch (index_type) {
        .uint16 => .uint16,
        .uint32 => .uint32,
    };
}

fn shaderStageFlags(visibility: core.ShaderVisibility) vk.ShaderStageFlags {
    return .{
        .vertex_bit = visibility.vertex,
        .fragment_bit = visibility.fragment,
        .compute_bit = visibility.compute,
    };
}

fn accessMaskForUsage(usage: core.ResourceUsageKind) vk.AccessFlags {
    return switch (usage) {
        .vertex_buffer => .{ .vertex_attribute_read_bit = true },
        .index_buffer => .{ .index_read_bit = true },
        .uniform_buffer => .{ .uniform_read_bit = true },
        .storage_buffer_read,
        .sampled_texture,
        .storage_texture_read,
        => .{ .shader_read_bit = true },
        .acceleration_structure_read,
        .acceleration_structure_build_input,
        => .{ .acceleration_structure_read_bit_khr = true },
        .storage_buffer_write,
        .storage_texture_write,
        => .{ .shader_read_bit = true, .shader_write_bit = true },
        .acceleration_structure_write,
        .acceleration_structure_scratch,
        => .{ .acceleration_structure_write_bit_khr = true },
        .indirect_buffer => .{ .indirect_command_read_bit = true },
        .shader_binding_table => .{ .shader_read_bit = true },
        .render_attachment_read => .{
            .color_attachment_read_bit = true,
            .depth_stencil_attachment_read_bit = true,
        },
        .render_attachment_write => .{
            .color_attachment_write_bit = true,
            .depth_stencil_attachment_write_bit = true,
        },
        .copy_source => .{ .transfer_read_bit = true },
        .copy_destination => .{ .transfer_write_bit = true },
        .present => .{ .memory_read_bit = true },
    };
}

fn stageMaskForUsage(usage: core.ResourceUsageKind) vk.PipelineStageFlags {
    return switch (usage) {
        .vertex_buffer,
        .index_buffer,
        => .{ .vertex_input_bit = true },
        .uniform_buffer,
        .storage_buffer_read,
        .storage_buffer_write,
        .sampled_texture,
        .storage_texture_read,
        .storage_texture_write,
        => .{
            .vertex_shader_bit = true,
            .fragment_shader_bit = true,
            .compute_shader_bit = true,
        },
        .acceleration_structure_read,
        .shader_binding_table,
        => .{ .ray_tracing_shader_bit_khr = true },
        .acceleration_structure_write,
        .acceleration_structure_scratch,
        .acceleration_structure_build_input,
        => .{ .acceleration_structure_build_bit_khr = true },
        .indirect_buffer => .{ .draw_indirect_bit = true },
        .render_attachment_read,
        .render_attachment_write,
        => .{
            .color_attachment_output_bit = true,
            .early_fragment_tests_bit = true,
            .late_fragment_tests_bit = true,
        },
        .copy_source,
        .copy_destination,
        => .{ .transfer_bit = true },
        .present => .{ .bottom_of_pipe_bit = true },
    };
}

fn imageLayoutForUsage(format: core.TextureFormat, usage: core.ResourceUsageKind) vk.ImageLayout {
    return switch (usage) {
        .sampled_texture => .shader_read_only_optimal,
        .storage_texture_read,
        .storage_texture_write,
        => .general,
        .render_attachment_read,
        .render_attachment_write,
        => if (core.isDepthFormat(format) or core.isStencilFormat(format))
            .depth_stencil_attachment_optimal
        else
            .color_attachment_optimal,
        .copy_source => .transfer_src_optimal,
        .copy_destination => .transfer_dst_optimal,
        .present => .present_src_khr,
        .vertex_buffer,
        .index_buffer,
        .uniform_buffer,
        .storage_buffer_read,
        .storage_buffer_write,
        .acceleration_structure_read,
        .acceleration_structure_write,
        .acceleration_structure_scratch,
        .acceleration_structure_build_input,
        .indirect_buffer,
        .shader_binding_table,
        => .general,
    };
}

fn imageAspectMask(format: core.TextureFormat) vk.ImageAspectFlags {
    return .{
        .color_bit = !core.isDepthFormat(format) and !core.isStencilFormat(format),
        .depth_bit = core.isDepthFormat(format),
        .stencil_bit = core.isStencilFormat(format),
    };
}

fn imageAspectMaskForAspect(aspect: core.TextureAspect) vk.ImageAspectFlags {
    return switch (aspect) {
        .all => .{ .depth_bit = true, .stencil_bit = true },
        .color => .{ .color_bit = true },
        .depth => .{ .depth_bit = true },
        .stencil => .{ .stencil_bit = true },
    };
}

test "Vulkan fill buffer fallback selection covers unaligned ranges" {
    try std.testing.expect(!fillBufferUsesStagingFallback(.{
        .offset = 4,
        .size = 8,
    }));
    try std.testing.expect(fillBufferUsesStagingFallback(.{
        .offset = 1,
        .size = 8,
    }));
    try std.testing.expect(fillBufferUsesStagingFallback(.{
        .offset = 4,
        .size = 7,
    }));

    const descriptors = [_]core.FillBufferDescriptor{
        .{
            .offset = 0,
            .size = 16,
        },
        .{
            .offset = 1,
            .size = 8,
        },
        .{
            .offset = 4,
            .size = 7,
        },
    };
    const diagnostics = fillBufferFallbackDiagnostics(descriptors[0..]);
    try std.testing.expectEqual(@as(u64, 1), diagnostics.native_fills);
    try std.testing.expectEqual(@as(u64, 2), diagnostics.staging_fallbacks);
    try std.testing.expectEqual(@as(u64, 16), diagnostics.native_bytes);
    try std.testing.expectEqual(@as(u64, 15), diagnostics.staging_bytes);
    try std.testing.expectEqual(@as(u64, 3), diagnostics.totalFills());
    try std.testing.expectEqual(@as(u64, 31), diagnostics.totalBytes());
}
