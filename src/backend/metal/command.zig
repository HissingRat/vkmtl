const core = @import("../../core.zig");
const metal = @import("metal_bridge");
const MetalBindGroup = @import("bind_group.zig").MetalBindGroup;
const MetalBuffer = @import("buffer.zig");
const MetalClearScreen = @import("clear_screen.zig");
const MetalComputePipelineState = @import("compute_pipeline.zig");
const MetalRenderPipelineState = @import("render_pipeline.zig");
const MetalTexture = @import("texture.zig");
const MetalTextureView = @import("texture_view.zig");
const slots = @import("slots.zig");

pub const RenderPassColorAttachmentTarget = union(enum) {
    current_drawable,
    texture_view: *const MetalTextureView,
};

pub const RenderPassColorAttachmentDescriptor = struct {
    target: RenderPassColorAttachmentTarget = .current_drawable,
    resolve_target: ?*const MetalTextureView = null,
    load_action: core.LoadAction = .clear,
    store_action: core.StoreAction = .store,
    clear_color: core.ClearColorLike = .{},
};

pub const RenderPassDepthAttachmentTarget = union(enum) {
    current_drawable,
    texture_view: *const MetalTextureView,
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
    owner: *MetalClearScreen,
    handle: *metal.vkmtl_metal_command_buffer,

    const Error = error{
        MetalUnsupported,
        InvalidCommand,
        NoDrawable,
        CommandFailed,
        UnexpectedMetalStatus,
    };

    pub fn init(owner: *MetalClearScreen) !CommandBuffer {
        var handle: ?*metal.vkmtl_metal_command_buffer = null;
        try check(metal.vkmtl_metal_command_buffer_create(owner.handle, &handle));

        return .{
            .owner = owner,
            .handle = handle orelse return Error.InvalidCommand,
        };
    }

    pub fn deinit(self: *CommandBuffer) void {
        metal.vkmtl_metal_command_buffer_destroy(self.handle);
    }

    pub fn makeRenderCommandEncoder(
        self: *CommandBuffer,
        descriptor: RenderPassDescriptor,
    ) !RenderCommandEncoder {
        const clear_color = descriptor.color_attachment.clear_color;
        const depth_attachment = descriptor.depth_attachment;

        var handle: ?*metal.vkmtl_metal_render_command_encoder = null;
        try check(metal.vkmtl_metal_render_command_encoder_create(
            self.owner.handle,
            self.handle,
            clear_color.red,
            clear_color.green,
            clear_color.blue,
            clear_color.alpha,
            colorTextureViewHandle(descriptor.color_attachment.target),
            resolveTextureViewHandle(descriptor.color_attachment.resolve_target),
            if (depth_attachment != null) 1 else 0,
            if (depth_attachment) |depth| depthTextureViewHandle(depth.target) else null,
            if (depth_attachment) |depth| depth.clear_depth else 1.0,
            &handle,
        ));

        return .{
            .handle = handle orelse return Error.InvalidCommand,
            .uses_depth_pass = depth_attachment != null,
            .sample_count = colorAttachmentSampleCount(descriptor.color_attachment),
        };
    }

    pub fn makeBlitCommandEncoder(self: *CommandBuffer) !BlitCommandEncoder {
        var handle: ?*metal.vkmtl_metal_blit_command_encoder = null;
        try check(metal.vkmtl_metal_blit_command_encoder_create(self.handle, &handle));
        return .{
            .handle = handle orelse return Error.InvalidCommand,
        };
    }

    pub fn makeComputeCommandEncoder(self: *CommandBuffer) !ComputeCommandEncoder {
        var handle: ?*metal.vkmtl_metal_compute_command_encoder = null;
        try check(metal.vkmtl_metal_compute_command_encoder_create(self.handle, &handle));
        return .{
            .handle = handle orelse return Error.InvalidCommand,
        };
    }

    pub fn presentDrawable(self: *CommandBuffer) !void {
        try check(metal.vkmtl_metal_command_buffer_present_drawable(self.handle));
    }

    pub fn commit(self: *CommandBuffer) !void {
        try check(metal.vkmtl_metal_command_buffer_commit(self.handle));
    }
};

pub const BlitCommandEncoder = struct {
    handle: *metal.vkmtl_metal_blit_command_encoder,

    const Error = CommandBuffer.Error;

    pub fn deinit(self: *BlitCommandEncoder) void {
        metal.vkmtl_metal_blit_command_encoder_destroy(self.handle);
    }

    pub fn copyBufferToBuffer(
        self: *BlitCommandEncoder,
        source: *const MetalBuffer,
        destination: *const MetalBuffer,
        descriptor: core.CopyBufferToBufferDescriptor,
    ) !void {
        try check(metal.vkmtl_metal_blit_command_encoder_copy_buffer_to_buffer(
            self.handle,
            source.handle,
            destination.handle,
            descriptor.source_offset,
            descriptor.destination_offset,
            descriptor.size,
        ));
    }

    pub fn copyBufferToTexture(
        self: *BlitCommandEncoder,
        source: *const MetalBuffer,
        destination: *const MetalTexture,
        resolved: core.ResolvedBufferTextureCopy,
    ) !void {
        try check(metal.vkmtl_metal_blit_command_encoder_copy_buffer_to_texture(
            self.handle,
            source.handle,
            destination.handle,
            resolved.buffer_offset,
            resolved.bytes_per_row,
            resolved.bytes_per_image,
            resolved.region.origin.x,
            resolved.region.origin.y,
            resolved.region.origin.z,
            resolved.region.size.width,
            resolved.region.size.height,
            resolved.region.size.depth,
            resolved.mip_level,
            resolved.slice,
        ));
    }

    pub fn copyTextureToBuffer(
        self: *BlitCommandEncoder,
        source: *const MetalTexture,
        destination: *const MetalBuffer,
        resolved: core.ResolvedBufferTextureCopy,
    ) !void {
        try check(metal.vkmtl_metal_blit_command_encoder_copy_texture_to_buffer(
            self.handle,
            source.handle,
            destination.handle,
            resolved.buffer_offset,
            resolved.bytes_per_row,
            resolved.bytes_per_image,
            resolved.region.origin.x,
            resolved.region.origin.y,
            resolved.region.origin.z,
            resolved.region.size.width,
            resolved.region.size.height,
            resolved.region.size.depth,
            resolved.mip_level,
            resolved.slice,
        ));
    }

    pub fn endEncoding(self: *BlitCommandEncoder) !void {
        try check(metal.vkmtl_metal_blit_command_encoder_end_encoding(self.handle));
    }
};

pub const ComputeCommandEncoder = struct {
    handle: *metal.vkmtl_metal_compute_command_encoder,

    const Error = CommandBuffer.Error;

    pub fn deinit(self: *ComputeCommandEncoder) void {
        metal.vkmtl_metal_compute_command_encoder_destroy(self.handle);
    }

    pub fn setComputePipelineState(self: *ComputeCommandEncoder, pipeline: *MetalComputePipelineState) !void {
        try check(metal.vkmtl_metal_compute_command_encoder_set_pipeline(
            self.handle,
            pipeline.handle,
        ));
    }

    pub fn setBindGroup(
        self: *ComputeCommandEncoder,
        bind_group: *const MetalBindGroup,
        binding: core.BindGroupBinding,
    ) !void {
        try binding.validate();

        for (bind_group.entries) |entry| {
            const layout_entry = bind_group.layoutEntryForBinding(entry.binding) orelse {
                return error.BindingResourceKindMismatch;
            };
            if (!layout_entry.visibility.compute) continue;

            switch (entry.resource) {
                .uniform_buffer, .storage_buffer => |buffer_binding| try self.setBufferResource(
                    buffer_binding,
                    layout_entry.binding,
                ),
                .storage_texture, .sampled_texture => |texture_view| try self.setTextureResource(
                    texture_view,
                    layout_entry.binding,
                ),
                .sampler, .compare_sampler => |sampler_state| try self.setSamplerResource(
                    sampler_state,
                    layout_entry.binding,
                ),
            }
        }
    }

    pub fn dispatchThreadgroups(
        self: *ComputeCommandEncoder,
        descriptor: core.DispatchThreadgroupsDescriptor,
    ) !void {
        try descriptor.validate();
        try check(metal.vkmtl_metal_compute_command_encoder_dispatch_threadgroups(
            self.handle,
            descriptor.threadgroup_count_x,
            descriptor.threadgroup_count_y,
            descriptor.threadgroup_count_z,
            descriptor.threads_per_threadgroup_x,
            descriptor.threads_per_threadgroup_y,
            descriptor.threads_per_threadgroup_z,
        ));
    }

    pub fn endEncoding(self: *ComputeCommandEncoder) !void {
        try check(metal.vkmtl_metal_compute_command_encoder_end_encoding(self.handle));
    }

    fn setBufferResource(
        self: *ComputeCommandEncoder,
        binding: MetalBindGroup.BufferBinding,
        index: u32,
    ) !void {
        try check(metal.vkmtl_metal_compute_command_encoder_set_buffer(
            self.handle,
            binding.buffer.handle,
            index,
            binding.offset,
        ));
    }

    fn setTextureResource(
        self: *ComputeCommandEncoder,
        texture_view: *const @import("texture_view.zig"),
        index: u32,
    ) !void {
        try check(metal.vkmtl_metal_compute_command_encoder_set_texture(
            self.handle,
            texture_view.handle,
            index,
        ));
    }

    fn setSamplerResource(
        self: *ComputeCommandEncoder,
        sampler_state: *const @import("sampler.zig"),
        index: u32,
    ) !void {
        try check(metal.vkmtl_metal_compute_command_encoder_set_sampler_state(
            self.handle,
            sampler_state.handle,
            index,
        ));
    }
};

pub const RenderCommandEncoder = struct {
    handle: *metal.vkmtl_metal_render_command_encoder,
    uses_depth_pass: bool,
    sample_count: u32,

    const Error = CommandBuffer.Error;

    pub fn deinit(self: *RenderCommandEncoder) void {
        metal.vkmtl_metal_render_command_encoder_destroy(self.handle);
    }

    pub fn setRenderPipelineState(self: *RenderCommandEncoder, pipeline: *MetalRenderPipelineState) !void {
        if (pipeline.uses_depth != self.uses_depth_pass) return core.CommandEncodingError.DepthStateRenderPassMismatch;
        if (pipeline.sample_count != self.sample_count) return core.CommandEncodingError.SampleCountRenderPassMismatch;
        try check(metal.vkmtl_metal_render_command_encoder_set_pipeline(
            self.handle,
            pipeline.handle,
        ));
    }

    pub fn setVertexBuffer(
        self: *RenderCommandEncoder,
        buffer: *MetalBuffer,
        binding: core.VertexBufferBinding,
    ) !void {
        const native_index = try slots.vertexBufferSlot(binding);
        try check(metal.vkmtl_metal_render_command_encoder_set_vertex_buffer(
            self.handle,
            buffer.handle,
            native_index,
            binding.offset,
        ));
    }

    pub fn setIndexBuffer(self: *RenderCommandEncoder, buffer: *MetalBuffer) !void {
        try check(metal.vkmtl_metal_render_command_encoder_set_index_buffer(
            self.handle,
            buffer.handle,
        ));
    }

    pub fn setBindGroup(
        self: *RenderCommandEncoder,
        bind_group: *const MetalBindGroup,
        binding: core.BindGroupBinding,
    ) !void {
        try binding.validate();

        for (bind_group.entries) |entry| {
            const layout_entry = bind_group.layoutEntryForBinding(entry.binding) orelse {
                return error.BindingResourceKindMismatch;
            };

            switch (entry.resource) {
                .uniform_buffer, .storage_buffer => |buffer_binding| try self.setBufferResource(
                    buffer_binding,
                    layout_entry.binding,
                    layout_entry.visibility,
                ),
                .storage_texture, .sampled_texture => |texture_view| try self.setTextureResource(
                    texture_view,
                    layout_entry.binding,
                    layout_entry.visibility,
                ),
                .sampler, .compare_sampler => |sampler_state| try self.setSamplerResource(
                    sampler_state,
                    layout_entry.binding,
                    layout_entry.visibility,
                ),
            }
        }
    }

    pub fn drawPrimitives(
        self: *RenderCommandEncoder,
        descriptor: core.DrawPrimitivesDescriptor,
    ) !void {
        try descriptor.validate();
        try check(metal.vkmtl_metal_render_command_encoder_draw_primitives(
            self.handle,
            primitiveType(descriptor.primitive_type),
            descriptor.vertex_start,
            descriptor.vertex_count,
            descriptor.instance_count,
        ));
    }

    pub fn drawIndexedPrimitives(
        self: *RenderCommandEncoder,
        descriptor: core.DrawIndexedPrimitivesDescriptor,
    ) !void {
        try descriptor.validate();
        try check(metal.vkmtl_metal_render_command_encoder_draw_indexed_primitives(
            self.handle,
            primitiveType(descriptor.primitive_type),
            indexTypeBits(descriptor.index_type),
            descriptor.index_count,
            descriptor.index_buffer_offset,
            descriptor.instance_count,
        ));
    }

    pub fn endEncoding(self: *RenderCommandEncoder) !void {
        try check(metal.vkmtl_metal_render_command_encoder_end_encoding(self.handle));
    }

    fn setBufferResource(
        self: *RenderCommandEncoder,
        binding: MetalBindGroup.BufferBinding,
        index: u32,
        visibility: core.ShaderVisibility,
    ) !void {
        if (visibility.vertex) {
            try check(metal.vkmtl_metal_render_command_encoder_set_vertex_buffer(
                self.handle,
                binding.buffer.handle,
                index,
                binding.offset,
            ));
        }
        if (visibility.fragment) {
            try check(metal.vkmtl_metal_render_command_encoder_set_fragment_buffer(
                self.handle,
                binding.buffer.handle,
                index,
                binding.offset,
            ));
        }
    }

    fn setTextureResource(
        self: *RenderCommandEncoder,
        texture_view: *const @import("texture_view.zig"),
        index: u32,
        visibility: core.ShaderVisibility,
    ) !void {
        if (visibility.vertex) {
            try check(metal.vkmtl_metal_render_command_encoder_set_vertex_texture(
                self.handle,
                texture_view.handle,
                index,
            ));
        }
        if (visibility.fragment) {
            try check(metal.vkmtl_metal_render_command_encoder_set_fragment_texture(
                self.handle,
                texture_view.handle,
                index,
            ));
        }
    }

    fn setSamplerResource(
        self: *RenderCommandEncoder,
        sampler_state: *const @import("sampler.zig"),
        index: u32,
        visibility: core.ShaderVisibility,
    ) !void {
        if (visibility.vertex) {
            try check(metal.vkmtl_metal_render_command_encoder_set_vertex_sampler_state(
                self.handle,
                sampler_state.handle,
                index,
            ));
        }
        if (visibility.fragment) {
            try check(metal.vkmtl_metal_render_command_encoder_set_fragment_sampler_state(
                self.handle,
                sampler_state.handle,
                index,
            ));
        }
    }
};

fn indexTypeBits(index_type: core.IndexType) c_uint {
    return switch (index_type) {
        .uint16 => 16,
        .uint32 => 32,
    };
}

fn primitiveType(primitive_type: core.PrimitiveTopology) c_uint {
    return switch (primitive_type) {
        .triangle => 0,
        .line => 1,
        .point => 2,
    };
}

fn colorTextureViewHandle(target: RenderPassColorAttachmentTarget) ?*metal.vkmtl_metal_texture_view {
    return switch (target) {
        .current_drawable => null,
        .texture_view => |texture_view| texture_view.handle,
    };
}

fn resolveTextureViewHandle(target: ?*const MetalTextureView) ?*metal.vkmtl_metal_texture_view {
    return if (target) |texture_view| texture_view.handle else null;
}

fn colorAttachmentSampleCount(attachment: RenderPassColorAttachmentDescriptor) u32 {
    return switch (attachment.target) {
        .current_drawable => 1,
        .texture_view => |texture_view| texture_view.sample_count,
    };
}

fn depthTextureViewHandle(target: RenderPassDepthAttachmentTarget) ?*metal.vkmtl_metal_texture_view {
    return switch (target) {
        .current_drawable => null,
        .texture_view => |texture_view| texture_view.handle,
    };
}

fn check(status: metal.vkmtl_metal_status) CommandBuffer.Error!void {
    return switch (status) {
        metal.VKMTL_METAL_STATUS_OK => {},
        metal.VKMTL_METAL_STATUS_UNSUPPORTED => CommandBuffer.Error.MetalUnsupported,
        metal.VKMTL_METAL_STATUS_NO_DRAWABLE => CommandBuffer.Error.NoDrawable,
        metal.VKMTL_METAL_STATUS_INVALID_COMMAND => CommandBuffer.Error.InvalidCommand,
        metal.VKMTL_METAL_STATUS_COMMAND_FAILED => CommandBuffer.Error.CommandFailed,
        else => CommandBuffer.Error.UnexpectedMetalStatus,
    };
}
