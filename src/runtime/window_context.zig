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
    submitted_work_serial: u64 = 0,
    completed_work_serial: u64 = 0,
    pending_retirements: usize = 0,

    pub fn retain(self: *ResourceTracker, kind: ResourceKind) void {
        self.countPtr(kind).* += 1;
    }

    pub fn release(self: *ResourceTracker, kind: ResourceKind) void {
        const count = self.countPtr(kind);
        if (builtin.mode == .Debug and count.* == 0) {
            std.debug.panic("vkmtl resource tracker underflow for {s}", .{kindName(kind)});
        }
        if (count.* != 0) count.* -= 1;
        self.retire(kind);
    }

    pub fn submitWork(self: *ResourceTracker) u64 {
        self.submitted_work_serial += 1;
        return self.submitted_work_serial;
    }

    pub fn completeWork(self: *ResourceTracker, serial: u64) void {
        self.completed_work_serial = @max(self.completed_work_serial, serial);
        self.flushCompletedRetirements();
    }

    pub fn completeAllWork(self: *ResourceTracker) void {
        self.completed_work_serial = self.submitted_work_serial;
        self.flushCompletedRetirements();
    }

    pub fn hasPendingRetirements(self: ResourceTracker) bool {
        return self.pending_retirements != 0;
    }

    fn retire(self: *ResourceTracker, kind: ResourceKind) void {
        _ = kind;
        if (self.completed_work_serial < self.submitted_work_serial) {
            self.pending_retirements += 1;
        }
    }

    fn flushCompletedRetirements(self: *ResourceTracker) void {
        if (self.completed_work_serial >= self.submitted_work_serial) {
            self.pending_retirements = 0;
        }
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
        if (builtin.mode == .Debug and self.hasPendingRetirements()) {
            std.debug.panic(
                "vkmtl has {} deferred resource retirements before WindowContext.deinit; complete submitted work before destroying the context",
                .{self.pending_retirements},
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
    length_value: usize,
    usage_value: core.BufferUsage = .{},
    usage_state: core.ResourceUsageState = .{},
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
        return self.length_value;
    }

    pub fn usage(self: Buffer) core.BufferUsage {
        return self.usage_value;
    }

    pub fn currentUsage(self: Buffer) ?core.ResourceUsageKind {
        return self.usage_state.current;
    }

    pub fn usageBarrierCount(self: Buffer) usize {
        return self.usage_state.barrier_count;
    }

    fn recordUsage(self: *Buffer, next_usage: core.ResourceUsageKind) core.ResourceUsageTransition {
        return self.usage_state.transitionTo(next_usage);
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
    usage_state: core.ResourceUsageState = .{},
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

    pub fn currentUsage(self: Texture) ?core.ResourceUsageKind {
        return self.usage_state.current;
    }

    pub fn usageBarrierCount(self: Texture) usize {
        return self.usage_state.barrier_count;
    }

    fn recordUsage(self: *Texture, next_usage: core.ResourceUsageKind) core.ResourceUsageTransition {
        return self.usage_state.transitionTo(next_usage);
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
    usage_state: core.ResourceUsageState = .{},
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

    pub fn currentUsage(self: TextureView) ?core.ResourceUsageKind {
        return self.usage_state.current;
    }

    pub fn usageBarrierCount(self: TextureView) usize {
        return self.usage_state.barrier_count;
    }

    fn recordUsage(self: *TextureView, next_usage: core.ResourceUsageKind) core.ResourceUsageTransition {
        return self.usage_state.transitionTo(next_usage);
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

fn recordRenderPassUsage(descriptor: RenderPassDescriptor) void {
    for (descriptor.color_attachments) |attachment| {
        switch (attachment.target) {
            .current_drawable => {},
            .texture_view => |texture_view| _ = texture_view.recordUsage(.render_attachment_write),
        }
        if (attachment.resolve_target) |resolve_target| {
            _ = resolve_target.recordUsage(.render_attachment_write);
        }
    }
    if (descriptor.depth_attachment) |depth_attachment| {
        switch (depth_attachment.target) {
            .current_drawable => {},
            .texture_view => |texture_view| _ = texture_view.recordUsage(.render_attachment_write),
        }
    }
}

pub const CommandBuffer = struct {
    backend: core.Backend,
    tracker: ?*ResourceTracker = null,
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
        recordRenderPassUsage(descriptor);

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
        const work_serial = if (self.tracker) |tracker| tracker.submitWork() else 0;
        switch (self.impl orelse {
            self.alive = false;
            if (self.tracker) |tracker| tracker.completeWork(work_serial);
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
        if (self.tracker) |tracker| tracker.completeWork(work_serial);
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
        _ = source.recordUsage(.copy_source);
        _ = destination.recordUsage(.copy_destination);
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
        _ = source.recordUsage(.copy_source);
        _ = destination.recordUsage(.copy_destination);
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
        _ = source.recordUsage(.copy_source);
        _ = destination.recordUsage(.copy_destination);
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
        _ = buffer.recordUsage(.vertex_buffer);
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
        _ = buffer.recordUsage(.index_buffer);
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
    DeviceLost,
    SurfaceLost,
    InvalidRenderPassAttachment,
    InvalidStorageTextureUsage,
    PresentRequiresCurrentDrawable,
};

const BackendRuntime = union(core.Backend) {
    vulkan: VulkanClearScreen,
    metal: MetalClearScreen,
};

pub const Surface = struct {
    backend: core.Backend,
    descriptor_value: core.SurfaceDescriptor,
    presentation: *core.PresentationDescriptor,
    impl: *BackendRuntime,

    pub fn selectedBackend(self: Surface) core.Backend {
        return self.backend;
    }

    pub fn descriptor(self: Surface) core.SurfaceDescriptor {
        return self.descriptor_value;
    }

    pub fn provider(self: Surface) ?core.SurfaceProvider {
        const source = self.descriptor_value.source orelse return null;
        return source.provider;
    }

    pub fn swapchain(self: *Surface) Swapchain {
        return .{
            .backend = self.backend,
            .presentation = self.presentation,
            .impl = self.impl,
        };
    }
};

pub const Swapchain = struct {
    backend: core.Backend,
    presentation: *core.PresentationDescriptor,
    impl: *BackendRuntime,

    pub fn selectedBackend(self: Swapchain) core.Backend {
        return self.backend;
    }

    pub fn presentationDescriptor(self: Swapchain) core.PresentationDescriptor {
        return self.presentation.*;
    }

    pub fn extent(self: Swapchain) core.Extent2D {
        return self.presentation.extent;
    }

    pub fn resize(self: *Swapchain, new_extent: core.Extent2D) !void {
        switch (self.impl.*) {
            .vulkan => |*vulkan| try vulkan.resize(new_extent),
            .metal => |*metal| try metal.resize(new_extent),
        }
        if (!new_extent.isZero()) {
            self.presentation.extent = new_extent;
        }
    }

    pub fn clear(self: *Swapchain, color: ClearColor) !void {
        switch (self.impl.*) {
            .vulkan => |*vulkan| try vulkan.clear(color),
            .metal => |*metal| try metal.clear(color),
        }
    }
};

pub const Queue = struct {
    backend: core.Backend,
    tracker: *ResourceTracker,
    impl: *BackendRuntime,

    pub fn selectedBackend(self: Queue) core.Backend {
        return self.backend;
    }

    pub fn makeCommandBuffer(self: *Queue) !CommandBuffer {
        const impl = switch (self.impl.*) {
            .vulkan => |*vulkan| CommandBuffer.Impl{ .vulkan = try vulkan.makeCommandBuffer() },
            .metal => |*metal| CommandBuffer.Impl{ .metal = try metal.makeCommandBuffer() },
        };
        return .{
            .backend = self.backend,
            .tracker = self.tracker,
            .impl = impl,
        };
    }
};

pub const Device = struct {
    allocator: std.mem.Allocator,
    tracker: *ResourceTracker,
    backend: core.Backend,
    impl: *BackendRuntime,
    adapter_info: core.AdapterInfo,
    shader_cache_dir: ?[]const u8 = null,
    slangc_path: ?[]const u8 = null,

    pub fn selectedBackend(self: Device) core.Backend {
        return self.backend;
    }

    pub fn adapterInfo(self: Device) core.AdapterInfo {
        return self.adapter_info;
    }

    pub fn features(self: Device) core.DeviceFeatures {
        return core.defaultDeviceFeatures(self.backend);
    }

    pub fn limits(self: Device) core.DeviceLimits {
        return core.defaultDeviceLimits(self.backend);
    }

    pub fn getFormatCaps(self: Device, format: core.TextureFormat) core.FormatCapabilities {
        _ = self;
        return core.defaultFormatCapabilities(format);
    }

    pub fn queue(self: *Device) Queue {
        return .{
            .backend = self.backend,
            .tracker = self.tracker,
            .impl = self.impl,
        };
    }

    pub fn compileRenderShader(
        self: *Device,
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
        self: *Device,
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

    pub fn makeBuffer(self: *Device, descriptor: core.BufferDescriptor) !Buffer {
        const length = try descriptor.resolvedLength();
        const impl = switch (self.impl.*) {
            .vulkan => |*vulkan| Buffer.Impl{ .vulkan = try vulkan.makeBuffer(descriptor) },
            .metal => |*metal| Buffer.Impl{ .metal = try metal.makeBuffer(descriptor) },
        };
        self.tracker.retain(.buffer);
        return .{
            .backend = self.backend,
            .tracker = self.tracker,
            .length_value = length,
            .usage_value = descriptor.usage,
            .impl = impl,
        };
    }

    pub fn makeShaderModule(self: *Device, descriptor: core.ShaderModuleDescriptor) !ShaderModule {
        const impl = switch (self.impl.*) {
            .vulkan => |*vulkan| ShaderModule.Impl{ .vulkan = try vulkan.makeShaderModule(descriptor) },
            .metal => |*metal| ShaderModule.Impl{ .metal = try metal.makeShaderModule(self.allocator, descriptor) },
        };
        self.tracker.retain(.shader_module);
        return .{
            .backend = self.backend,
            .tracker = self.tracker,
            .impl = impl,
        };
    }

    pub fn makeRenderPipelineState(self: *Device, descriptor: core.RenderPipelineDescriptor) !RenderPipelineState {
        try descriptor.validate();
        try ShaderReflection.validateRenderPipelineDescriptor(self.allocator, descriptor);
        const impl = switch (self.impl.*) {
            .vulkan => |*vulkan| RenderPipelineState.Impl{ .vulkan = try vulkan.makeRenderPipelineState(descriptor) },
            .metal => |*metal| RenderPipelineState.Impl{ .metal = try metal.makeRenderPipelineState(self.allocator, descriptor) },
        };
        self.tracker.retain(.render_pipeline_state);
        return .{
            .backend = self.backend,
            .tracker = self.tracker,
            .impl = impl,
        };
    }

    pub fn makeComputePipelineState(self: *Device, descriptor: core.ComputePipelineDescriptor) !ComputePipelineState {
        try descriptor.validate();
        try ShaderReflection.validateComputePipelineDescriptor(self.allocator, descriptor);
        const impl = switch (self.impl.*) {
            .vulkan => |*vulkan| ComputePipelineState.Impl{ .vulkan = try vulkan.makeComputePipelineState(descriptor) },
            .metal => |*metal| ComputePipelineState.Impl{ .metal = try metal.makeComputePipelineState(self.allocator, descriptor) },
        };
        self.tracker.retain(.compute_pipeline_state);
        return .{
            .backend = self.backend,
            .tracker = self.tracker,
            .impl = impl,
        };
    }

    pub fn makeBindGroupLayout(self: *Device, descriptor: core.BindGroupLayoutDescriptor) !BindGroupLayout {
        try descriptor.validate();

        const entries = try self.allocator.dupe(core.BindGroupLayoutEntry, descriptor.entries);
        errdefer self.allocator.free(entries);

        const impl = switch (self.impl.*) {
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

    pub fn makeBindGroup(self: *Device, descriptor: BindGroupDescriptor) !BindGroup {
        const entries = try materializeBindGroupEntries(self.allocator, self.backend, descriptor);
        errdefer self.allocator.free(entries);

        const impl = switch (self.impl.*) {
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

    pub fn makeTexture(self: *Device, descriptor: core.TextureDescriptor) !Texture {
        const impl = switch (self.impl.*) {
            .vulkan => |*vulkan| Texture.Impl{ .vulkan = try vulkan.makeTexture(descriptor) },
            .metal => |*metal| Texture.Impl{ .metal = try metal.makeTexture(descriptor) },
        };
        self.tracker.retain(.texture);
        return .{
            .backend = self.backend,
            .tracker = self.tracker,
            .dimension_value = descriptor.dimension,
            .format_value = descriptor.format,
            .usage_value = descriptor.usage,
            .sample_count_value = descriptor.sample_count,
            .impl = impl,
        };
    }

    pub fn makeSamplerState(self: *Device, descriptor: core.SamplerDescriptor) !SamplerState {
        const impl = switch (self.impl.*) {
            .vulkan => |*vulkan| SamplerState.Impl{ .vulkan = try vulkan.makeSamplerState(descriptor) },
            .metal => |*metal| SamplerState.Impl{ .metal = try metal.makeSamplerState(descriptor) },
        };
        self.tracker.retain(.sampler_state);
        return .{
            .backend = self.backend,
            .tracker = self.tracker,
            .impl = impl,
        };
    }

    fn shaderCompilerOptions(self: Device) ShaderCompiler.CompilerOptions {
        return .{
            .slangc_path = self.slangc_path orelse build_options.slangc_path,
            .cache_dir = self.shader_cache_dir,
        };
    }
};

const ResolvedAdapterInfo = struct {
    info: core.AdapterInfo,
    owned_name: ?[]u8 = null,

    fn deinit(self: ResolvedAdapterInfo, allocator: std.mem.Allocator) void {
        if (self.owned_name) |name| {
            allocator.free(name);
        }
    }
};

fn resolveAdapterInfo(allocator: std.mem.Allocator, impl: *BackendRuntime) !ResolvedAdapterInfo {
    return switch (impl.*) {
        .vulkan => |*vulkan| blk: {
            const result = vulkan.adapterInfo();
            break :blk .{
                .info = result.info,
                .owned_name = result.owned_name,
            };
        },
        .metal => |*metal| blk: {
            const result = try metal.adapterInfo(allocator);
            break :blk .{
                .info = result.info,
                .owned_name = result.owned_name,
            };
        },
    };
}

fn deinitBackendRuntime(impl: *BackendRuntime) void {
    switch (impl.*) {
        .vulkan => |*vulkan| vulkan.deinit(),
        .metal => |*metal| metal.deinit(),
    }
}

pub const WindowContext = struct {
    allocator: std.mem.Allocator,
    tracker: *ResourceTracker,
    backend: core.Backend,
    surface_descriptor: core.SurfaceDescriptor,
    presentation_descriptor: core.PresentationDescriptor,
    adapter_info: core.AdapterInfo,
    owned_adapter_name: ?[]u8 = null,
    shader_cache_dir: ?[]const u8 = null,
    owns_shader_cache_dir: bool = false,
    slangc_path: ?[]const u8 = null,
    impl: BackendRuntime,

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

        var impl: BackendRuntime = switch (backend) {
            .vulkan => .{
                .vulkan = try VulkanClearScreen.init(
                    allocator,
                    options.app_name,
                    options.surface,
                    options.presentation,
                ),
            },
            .metal => .{
                .metal = try MetalClearScreen.init(
                    options.surface,
                    options.presentation,
                ),
            },
        };
        errdefer deinitBackendRuntime(&impl);

        const adapter_info = try resolveAdapterInfo(allocator, &impl);
        errdefer adapter_info.deinit(allocator);

        return .{
            .allocator = allocator,
            .tracker = tracker,
            .backend = backend,
            .surface_descriptor = options.surface,
            .presentation_descriptor = options.presentation,
            .adapter_info = adapter_info.info,
            .owned_adapter_name = adapter_info.owned_name,
            .shader_cache_dir = resolved_shader_cache_dir.value,
            .owns_shader_cache_dir = resolved_shader_cache_dir.owned,
            .slangc_path = options.slangc_path,
            .impl = impl,
        };
    }

    pub fn deinit(self: *WindowContext) void {
        self.tracker.completeAllWork();
        self.tracker.assertNoLeaks();
        deinitBackendRuntime(&self.impl);
        if (self.owned_adapter_name) |name| {
            self.allocator.free(name);
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

    pub fn adapterInfo(self: WindowContext) core.AdapterInfo {
        return self.adapter_info;
    }

    pub fn nativeHandles(self: *WindowContext) !core.NativeHandles {
        return switch (self.impl) {
            .vulkan => |*vulkan| vulkan.nativeHandles(),
            .metal => |*metal| try metal.nativeHandles(),
        };
    }

    pub fn device(self: *WindowContext) Device {
        return .{
            .allocator = self.allocator,
            .tracker = self.tracker,
            .backend = self.backend,
            .impl = &self.impl,
            .adapter_info = self.adapter_info,
            .shader_cache_dir = self.shader_cache_dir,
            .slangc_path = self.slangc_path,
        };
    }

    pub fn queue(self: *WindowContext) Queue {
        return .{
            .backend = self.backend,
            .tracker = self.tracker,
            .impl = &self.impl,
        };
    }

    pub fn surface(self: *WindowContext) Surface {
        return .{
            .backend = self.backend,
            .descriptor_value = self.surface_descriptor,
            .presentation = &self.presentation_descriptor,
            .impl = &self.impl,
        };
    }

    pub fn swapchain(self: *WindowContext) Swapchain {
        return .{
            .backend = self.backend,
            .presentation = &self.presentation_descriptor,
            .impl = &self.impl,
        };
    }

    pub fn compileRenderShader(
        self: *WindowContext,
        name: []const u8,
        source: []const u8,
        options: ShaderCompiler.RenderShaderOptions,
    ) !ShaderCompiler.CompiledRenderShader {
        var device_view = self.device();
        return try device_view.compileRenderShader(name, source, options);
    }

    pub fn compileComputeShader(
        self: *WindowContext,
        name: []const u8,
        source: []const u8,
        options: ShaderCompiler.ComputeShaderOptions,
    ) !ShaderCompiler.CompiledComputeShader {
        var device_view = self.device();
        return try device_view.compileComputeShader(name, source, options);
    }

    pub fn resize(self: *WindowContext, extent: core.Extent2D) !void {
        var swapchain_view = self.swapchain();
        return try swapchain_view.resize(extent);
    }

    pub fn clear(self: *WindowContext, color: ClearColor) !void {
        var swapchain_view = self.swapchain();
        return try swapchain_view.clear(color);
    }

    pub fn makeCommandBuffer(self: *WindowContext) !CommandBuffer {
        var queue_view = self.queue();
        return try queue_view.makeCommandBuffer();
    }

    pub fn makeBuffer(self: *WindowContext, descriptor: core.BufferDescriptor) !Buffer {
        var device_view = self.device();
        return try device_view.makeBuffer(descriptor);
    }

    pub fn makeShaderModule(self: *WindowContext, descriptor: core.ShaderModuleDescriptor) !ShaderModule {
        var device_view = self.device();
        return try device_view.makeShaderModule(descriptor);
    }

    pub fn makeRenderPipelineState(self: *WindowContext, descriptor: core.RenderPipelineDescriptor) !RenderPipelineState {
        var device_view = self.device();
        return try device_view.makeRenderPipelineState(descriptor);
    }

    pub fn makeComputePipelineState(self: *WindowContext, descriptor: core.ComputePipelineDescriptor) !ComputePipelineState {
        var device_view = self.device();
        return try device_view.makeComputePipelineState(descriptor);
    }

    pub fn makeBindGroupLayout(self: *WindowContext, descriptor: core.BindGroupLayoutDescriptor) !BindGroupLayout {
        var device_view = self.device();
        return try device_view.makeBindGroupLayout(descriptor);
    }

    pub fn makeBindGroup(self: *WindowContext, descriptor: BindGroupDescriptor) !BindGroup {
        var device_view = self.device();
        return try device_view.makeBindGroup(descriptor);
    }

    pub fn makeTexture(self: *WindowContext, descriptor: core.TextureDescriptor) !Texture {
        var device_view = self.device();
        return try device_view.makeTexture(descriptor);
    }

    pub fn makeSamplerState(self: *WindowContext, descriptor: core.SamplerDescriptor) !SamplerState {
        var device_view = self.device();
        return try device_view.makeSamplerState(descriptor);
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

test "resource tracker defers retirements until submitted work completes" {
    var tracker = ResourceTracker{};
    tracker.retain(.buffer);

    const serial = tracker.submitWork();
    tracker.release(.buffer);

    try std.testing.expect(!tracker.hasLeaks());
    try std.testing.expect(tracker.hasPendingRetirements());

    tracker.completeWork(serial);
    try std.testing.expect(!tracker.hasPendingRetirements());
}

test "resource tracker completeAllWork flushes pending retirements" {
    var tracker = ResourceTracker{};
    tracker.retain(.texture);

    _ = tracker.submitWork();
    tracker.release(.texture);
    try std.testing.expect(tracker.hasPendingRetirements());

    tracker.completeAllWork();
    try std.testing.expect(!tracker.hasPendingRetirements());
}

test "runtime blit encoder records buffer usage transitions" {
    var tracker = ResourceTracker{};
    var command_buffer = CommandBuffer{ .backend = .vulkan };
    var encoder = BlitCommandEncoder{
        .backend = .vulkan,
        .command_buffer = &command_buffer,
    };
    var source = Buffer{
        .backend = .vulkan,
        .tracker = &tracker,
        .length_value = 4,
        .usage_value = .{ .copy_source = true },
        .impl = undefined,
    };
    var destination = Buffer{
        .backend = .vulkan,
        .tracker = &tracker,
        .length_value = 4,
        .usage_value = .{ .copy_destination = true },
        .impl = undefined,
    };

    try encoder.copyBufferToBuffer(&source, &destination, .{ .size = 4 });

    try std.testing.expectEqual(core.ResourceUsageKind.copy_source, source.currentUsage().?);
    try std.testing.expectEqual(core.ResourceUsageKind.copy_destination, destination.currentUsage().?);
}

test "runtime device exposes adapter features limits and format caps" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    const device = Device{
        .allocator = std.testing.allocator,
        .tracker = &tracker,
        .backend = .metal,
        .impl = &backend_runtime,
        .adapter_info = .{
            .backend = .metal,
            .name = "test metal adapter",
            .vendor = "Test Vendor",
        },
    };

    try std.testing.expectEqual(core.Backend.metal, device.selectedBackend());
    try std.testing.expectEqual(core.Backend.metal, device.adapterInfo().backend);
    try std.testing.expectEqualStrings("test metal adapter", device.adapterInfo().name);
    try std.testing.expect(device.features().runtime_slang);
    try std.testing.expectEqual(core.default_max_bind_group_slots, device.limits().max_bind_group_slots);
    try std.testing.expect(device.getFormatCaps(.rgba8_unorm).storage);
    try std.testing.expect(device.getFormatCaps(.depth32_float).depth_stencil_attachment);
}

test "window context exposes device and queue views" {
    var tracker = ResourceTracker{};
    var context = WindowContext{
        .allocator = std.testing.allocator,
        .tracker = &tracker,
        .backend = .vulkan,
        .surface_descriptor = .{
            .source = .{
                .provider = .external,
                .window = @ptrFromInt(1),
            },
        },
        .presentation_descriptor = .{
            .extent = .{ .width = 640, .height = 480 },
        },
        .adapter_info = .{
            .backend = .vulkan,
            .name = "test vulkan adapter",
            .vendor = "Test Vendor",
        },
        .impl = undefined,
    };

    const device = context.device();
    const queue_view = context.queue();
    var surface_view = context.surface();
    const swapchain_view = context.swapchain();
    const surface_swapchain_view = surface_view.swapchain();

    try std.testing.expectEqual(core.Backend.vulkan, device.selectedBackend());
    try std.testing.expectEqual(core.Backend.vulkan, queue_view.selectedBackend());
    try std.testing.expectEqual(core.Backend.vulkan, surface_view.selectedBackend());
    try std.testing.expectEqual(core.Backend.vulkan, swapchain_view.selectedBackend());
    try std.testing.expectEqual(core.Backend.vulkan, surface_swapchain_view.selectedBackend());
    try std.testing.expectEqual(core.Backend.vulkan, context.adapterInfo().backend);
    try std.testing.expectEqualStrings("test vulkan adapter", device.adapterInfo().name);
    try std.testing.expectEqual(core.SurfaceProvider.external, surface_view.provider().?);
    try std.testing.expectEqual(@as(u32, 640), swapchain_view.extent().width);
    try std.testing.expectEqual(@as(u32, 480), swapchain_view.presentationDescriptor().extent.height);
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
        .length_value = 128,
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
        .length_value = 128,
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
