const std = @import("std");
const builtin = @import("builtin");
const core = @import("../core.zig");
const build_options = @import("vkmtl_build_options");
const ShaderCompiler = @import("../shader/compiler.zig");
const ShaderReflection = @import("../shader/reflection.zig");
const MetalBuffer = @import("../backend/metal/buffer.zig");
const MetalBindGroupBackend = @import("../backend/metal/bind_group.zig");
const MetalCommand = @import("../backend/metal/command.zig");
const MetalComputePipelineState = @import("../backend/metal/compute_pipeline.zig");
const MetalClearScreen = @import("../backend/metal/clear_screen.zig");
const MetalRenderPipelineState = @import("../backend/metal/render_pipeline.zig");
const MetalSamplerState = @import("../backend/metal/sampler.zig");
const MetalShaderModule = @import("../backend/metal/shader_module.zig");
const MetalTexture = @import("../backend/metal/texture.zig");
const MetalTextureView = @import("../backend/metal/texture_view.zig");
const VulkanBindGroupBackend = @import("../backend/vulkan/bind_group.zig");
const VulkanBuffer = @import("../backend/vulkan/buffer.zig");
const VulkanCommand = @import("../backend/vulkan/command.zig");
const VulkanComputePipelineState = @import("../backend/vulkan/compute_pipeline.zig");
const VulkanClearScreen = @import("../backend/vulkan/clear_screen.zig");
const VulkanRenderPipelineState = @import("../backend/vulkan/render_pipeline.zig");
const VulkanSamplerState = @import("../backend/vulkan/sampler.zig");
const VulkanShaderModule = @import("../backend/vulkan/shader_module.zig");
const VulkanTexture = @import("../backend/vulkan/texture.zig");
const VulkanTextureView = @import("../backend/vulkan/texture_view.zig");

pub const ClearColor = core.ClearColorLike;

pub const ResourceKind = enum {
    buffer,
    texture,
    texture_view,
    sampler_state,
    shader_module,
    render_pipeline_state,
    compute_pipeline_state,
    bind_group_layout,
    bind_group,
};

pub const ResourceTracker = struct {
    buffers: usize = 0,
    textures: usize = 0,
    texture_views: usize = 0,
    sampler_states: usize = 0,
    shader_modules: usize = 0,
    render_pipeline_states: usize = 0,
    compute_pipeline_states: usize = 0,
    bind_group_layouts: usize = 0,
    bind_groups: usize = 0,

    pub fn retain(self: *ResourceTracker, kind: ResourceKind) void {
        self.countPtr(kind).* += 1;
    }

    pub fn release(self: *ResourceTracker, kind: ResourceKind) void {
        const count = self.countPtr(kind);
        if (builtin.mode == .Debug and count.* == 0) {
            std.debug.panic("vkmtl resource tracker underflow for {s}", .{kindName(kind)});
        }
        if (count.* != 0) count.* -= 1;
    }

    pub fn hasLeaks(self: ResourceTracker) bool {
        return self.buffers != 0 or
            self.textures != 0 or
            self.texture_views != 0 or
            self.sampler_states != 0 or
            self.shader_modules != 0 or
            self.render_pipeline_states != 0 or
            self.compute_pipeline_states != 0 or
            self.bind_group_layouts != 0 or
            self.bind_groups != 0;
    }

    pub fn assertNoLeaks(self: ResourceTracker) void {
        if (builtin.mode == .Debug and self.hasLeaks()) {
            std.debug.panic(
                "vkmtl leaked resources before WindowContext.deinit: buffers={}, textures={}, texture_views={}, sampler_states={}, shader_modules={}, render_pipeline_states={}, compute_pipeline_states={}, bind_group_layouts={}, bind_groups={}",
                .{
                    self.buffers,
                    self.textures,
                    self.texture_views,
                    self.sampler_states,
                    self.shader_modules,
                    self.render_pipeline_states,
                    self.compute_pipeline_states,
                    self.bind_group_layouts,
                    self.bind_groups,
                },
            );
        }
    }

    fn countPtr(self: *ResourceTracker, kind: ResourceKind) *usize {
        return switch (kind) {
            .buffer => &self.buffers,
            .texture => &self.textures,
            .texture_view => &self.texture_views,
            .sampler_state => &self.sampler_states,
            .shader_module => &self.shader_modules,
            .render_pipeline_state => &self.render_pipeline_states,
            .compute_pipeline_state => &self.compute_pipeline_states,
            .bind_group_layout => &self.bind_group_layouts,
            .bind_group => &self.bind_groups,
        };
    }
};

pub const Buffer = struct {
    backend: core.Backend,
    tracker: *ResourceTracker,
    usage_value: core.BufferUsage = .{},
    alive: bool = true,
    impl: Impl,

    const Impl = union(core.Backend) {
        vulkan: VulkanBuffer,
        metal: MetalBuffer,
    };

    pub fn deinit(self: *Buffer) void {
        assertAlive(self.alive, .buffer);
        self.alive = false;
        switch (self.impl) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        }
        self.tracker.release(.buffer);
    }

    pub fn selectedBackend(self: Buffer) core.Backend {
        return self.backend;
    }

    pub fn length(self: Buffer) usize {
        return switch (self.impl) {
            .vulkan => |vulkan| vulkan.length(),
            .metal => |metal| metal.length(),
        };
    }

    pub fn usage(self: Buffer) core.BufferUsage {
        return self.usage_value;
    }

    pub fn replaceBytes(self: *Buffer, offset: usize, bytes: []const u8) !void {
        assertAlive(self.alive, .buffer);
        const descriptor = core.BufferWriteDescriptor{
            .offset = offset,
            .bytes = bytes,
        };
        try descriptor.validate(self.length());
        switch (self.impl) {
            .vulkan => |*vulkan| try vulkan.replaceBytes(offset, bytes),
            .metal => |*metal| try metal.replaceBytes(offset, bytes),
        }
    }

    pub fn readBytes(self: *Buffer, offset: usize, destination: []u8) !void {
        assertAlive(self.alive, .buffer);
        const descriptor = core.BufferReadDescriptor{
            .offset = offset,
            .destination = destination,
        };
        try descriptor.validate(self.length());
        switch (self.impl) {
            .vulkan => |*vulkan| try vulkan.readBytes(offset, destination),
            .metal => |*metal| try metal.readBytes(offset, destination),
        }
    }
};

pub const Texture = struct {
    backend: core.Backend,
    tracker: *ResourceTracker,
    dimension_value: core.TextureDimension = .two_d,
    format_value: core.TextureFormat,
    usage_value: core.TextureUsage,
    sample_count_value: u32,
    alive: bool = true,
    impl: Impl,

    const Impl = union(core.Backend) {
        vulkan: VulkanTexture,
        metal: MetalTexture,
    };

    pub fn deinit(self: *Texture) void {
        assertAlive(self.alive, .texture);
        self.alive = false;
        switch (self.impl) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        }
        self.tracker.release(.texture);
    }

    pub fn selectedBackend(self: Texture) core.Backend {
        return self.backend;
    }

    pub fn format(self: Texture) core.TextureFormat {
        return self.format_value;
    }

    pub fn usage(self: Texture) core.TextureUsage {
        return self.usage_value;
    }

    pub fn sampleCount(self: Texture) u32 {
        return self.sample_count_value;
    }

    pub fn width(self: Texture) u32 {
        return switch (self.impl) {
            .vulkan => |vulkan| vulkan.width(),
            .metal => |metal| metal.width(),
        };
    }

    pub fn height(self: Texture) u32 {
        return switch (self.impl) {
            .vulkan => |vulkan| vulkan.height(),
            .metal => |metal| metal.height(),
        };
    }

    pub fn depthOrArrayLayers(self: Texture) u32 {
        return switch (self.impl) {
            .vulkan => |vulkan| vulkan.depthOrArrayLayers(),
            .metal => |metal| metal.depthOrArrayLayers(),
        };
    }

    pub fn mipLevelCount(self: Texture) u32 {
        return switch (self.impl) {
            .vulkan => |vulkan| vulkan.mipLevelCount(),
            .metal => |metal| metal.mipLevelCount(),
        };
    }

    pub fn textureDescriptor(self: Texture) core.TextureDescriptor {
        return .{
            .format = self.format_value,
            .dimension = self.dimension_value,
            .width = self.width(),
            .height = self.height(),
            .depth_or_array_layers = self.depthOrArrayLayers(),
            .mip_level_count = self.mipLevelCount(),
            .sample_count = self.sample_count_value,
            .usage = self.usage_value,
        };
    }

    pub fn makeTextureView(self: *Texture, descriptor: core.TextureViewDescriptor) !TextureView {
        assertAlive(self.alive, .texture);
        const resolved = try descriptor.resolveForTexture(.{
            .format = self.format_value,
            .width = self.width(),
            .height = self.height(),
            .depth_or_array_layers = self.depthOrArrayLayers(),
            .mip_level_count = self.mipLevelCount(),
            .usage = self.usage_value,
        });
        const impl = switch (self.impl) {
            .vulkan => |*vulkan| TextureView.Impl{ .vulkan = try vulkan.makeTextureView(descriptor) },
            .metal => |*metal| TextureView.Impl{ .metal = try metal.makeTextureView(descriptor) },
        };
        self.tracker.retain(.texture_view);
        return switch (self.impl) {
            .vulkan => .{
                .backend = .vulkan,
                .tracker = self.tracker,
                .format_value = resolved.format,
                .usage_value = self.usage_value,
                .sample_count_value = self.sample_count_value,
                .width_value = mipDimension(self.width(), resolved.base_mip_level),
                .height_value = mipDimension(self.height(), resolved.base_mip_level),
                .impl = impl,
            },
            .metal => .{
                .backend = .metal,
                .tracker = self.tracker,
                .format_value = resolved.format,
                .usage_value = self.usage_value,
                .sample_count_value = self.sample_count_value,
                .width_value = mipDimension(self.width(), resolved.base_mip_level),
                .height_value = mipDimension(self.height(), resolved.base_mip_level),
                .impl = impl,
            },
        };
    }

    pub fn replaceRegion(
        self: *Texture,
        region: core.Region3D,
        descriptor: core.TextureReplaceRegionDescriptor,
    ) !void {
        assertAlive(self.alive, .texture);
        switch (self.impl) {
            .vulkan => |*vulkan| try vulkan.replaceRegion(region, descriptor),
            .metal => |*metal| try metal.replaceRegion(region, descriptor),
        }
    }

    pub fn replaceAll2D(self: *Texture, descriptor: core.TextureUpload2DDescriptor) !void {
        try self.replaceRegion(.{
            .size = .{
                .width = mipDimension(self.width(), descriptor.mip_level),
                .height = mipDimension(self.height(), descriptor.mip_level),
            },
        }, descriptor.asReplaceRegionDescriptor());
    }
};

pub const TextureView = struct {
    backend: core.Backend,
    tracker: *ResourceTracker,
    format_value: core.TextureFormat,
    usage_value: core.TextureUsage,
    sample_count_value: u32,
    width_value: u32,
    height_value: u32,
    alive: bool = true,
    impl: Impl,

    const Impl = union(core.Backend) {
        vulkan: VulkanTextureView,
        metal: MetalTextureView,
    };

    pub fn deinit(self: *TextureView) void {
        assertAlive(self.alive, .texture_view);
        self.alive = false;
        switch (self.impl) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        }
        self.tracker.release(.texture_view);
    }

    pub fn selectedBackend(self: TextureView) core.Backend {
        return self.backend;
    }

    pub fn format(self: TextureView) core.TextureFormat {
        return self.format_value;
    }

    pub fn usage(self: TextureView) core.TextureUsage {
        return self.usage_value;
    }

    pub fn sampleCount(self: TextureView) u32 {
        return self.sample_count_value;
    }

    pub fn width(self: TextureView) u32 {
        return self.width_value;
    }

    pub fn height(self: TextureView) u32 {
        return self.height_value;
    }
};

pub const SamplerState = struct {
    backend: core.Backend,
    tracker: *ResourceTracker,
    alive: bool = true,
    impl: Impl,

    const Impl = union(core.Backend) {
        vulkan: VulkanSamplerState,
        metal: MetalSamplerState,
    };

    pub fn deinit(self: *SamplerState) void {
        assertAlive(self.alive, .sampler_state);
        self.alive = false;
        switch (self.impl) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        }
        self.tracker.release(.sampler_state);
    }

    pub fn selectedBackend(self: SamplerState) core.Backend {
        return self.backend;
    }
};

pub const ShaderModule = struct {
    backend: core.Backend,
    tracker: *ResourceTracker,
    alive: bool = true,
    impl: Impl,

    const Impl = union(core.Backend) {
        vulkan: VulkanShaderModule,
        metal: MetalShaderModule,
    };

    pub fn deinit(self: *ShaderModule) void {
        assertAlive(self.alive, .shader_module);
        self.alive = false;
        switch (self.impl) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        }
        self.tracker.release(.shader_module);
    }

    pub fn selectedBackend(self: ShaderModule) core.Backend {
        return self.backend;
    }
};

pub const RenderPipelineState = struct {
    backend: core.Backend,
    tracker: *ResourceTracker,
    alive: bool = true,
    impl: Impl,

    const Impl = union(core.Backend) {
        vulkan: VulkanRenderPipelineState,
        metal: MetalRenderPipelineState,
    };

    pub fn deinit(self: *RenderPipelineState) void {
        assertAlive(self.alive, .render_pipeline_state);
        self.alive = false;
        switch (self.impl) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        }
        self.tracker.release(.render_pipeline_state);
    }

    pub fn selectedBackend(self: RenderPipelineState) core.Backend {
        return self.backend;
    }
};

pub const ComputePipelineState = struct {
    backend: core.Backend,
    tracker: *ResourceTracker,
    alive: bool = true,
    impl: Impl,

    const Impl = union(core.Backend) {
        vulkan: VulkanComputePipelineState,
        metal: MetalComputePipelineState,
    };

    pub fn deinit(self: *ComputePipelineState) void {
        assertAlive(self.alive, .compute_pipeline_state);
        self.alive = false;
        switch (self.impl) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        }
        self.tracker.release(.compute_pipeline_state);
    }

    pub fn selectedBackend(self: ComputePipelineState) core.Backend {
        return self.backend;
    }
};

pub const BindGroupLayout = struct {
    backend: core.Backend,
    tracker: *ResourceTracker,
    allocator: std.mem.Allocator,
    alive: bool = true,
    entries: []core.BindGroupLayoutEntry,
    impl: ?Impl = null,

    const Impl = union(core.Backend) {
        vulkan: VulkanBindGroupBackend.VulkanBindGroupLayout,
        metal: MetalBindGroupBackend.MetalBindGroupLayout,
    };

    pub fn deinit(self: *BindGroupLayout) void {
        assertAlive(self.alive, .bind_group_layout);
        self.alive = false;
        if (self.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        };
        self.allocator.free(self.entries);
        self.tracker.release(.bind_group_layout);
    }

    pub fn selectedBackend(self: BindGroupLayout) core.Backend {
        return self.backend;
    }

    pub fn descriptor(self: BindGroupLayout) core.BindGroupLayoutDescriptor {
        assertAlive(self.alive, .bind_group_layout);
        return .{ .entries = self.entries };
    }
};

pub const BindGroupBufferBinding = struct {
    buffer: *Buffer,
    offset: u64 = 0,
    size: ?u64 = null,
};

pub const BindGroupResource = union(core.BindingResourceKind) {
    uniform_buffer: BindGroupBufferBinding,
    storage_buffer: BindGroupBufferBinding,
    storage_texture: *TextureView,
    sampled_texture: *TextureView,
    sampler: *SamplerState,

    fn resourceKind(self: BindGroupResource) core.BindingResourceKind {
        return switch (self) {
            .uniform_buffer => .uniform_buffer,
            .storage_buffer => .storage_buffer,
            .storage_texture => .storage_texture,
            .sampled_texture => .sampled_texture,
            .sampler => .sampler,
        };
    }

    fn validateRuntimeResource(self: BindGroupResource, expected_backend: core.Backend) RuntimeError!void {
        switch (self) {
            .uniform_buffer, .storage_buffer => |binding| {
                assertAlive(binding.buffer.alive, .buffer);
                try expectSameBackend(expected_backend, binding.buffer.backend);
            },
            .storage_texture => |texture_view| {
                assertAlive(texture_view.alive, .texture_view);
                try expectSameBackend(expected_backend, texture_view.backend);
                if (!texture_view.usage_value.shader_write) return RuntimeError.InvalidStorageTextureUsage;
            },
            .sampled_texture => |texture_view| {
                assertAlive(texture_view.alive, .texture_view);
                try expectSameBackend(expected_backend, texture_view.backend);
            },
            .sampler => |sampler_state| {
                assertAlive(sampler_state.alive, .sampler_state);
                try expectSameBackend(expected_backend, sampler_state.backend);
            },
        }
    }

    fn toCoreResource(self: BindGroupResource) core.BindGroupResource {
        return switch (self) {
            .uniform_buffer => |binding| .{
                .uniform_buffer = .{
                    .offset = binding.offset,
                    .size = binding.size,
                },
            },
            .storage_buffer => |binding| .{
                .storage_buffer = .{
                    .offset = binding.offset,
                    .size = binding.size,
                },
            },
            .storage_texture => .{ .storage_texture = .{} },
            .sampled_texture => .{ .sampled_texture = .{} },
            .sampler => .{ .sampler = .{} },
        };
    }
};

pub const BindGroupEntry = struct {
    binding: u32,
    resource: BindGroupResource,
};

pub const BindGroupDescriptor = struct {
    label: ?[]const u8 = null,
    layout: *BindGroupLayout,
    entries: []const BindGroupEntry = &.{},
};

pub const BindGroup = struct {
    backend: core.Backend,
    tracker: *ResourceTracker,
    allocator: std.mem.Allocator,
    alive: bool = true,
    entries: []core.BindGroupEntry,
    impl: ?Impl = null,

    const Impl = union(core.Backend) {
        vulkan: VulkanBindGroupBackend.VulkanBindGroup,
        metal: MetalBindGroupBackend.MetalBindGroup,
    };

    pub fn deinit(self: *BindGroup) void {
        assertAlive(self.alive, .bind_group);
        self.alive = false;
        if (self.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        };
        self.allocator.free(self.entries);
        self.tracker.release(.bind_group);
    }

    pub fn selectedBackend(self: BindGroup) core.Backend {
        return self.backend;
    }

    pub fn entryForBinding(self: BindGroup, binding: u32) ?core.BindGroupEntry {
        assertAlive(self.alive, .bind_group);
        for (self.entries) |entry| {
            if (entry.binding == binding) return entry;
        }
        return null;
    }
};

pub const RenderPassColorAttachmentTarget = union(enum) {
    current_drawable,
    texture_view: *TextureView,
};

pub const RenderPassColorAttachmentDescriptor = struct {
    target: RenderPassColorAttachmentTarget = .current_drawable,
    resolve_target: ?*TextureView = null,
    load_action: core.LoadAction = .clear,
    store_action: core.StoreAction = .store,
    clear_color: core.ClearColorLike = .{},

    fn validateRuntime(self: RenderPassColorAttachmentDescriptor, backend: core.Backend) !void {
        switch (self.target) {
            .current_drawable => {
                if (self.resolve_target != null) return RuntimeError.InvalidRenderPassAttachment;
            },
            .texture_view => |texture_view| {
                assertAlive(texture_view.alive, .texture_view);
                try expectSameBackend(backend, texture_view.backend);
                if (!texture_view.usage().render_attachment or !core.isColorFormat(texture_view.format())) {
                    return RuntimeError.InvalidRenderPassAttachment;
                }
                if (self.resolve_target) |resolve_target| {
                    assertAlive(resolve_target.alive, .texture_view);
                    try expectSameBackend(backend, resolve_target.backend);
                    if (!resolve_target.usage().render_attachment or !core.isColorFormat(resolve_target.format())) {
                        return RuntimeError.InvalidRenderPassAttachment;
                    }
                    if (texture_view.sampleCount() == 1 or resolve_target.sampleCount() != 1) {
                        return RuntimeError.InvalidRenderPassAttachment;
                    }
                    if (texture_view.format() != resolve_target.format() or
                        texture_view.width() != resolve_target.width() or
                        texture_view.height() != resolve_target.height())
                    {
                        return RuntimeError.InvalidRenderPassAttachment;
                    }
                } else if (texture_view.sampleCount() != 1) {
                    return RuntimeError.InvalidRenderPassAttachment;
                }
            },
        }
    }

    fn toCore(self: RenderPassColorAttachmentDescriptor) core.RenderPassColorAttachmentDescriptor {
        return .{
            .target = switch (self.target) {
                .current_drawable => .current_drawable,
                .texture_view => .texture_view,
            },
            .resolve_target = if (self.resolve_target) |_| .texture_view else null,
            .load_action = self.load_action,
            .store_action = self.store_action,
            .clear_color = self.clear_color,
        };
    }
};

pub const RenderPassDepthAttachmentTarget = union(enum) {
    current_drawable,
    texture_view: *TextureView,
};

pub const RenderPassDepthAttachmentDescriptor = struct {
    target: RenderPassDepthAttachmentTarget = .current_drawable,
    load_action: core.LoadAction = .clear,
    store_action: core.StoreAction = .dont_care,
    clear_depth: f32 = 1.0,

    fn validateRuntime(self: RenderPassDepthAttachmentDescriptor, backend: core.Backend) !void {
        try self.toCore().validate();
        switch (self.target) {
            .current_drawable => {},
            .texture_view => |texture_view| {
                assertAlive(texture_view.alive, .texture_view);
                try expectSameBackend(backend, texture_view.backend);
                if (!texture_view.usage().render_attachment or !core.isDepthFormat(texture_view.format())) {
                    return RuntimeError.InvalidRenderPassAttachment;
                }
            },
        }
    }

    fn toCore(self: RenderPassDepthAttachmentDescriptor) core.RenderPassDepthAttachmentDescriptor {
        return .{
            .target = switch (self.target) {
                .current_drawable => .current_drawable,
                .texture_view => .texture_view,
            },
            .load_action = self.load_action,
            .store_action = self.store_action,
            .clear_depth = self.clear_depth,
        };
    }
};

pub const RenderPassDescriptor = struct {
    label: ?[]const u8 = null,
    color_attachments: []const RenderPassColorAttachmentDescriptor = &.{},
    depth_attachment: ?RenderPassDepthAttachmentDescriptor = null,

    fn validateRuntime(self: RenderPassDescriptor, backend: core.Backend) !void {
        if (self.color_attachments.len != 1) return RuntimeError.InvalidRenderPassAttachment;
        for (self.color_attachments) |attachment| {
            try attachment.validateRuntime(backend);
        }
        if (self.depth_attachment) |depth_attachment| {
            try depth_attachment.validateRuntime(backend);
            try validateAttachmentExtents(self.color_attachments[0], depth_attachment);
            try validateAttachmentSampleCounts(self.color_attachments[0], depth_attachment);
        }
    }

    fn colorTargetUsesCurrentDrawable(self: RenderPassDescriptor) bool {
        if (self.color_attachments.len == 0) return false;
        return switch (self.color_attachments[0].target) {
            .current_drawable => true,
            .texture_view => false,
        };
    }
};

fn validateAttachmentExtents(
    color_attachment: RenderPassColorAttachmentDescriptor,
    depth_attachment: RenderPassDepthAttachmentDescriptor,
) RuntimeError!void {
    const color_view = switch (color_attachment.target) {
        .current_drawable => switch (depth_attachment.target) {
            .current_drawable => return,
            .texture_view => return RuntimeError.InvalidRenderPassAttachment,
        },
        .texture_view => |texture_view| texture_view,
    };
    const depth_view = switch (depth_attachment.target) {
        .current_drawable => return RuntimeError.InvalidRenderPassAttachment,
        .texture_view => |texture_view| texture_view,
    };

    if (color_view.width() != depth_view.width() or color_view.height() != depth_view.height()) {
        return RuntimeError.InvalidRenderPassAttachment;
    }
}

fn validateAttachmentSampleCounts(
    color_attachment: RenderPassColorAttachmentDescriptor,
    depth_attachment: RenderPassDepthAttachmentDescriptor,
) RuntimeError!void {
    const color_view = switch (color_attachment.target) {
        .current_drawable => switch (depth_attachment.target) {
            .current_drawable => return,
            .texture_view => return RuntimeError.InvalidRenderPassAttachment,
        },
        .texture_view => |texture_view| texture_view,
    };
    const depth_view = switch (depth_attachment.target) {
        .current_drawable => return RuntimeError.InvalidRenderPassAttachment,
        .texture_view => |texture_view| texture_view,
    };

    if (color_view.sampleCount() != depth_view.sampleCount()) {
        return RuntimeError.InvalidRenderPassAttachment;
    }
}

fn vulkanRenderPassDescriptor(descriptor: RenderPassDescriptor) VulkanCommand.RenderPassDescriptor {
    return .{
        .label = descriptor.label,
        .color_attachment = .{
            .target = vulkanColorAttachmentTarget(descriptor.color_attachments[0].target),
            .resolve_target = vulkanResolveAttachmentTarget(descriptor.color_attachments[0].resolve_target),
            .load_action = descriptor.color_attachments[0].load_action,
            .store_action = descriptor.color_attachments[0].store_action,
            .clear_color = descriptor.color_attachments[0].clear_color,
        },
        .depth_attachment = if (descriptor.depth_attachment) |depth_attachment| .{
            .target = vulkanDepthAttachmentTarget(depth_attachment.target),
            .load_action = depth_attachment.load_action,
            .store_action = depth_attachment.store_action,
            .clear_depth = depth_attachment.clear_depth,
        } else null,
    };
}

fn vulkanColorAttachmentTarget(target: RenderPassColorAttachmentTarget) VulkanCommand.RenderPassColorAttachmentTarget {
    return switch (target) {
        .current_drawable => .current_drawable,
        .texture_view => |texture_view| .{ .texture_view = &texture_view.impl.vulkan },
    };
}

fn vulkanResolveAttachmentTarget(target: ?*TextureView) ?*const @import("../backend/vulkan/texture_view.zig") {
    return if (target) |texture_view| &texture_view.impl.vulkan else null;
}

fn vulkanDepthAttachmentTarget(target: RenderPassDepthAttachmentTarget) VulkanCommand.RenderPassDepthAttachmentTarget {
    return switch (target) {
        .current_drawable => .current_drawable,
        .texture_view => |texture_view| .{ .texture_view = &texture_view.impl.vulkan },
    };
}

fn metalRenderPassDescriptor(descriptor: RenderPassDescriptor) MetalCommand.RenderPassDescriptor {
    return .{
        .label = descriptor.label,
        .color_attachment = .{
            .target = metalColorAttachmentTarget(descriptor.color_attachments[0].target),
            .resolve_target = metalResolveAttachmentTarget(descriptor.color_attachments[0].resolve_target),
            .load_action = descriptor.color_attachments[0].load_action,
            .store_action = descriptor.color_attachments[0].store_action,
            .clear_color = descriptor.color_attachments[0].clear_color,
        },
        .depth_attachment = if (descriptor.depth_attachment) |depth_attachment| .{
            .target = metalDepthAttachmentTarget(depth_attachment.target),
            .load_action = depth_attachment.load_action,
            .store_action = depth_attachment.store_action,
            .clear_depth = depth_attachment.clear_depth,
        } else null,
    };
}

fn metalColorAttachmentTarget(target: RenderPassColorAttachmentTarget) MetalCommand.RenderPassColorAttachmentTarget {
    return switch (target) {
        .current_drawable => .current_drawable,
        .texture_view => |texture_view| .{ .texture_view = &texture_view.impl.metal },
    };
}

fn metalResolveAttachmentTarget(target: ?*TextureView) ?*const @import("../backend/metal/texture_view.zig") {
    return if (target) |texture_view| &texture_view.impl.metal else null;
}

fn metalDepthAttachmentTarget(target: RenderPassDepthAttachmentTarget) MetalCommand.RenderPassDepthAttachmentTarget {
    return switch (target) {
        .current_drawable => .current_drawable,
        .texture_view => |texture_view| .{ .texture_view = &texture_view.impl.metal },
    };
}

pub const CommandBuffer = struct {
    backend: core.Backend,
    alive: bool = true,
    uses_current_drawable_pass: bool = false,
    debug: core.CommandBufferDebugState = .{},
    impl: ?Impl = null,

    const Impl = union(core.Backend) {
        vulkan: VulkanCommand.CommandBuffer,
        metal: MetalCommand.CommandBuffer,
    };

    pub fn makeRenderCommandEncoder(
        self: *CommandBuffer,
        descriptor: RenderPassDescriptor,
    ) !RenderCommandEncoder {
        assertObjectAlive(self.alive, "command_buffer");
        try descriptor.validateRuntime(self.backend);

        const core_color_attachments = [_]core.RenderPassColorAttachmentDescriptor{
            descriptor.color_attachments[0].toCore(),
        };
        const core_depth_attachment = if (descriptor.depth_attachment) |depth_attachment| depth_attachment.toCore() else null;
        const core_descriptor = core.RenderPassDescriptor{
            .label = descriptor.label,
            .color_attachments = core_color_attachments[0..],
            .depth_attachment = core_depth_attachment,
        };

        const debug_encoder = try self.debug.makeRenderCommandEncoder(core_descriptor);
        errdefer self.debug.state = .ready;
        self.uses_current_drawable_pass = descriptor.colorTargetUsesCurrentDrawable();

        const encoder_impl: ?RenderCommandEncoder.Impl = if (self.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| .{ .vulkan = try vulkan.makeRenderCommandEncoder(vulkanRenderPassDescriptor(descriptor)) },
            .metal => |*metal| .{ .metal = try metal.makeRenderCommandEncoder(metalRenderPassDescriptor(descriptor)) },
        } else null;

        return .{
            .backend = self.backend,
            .command_buffer = self,
            .debug = debug_encoder,
            .impl = encoder_impl,
        };
    }

    pub fn makeBlitCommandEncoder(self: *CommandBuffer) !BlitCommandEncoder {
        assertObjectAlive(self.alive, "command_buffer");

        const debug_encoder = try self.debug.makeBlitCommandEncoder();
        errdefer self.debug.state = .ready;
        self.uses_current_drawable_pass = false;

        const encoder_impl: ?BlitCommandEncoder.Impl = if (self.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| .{ .vulkan = try vulkan.makeBlitCommandEncoder() },
            .metal => |*metal| .{ .metal = try metal.makeBlitCommandEncoder() },
        } else null;

        return .{
            .backend = self.backend,
            .command_buffer = self,
            .debug = debug_encoder,
            .impl = encoder_impl,
        };
    }

    pub fn makeComputeCommandEncoder(self: *CommandBuffer) !ComputeCommandEncoder {
        assertObjectAlive(self.alive, "command_buffer");

        const debug_encoder = try self.debug.makeComputeCommandEncoder();
        errdefer self.debug.state = .ready;
        self.uses_current_drawable_pass = false;

        const encoder_impl: ?ComputeCommandEncoder.Impl = if (self.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| .{ .vulkan = try vulkan.makeComputeCommandEncoder() },
            .metal => |*metal| .{ .metal = try metal.makeComputeCommandEncoder() },
        } else null;

        return .{
            .backend = self.backend,
            .command_buffer = self,
            .debug = debug_encoder,
            .impl = encoder_impl,
        };
    }

    pub fn presentDrawable(self: *CommandBuffer) !void {
        assertObjectAlive(self.alive, "command_buffer");
        if (!self.uses_current_drawable_pass) return RuntimeError.PresentRequiresCurrentDrawable;
        try self.debug.presentDrawable();
        switch (self.impl orelse return) {
            .vulkan => |*vulkan| try vulkan.presentDrawable(),
            .metal => |*metal| try metal.presentDrawable(),
        }
    }

    pub fn commit(self: *CommandBuffer) !void {
        assertObjectAlive(self.alive, "command_buffer");
        try self.debug.commit();
        switch (self.impl orelse {
            self.alive = false;
            return;
        }) {
            .vulkan => |*vulkan| {
                try vulkan.commit();
                vulkan.deinit();
            },
            .metal => |*metal| {
                try metal.commit();
                metal.deinit();
            },
        }
        self.alive = false;
    }

    pub fn selectedBackend(self: CommandBuffer) core.Backend {
        return self.backend;
    }
};

pub const BlitCommandEncoder = struct {
    backend: core.Backend,
    command_buffer: *CommandBuffer,
    alive: bool = true,
    debug: core.BlitCommandEncoderDebugState = .{},
    impl: ?Impl = null,

    const Impl = union(core.Backend) {
        vulkan: VulkanCommand.BlitCommandEncoder,
        metal: MetalCommand.BlitCommandEncoder,
    };

    pub fn copyBufferToBuffer(
        self: *BlitCommandEncoder,
        source: *Buffer,
        destination: *Buffer,
        descriptor: core.CopyBufferToBufferDescriptor,
    ) !void {
        assertObjectAlive(self.alive, "blit_command_encoder");
        assertAlive(source.alive, .buffer);
        assertAlive(destination.alive, .buffer);
        try expectSameBackend(self.backend, source.backend);
        try expectSameBackend(self.backend, destination.backend);
        if (!source.usage_value.copy_source) return core.CommandEncodingError.InvalidCopyBufferUsage;
        if (!destination.usage_value.copy_destination) return core.CommandEncodingError.InvalidCopyBufferUsage;
        try self.debug.copyBufferToBuffer(descriptor, source.length(), destination.length());
        if (self.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.copyBufferToBuffer(&source.impl.vulkan, &destination.impl.vulkan, descriptor),
            .metal => |*metal| try metal.copyBufferToBuffer(&source.impl.metal, &destination.impl.metal, descriptor),
        };
    }

    pub fn copyBufferToTexture(
        self: *BlitCommandEncoder,
        source: *Buffer,
        destination: *Texture,
        descriptor: core.CopyBufferToTextureDescriptor,
    ) !void {
        assertObjectAlive(self.alive, "blit_command_encoder");
        assertAlive(source.alive, .buffer);
        assertAlive(destination.alive, .texture);
        try expectSameBackend(self.backend, source.backend);
        try expectSameBackend(self.backend, destination.backend);
        if (!source.usage_value.copy_source) return core.CommandEncodingError.InvalidCopyBufferUsage;
        if (!destination.usage_value.copy_destination) return core.CommandEncodingError.InvalidCopyTextureUsage;
        const resolved = try self.debug.copyBufferToTexture(descriptor, source.length(), destination.textureDescriptor());
        if (self.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.copyBufferToTexture(&source.impl.vulkan, &destination.impl.vulkan, resolved),
            .metal => |*metal| try metal.copyBufferToTexture(&source.impl.metal, &destination.impl.metal, resolved),
        };
    }

    pub fn copyTextureToBuffer(
        self: *BlitCommandEncoder,
        source: *Texture,
        destination: *Buffer,
        descriptor: core.CopyTextureToBufferDescriptor,
    ) !void {
        assertObjectAlive(self.alive, "blit_command_encoder");
        assertAlive(source.alive, .texture);
        assertAlive(destination.alive, .buffer);
        try expectSameBackend(self.backend, source.backend);
        try expectSameBackend(self.backend, destination.backend);
        if (!source.usage_value.copy_source) return core.CommandEncodingError.InvalidCopyTextureUsage;
        if (!destination.usage_value.copy_destination) return core.CommandEncodingError.InvalidCopyBufferUsage;
        const resolved = try self.debug.copyTextureToBuffer(descriptor, source.textureDescriptor(), destination.length());
        if (self.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.copyTextureToBuffer(&source.impl.vulkan, &destination.impl.vulkan, resolved),
            .metal => |*metal| try metal.copyTextureToBuffer(&source.impl.metal, &destination.impl.metal, resolved),
        };
    }

    pub fn endEncoding(self: *BlitCommandEncoder) !void {
        assertObjectAlive(self.alive, "blit_command_encoder");
        try self.debug.endEncoding(&self.command_buffer.debug);
        if (self.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.endEncoding(),
            .metal => |*metal| {
                try metal.endEncoding();
                metal.deinit();
            },
        };
        self.alive = false;
    }

    pub fn selectedBackend(self: BlitCommandEncoder) core.Backend {
        return self.backend;
    }
};

pub const ComputeCommandEncoder = struct {
    backend: core.Backend,
    command_buffer: *CommandBuffer,
    alive: bool = true,
    debug: core.ComputeCommandEncoderDebugState = .{},
    impl: ?Impl = null,

    const Impl = union(core.Backend) {
        vulkan: VulkanCommand.ComputeCommandEncoder,
        metal: MetalCommand.ComputeCommandEncoder,
    };

    pub fn setComputePipelineState(
        self: *ComputeCommandEncoder,
        pipeline: *ComputePipelineState,
    ) !void {
        assertObjectAlive(self.alive, "compute_command_encoder");
        assertAlive(pipeline.alive, .compute_pipeline_state);
        try expectSameBackend(self.backend, pipeline.backend);
        try self.debug.setComputePipelineState();
        if (self.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.setComputePipelineState(&pipeline.impl.vulkan),
            .metal => |*metal| try metal.setComputePipelineState(&pipeline.impl.metal),
        };
    }

    pub fn setBindGroup(
        self: *ComputeCommandEncoder,
        bind_group: *BindGroup,
        binding: core.BindGroupBinding,
    ) !void {
        assertObjectAlive(self.alive, "compute_command_encoder");
        assertAlive(bind_group.alive, .bind_group);
        try expectSameBackend(self.backend, bind_group.backend);
        try self.debug.setBindGroup(binding);
        if (self.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.setBindGroup(&bind_group.impl.?.vulkan, binding),
            .metal => |*metal| try metal.setBindGroup(&bind_group.impl.?.metal, binding),
        };
    }

    pub fn dispatchThreadgroups(
        self: *ComputeCommandEncoder,
        descriptor: core.DispatchThreadgroupsDescriptor,
    ) !void {
        assertObjectAlive(self.alive, "compute_command_encoder");
        try self.debug.dispatchThreadgroups(descriptor);
        if (self.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.dispatchThreadgroups(descriptor),
            .metal => |*metal| try metal.dispatchThreadgroups(descriptor),
        };
    }

    pub fn endEncoding(self: *ComputeCommandEncoder) !void {
        assertObjectAlive(self.alive, "compute_command_encoder");
        try self.debug.endEncoding(&self.command_buffer.debug);
        if (self.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.endEncoding(),
            .metal => |*metal| {
                try metal.endEncoding();
                metal.deinit();
            },
        };
        self.alive = false;
    }

    pub fn selectedBackend(self: ComputeCommandEncoder) core.Backend {
        return self.backend;
    }
};

pub const RenderCommandEncoder = struct {
    backend: core.Backend,
    command_buffer: *CommandBuffer,
    alive: bool = true,
    debug: core.RenderCommandEncoderDebugState = .{},
    impl: ?Impl = null,

    const Impl = union(core.Backend) {
        vulkan: VulkanCommand.RenderCommandEncoder,
        metal: MetalCommand.RenderCommandEncoder,
    };

    pub fn setRenderPipelineState(
        self: *RenderCommandEncoder,
        pipeline: *RenderPipelineState,
    ) !void {
        assertObjectAlive(self.alive, "render_command_encoder");
        assertAlive(pipeline.alive, .render_pipeline_state);
        try expectSameBackend(self.backend, pipeline.backend);
        try self.debug.setRenderPipelineState();
        if (self.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.setRenderPipelineState(&pipeline.impl.vulkan),
            .metal => |*metal| try metal.setRenderPipelineState(&pipeline.impl.metal),
        };
    }

    pub fn setVertexBuffer(
        self: *RenderCommandEncoder,
        buffer: *Buffer,
        binding: core.VertexBufferBinding,
    ) !void {
        assertObjectAlive(self.alive, "render_command_encoder");
        assertAlive(buffer.alive, .buffer);
        try expectSameBackend(self.backend, buffer.backend);
        try self.debug.setVertexBuffer(binding);
        if (self.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.setVertexBuffer(&buffer.impl.vulkan, binding),
            .metal => |*metal| try metal.setVertexBuffer(&buffer.impl.metal, binding),
        };
    }

    pub fn setIndexBuffer(self: *RenderCommandEncoder, buffer: *Buffer) !void {
        assertObjectAlive(self.alive, "render_command_encoder");
        assertAlive(buffer.alive, .buffer);
        try expectSameBackend(self.backend, buffer.backend);
        try self.debug.setIndexBuffer();
        if (self.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.setIndexBuffer(&buffer.impl.vulkan),
            .metal => |*metal| try metal.setIndexBuffer(&buffer.impl.metal),
        };
    }

    pub fn setBindGroup(
        self: *RenderCommandEncoder,
        bind_group: *BindGroup,
        binding: core.BindGroupBinding,
    ) !void {
        assertObjectAlive(self.alive, "render_command_encoder");
        assertAlive(bind_group.alive, .bind_group);
        try expectSameBackend(self.backend, bind_group.backend);
        try self.debug.setBindGroup(binding);
        if (self.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.setBindGroup(&bind_group.impl.?.vulkan, binding),
            .metal => |*metal| try metal.setBindGroup(&bind_group.impl.?.metal, binding),
        };
    }

    pub fn drawPrimitives(
        self: *RenderCommandEncoder,
        descriptor: core.DrawPrimitivesDescriptor,
    ) !void {
        assertObjectAlive(self.alive, "render_command_encoder");
        try self.debug.drawPrimitives(descriptor);
        if (self.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.drawPrimitives(descriptor),
            .metal => |*metal| try metal.drawPrimitives(descriptor),
        };
    }

    pub fn drawIndexedPrimitives(
        self: *RenderCommandEncoder,
        descriptor: core.DrawIndexedPrimitivesDescriptor,
    ) !void {
        assertObjectAlive(self.alive, "render_command_encoder");
        try self.debug.drawIndexedPrimitives(descriptor);
        if (self.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.drawIndexedPrimitives(descriptor),
            .metal => |*metal| try metal.drawIndexedPrimitives(descriptor),
        };
    }

    pub fn endEncoding(self: *RenderCommandEncoder) !void {
        assertObjectAlive(self.alive, "render_command_encoder");
        try self.debug.endEncoding(&self.command_buffer.debug);
        if (self.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.endEncoding(),
            .metal => |*metal| {
                try metal.endEncoding();
                metal.deinit();
            },
        };
        self.alive = false;
    }

    pub fn selectedBackend(self: RenderCommandEncoder) core.Backend {
        return self.backend;
    }
};

pub const WindowContextOptions = struct {
    app_name: [*:0]const u8,
    backend: core.BackendPreference = .auto,
    debug_backend_override: ?core.Backend = null,
    process_args: ?std.process.Args = null,
    shader_cache_dir: ?[]const u8 = null,
    slangc_path: ?[]const u8 = null,
    surface: core.SurfaceDescriptor,
    presentation: core.PresentationDescriptor,
};

pub const RuntimeError = error{
    UnsupportedSurfaceProvider,
    UnsupportedBackendForPresentation,
    BackendMismatch,
    InvalidRenderPassAttachment,
    InvalidStorageTextureUsage,
    PresentRequiresCurrentDrawable,
};

pub const WindowContext = struct {
    allocator: std.mem.Allocator,
    tracker: *ResourceTracker,
    backend: core.Backend,
    shader_cache_dir: ?[]const u8 = null,
    owns_shader_cache_dir: bool = false,
    slangc_path: ?[]const u8 = null,
    impl: Impl,

    const Impl = union(core.Backend) {
        vulkan: VulkanClearScreen,
        metal: MetalClearScreen,
    };

    pub fn init(allocator: std.mem.Allocator, options: WindowContextOptions) !WindowContext {
        const tracker = try allocator.create(ResourceTracker);
        errdefer allocator.destroy(tracker);
        tracker.* = .{};

        const resolved_shader_cache_dir = try resolveShaderCacheDir(allocator, options);
        errdefer resolved_shader_cache_dir.deinit(allocator);

        const backend_preference: core.BackendPreference = if (build_options.force_vulkan) .vulkan else options.backend;
        const debug_backend_override: ?core.Backend = if (build_options.force_vulkan) null else options.debug_backend_override;
        const backend = try core.selectBackend(.{
            .preference = backend_preference,
            .availability = presentationAvailability(options.surface),
            .debug_override = debug_backend_override,
        });

        return switch (backend) {
            .vulkan => .{
                .allocator = allocator,
                .tracker = tracker,
                .backend = .vulkan,
                .shader_cache_dir = resolved_shader_cache_dir.value,
                .owns_shader_cache_dir = resolved_shader_cache_dir.owned,
                .slangc_path = options.slangc_path,
                .impl = .{
                    .vulkan = try VulkanClearScreen.init(
                        allocator,
                        options.app_name,
                        options.surface,
                        options.presentation,
                    ),
                },
            },
            .metal => .{
                .allocator = allocator,
                .tracker = tracker,
                .backend = .metal,
                .shader_cache_dir = resolved_shader_cache_dir.value,
                .owns_shader_cache_dir = resolved_shader_cache_dir.owned,
                .slangc_path = options.slangc_path,
                .impl = .{
                    .metal = try MetalClearScreen.init(
                        options.surface,
                        options.presentation,
                    ),
                },
            },
        };
    }

    pub fn deinit(self: *WindowContext) void {
        self.tracker.assertNoLeaks();
        switch (self.impl) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        }
        if (self.owns_shader_cache_dir) {
            if (self.shader_cache_dir) |shader_cache_dir| {
                self.allocator.free(shader_cache_dir);
            }
        }
        self.allocator.destroy(self.tracker);
    }

    pub fn selectedBackend(self: WindowContext) core.Backend {
        return self.backend;
    }

    pub fn compileRenderShader(
        self: *WindowContext,
        name: []const u8,
        source: []const u8,
        options: ShaderCompiler.RenderShaderOptions,
    ) !ShaderCompiler.CompiledRenderShader {
        return try ShaderCompiler.compileRenderShader(
            self.allocator,
            name,
            source,
            options,
            self.shaderCompilerOptions(),
        );
    }

    pub fn compileComputeShader(
        self: *WindowContext,
        name: []const u8,
        source: []const u8,
        options: ShaderCompiler.ComputeShaderOptions,
    ) !ShaderCompiler.CompiledComputeShader {
        return try ShaderCompiler.compileComputeShader(
            self.allocator,
            name,
            source,
            options,
            self.shaderCompilerOptions(),
        );
    }

    fn shaderCompilerOptions(self: WindowContext) ShaderCompiler.CompilerOptions {
        return .{
            .slangc_path = self.slangc_path orelse build_options.slangc_path,
            .cache_dir = self.shader_cache_dir,
        };
    }

    pub fn resize(self: *WindowContext, extent: core.Extent2D) !void {
        switch (self.impl) {
            .vulkan => |*vulkan| try vulkan.resize(extent),
            .metal => |*metal| try metal.resize(extent),
        }
    }

    pub fn clear(self: *WindowContext, color: ClearColor) !void {
        switch (self.impl) {
            .vulkan => |*vulkan| try vulkan.clear(color),
            .metal => |*metal| try metal.clear(color),
        }
    }

    pub fn makeCommandBuffer(self: *WindowContext) !CommandBuffer {
        const impl = switch (self.impl) {
            .vulkan => |*vulkan| CommandBuffer.Impl{ .vulkan = try vulkan.makeCommandBuffer() },
            .metal => |*metal| CommandBuffer.Impl{ .metal = try metal.makeCommandBuffer() },
        };
        return .{
            .backend = self.backend,
            .impl = impl,
        };
    }

    pub fn makeBuffer(self: *WindowContext, descriptor: core.BufferDescriptor) !Buffer {
        const impl = switch (self.impl) {
            .vulkan => |*vulkan| Buffer.Impl{ .vulkan = try vulkan.makeBuffer(descriptor) },
            .metal => |*metal| Buffer.Impl{ .metal = try metal.makeBuffer(descriptor) },
        };
        self.tracker.retain(.buffer);
        return switch (self.impl) {
            .vulkan => .{
                .backend = .vulkan,
                .tracker = self.tracker,
                .usage_value = descriptor.usage,
                .impl = impl,
            },
            .metal => .{
                .backend = .metal,
                .tracker = self.tracker,
                .usage_value = descriptor.usage,
                .impl = impl,
            },
        };
    }

    pub fn makeShaderModule(self: *WindowContext, descriptor: core.ShaderModuleDescriptor) !ShaderModule {
        const impl = switch (self.impl) {
            .vulkan => |*vulkan| ShaderModule.Impl{ .vulkan = try vulkan.makeShaderModule(descriptor) },
            .metal => |*metal| ShaderModule.Impl{ .metal = try metal.makeShaderModule(self.allocator, descriptor) },
        };
        self.tracker.retain(.shader_module);
        return switch (self.impl) {
            .vulkan => .{
                .backend = .vulkan,
                .tracker = self.tracker,
                .impl = impl,
            },
            .metal => .{
                .backend = .metal,
                .tracker = self.tracker,
                .impl = impl,
            },
        };
    }

    pub fn makeRenderPipelineState(self: *WindowContext, descriptor: core.RenderPipelineDescriptor) !RenderPipelineState {
        try descriptor.validate();
        try ShaderReflection.validateRenderPipelineDescriptor(self.allocator, descriptor);
        const impl = switch (self.impl) {
            .vulkan => |*vulkan| RenderPipelineState.Impl{ .vulkan = try vulkan.makeRenderPipelineState(descriptor) },
            .metal => |*metal| RenderPipelineState.Impl{ .metal = try metal.makeRenderPipelineState(self.allocator, descriptor) },
        };
        self.tracker.retain(.render_pipeline_state);
        return switch (self.impl) {
            .vulkan => .{
                .backend = .vulkan,
                .tracker = self.tracker,
                .impl = impl,
            },
            .metal => .{
                .backend = .metal,
                .tracker = self.tracker,
                .impl = impl,
            },
        };
    }

    pub fn makeComputePipelineState(self: *WindowContext, descriptor: core.ComputePipelineDescriptor) !ComputePipelineState {
        try descriptor.validate();
        try ShaderReflection.validateComputePipelineDescriptor(self.allocator, descriptor);
        const impl = switch (self.impl) {
            .vulkan => |*vulkan| ComputePipelineState.Impl{ .vulkan = try vulkan.makeComputePipelineState(descriptor) },
            .metal => |*metal| ComputePipelineState.Impl{ .metal = try metal.makeComputePipelineState(self.allocator, descriptor) },
        };
        self.tracker.retain(.compute_pipeline_state);
        return switch (self.impl) {
            .vulkan => .{
                .backend = .vulkan,
                .tracker = self.tracker,
                .impl = impl,
            },
            .metal => .{
                .backend = .metal,
                .tracker = self.tracker,
                .impl = impl,
            },
        };
    }

    pub fn makeBindGroupLayout(self: *WindowContext, descriptor: core.BindGroupLayoutDescriptor) !BindGroupLayout {
        try descriptor.validate();

        const entries = try self.allocator.dupe(core.BindGroupLayoutEntry, descriptor.entries);
        errdefer self.allocator.free(entries);

        const impl = switch (self.impl) {
            .vulkan => |*vulkan| BindGroupLayout.Impl{
                .vulkan = try VulkanBindGroupBackend.VulkanBindGroupLayout.init(
                    vulkan.gc,
                    self.allocator,
                    descriptor,
                ),
            },
            .metal => BindGroupLayout.Impl{
                .metal = try MetalBindGroupBackend.MetalBindGroupLayout.init(
                    self.allocator,
                    descriptor,
                ),
            },
        };

        self.tracker.retain(.bind_group_layout);
        return .{
            .backend = self.backend,
            .tracker = self.tracker,
            .allocator = self.allocator,
            .entries = entries,
            .impl = impl,
        };
    }

    pub fn makeBindGroup(self: *WindowContext, descriptor: BindGroupDescriptor) !BindGroup {
        const entries = try materializeBindGroupEntries(self.allocator, self.backend, descriptor);
        errdefer self.allocator.free(entries);

        const impl = switch (self.impl) {
            .vulkan => |*vulkan| bind_group_impl: {
                const vulkan_entries = try materializeVulkanBindGroupEntries(self.allocator, descriptor.entries);
                defer self.allocator.free(vulkan_entries);

                break :bind_group_impl BindGroup.Impl{
                    .vulkan = try VulkanBindGroupBackend.VulkanBindGroup.init(
                        vulkan.gc,
                        self.allocator,
                        &descriptor.layout.impl.?.vulkan,
                        vulkan_entries,
                    ),
                };
            },
            .metal => bind_group_impl: {
                const metal_entries = try materializeMetalBindGroupEntries(self.allocator, descriptor.entries);
                defer self.allocator.free(metal_entries);

                break :bind_group_impl BindGroup.Impl{
                    .metal = try MetalBindGroupBackend.MetalBindGroup.init(
                        self.allocator,
                        &descriptor.layout.impl.?.metal,
                        metal_entries,
                    ),
                };
            },
        };

        self.tracker.retain(.bind_group);
        return .{
            .backend = self.backend,
            .tracker = self.tracker,
            .allocator = self.allocator,
            .entries = entries,
            .impl = impl,
        };
    }

    pub fn makeTexture(self: *WindowContext, descriptor: core.TextureDescriptor) !Texture {
        const impl = switch (self.impl) {
            .vulkan => |*vulkan| Texture.Impl{ .vulkan = try vulkan.makeTexture(descriptor) },
            .metal => |*metal| Texture.Impl{ .metal = try metal.makeTexture(descriptor) },
        };
        self.tracker.retain(.texture);
        return switch (self.impl) {
            .vulkan => .{
                .backend = .vulkan,
                .tracker = self.tracker,
                .dimension_value = descriptor.dimension,
                .format_value = descriptor.format,
                .usage_value = descriptor.usage,
                .sample_count_value = descriptor.sample_count,
                .impl = impl,
            },
            .metal => .{
                .backend = .metal,
                .tracker = self.tracker,
                .dimension_value = descriptor.dimension,
                .format_value = descriptor.format,
                .usage_value = descriptor.usage,
                .sample_count_value = descriptor.sample_count,
                .impl = impl,
            },
        };
    }

    pub fn makeSamplerState(self: *WindowContext, descriptor: core.SamplerDescriptor) !SamplerState {
        const impl = switch (self.impl) {
            .vulkan => |*vulkan| SamplerState.Impl{ .vulkan = try vulkan.makeSamplerState(descriptor) },
            .metal => |*metal| SamplerState.Impl{ .metal = try metal.makeSamplerState(descriptor) },
        };
        self.tracker.retain(.sampler_state);
        return switch (self.impl) {
            .vulkan => .{
                .backend = .vulkan,
                .tracker = self.tracker,
                .impl = impl,
            },
            .metal => .{
                .backend = .metal,
                .tracker = self.tracker,
                .impl = impl,
            },
        };
    }
};

fn materializeBindGroupEntries(
    allocator: std.mem.Allocator,
    backend: core.Backend,
    descriptor: BindGroupDescriptor,
) ![]core.BindGroupEntry {
    assertAlive(descriptor.layout.alive, .bind_group_layout);
    try expectSameBackend(backend, descriptor.layout.backend);

    const entries = try allocator.alloc(core.BindGroupEntry, descriptor.entries.len);
    errdefer allocator.free(entries);

    for (descriptor.entries, entries) |entry, *out| {
        try entry.resource.validateRuntimeResource(backend);
        out.* = .{
            .binding = entry.binding,
            .resource = entry.resource.toCoreResource(),
        };
    }

    try (core.BindGroupDescriptor{
        .layout = descriptor.layout.descriptor(),
        .entries = entries,
    }).validate();

    return entries;
}

fn materializeVulkanBindGroupEntries(
    allocator: std.mem.Allocator,
    entries: []const BindGroupEntry,
) ![]VulkanBindGroupBackend.VulkanBindGroup.Entry {
    const vulkan_entries = try allocator.alloc(VulkanBindGroupBackend.VulkanBindGroup.Entry, entries.len);

    for (entries, vulkan_entries) |entry, *out| {
        out.* = .{
            .binding = entry.binding,
            .resource = switch (entry.resource) {
                .uniform_buffer => |binding| .{
                    .uniform_buffer = .{
                        .buffer = &binding.buffer.impl.vulkan,
                        .offset = binding.offset,
                        .size = binding.size,
                    },
                },
                .storage_buffer => |binding| .{
                    .storage_buffer = .{
                        .buffer = &binding.buffer.impl.vulkan,
                        .offset = binding.offset,
                        .size = binding.size,
                    },
                },
                .storage_texture => |texture_view| .{
                    .storage_texture = &texture_view.impl.vulkan,
                },
                .sampled_texture => |texture_view| .{
                    .sampled_texture = &texture_view.impl.vulkan,
                },
                .sampler => |sampler_state| .{
                    .sampler = &sampler_state.impl.vulkan,
                },
            },
        };
    }

    return vulkan_entries;
}

fn materializeMetalBindGroupEntries(
    allocator: std.mem.Allocator,
    entries: []const BindGroupEntry,
) ![]MetalBindGroupBackend.MetalBindGroup.Entry {
    const metal_entries = try allocator.alloc(MetalBindGroupBackend.MetalBindGroup.Entry, entries.len);

    for (entries, metal_entries) |entry, *out| {
        out.* = .{
            .binding = entry.binding,
            .resource = switch (entry.resource) {
                .uniform_buffer => |binding| .{
                    .uniform_buffer = .{
                        .buffer = &binding.buffer.impl.metal,
                        .offset = binding.offset,
                        .size = binding.size,
                    },
                },
                .storage_buffer => |binding| .{
                    .storage_buffer = .{
                        .buffer = &binding.buffer.impl.metal,
                        .offset = binding.offset,
                        .size = binding.size,
                    },
                },
                .storage_texture => |texture_view| .{
                    .storage_texture = &texture_view.impl.metal,
                },
                .sampled_texture => |texture_view| .{
                    .sampled_texture = &texture_view.impl.metal,
                },
                .sampler => |sampler_state| .{
                    .sampler = &sampler_state.impl.metal,
                },
            },
        };
    }

    return metal_entries;
}

fn assertAlive(alive: bool, kind: ResourceKind) void {
    if (builtin.mode == .Debug and !alive) {
        std.debug.panic("vkmtl attempted to use a deinitialized {s}", .{kindName(kind)});
    }
}

fn assertObjectAlive(alive: bool, comptime name: []const u8) void {
    if (builtin.mode == .Debug and !alive) {
        std.debug.panic("vkmtl attempted to use a deinitialized {s}", .{name});
    }
}

fn expectSameBackend(lhs: core.Backend, rhs: core.Backend) RuntimeError!void {
    if (lhs != rhs) return RuntimeError.BackendMismatch;
}

fn kindName(kind: ResourceKind) []const u8 {
    return switch (kind) {
        .buffer => "buffer",
        .texture => "texture",
        .texture_view => "texture_view",
        .sampler_state => "sampler_state",
        .shader_module => "shader_module",
        .render_pipeline_state => "render_pipeline_state",
        .compute_pipeline_state => "compute_pipeline_state",
        .bind_group_layout => "bind_group_layout",
        .bind_group => "bind_group",
    };
}

fn presentationAvailability(surface: core.SurfaceDescriptor) core.BackendAvailability {
    const source = surface.source;
    return .{
        .vulkan = if (source) |src| src.vulkan != null else false,
        .metal = builtin.os.tag.isDarwin() and metalSurfaceCompatible(surface),
    };
}

fn metalSurfaceCompatible(surface: core.SurfaceDescriptor) bool {
    const source = surface.source orelse return false;
    return source.display != null or source.provider == .metal_layer or source.provider == .app_kit_view;
}

const ResolvedShaderCacheDir = struct {
    value: ?[]const u8 = null,
    owned: bool = false,

    fn deinit(self: ResolvedShaderCacheDir, allocator: std.mem.Allocator) void {
        if (self.owned) {
            if (self.value) |value| allocator.free(value);
        }
    }
};

fn resolveShaderCacheDir(
    allocator: std.mem.Allocator,
    options: WindowContextOptions,
) !ResolvedShaderCacheDir {
    if (options.shader_cache_dir) |shader_cache_dir| {
        return .{ .value = shader_cache_dir };
    }

    const process_args = options.process_args orelse return .{};
    const parsed = try parseShaderCacheDirFromProcessArgs(allocator, process_args);
    return .{
        .value = parsed,
        .owned = parsed != null,
    };
}

fn parseShaderCacheDirFromProcessArgs(
    allocator: std.mem.Allocator,
    args: std.process.Args,
) !?[]u8 {
    var iterator = try std.process.Args.Iterator.initAllocator(args, allocator);
    defer iterator.deinit();

    _ = iterator.skip();
    return try parseShaderCacheDirFromIterator(allocator, &iterator);
}

fn parseShaderCacheDirFromIterator(
    allocator: std.mem.Allocator,
    iterator: anytype,
) !?[]u8 {
    while (iterator.next()) |arg| {
        if (std.mem.eql(u8, arg, "--cache-dir")) {
            const value = iterator.next() orelse return error.MissingShaderCacheDirValue;
            if (value.len == 0) return error.MissingShaderCacheDirValue;
            return try allocator.dupe(u8, value);
        }

        if (std.mem.startsWith(u8, arg, "--cache-dir=")) {
            const value = arg["--cache-dir=".len..];
            if (value.len == 0) return error.MissingShaderCacheDirValue;
            return try allocator.dupe(u8, value);
        }
    }

    return null;
}

fn mipDimension(base: u32, level: u32) u32 {
    var value = base;
    var i: u32 = 0;
    while (i < level and value > 1) : (i += 1) {
        value /= 2;
    }
    return value;
}

const TestArgIterator = struct {
    args: []const []const u8,
    index: usize = 0,

    fn next(self: *TestArgIterator) ?[]const u8 {
        if (self.index >= self.args.len) return null;
        const arg = self.args[self.index];
        self.index += 1;
        return arg;
    }
};

test "runtime parses shader cache dir from split process args" {
    var iterator = TestArgIterator{ .args = &.{ "--cache-dir", "zig-out/custom-cache" } };
    const parsed = try parseShaderCacheDirFromIterator(std.testing.allocator, &iterator);
    defer std.testing.allocator.free(parsed.?);

    try std.testing.expectEqualStrings("zig-out/custom-cache", parsed.?);
}

test "runtime parses shader cache dir from equals process arg" {
    var iterator = TestArgIterator{ .args = &.{"--cache-dir=zig-out/custom-cache"} };
    const parsed = try parseShaderCacheDirFromIterator(std.testing.allocator, &iterator);
    defer std.testing.allocator.free(parsed.?);

    try std.testing.expectEqualStrings("zig-out/custom-cache", parsed.?);
}

test "runtime rejects shader cache dir arg without value" {
    var iterator = TestArgIterator{ .args = &.{"--cache-dir"} };
    try std.testing.expectError(
        error.MissingShaderCacheDirValue,
        parseShaderCacheDirFromIterator(std.testing.allocator, &iterator),
    );
}

test "runtime bind group materialization validates resources against layout" {
    const allocator = std.testing.allocator;
    var tracker = ResourceTracker{};

    const layout_entries = [_]core.BindGroupLayoutEntry{
        .{
            .binding = 0,
            .resource = .uniform_buffer,
            .visibility = .{ .vertex = true },
        },
        .{
            .binding = 1,
            .resource = .sampled_texture,
            .visibility = .{ .fragment = true },
        },
        .{
            .binding = 2,
            .resource = .sampler,
            .visibility = .{ .fragment = true },
        },
    };
    const copied_layout_entries = try allocator.dupe(core.BindGroupLayoutEntry, layout_entries[0..]);
    var layout = BindGroupLayout{
        .backend = .vulkan,
        .tracker = &tracker,
        .allocator = allocator,
        .entries = copied_layout_entries,
    };
    tracker.retain(.bind_group_layout);
    defer layout.deinit();

    var buffer = Buffer{
        .backend = .vulkan,
        .tracker = &tracker,
        .impl = undefined,
    };
    var texture_view = TextureView{
        .backend = .vulkan,
        .tracker = &tracker,
        .format_value = .rgba8_unorm,
        .usage_value = .{ .shader_read = true },
        .sample_count_value = 1,
        .width_value = 1,
        .height_value = 1,
        .impl = undefined,
    };
    var sampler = SamplerState{
        .backend = .vulkan,
        .tracker = &tracker,
        .impl = undefined,
    };

    const entries = [_]BindGroupEntry{
        .{
            .binding = 0,
            .resource = .{ .uniform_buffer = .{ .buffer = &buffer, .offset = 16, .size = 64 } },
        },
        .{
            .binding = 1,
            .resource = .{ .sampled_texture = &texture_view },
        },
        .{
            .binding = 2,
            .resource = .{ .sampler = &sampler },
        },
    };

    const materialized = try materializeBindGroupEntries(allocator, .vulkan, .{
        .layout = &layout,
        .entries = entries[0..],
    });
    defer allocator.free(materialized);

    try std.testing.expectEqual(@as(usize, 3), materialized.len);
    try std.testing.expectEqual(core.BindingResourceKind.uniform_buffer, materialized[0].resource.resourceKind());
    try std.testing.expectEqual(@as(u64, 16), materialized[0].resource.uniform_buffer.offset);
    try std.testing.expectEqual(@as(?u64, 64), materialized[0].resource.uniform_buffer.size);

    try std.testing.expectError(core.BindingError.MissingBindGroupEntry, materializeBindGroupEntries(allocator, .vulkan, .{
        .layout = &layout,
        .entries = entries[0..2],
    }));

    const invalid_range_entries = [_]BindGroupEntry{
        .{
            .binding = 0,
            .resource = .{ .uniform_buffer = .{ .buffer = &buffer, .size = 0 } },
        },
        .{
            .binding = 1,
            .resource = .{ .sampled_texture = &texture_view },
        },
        .{
            .binding = 2,
            .resource = .{ .sampler = &sampler },
        },
    };
    try std.testing.expectError(core.BindingError.InvalidBufferBindingRange, materializeBindGroupEntries(allocator, .vulkan, .{
        .layout = &layout,
        .entries = invalid_range_entries[0..],
    }));

    var metal_buffer = Buffer{
        .backend = .metal,
        .tracker = &tracker,
        .impl = undefined,
    };
    const backend_mismatch_entries = [_]BindGroupEntry{
        .{
            .binding = 0,
            .resource = .{ .uniform_buffer = .{ .buffer = &metal_buffer } },
        },
        .{
            .binding = 1,
            .resource = .{ .sampled_texture = &texture_view },
        },
        .{
            .binding = 2,
            .resource = .{ .sampler = &sampler },
        },
    };
    try std.testing.expectError(RuntimeError.BackendMismatch, materializeBindGroupEntries(allocator, .vulkan, .{
        .layout = &layout,
        .entries = backend_mismatch_entries[0..],
    }));
}

test "runtime render encoder validates bind group binding" {
    var command_buffer = CommandBuffer{ .backend = .vulkan };
    const color_attachments = [_]RenderPassColorAttachmentDescriptor{.{}};
    var encoder = try command_buffer.makeRenderCommandEncoder(.{
        .color_attachments = color_attachments[0..],
    });

    var tracker = ResourceTracker{};
    var entries = [_]core.BindGroupEntry{};
    var bind_group = BindGroup{
        .backend = .vulkan,
        .tracker = &tracker,
        .allocator = std.testing.allocator,
        .entries = entries[0..],
    };
    try encoder.setBindGroup(&bind_group, .{ .index = 0 });
    try std.testing.expectEqual(@as(u64, 1), encoder.debug.bind_group_mask);

    var metal_bind_group = BindGroup{
        .backend = .metal,
        .tracker = &tracker,
        .allocator = std.testing.allocator,
        .entries = entries[0..],
    };
    try std.testing.expectError(RuntimeError.BackendMismatch, encoder.setBindGroup(&metal_bind_group, .{ .index = 0 }));
    try std.testing.expectError(error.InvalidBindGroupIndex, encoder.setBindGroup(&bind_group, .{ .index = 16 }));

    try encoder.endEncoding();
}

test "runtime render pass descriptor accepts texture-backed color targets" {
    var tracker = ResourceTracker{};
    var color_view = TextureView{
        .backend = .vulkan,
        .tracker = &tracker,
        .format_value = .rgba8_unorm,
        .usage_value = .{ .render_attachment = true, .shader_read = true },
        .sample_count_value = 1,
        .width_value = 64,
        .height_value = 64,
        .impl = undefined,
    };
    const color_attachments = [_]RenderPassColorAttachmentDescriptor{.{
        .target = .{ .texture_view = &color_view },
    }};

    try (RenderPassDescriptor{
        .color_attachments = color_attachments[0..],
    }).validateRuntime(.vulkan);
}

test "runtime render pass descriptor rejects invalid texture targets" {
    var tracker = ResourceTracker{};
    var sampled_only_view = TextureView{
        .backend = .vulkan,
        .tracker = &tracker,
        .format_value = .rgba8_unorm,
        .usage_value = .{ .shader_read = true },
        .sample_count_value = 1,
        .width_value = 64,
        .height_value = 64,
        .impl = undefined,
    };
    const color_attachments = [_]RenderPassColorAttachmentDescriptor{.{
        .target = .{ .texture_view = &sampled_only_view },
    }};

    try std.testing.expectError(RuntimeError.InvalidRenderPassAttachment, (RenderPassDescriptor{
        .color_attachments = color_attachments[0..],
    }).validateRuntime(.vulkan));
}

test "runtime render pass descriptor validates msaa resolve targets" {
    var tracker = ResourceTracker{};
    var msaa_view = TextureView{
        .backend = .vulkan,
        .tracker = &tracker,
        .format_value = .rgba8_unorm,
        .usage_value = .{ .render_attachment = true },
        .sample_count_value = 4,
        .width_value = 64,
        .height_value = 64,
        .impl = undefined,
    };
    var resolve_view = TextureView{
        .backend = .vulkan,
        .tracker = &tracker,
        .format_value = .rgba8_unorm,
        .usage_value = .{ .render_attachment = true, .shader_read = true },
        .sample_count_value = 1,
        .width_value = 64,
        .height_value = 64,
        .impl = undefined,
    };

    const color_attachments = [_]RenderPassColorAttachmentDescriptor{.{
        .target = .{ .texture_view = &msaa_view },
        .resolve_target = &resolve_view,
    }};
    try (RenderPassDescriptor{
        .color_attachments = color_attachments[0..],
    }).validateRuntime(.vulkan);

    const missing_resolve = [_]RenderPassColorAttachmentDescriptor{.{
        .target = .{ .texture_view = &msaa_view },
    }};
    try std.testing.expectError(RuntimeError.InvalidRenderPassAttachment, (RenderPassDescriptor{
        .color_attachments = missing_resolve[0..],
    }).validateRuntime(.vulkan));

    resolve_view.sample_count_value = 4;
    try std.testing.expectError(RuntimeError.InvalidRenderPassAttachment, (RenderPassDescriptor{
        .color_attachments = color_attachments[0..],
    }).validateRuntime(.vulkan));
}

test "runtime command buffer refuses to present offscreen render passes" {
    var tracker = ResourceTracker{};
    var color_view = TextureView{
        .backend = .vulkan,
        .tracker = &tracker,
        .format_value = .rgba8_unorm,
        .usage_value = .{ .render_attachment = true },
        .sample_count_value = 1,
        .width_value = 32,
        .height_value = 32,
        .impl = undefined,
    };
    const color_attachments = [_]RenderPassColorAttachmentDescriptor{.{
        .target = .{ .texture_view = &color_view },
    }};

    var command_buffer = CommandBuffer{ .backend = .vulkan };
    var encoder = try command_buffer.makeRenderCommandEncoder(.{
        .color_attachments = color_attachments[0..],
    });
    try encoder.endEncoding();

    try std.testing.expectError(RuntimeError.PresentRequiresCurrentDrawable, command_buffer.presentDrawable());
}
