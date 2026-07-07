const std = @import("std");
const builtin = @import("builtin");
const core = @import("../core.zig");
const build_options = @import("vkmtl_build_options");
const ShaderCompiler = @import("../shader/compiler.zig");
const ShaderReflection = @import("../shader/reflection.zig");
const MetalBuffer = @import("../backend/metal/buffer.zig");
const MetalAdvancedBindGroupBackend = @import("../backend/metal/advanced_binding.zig");
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
const VulkanAdvancedBindGroupBackend = @import("../backend/vulkan/advanced_binding.zig");
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
    advanced_bind_group_layout,
};

const object_cache_fingerprint_capacity = 32;
const object_cache_fingerprint_slots = core.object_cache_kind_count * object_cache_fingerprint_capacity;

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
    advanced_bind_group_layouts: usize = 0,
    submitted_work_serial: u64 = 0,
    completed_work_serial: u64 = 0,
    pending_retirements: usize = 0,
    object_cache_diagnostics: core.ObjectCacheDiagnostics = .{},
    object_cache_fingerprints: [object_cache_fingerprint_slots]u64 = [_]u64{0} ** object_cache_fingerprint_slots,
    object_cache_fingerprint_counts: [core.object_cache_kind_count]usize = [_]usize{0} ** core.object_cache_kind_count,

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

    pub fn objectCacheDiagnostics(self: ResourceTracker) core.ObjectCacheDiagnostics {
        return self.object_cache_diagnostics;
    }

    pub fn recordObjectCreation(
        self: *ResourceTracker,
        kind: core.ObjectCacheKind,
        fingerprint: u64,
        policy: core.ObjectCachePolicy,
        creation_time_ns: u64,
    ) void {
        const equivalent = self.hasObjectFingerprint(kind, fingerprint);
        self.object_cache_diagnostics.recordCreation(kind, equivalent, policy, creation_time_ns);
        if (policy.recordsDiagnostics()) {
            self.rememberObjectFingerprint(kind, fingerprint);
        }
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
            self.bind_groups != 0 or
            self.advanced_bind_group_layouts != 0;
    }

    pub fn assertNoLeaks(self: ResourceTracker) void {
        if (builtin.mode == .Debug and self.hasLeaks()) {
            std.debug.panic(
                "vkmtl leaked resources before WindowContext.deinit: buffers={}, textures={}, texture_views={}, sampler_states={}, shader_modules={}, render_pipeline_states={}, compute_pipeline_states={}, bind_group_layouts={}, bind_groups={}, advanced_bind_group_layouts={}",
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
                    self.advanced_bind_group_layouts,
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
            .advanced_bind_group_layout => &self.advanced_bind_group_layouts,
        };
    }

    fn hasObjectFingerprint(self: ResourceTracker, kind: core.ObjectCacheKind, fingerprint: u64) bool {
        const kind_index: usize = @intFromEnum(kind);
        const base = kind_index * object_cache_fingerprint_capacity;
        const count = @min(self.object_cache_fingerprint_counts[kind_index], object_cache_fingerprint_capacity);
        for (0..count) |i| {
            if (self.object_cache_fingerprints[base + i] == fingerprint) return true;
        }
        return false;
    }

    fn rememberObjectFingerprint(self: *ResourceTracker, kind: core.ObjectCacheKind, fingerprint: u64) void {
        const kind_index: usize = @intFromEnum(kind);
        const base = kind_index * object_cache_fingerprint_capacity;
        const count = self.object_cache_fingerprint_counts[kind_index];
        if (count < object_cache_fingerprint_capacity) {
            self.object_cache_fingerprints[base + count] = fingerprint;
            self.object_cache_fingerprint_counts[kind_index] = count + 1;
            return;
        }

        const slot: usize = @intCast(fingerprint % object_cache_fingerprint_capacity);
        self.object_cache_fingerprints[base + slot] = fingerprint;
    }
};

fn objectFingerprintStart(kind: core.ObjectCacheKind, backend: core.Backend) u64 {
    var hash: u64 = 0xcbf29ce484222325;
    hashU64(&hash, @intFromEnum(kind));
    hashU64(&hash, @intFromEnum(backend));
    return hash;
}

fn hashByte(hash: *u64, byte: u8) void {
    hash.* ^= byte;
    hash.* *%= 0x100000001b3;
}

fn hashBytes(hash: *u64, bytes: []const u8) void {
    hashU64(hash, bytes.len);
    for (bytes) |byte| hashByte(hash, byte);
}

fn hashU32Slice(hash: *u64, values: []const u32) void {
    hashU64(hash, values.len);
    for (values) |value| hashU64(hash, value);
}

fn hashU64(hash: *u64, value: u64) void {
    var remaining = value;
    for (0..8) |_| {
        hashByte(hash, @intCast(remaining & 0xff));
        remaining >>= 8;
    }
}

fn hashBool(hash: *u64, value: bool) void {
    hashByte(hash, if (value) 1 else 0);
}

fn hashF32(hash: *u64, value: f32) void {
    const bits: u32 = @bitCast(value);
    hashU64(hash, bits);
}

fn hashOptionalBytes(hash: *u64, value: ?[]const u8) void {
    if (value) |bytes| {
        hashBool(hash, true);
        hashBytes(hash, bytes);
    } else {
        hashBool(hash, false);
    }
}

fn hashShaderSource(hash: *u64, source: core.ShaderSource) void {
    switch (source) {
        .slang => |bytes| {
            hashU64(hash, 0);
            hashBytes(hash, bytes);
        },
        .spirv => |words| {
            hashU64(hash, 1);
            hashU32Slice(hash, words);
        },
        .msl => |bytes| {
            hashU64(hash, 2);
            hashBytes(hash, bytes);
        },
        .artifact => |artifact| {
            hashU64(hash, 3);
            hashU64(hash, @intFromEnum(artifact.language));
            hashBytes(hash, artifact.path);
        },
    }
}

fn hashShaderModuleDescriptor(hash: *u64, descriptor: core.ShaderModuleDescriptor) void {
    hashShaderSource(hash, descriptor.source);
}

fn hashShaderSpecialization(hash: *u64, descriptor: core.ShaderSpecializationDescriptor) void {
    hashU64(hash, descriptor.constants.len);
    for (descriptor.constants) |constant| {
        hashU64(hash, constant.id);
        hashOptionalBytes(hash, constant.name);
        switch (constant.value) {
            .bool => |value| {
                hashU64(hash, 0);
                hashBool(hash, value);
            },
            .i32 => |value| {
                hashU64(hash, 1);
                hashU64(hash, @bitCast(@as(i64, value)));
            },
            .u32 => |value| {
                hashU64(hash, 2);
                hashU64(hash, value);
            },
            .f32 => |value| {
                hashU64(hash, 3);
                hashF32(hash, value);
            },
        }
    }
}

fn hashProgrammableStage(hash: *u64, stage: core.ProgrammableStageDescriptor) void {
    hashShaderModuleDescriptor(hash, stage.module);
    hashU64(hash, @intFromEnum(stage.stage));
    hashBytes(hash, stage.entry_point);
    hashShaderSpecialization(hash, stage.specialization);
}

fn hashBindGroupLayoutDescriptor(hash: *u64, descriptor: core.BindGroupLayoutDescriptor) void {
    hashU64(hash, descriptor.entries.len);
    for (descriptor.entries) |entry| {
        hashU64(hash, entry.binding);
        hashU64(hash, @intFromEnum(entry.resource));
        hashBool(hash, entry.visibility.vertex);
        hashBool(hash, entry.visibility.fragment);
        hashBool(hash, entry.visibility.compute);
        hashBool(hash, entry.dynamic_offset);
        hashU64(hash, entry.array_count);
        if (entry.storage_access) |access| {
            hashBool(hash, true);
            hashU64(hash, @intFromEnum(access));
        } else {
            hashBool(hash, false);
        }
    }
}

fn hashVertexDescriptor(hash: *u64, descriptor: core.VertexDescriptor) void {
    hashU64(hash, descriptor.buffers.len);
    for (descriptor.buffers) |buffer| {
        hashU64(hash, buffer.stride);
        hashU64(hash, @intFromEnum(buffer.step_function));
        hashU64(hash, buffer.instance_step_rate);
        if (buffer.buffer_index) |buffer_index| {
            hashBool(hash, true);
            hashU64(hash, buffer_index);
        } else {
            hashBool(hash, false);
        }
        hashU64(hash, buffer.attributes.len);
        for (buffer.attributes) |attribute| {
            hashU64(hash, attribute.location);
            hashU64(hash, @intFromEnum(attribute.format));
            hashU64(hash, attribute.offset);
        }
    }
}

fn hashDepthStencilDescriptor(hash: *u64, descriptor: core.DepthStencilDescriptor) void {
    hashU64(hash, @intFromEnum(descriptor.format));
    hashBool(hash, descriptor.depth_write_enabled);
    hashBool(hash, descriptor.depth_test_enabled);
    hashU64(hash, @intFromEnum(descriptor.depth_compare_function));
    hashBool(hash, descriptor.stencil.enabled);
    hashU64(hash, @intFromEnum(descriptor.stencil.front.stencil_compare_function));
    hashU64(hash, @intFromEnum(descriptor.stencil.front.stencil_fail_operation));
    hashU64(hash, @intFromEnum(descriptor.stencil.front.depth_fail_operation));
    hashU64(hash, @intFromEnum(descriptor.stencil.front.depth_stencil_pass_operation));
    hashU64(hash, @intFromEnum(descriptor.stencil.back.stencil_compare_function));
    hashU64(hash, @intFromEnum(descriptor.stencil.back.stencil_fail_operation));
    hashU64(hash, @intFromEnum(descriptor.stencil.back.depth_fail_operation));
    hashU64(hash, @intFromEnum(descriptor.stencil.back.depth_stencil_pass_operation));
    hashU64(hash, descriptor.stencil.read_mask);
    hashU64(hash, descriptor.stencil.write_mask);
}

fn hashRenderPipelineDescriptor(hash: *u64, descriptor: core.RenderPipelineDescriptor) void {
    hashProgrammableStage(hash, descriptor.vertex);
    if (descriptor.fragment) |fragment| {
        hashBool(hash, true);
        hashProgrammableStage(hash, fragment);
    } else {
        hashBool(hash, false);
    }
    hashVertexDescriptor(hash, descriptor.vertex_descriptor);
    hashU64(hash, descriptor.bind_group_layouts.len);
    for (descriptor.bind_group_layouts) |layout| hashBindGroupLayoutDescriptor(hash, layout);
    hashU64(hash, @intFromEnum(descriptor.primitive_topology));
    hashU64(hash, @intFromEnum(descriptor.front_facing_winding));
    hashU64(hash, @intFromEnum(descriptor.cull_mode));
    hashU64(hash, @intFromEnum(descriptor.fill_mode));
    hashBool(hash, descriptor.depth_bias.enabled);
    hashF32(hash, descriptor.depth_bias.constant);
    hashF32(hash, descriptor.depth_bias.slope);
    hashF32(hash, descriptor.depth_bias.clamp);
    hashBool(hash, descriptor.conservative_rasterization);
    hashU64(hash, descriptor.sample_count);
    hashU64(hash, descriptor.color_attachments.len);
    for (descriptor.color_attachments) |attachment| {
        hashU64(hash, @intFromEnum(attachment.format));
        hashBool(hash, attachment.write_mask.red);
        hashBool(hash, attachment.write_mask.green);
        hashBool(hash, attachment.write_mask.blue);
        hashBool(hash, attachment.write_mask.alpha);
        if (attachment.blend) |blend| {
            hashBool(hash, true);
            hashU64(hash, @intFromEnum(blend.source_rgb_blend_factor));
            hashU64(hash, @intFromEnum(blend.destination_rgb_blend_factor));
            hashU64(hash, @intFromEnum(blend.rgb_blend_operation));
            hashU64(hash, @intFromEnum(blend.source_alpha_blend_factor));
            hashU64(hash, @intFromEnum(blend.destination_alpha_blend_factor));
            hashU64(hash, @intFromEnum(blend.alpha_blend_operation));
        } else {
            hashBool(hash, false);
        }
    }
    if (descriptor.depth_stencil) |depth_stencil| {
        hashBool(hash, true);
        hashDepthStencilDescriptor(hash, depth_stencil);
    } else {
        hashBool(hash, false);
    }
}

fn hashComputePipelineDescriptor(hash: *u64, descriptor: core.ComputePipelineDescriptor) void {
    hashProgrammableStage(hash, descriptor.compute);
    hashU64(hash, descriptor.bind_group_layouts.len);
    for (descriptor.bind_group_layouts) |layout| hashBindGroupLayoutDescriptor(hash, layout);
}

fn hashSamplerDescriptor(hash: *u64, descriptor: core.SamplerDescriptor) void {
    hashU64(hash, @intFromEnum(descriptor.min_filter));
    hashU64(hash, @intFromEnum(descriptor.mag_filter));
    hashU64(hash, @intFromEnum(descriptor.mip_filter));
    hashU64(hash, @intFromEnum(descriptor.address_mode_u));
    hashU64(hash, @intFromEnum(descriptor.address_mode_v));
    hashU64(hash, @intFromEnum(descriptor.address_mode_w));
    hashF32(hash, descriptor.lod_min_clamp);
    hashF32(hash, descriptor.lod_max_clamp);
    if (descriptor.compare_function) |compare| {
        hashBool(hash, true);
        hashU64(hash, @intFromEnum(compare));
    } else {
        hashBool(hash, false);
    }
    hashF32(hash, descriptor.max_anisotropy);
    if (descriptor.border_color) |border_color| {
        hashBool(hash, true);
        hashU64(hash, @intFromEnum(border_color));
    } else {
        hashBool(hash, false);
    }
}

fn objectCreationTimerStart() i128 {
    if (builtin.os.tag == .windows or builtin.os.tag == .wasi) return 0;
    var timespec: std.posix.timespec = undefined;
    return switch (std.posix.errno(std.posix.system.clock_gettime(.MONOTONIC, &timespec))) {
        .SUCCESS => @as(i128, timespec.sec) * std.time.ns_per_s + timespec.nsec,
        else => 0,
    };
}

fn objectCreationElapsedNs(start: i128) u64 {
    if (start == 0) return 0;
    const delta = objectCreationTimerStart() - start;
    if (delta <= 0) return 0;
    const max_u64_as_delta: @TypeOf(delta) = std.math.maxInt(u64);
    if (delta > max_u64_as_delta) return std.math.maxInt(u64);
    return @intCast(delta);
}

pub const Buffer = struct {
    backend: core.Backend,
    tracker: *ResourceTracker,
    label_value: ?[]const u8 = null,
    length_value: usize,
    usage_value: core.BufferUsage = .{},
    storage_mode_value: core.ResourceStorageMode = .automatic,
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

    pub fn label(self: Buffer) ?[]const u8 {
        return self.label_value;
    }

    pub fn setLabel(self: *Buffer, label_value: ?[]const u8) void {
        assertAlive(self.alive, .buffer);
        self.label_value = label_value;
    }

    pub fn usage(self: Buffer) core.BufferUsage {
        return self.usage_value;
    }

    pub fn storageMode(self: Buffer) core.ResourceStorageMode {
        return self.storage_mode_value;
    }

    pub fn cpuVisible(self: Buffer) bool {
        return self.storage_mode_value.cpuVisible();
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

    pub fn mapRange(self: *Buffer, descriptor: core.BufferMapDescriptor) !MappedBufferRange {
        assertAlive(self.alive, .buffer);
        if (!self.cpuVisible()) return core.BufferError.BufferNotCpuVisible;
        try descriptor.validate(self.length());

        const impl = switch (self.impl) {
            .vulkan => |*vulkan| MappedBufferRange.Impl{ .vulkan = try vulkan.mapRange(descriptor) },
            .metal => |*metal| MappedBufferRange.Impl{ .metal = try metal.mapRange(descriptor) },
        };
        return .{
            .backend = self.backend,
            .buffer = self,
            .bytes_value = switch (impl) {
                .vulkan => |range| range.bytes,
                .metal => |range| range.bytes,
            },
            .impl = impl,
        };
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

pub const MappedBufferRange = struct {
    backend: core.Backend,
    buffer: *Buffer,
    bytes_value: []u8,
    alive: bool = true,
    impl: Impl,

    const Impl = union(core.Backend) {
        vulkan: VulkanBuffer.MappedRange,
        metal: MetalBuffer.MappedRange,
    };

    pub fn bytes(self: MappedBufferRange) []u8 {
        assertObjectAlive(self.alive, "mapped_buffer_range");
        return self.bytes_value;
    }

    pub fn deinit(self: *MappedBufferRange) void {
        assertObjectAlive(self.alive, "mapped_buffer_range");
        assertAlive(self.buffer.alive, .buffer);
        switch (self.impl) {
            .vulkan => |range| self.buffer.impl.vulkan.unmapRange(range),
            .metal => |range| self.buffer.impl.metal.unmapRange(range) catch |err| {
                if (builtin.mode == .Debug) {
                    std.debug.panic("vkmtl failed to unmap Metal buffer: {s}", .{@errorName(err)});
                }
            },
        }
        self.alive = false;
    }
};

pub const Texture = struct {
    backend: core.Backend,
    tracker: *ResourceTracker,
    label_value: ?[]const u8 = null,
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

    pub fn label(self: Texture) ?[]const u8 {
        return self.label_value;
    }

    pub fn setLabel(self: *Texture, label_value: ?[]const u8) void {
        assertAlive(self.alive, .texture);
        self.label_value = label_value;
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
                .label_value = descriptor.label,
                .format_value = resolved.format,
                .dimension_value = resolved.dimension,
                .usage_value = self.usage_value,
                .sample_count_value = self.sample_count_value,
                .width_value = mipDimension(self.width(), resolved.base_mip_level),
                .height_value = mipDimension(self.height(), resolved.base_mip_level),
                .base_mip_level_value = resolved.base_mip_level,
                .mip_level_count_value = resolved.mip_level_count,
                .base_array_layer_value = resolved.base_array_layer,
                .array_layer_count_value = resolved.array_layer_count,
                .impl = impl,
            },
            .metal => .{
                .backend = .metal,
                .tracker = self.tracker,
                .label_value = descriptor.label,
                .format_value = resolved.format,
                .dimension_value = resolved.dimension,
                .usage_value = self.usage_value,
                .sample_count_value = self.sample_count_value,
                .width_value = mipDimension(self.width(), resolved.base_mip_level),
                .height_value = mipDimension(self.height(), resolved.base_mip_level),
                .base_mip_level_value = resolved.base_mip_level,
                .mip_level_count_value = resolved.mip_level_count,
                .base_array_layer_value = resolved.base_array_layer,
                .array_layer_count_value = resolved.array_layer_count,
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
    label_value: ?[]const u8 = null,
    format_value: core.TextureFormat,
    dimension_value: core.TextureViewDimension = .automatic,
    usage_value: core.TextureUsage,
    sample_count_value: u32,
    width_value: u32,
    height_value: u32,
    base_mip_level_value: u32 = 0,
    mip_level_count_value: u32 = 1,
    base_array_layer_value: u32 = 0,
    array_layer_count_value: u32 = 1,
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

    pub fn label(self: TextureView) ?[]const u8 {
        return self.label_value;
    }

    pub fn setLabel(self: *TextureView, label_value: ?[]const u8) void {
        assertAlive(self.alive, .texture_view);
        self.label_value = label_value;
    }

    pub fn format(self: TextureView) core.TextureFormat {
        return self.format_value;
    }

    pub fn dimension(self: TextureView) core.TextureViewDimension {
        return self.dimension_value;
    }

    pub fn baseMipLevel(self: TextureView) u32 {
        return self.base_mip_level_value;
    }

    pub fn mipLevelCount(self: TextureView) u32 {
        return self.mip_level_count_value;
    }

    pub fn baseArrayLayer(self: TextureView) u32 {
        return self.base_array_layer_value;
    }

    pub fn arrayLayerCount(self: TextureView) u32 {
        return self.array_layer_count_value;
    }

    pub fn descriptor(self: TextureView) core.ResolvedTextureViewDescriptor {
        assertAlive(self.alive, .texture_view);
        return .{
            .format = self.format_value,
            .dimension = self.dimension_value,
            .base_mip_level = self.base_mip_level_value,
            .mip_level_count = self.mip_level_count_value,
            .base_array_layer = self.base_array_layer_value,
            .array_layer_count = self.array_layer_count_value,
        };
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
    label_value: ?[]const u8 = null,
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

    pub fn label(self: SamplerState) ?[]const u8 {
        return self.label_value;
    }

    pub fn setLabel(self: *SamplerState, label_value: ?[]const u8) void {
        assertAlive(self.alive, .sampler_state);
        self.label_value = label_value;
    }
};

pub const ShaderModule = struct {
    backend: core.Backend,
    tracker: *ResourceTracker,
    label_value: ?[]const u8 = null,
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

    pub fn label(self: ShaderModule) ?[]const u8 {
        return self.label_value;
    }

    pub fn setLabel(self: *ShaderModule, label_value: ?[]const u8) void {
        assertAlive(self.alive, .shader_module);
        self.label_value = label_value;
    }
};

pub const RenderPipelineState = struct {
    backend: core.Backend,
    tracker: *ResourceTracker,
    label_value: ?[]const u8 = null,
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

    pub fn label(self: RenderPipelineState) ?[]const u8 {
        return self.label_value;
    }

    pub fn setLabel(self: *RenderPipelineState, label_value: ?[]const u8) void {
        assertAlive(self.alive, .render_pipeline_state);
        self.label_value = label_value;
    }
};

pub const ComputePipelineState = struct {
    backend: core.Backend,
    tracker: *ResourceTracker,
    label_value: ?[]const u8 = null,
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

    pub fn label(self: ComputePipelineState) ?[]const u8 {
        return self.label_value;
    }

    pub fn setLabel(self: *ComputePipelineState, label_value: ?[]const u8) void {
        assertAlive(self.alive, .compute_pipeline_state);
        self.label_value = label_value;
    }
};

pub const BindGroupLayout = struct {
    backend: core.Backend,
    tracker: *ResourceTracker,
    allocator: std.mem.Allocator,
    label_value: ?[]const u8 = null,
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

    pub fn label(self: BindGroupLayout) ?[]const u8 {
        return self.label_value;
    }

    pub fn setLabel(self: *BindGroupLayout, label_value: ?[]const u8) void {
        assertAlive(self.alive, .bind_group_layout);
        self.label_value = label_value;
    }

    pub fn descriptor(self: BindGroupLayout) core.BindGroupLayoutDescriptor {
        assertAlive(self.alive, .bind_group_layout);
        return .{ .label = self.label_value, .entries = self.entries };
    }
};

pub const AdvancedBindGroupLayout = struct {
    backend: core.Backend,
    tracker: *ResourceTracker,
    allocator: std.mem.Allocator,
    label_value: ?[]const u8 = null,
    model_value: core.AdvancedBindingModel,
    ranges: []core.DescriptorIndexingRange,
    alive: bool = true,
    impl: ?Impl = null,

    const Impl = union(core.Backend) {
        vulkan: VulkanAdvancedBindGroupBackend,
        metal: MetalAdvancedBindGroupBackend,
    };

    pub fn deinit(self: *AdvancedBindGroupLayout) void {
        assertObjectAlive(self.alive, "advanced_bind_group_layout");
        self.alive = false;
        if (self.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => {},
        };
        self.allocator.free(self.ranges);
        self.tracker.release(.advanced_bind_group_layout);
    }

    pub fn selectedBackend(self: AdvancedBindGroupLayout) core.Backend {
        return self.backend;
    }

    pub fn label(self: AdvancedBindGroupLayout) ?[]const u8 {
        return self.label_value;
    }

    pub fn model(self: AdvancedBindGroupLayout) core.AdvancedBindingModel {
        return self.model_value;
    }

    pub fn rangeCount(self: AdvancedBindGroupLayout) usize {
        return self.ranges.len;
    }

    pub fn range(self: AdvancedBindGroupLayout, index: usize) ?core.DescriptorIndexingRange {
        if (index >= self.ranges.len) return null;
        return self.ranges[index];
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
    compare_sampler: *SamplerState,

    fn resourceKind(self: BindGroupResource) core.BindingResourceKind {
        return switch (self) {
            .uniform_buffer => .uniform_buffer,
            .storage_buffer => .storage_buffer,
            .storage_texture => .storage_texture,
            .sampled_texture => .sampled_texture,
            .sampler => .sampler,
            .compare_sampler => .compare_sampler,
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
            },
            .sampled_texture => |texture_view| {
                assertAlive(texture_view.alive, .texture_view);
                try expectSameBackend(expected_backend, texture_view.backend);
            },
            .sampler, .compare_sampler => |sampler_state| {
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
            .compare_sampler => .{ .compare_sampler = .{} },
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
    label_value: ?[]const u8 = null,
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

    pub fn label(self: BindGroup) ?[]const u8 {
        return self.label_value;
    }

    pub fn setLabel(self: *BindGroup, label_value: ?[]const u8) void {
        assertAlive(self.alive, .bind_group);
        self.label_value = label_value;
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
    options: core.RenderPassAttachmentOptions = .{},

    fn validateRuntime(self: RenderPassColorAttachmentDescriptor, backend: core.Backend) !void {
        if (self.options.transient) return RuntimeError.UnsupportedTransientAttachment;
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
            .options = self.options,
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
    options: core.RenderPassAttachmentOptions = .{},

    fn validateRuntime(self: RenderPassDepthAttachmentDescriptor, backend: core.Backend) !void {
        try self.toCore().validate();
        if (self.options.transient) return RuntimeError.UnsupportedTransientAttachment;
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
            .options = self.options,
        };
    }
};

pub const RenderPassStencilAttachmentTarget = union(enum) {
    current_drawable,
    texture_view: *TextureView,
};

pub const RenderPassStencilAttachmentDescriptor = struct {
    target: RenderPassStencilAttachmentTarget = .current_drawable,
    load_action: core.LoadAction = .clear,
    store_action: core.StoreAction = .dont_care,
    clear_stencil: u32 = 0,
    options: core.RenderPassAttachmentOptions = .{},

    fn validateRuntime(self: RenderPassStencilAttachmentDescriptor, backend: core.Backend) !void {
        try self.toCore().validate();
        if (self.options.transient) return RuntimeError.UnsupportedTransientAttachment;
        switch (self.target) {
            .current_drawable => {},
            .texture_view => |texture_view| {
                assertAlive(texture_view.alive, .texture_view);
                try expectSameBackend(backend, texture_view.backend);
                if (!texture_view.usage().render_attachment or !core.isStencilFormat(texture_view.format())) {
                    return RuntimeError.InvalidRenderPassAttachment;
                }
            },
        }
    }

    fn toCore(self: RenderPassStencilAttachmentDescriptor) core.RenderPassStencilAttachmentDescriptor {
        return .{
            .target = switch (self.target) {
                .current_drawable => .current_drawable,
                .texture_view => .texture_view,
            },
            .load_action = self.load_action,
            .store_action = self.store_action,
            .clear_stencil = self.clear_stencil,
            .options = self.options,
        };
    }
};

pub const RenderPassDescriptor = struct {
    label: ?[]const u8 = null,
    color_attachments: []const RenderPassColorAttachmentDescriptor = &.{},
    depth_attachment: ?RenderPassDepthAttachmentDescriptor = null,
    stencil_attachment: ?RenderPassStencilAttachmentDescriptor = null,

    fn validateRuntime(self: RenderPassDescriptor, backend: core.Backend) !void {
        if (self.color_attachments.len == 0) return core.CommandEncodingError.MissingColorAttachment;
        if (self.color_attachments.len != 1) return RuntimeError.UnsupportedMultipleRenderTargets;
        for (self.color_attachments) |attachment| {
            try attachment.validateRuntime(backend);
        }
        if (self.depth_attachment) |depth_attachment| {
            try depth_attachment.validateRuntime(backend);
            try validateAttachmentExtents(self.color_attachments[0], depth_attachment);
            try validateAttachmentSampleCounts(self.color_attachments[0], depth_attachment);
        }
        if (self.stencil_attachment) |stencil_attachment| {
            try stencil_attachment.validateRuntime(backend);
            return RuntimeError.UnsupportedStencilAttachment;
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
    if (descriptor.stencil_attachment) |stencil_attachment| {
        switch (stencil_attachment.target) {
            .current_drawable => {},
            .texture_view => |texture_view| _ = texture_view.recordUsage(.render_attachment_write),
        }
    }
}

pub const CommandBuffer = struct {
    backend: core.Backend,
    tracker: ?*ResourceTracker = null,
    label_value: ?[]const u8 = null,
    alive: bool = true,
    uses_current_drawable_pass: bool = false,
    debug: core.CommandBufferDebugState = .{},
    debug_groups: core.DebugGroupStack = .{},
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
            .stencil_attachment = if (descriptor.stencil_attachment) |stencil_attachment| stencil_attachment.toCore() else null,
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
            .label_value = descriptor.label,
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

    pub fn label(self: CommandBuffer) ?[]const u8 {
        return self.label_value;
    }

    pub fn state(self: CommandBuffer) core.CommandBufferState {
        return self.debug.status();
    }

    pub fn setLabel(self: *CommandBuffer, label_value: ?[]const u8) void {
        assertObjectAlive(self.alive, "command_buffer");
        self.label_value = label_value;
    }

    pub fn pushDebugGroup(self: *CommandBuffer, label_value: []const u8) !void {
        assertObjectAlive(self.alive, "command_buffer");
        try self.debug_groups.push(label_value);
    }

    pub fn popDebugGroup(self: *CommandBuffer) !void {
        assertObjectAlive(self.alive, "command_buffer");
        try self.debug_groups.pop();
    }

    pub fn insertDebugSignpost(self: *CommandBuffer, label_value: []const u8) !void {
        assertObjectAlive(self.alive, "command_buffer");
        try self.debug.insertDebugSignpost(.{ .label = label_value });
    }

    pub fn commit(self: *CommandBuffer) !void {
        assertObjectAlive(self.alive, "command_buffer");
        try self.debug_groups.requireEmpty();
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
    label_value: ?[]const u8 = null,
    alive: bool = true,
    debug: core.BlitCommandEncoderDebugState = .{},
    debug_groups: core.DebugGroupStack = .{},
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

    pub fn copyTextureToTexture(
        self: *BlitCommandEncoder,
        source: *Texture,
        destination: *Texture,
        descriptor: core.CopyTextureToTextureDescriptor,
    ) !void {
        assertObjectAlive(self.alive, "blit_command_encoder");
        assertAlive(source.alive, .texture);
        assertAlive(destination.alive, .texture);
        try expectSameBackend(self.backend, source.backend);
        try expectSameBackend(self.backend, destination.backend);
        if (!source.usage_value.copy_source) return core.CommandEncodingError.InvalidCopyTextureUsage;
        if (!destination.usage_value.copy_destination) return core.CommandEncodingError.InvalidCopyTextureUsage;
        _ = try self.debug.copyTextureToTexture(
            descriptor,
            source.textureDescriptor(),
            destination.textureDescriptor(),
        );
        return core.CommandEncodingError.UnsupportedTextureToTextureCopy;
    }

    pub fn fillBuffer(
        self: *BlitCommandEncoder,
        buffer: *Buffer,
        descriptor: core.FillBufferDescriptor,
    ) !void {
        assertObjectAlive(self.alive, "blit_command_encoder");
        assertAlive(buffer.alive, .buffer);
        try expectSameBackend(self.backend, buffer.backend);
        if (!buffer.usage_value.copy_destination) return core.CommandEncodingError.InvalidCopyBufferUsage;
        try self.debug.fillBuffer(descriptor, buffer.length());
        return core.CommandEncodingError.UnsupportedFillBuffer;
    }

    pub fn endEncoding(self: *BlitCommandEncoder) !void {
        assertObjectAlive(self.alive, "blit_command_encoder");
        try self.debug_groups.requireEmpty();
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

    pub fn label(self: BlitCommandEncoder) ?[]const u8 {
        return self.label_value;
    }

    pub fn setLabel(self: *BlitCommandEncoder, label_value: ?[]const u8) void {
        assertObjectAlive(self.alive, "blit_command_encoder");
        self.label_value = label_value;
    }

    pub fn pushDebugGroup(self: *BlitCommandEncoder, label_value: []const u8) !void {
        assertObjectAlive(self.alive, "blit_command_encoder");
        try self.debug_groups.push(label_value);
    }

    pub fn popDebugGroup(self: *BlitCommandEncoder) !void {
        assertObjectAlive(self.alive, "blit_command_encoder");
        try self.debug_groups.pop();
    }

    pub fn insertDebugSignpost(self: *BlitCommandEncoder, label_value: []const u8) !void {
        assertObjectAlive(self.alive, "blit_command_encoder");
        try self.debug.insertDebugSignpost(.{ .label = label_value });
    }

    pub fn selectedBackend(self: BlitCommandEncoder) core.Backend {
        return self.backend;
    }
};

pub const ComputeCommandEncoder = struct {
    backend: core.Backend,
    command_buffer: *CommandBuffer,
    label_value: ?[]const u8 = null,
    alive: bool = true,
    debug: core.ComputeCommandEncoderDebugState = .{},
    debug_groups: core.DebugGroupStack = .{},
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
        try descriptor.validateForLimits(core.defaultDeviceLimits(self.backend));
        if (self.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.dispatchThreadgroups(descriptor),
            .metal => |*metal| try metal.dispatchThreadgroups(descriptor),
        };
    }

    pub fn dispatchThreads(
        self: *ComputeCommandEncoder,
        descriptor: core.DispatchThreadsDescriptor,
    ) !void {
        assertObjectAlive(self.alive, "compute_command_encoder");
        const resolved = try self.debug.dispatchThreads(
            descriptor,
            core.defaultDeviceLimits(self.backend),
        );
        if (self.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.dispatchThreadgroups(resolved),
            .metal => |*metal| try metal.dispatchThreadgroups(resolved),
        };
    }

    pub fn dispatchThreadgroupsIndirect(
        self: *ComputeCommandEncoder,
        indirect_buffer: *Buffer,
        descriptor: core.DispatchThreadgroupsIndirectDescriptor,
    ) !void {
        assertObjectAlive(self.alive, "compute_command_encoder");
        assertAlive(indirect_buffer.alive, .buffer);
        try expectSameBackend(self.backend, indirect_buffer.backend);
        if (!indirect_buffer.usage_value.indirect) return core.CommandEncodingError.InvalidIndirectBufferUsage;
        try self.debug.dispatchThreadgroupsIndirect(
            descriptor,
            indirect_buffer.length(),
            .{ .compute_dispatch_indirect = true },
            core.defaultDeviceLimits(self.backend),
        );
        return core.CommandEncodingError.UnsupportedDispatchIndirect;
    }

    pub fn endEncoding(self: *ComputeCommandEncoder) !void {
        assertObjectAlive(self.alive, "compute_command_encoder");
        try self.debug_groups.requireEmpty();
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

    pub fn label(self: ComputeCommandEncoder) ?[]const u8 {
        return self.label_value;
    }

    pub fn setLabel(self: *ComputeCommandEncoder, label_value: ?[]const u8) void {
        assertObjectAlive(self.alive, "compute_command_encoder");
        self.label_value = label_value;
    }

    pub fn pushDebugGroup(self: *ComputeCommandEncoder, label_value: []const u8) !void {
        assertObjectAlive(self.alive, "compute_command_encoder");
        try self.debug_groups.push(label_value);
    }

    pub fn popDebugGroup(self: *ComputeCommandEncoder) !void {
        assertObjectAlive(self.alive, "compute_command_encoder");
        try self.debug_groups.pop();
    }

    pub fn insertDebugSignpost(self: *ComputeCommandEncoder, label_value: []const u8) !void {
        assertObjectAlive(self.alive, "compute_command_encoder");
        try self.debug.insertDebugSignpost(.{ .label = label_value });
    }

    pub fn selectedBackend(self: ComputeCommandEncoder) core.Backend {
        return self.backend;
    }
};

pub const RenderCommandEncoder = struct {
    backend: core.Backend,
    command_buffer: *CommandBuffer,
    label_value: ?[]const u8 = null,
    alive: bool = true,
    debug: core.RenderCommandEncoderDebugState = .{},
    debug_groups: core.DebugGroupStack = .{},
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

    pub fn setViewport(self: *RenderCommandEncoder, viewport: core.Viewport) !void {
        assertObjectAlive(self.alive, "render_command_encoder");
        try self.debug.setViewport(viewport);
        return RuntimeError.UnsupportedDynamicRenderState;
    }

    pub fn setScissorRect(self: *RenderCommandEncoder, rect: core.ScissorRect) !void {
        assertObjectAlive(self.alive, "render_command_encoder");
        try self.debug.setScissorRect(rect);
        return RuntimeError.UnsupportedDynamicRenderState;
    }

    pub fn setBlendColor(self: *RenderCommandEncoder, color: core.BlendColor) !void {
        assertObjectAlive(self.alive, "render_command_encoder");
        try self.debug.setBlendColor(color);
        return RuntimeError.UnsupportedDynamicRenderState;
    }

    pub fn setStencilReference(self: *RenderCommandEncoder, reference: core.StencilReference) !void {
        assertObjectAlive(self.alive, "render_command_encoder");
        try self.debug.setStencilReference(reference);
        return RuntimeError.UnsupportedDynamicRenderState;
    }

    pub fn setDepthBias(self: *RenderCommandEncoder, descriptor: core.DepthBiasDescriptor) !void {
        assertObjectAlive(self.alive, "render_command_encoder");
        try self.debug.setDepthBias(descriptor);
        return RuntimeError.UnsupportedDynamicRenderState;
    }

    pub fn drawPrimitives(
        self: *RenderCommandEncoder,
        descriptor: core.DrawPrimitivesDescriptor,
    ) !void {
        assertObjectAlive(self.alive, "render_command_encoder");
        try self.debug.drawPrimitives(descriptor);
        try validateDrawPrimitivesLowering(descriptor, .{});
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
        try validateDrawIndexedPrimitivesLowering(descriptor, .{});
        if (self.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.drawIndexedPrimitives(descriptor),
            .metal => |*metal| try metal.drawIndexedPrimitives(descriptor),
        };
    }

    pub fn drawPrimitivesIndirect(
        self: *RenderCommandEncoder,
        indirect_buffer: *Buffer,
        descriptor: core.DrawPrimitivesIndirectDescriptor,
    ) !void {
        assertObjectAlive(self.alive, "render_command_encoder");
        assertAlive(indirect_buffer.alive, .buffer);
        try expectSameBackend(self.backend, indirect_buffer.backend);
        try self.debug.drawPrimitivesIndirect(descriptor);
        return core.CommandEncodingError.UnsupportedIndirectDraw;
    }

    pub fn drawIndexedPrimitivesIndirect(
        self: *RenderCommandEncoder,
        indirect_buffer: *Buffer,
        descriptor: core.DrawIndexedPrimitivesIndirectDescriptor,
    ) !void {
        assertObjectAlive(self.alive, "render_command_encoder");
        assertAlive(indirect_buffer.alive, .buffer);
        try expectSameBackend(self.backend, indirect_buffer.backend);
        try self.debug.drawIndexedPrimitivesIndirect(descriptor);
        return core.CommandEncodingError.UnsupportedIndirectDraw;
    }

    pub fn drawPrimitivesMulti(
        self: *RenderCommandEncoder,
        descriptor: core.MultiDrawPrimitivesDescriptor,
    ) !void {
        assertObjectAlive(self.alive, "render_command_encoder");
        try self.debug.drawPrimitivesMulti(descriptor);
        return core.CommandEncodingError.UnsupportedMultiDraw;
    }

    pub fn drawIndexedPrimitivesMulti(
        self: *RenderCommandEncoder,
        descriptor: core.MultiDrawIndexedPrimitivesDescriptor,
    ) !void {
        assertObjectAlive(self.alive, "render_command_encoder");
        try self.debug.drawIndexedPrimitivesMulti(descriptor);
        return core.CommandEncodingError.UnsupportedMultiDraw;
    }

    pub fn endEncoding(self: *RenderCommandEncoder) !void {
        assertObjectAlive(self.alive, "render_command_encoder");
        try self.debug_groups.requireEmpty();
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

    pub fn label(self: RenderCommandEncoder) ?[]const u8 {
        return self.label_value;
    }

    pub fn setLabel(self: *RenderCommandEncoder, label_value: ?[]const u8) void {
        assertObjectAlive(self.alive, "render_command_encoder");
        self.label_value = label_value;
    }

    pub fn pushDebugGroup(self: *RenderCommandEncoder, label_value: []const u8) !void {
        assertObjectAlive(self.alive, "render_command_encoder");
        try self.debug_groups.push(label_value);
    }

    pub fn popDebugGroup(self: *RenderCommandEncoder) !void {
        assertObjectAlive(self.alive, "render_command_encoder");
        try self.debug_groups.pop();
    }

    pub fn insertDebugSignpost(self: *RenderCommandEncoder, label_value: []const u8) !void {
        assertObjectAlive(self.alive, "render_command_encoder");
        try self.debug.insertDebugSignpost(.{ .label = label_value });
    }

    pub fn selectedBackend(self: RenderCommandEncoder) core.Backend {
        return self.backend;
    }
};

pub const WindowContextOptions = struct {
    app_name: [*:0]const u8,
    backend: core.BackendPreference = .auto,
    adapter_selection: core.AdapterSelectionDescriptor = .{},
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
    UnsupportedMultipleRenderTargets,
    UnsupportedStencilAttachment,
    UnsupportedTransientAttachment,
    UnsupportedDynamicRenderState,
    InvalidStorageBufferUsage,
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
    features_value: core.DeviceFeatures,
    kind_value: core.QueueKind = .graphics,

    pub fn selectedBackend(self: Queue) core.Backend {
        return self.backend;
    }

    pub fn kind(self: Queue) core.QueueKind {
        return self.kind_value;
    }

    pub fn makeCommandBuffer(self: *Queue) !CommandBuffer {
        return try self.makeCommandBufferWithDescriptor(.{});
    }

    pub fn makeCommandBufferWithDescriptor(
        self: *Queue,
        descriptor: core.CommandBufferDescriptor,
    ) !CommandBuffer {
        const debug = try core.CommandBufferDebugState.init(
            descriptor,
            self.features_value,
        );
        const impl = switch (self.impl.*) {
            .vulkan => |*vulkan| CommandBuffer.Impl{ .vulkan = try vulkan.makeCommandBuffer() },
            .metal => |*metal| CommandBuffer.Impl{ .metal = try metal.makeCommandBuffer() },
        };
        return .{
            .backend = self.backend,
            .tracker = self.tracker,
            .label_value = descriptor.label,
            .debug = debug,
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
    capability_report: core.DeviceCapabilityReport,
    shader_cache_dir: ?[]const u8 = null,
    slangc_path: ?[]const u8 = null,

    pub fn selectedBackend(self: Device) core.Backend {
        return self.backend;
    }

    pub fn adapterInfo(self: Device) core.AdapterInfo {
        return self.adapter_info;
    }

    pub fn features(self: Device) core.DeviceFeatures {
        return self.capability_report.features;
    }

    pub fn nativeFeatures(self: Device) core.DeviceFeatures {
        return self.capability_report.native_features;
    }

    pub fn limits(self: Device) core.DeviceLimits {
        return self.capability_report.limits;
    }

    pub fn capabilityReport(self: Device) core.DeviceCapabilityReport {
        return self.capability_report;
    }

    pub fn validateDescriptorIndexingLayout(self: Device, descriptor: core.DescriptorIndexingLayoutDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.features(), self.limits());
    }

    pub fn validateSparseMappingCommit(self: Device, descriptor: core.SparseMappingCommitDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.features(), self.limits());
    }

    pub fn validateExternalTextureDescriptor(self: Device, descriptor: core.ExternalTextureDescriptor) (core.AdvancedFeatureError || core.TextureError)!void {
        try descriptor.validate(self.backend, self.features());
    }

    pub fn validateExternalSemaphoreDescriptor(self: Device, descriptor: core.ExternalSemaphoreDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.backend, self.features());
    }

    pub fn validateTessellationDescriptor(self: Device, descriptor: core.TessellationDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.features(), self.limits());
    }

    pub fn validateMeshPipelineDescriptor(self: Device, descriptor: core.MeshPipelineDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.features(), self.limits());
    }

    pub fn validateAccelerationStructureDescriptor(self: Device, descriptor: core.AccelerationStructureDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.features());
    }

    pub fn validateRayTracingPipelineDescriptor(self: Device, descriptor: core.RayTracingPipelineDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.features(), self.limits());
    }

    pub fn validateShaderBindingTableDescriptor(self: Device, descriptor: core.ShaderBindingTableDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.features(), self.limits());
    }

    pub fn validateDriverPipelineCacheDescriptor(self: Device, descriptor: core.DriverPipelineCacheDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.features(), self.limits());
    }

    pub fn getFormatCaps(self: Device, format: core.TextureFormat) core.FormatCapabilities {
        return switch (self.impl.*) {
            .vulkan => |*vulkan| vulkan.formatCapabilities(format),
            .metal => |*metal| metal.formatCapabilities(format),
        };
    }

    pub fn objectCacheDiagnostics(self: Device) core.ObjectCacheDiagnostics {
        return self.tracker.objectCacheDiagnostics();
    }

    pub fn queue(self: *Device) Queue {
        return .{
            .backend = self.backend,
            .tracker = self.tracker,
            .impl = self.impl,
            .features_value = self.features(),
        };
    }

    pub fn queueWithDescriptor(self: *Device, descriptor: core.QueueDescriptor) !Queue {
        try descriptor.validate(self.features(), .{});
        if (descriptor.kind != .graphics) return core.CommandEncodingError.UnsupportedMultiQueue;
        var queue_view = self.queue();
        queue_view.kind_value = .graphics;
        return queue_view;
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
            .label_value = descriptor.label,
            .length_value = length,
            .usage_value = descriptor.usage,
            .storage_mode_value = descriptor.storage_mode,
            .impl = impl,
        };
    }

    pub fn makeShaderModule(self: *Device, descriptor: core.ShaderModuleDescriptor) !ShaderModule {
        var fingerprint = objectFingerprintStart(.shader_module, self.backend);
        hashShaderModuleDescriptor(&fingerprint, descriptor);
        const timer_start = objectCreationTimerStart();
        const impl = switch (self.impl.*) {
            .vulkan => |*vulkan| ShaderModule.Impl{ .vulkan = try vulkan.makeShaderModule(descriptor) },
            .metal => |*metal| ShaderModule.Impl{ .metal = try metal.makeShaderModule(self.allocator, descriptor) },
        };
        const elapsed_ns = objectCreationElapsedNs(timer_start);
        self.tracker.retain(.shader_module);
        self.tracker.recordObjectCreation(.shader_module, fingerprint, .{}, elapsed_ns);
        return .{
            .backend = self.backend,
            .tracker = self.tracker,
            .label_value = descriptor.label,
            .impl = impl,
        };
    }

    pub fn makeRenderPipelineState(self: *Device, descriptor: core.RenderPipelineDescriptor) !RenderPipelineState {
        try descriptor.validate();
        try validateRuntimeRenderPipelineShape(descriptor, self.features());
        try validateRuntimeSpecialization(descriptor.vertex);
        if (descriptor.fragment) |fragment| try validateRuntimeSpecialization(fragment);
        try ShaderReflection.validateRenderPipelineDescriptor(self.allocator, descriptor);
        var fingerprint = objectFingerprintStart(.render_pipeline, self.backend);
        hashRenderPipelineDescriptor(&fingerprint, descriptor);
        const timer_start = objectCreationTimerStart();
        const impl = switch (self.impl.*) {
            .vulkan => |*vulkan| RenderPipelineState.Impl{ .vulkan = try vulkan.makeRenderPipelineState(descriptor) },
            .metal => |*metal| RenderPipelineState.Impl{ .metal = try metal.makeRenderPipelineState(self.allocator, descriptor) },
        };
        const elapsed_ns = objectCreationElapsedNs(timer_start);
        self.tracker.retain(.render_pipeline_state);
        self.tracker.recordObjectCreation(.render_pipeline, fingerprint, .{}, elapsed_ns);
        return .{
            .backend = self.backend,
            .tracker = self.tracker,
            .label_value = descriptor.label,
            .impl = impl,
        };
    }

    pub fn makeComputePipelineState(self: *Device, descriptor: core.ComputePipelineDescriptor) !ComputePipelineState {
        try descriptor.validate();
        try validateRuntimeSpecialization(descriptor.compute);
        try ShaderReflection.validateComputePipelineDescriptor(self.allocator, descriptor);
        var fingerprint = objectFingerprintStart(.compute_pipeline, self.backend);
        hashComputePipelineDescriptor(&fingerprint, descriptor);
        const timer_start = objectCreationTimerStart();
        const impl = switch (self.impl.*) {
            .vulkan => |*vulkan| ComputePipelineState.Impl{ .vulkan = try vulkan.makeComputePipelineState(descriptor) },
            .metal => |*metal| ComputePipelineState.Impl{ .metal = try metal.makeComputePipelineState(self.allocator, descriptor) },
        };
        const elapsed_ns = objectCreationElapsedNs(timer_start);
        self.tracker.retain(.compute_pipeline_state);
        self.tracker.recordObjectCreation(.compute_pipeline, fingerprint, .{}, elapsed_ns);
        return .{
            .backend = self.backend,
            .tracker = self.tracker,
            .label_value = descriptor.label,
            .impl = impl,
        };
    }

    pub fn makeBindGroupLayout(self: *Device, descriptor: core.BindGroupLayoutDescriptor) !BindGroupLayout {
        try descriptor.validate();
        try validateFirstSliceBindGroupLayout(descriptor);
        var fingerprint = objectFingerprintStart(.bind_group_layout, self.backend);
        hashBindGroupLayoutDescriptor(&fingerprint, descriptor);
        const timer_start = objectCreationTimerStart();

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

        const elapsed_ns = objectCreationElapsedNs(timer_start);
        self.tracker.retain(.bind_group_layout);
        self.tracker.recordObjectCreation(.bind_group_layout, fingerprint, .{}, elapsed_ns);
        return .{
            .backend = self.backend,
            .tracker = self.tracker,
            .allocator = self.allocator,
            .label_value = descriptor.label,
            .entries = entries,
            .impl = impl,
        };
    }

    pub fn makeAdvancedBindGroupLayout(self: *Device, descriptor: core.DescriptorIndexingLayoutDescriptor) !AdvancedBindGroupLayout {
        try descriptor.validate(self.features(), self.limits());
        const ranges = try self.allocator.dupe(core.DescriptorIndexingRange, descriptor.ranges);
        errdefer self.allocator.free(ranges);
        const impl: ?AdvancedBindGroupLayout.Impl = switch (self.impl.*) {
            .vulkan => |*vulkan| .{ .vulkan = try VulkanAdvancedBindGroupBackend.init(vulkan.gc, descriptor) },
            .metal => .{ .metal = try MetalAdvancedBindGroupBackend.init(descriptor) },
        };

        self.tracker.retain(.advanced_bind_group_layout);
        return .{
            .backend = self.backend,
            .tracker = self.tracker,
            .allocator = self.allocator,
            .label_value = descriptor.label,
            .model_value = descriptor.model,
            .ranges = ranges,
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
            .label_value = descriptor.label,
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
            .label_value = descriptor.label,
            .dimension_value = descriptor.dimension,
            .format_value = descriptor.format,
            .usage_value = descriptor.usage,
            .sample_count_value = descriptor.sample_count,
            .impl = impl,
        };
    }

    pub fn makeSamplerState(self: *Device, descriptor: core.SamplerDescriptor) !SamplerState {
        try descriptor.validateForDevice(self.features(), self.limits());
        var fingerprint = objectFingerprintStart(.sampler, self.backend);
        hashSamplerDescriptor(&fingerprint, descriptor);
        const timer_start = objectCreationTimerStart();
        const impl = switch (self.impl.*) {
            .vulkan => |*vulkan| SamplerState.Impl{ .vulkan = try vulkan.makeSamplerState(descriptor) },
            .metal => |*metal| SamplerState.Impl{ .metal = try metal.makeSamplerState(descriptor) },
        };
        const elapsed_ns = objectCreationElapsedNs(timer_start);
        self.tracker.retain(.sampler_state);
        self.tracker.recordObjectCreation(.sampler, fingerprint, .{}, elapsed_ns);
        return .{
            .backend = self.backend,
            .tracker = self.tracker,
            .label_value = descriptor.label,
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

fn resolveCapabilityReport(impl: *BackendRuntime) core.DeviceCapabilityReport {
    return switch (impl.*) {
        .vulkan => |*vulkan| .{
            .backend = .vulkan,
            .source = .vulkan_query,
            .features = vulkan.features(),
            .native_features = vulkan.nativeFeatures(),
            .limits = vulkan.limits(),
        },
        .metal => |*metal| .{
            .backend = .metal,
            .source = .metal_query,
            .features = metal.features(),
            .native_features = metal.nativeFeatures(),
            .limits = metal.limits(),
        },
    };
}

fn validateAdapterSelection(selection: core.AdapterSelectionDescriptor, adapter: core.AdapterInfo) core.BackendSelectionError!void {
    if (!selection.matches(adapter)) return core.BackendSelectionError.AdapterNotFound;
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
    capability_report: core.DeviceCapabilityReport,
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
        var adapter_selection = options.adapter_selection;
        if (build_options.force_vulkan) adapter_selection.backend = .vulkan;
        const debug_backend_override: ?core.Backend = if (build_options.force_vulkan) null else options.debug_backend_override;
        const backend = try core.selectBackend(.{
            .preference = backend_preference,
            .adapter_selection = adapter_selection,
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
        try validateAdapterSelection(adapter_selection, adapter_info.info);
        const capability_report = resolveCapabilityReport(&impl);

        return .{
            .allocator = allocator,
            .tracker = tracker,
            .backend = backend,
            .surface_descriptor = options.surface,
            .presentation_descriptor = options.presentation,
            .adapter_info = adapter_info.info,
            .capability_report = capability_report,
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

    pub fn objectCacheDiagnostics(self: WindowContext) core.ObjectCacheDiagnostics {
        return self.tracker.objectCacheDiagnostics();
    }

    pub fn device(self: *WindowContext) Device {
        return .{
            .allocator = self.allocator,
            .tracker = self.tracker,
            .backend = self.backend,
            .impl = &self.impl,
            .adapter_info = self.adapter_info,
            .capability_report = self.capability_report,
            .shader_cache_dir = self.shader_cache_dir,
            .slangc_path = self.slangc_path,
        };
    }

    pub fn queue(self: *WindowContext) Queue {
        return .{
            .backend = self.backend,
            .tracker = self.tracker,
            .impl = &self.impl,
            .features_value = self.capability_report.features,
        };
    }

    pub fn queueWithDescriptor(self: *WindowContext, descriptor: core.QueueDescriptor) !Queue {
        var device_view = self.device();
        return try device_view.queueWithDescriptor(descriptor);
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

    pub fn makeCommandBufferWithDescriptor(
        self: *WindowContext,
        descriptor: core.CommandBufferDescriptor,
    ) !CommandBuffer {
        var queue_view = self.queue();
        return try queue_view.makeCommandBufferWithDescriptor(descriptor);
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

    pub fn makeAdvancedBindGroupLayout(self: *WindowContext, descriptor: core.DescriptorIndexingLayoutDescriptor) !AdvancedBindGroupLayout {
        var device_view = self.device();
        return try device_view.makeAdvancedBindGroupLayout(descriptor);
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
    const layout_descriptor = descriptor.layout.descriptor();
    try validateFirstSliceBindGroupLayout(layout_descriptor);

    const entries = try allocator.alloc(core.BindGroupEntry, descriptor.entries.len);
    errdefer allocator.free(entries);

    for (descriptor.entries, entries) |entry, *out| {
        try entry.resource.validateRuntimeResource(backend);
        const layout_entry = layout_descriptor.entryForBinding(entry.binding) orelse {
            return core.BindingError.ExtraBindGroupEntry;
        };
        try validateAndRecordStorageAccess(entry.resource, layout_entry);
        out.* = .{
            .binding = entry.binding,
            .resource = entry.resource.toCoreResource(),
        };
    }

    try (core.BindGroupDescriptor{
        .layout = layout_descriptor,
        .entries = entries,
    }).validate();

    return entries;
}

fn validateAndRecordStorageAccess(
    resource: BindGroupResource,
    layout_entry: core.BindGroupLayoutEntry,
) !void {
    const access = layout_entry.resolvedStorageAccess() orelse return;
    switch (resource) {
        .storage_buffer => |binding| {
            if (!binding.buffer.usage_value.storage) return RuntimeError.InvalidStorageBufferUsage;
            if (access.requiresWrite()) {
                _ = binding.buffer.recordUsage(.storage_buffer_write);
            } else {
                _ = binding.buffer.recordUsage(.storage_buffer_read);
            }
        },
        .storage_texture => |texture_view| {
            if (access.requiresRead() and !texture_view.usage_value.shader_read) {
                return RuntimeError.InvalidStorageTextureUsage;
            }
            if (access.requiresWrite() and !texture_view.usage_value.shader_write) {
                return RuntimeError.InvalidStorageTextureUsage;
            }
            if (access.requiresWrite()) {
                _ = texture_view.recordUsage(.storage_texture_write);
            } else {
                _ = texture_view.recordUsage(.storage_texture_read);
            }
        },
        .uniform_buffer, .sampled_texture, .sampler, .compare_sampler => {},
    }
}

fn validateFirstSliceBindGroupLayout(descriptor: core.BindGroupLayoutDescriptor) core.BindingError!void {
    for (descriptor.entries) |entry| {
        if (entry.array_count != 1) return core.BindingError.UnsupportedResourceArray;
        if (entry.dynamic_offset) return core.BindingError.UnsupportedDynamicBinding;
    }
}

fn validateRuntimeSpecialization(stage: core.ProgrammableStageDescriptor) core.ShaderError!void {
    if (stage.specialization.constants.len != 0) return core.ShaderError.UnsupportedShaderSpecialization;
}

fn validateRuntimeRenderPipelineShape(
    descriptor: core.RenderPipelineDescriptor,
    features: core.DeviceFeatures,
) core.PipelineError!void {
    if (descriptor.fill_mode != .fill and !features.wireframe_fill_mode) return core.PipelineError.UnsupportedFillMode;
    if (descriptor.depth_bias.enabled and !features.depth_bias) return core.PipelineError.UnsupportedDepthBias;
    if (descriptor.conservative_rasterization and !features.conservative_rasterization) {
        return core.PipelineError.UnsupportedConservativeRasterization;
    }
    var first_blend: ?core.RenderPipelineBlendDescriptor = null;
    for (descriptor.color_attachments) |attachment| {
        const blend = attachment.blend orelse continue;
        if (!features.blend_state) return core.PipelineError.UnsupportedBlendState;
        if (first_blend) |existing| {
            if (!core.RenderPipelineBlendDescriptor.eql(existing, blend) and !features.independent_blend) {
                return core.PipelineError.UnsupportedIndependentBlend;
            }
        } else {
            first_blend = blend;
        }
    }
    if (descriptor.depth_stencil) |depth_stencil| {
        if (depth_stencil.stencil.enabled and !features.stencil_state) return core.PipelineError.UnsupportedStencilState;
    }
    for (descriptor.vertex_descriptor.buffers) |buffer| {
        if (buffer.instance_step_rate != 1 and !features.vertex_instance_step_rate) {
            return core.PipelineError.UnsupportedInstanceStepRate;
        }
    }
}

fn validateDrawPrimitivesLowering(
    descriptor: core.DrawPrimitivesDescriptor,
    features: core.DeviceFeatures,
) core.CommandEncodingError!void {
    if (descriptor.base_instance != 0 and !features.draw_base_instance) return core.CommandEncodingError.UnsupportedBaseInstance;
}

fn validateDrawIndexedPrimitivesLowering(
    descriptor: core.DrawIndexedPrimitivesDescriptor,
    features: core.DeviceFeatures,
) core.CommandEncodingError!void {
    if (descriptor.base_vertex != 0 and !features.draw_base_vertex) return core.CommandEncodingError.UnsupportedBaseVertex;
    if (descriptor.base_instance != 0 and !features.draw_base_instance) return core.CommandEncodingError.UnsupportedBaseInstance;
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
                .compare_sampler => |sampler_state| .{
                    .compare_sampler = &sampler_state.impl.vulkan,
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
                .compare_sampler => |sampler_state| .{
                    .compare_sampler = &sampler_state.impl.metal,
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
        .advanced_bind_group_layout => "advanced_bind_group_layout",
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

test "resource tracker records equivalent object cache creations" {
    var tracker = ResourceTracker{};
    tracker.recordObjectCreation(.sampler, 42, .{}, 10);
    tracker.recordObjectCreation(.sampler, 42, .{}, 7);
    tracker.recordObjectCreation(.sampler, 7, .{ .mode = .disabled }, 3);

    const diagnostics = tracker.objectCacheDiagnostics();
    const sampler_stats = diagnostics.stats(.sampler);
    try std.testing.expectEqual(@as(u64, 2), sampler_stats.creation_attempts);
    try std.testing.expectEqual(@as(u64, 2), sampler_stats.misses);
    try std.testing.expectEqual(@as(u64, 1), sampler_stats.equivalent_recreations);
    try std.testing.expectEqual(@as(u64, 1), sampler_stats.diagnostics_suppressed);
    try std.testing.expectEqual(@as(u64, 17), sampler_stats.total_creation_time_ns);
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

test "runtime compute encoder validates dispatch indirect before unsupported gate" {
    var tracker = ResourceTracker{};
    var command_buffer = CommandBuffer{ .backend = .vulkan };
    var encoder = ComputeCommandEncoder{
        .backend = .vulkan,
        .command_buffer = &command_buffer,
        .debug = .{ .pipeline_set = true },
    };
    var indirect_buffer = Buffer{
        .backend = .vulkan,
        .tracker = &tracker,
        .length_value = 16,
        .usage_value = .{ .indirect = true },
        .impl = undefined,
    };
    var storage_buffer = Buffer{
        .backend = .vulkan,
        .tracker = &tracker,
        .length_value = 16,
        .usage_value = .{ .storage = true },
        .impl = undefined,
    };

    try std.testing.expectError(
        core.CommandEncodingError.UnsupportedDispatchIndirect,
        encoder.dispatchThreadgroupsIndirect(&indirect_buffer, .{}),
    );
    try std.testing.expectError(
        core.CommandEncodingError.InvalidIndirectBufferUsage,
        encoder.dispatchThreadgroupsIndirect(&storage_buffer, .{}),
    );
}

test "runtime device exposes adapter features limits and format caps" {
    var tracker = ResourceTracker{};
    var backend_runtime = BackendRuntime{
        .metal = .{
            .handle = undefined,
            .extent = .{ .width = 1, .height = 1 },
        },
    };
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
        .capability_report = core.defaultDeviceCapabilityReport(.metal),
    };

    try std.testing.expectEqual(core.Backend.metal, device.selectedBackend());
    try std.testing.expectEqual(core.Backend.metal, device.adapterInfo().backend);
    try std.testing.expectEqualStrings("test metal adapter", device.adapterInfo().name);
    try std.testing.expect(device.features().runtime_slang);
    try std.testing.expectEqual(core.default_max_bind_group_slots, device.limits().max_bind_group_slots);
    try std.testing.expect(device.getFormatCaps(.rgba8_unorm).storage);
    try std.testing.expect(device.getFormatCaps(.depth32_float).depth_stencil_attachment);
    try std.testing.expectEqual(core.DeviceCapabilitySource.defaults, device.capabilityReport().source);
}

test "runtime device validates advanced descriptors against selected capabilities" {
    var tracker = ResourceTracker{};
    var backend_runtime = BackendRuntime{
        .metal = .{
            .handle = undefined,
            .extent = .{ .width = 1, .height = 1 },
        },
    };
    const device = Device{
        .allocator = std.testing.allocator,
        .tracker = &tracker,
        .backend = .metal,
        .impl = &backend_runtime,
        .adapter_info = .{
            .backend = .metal,
            .name = "test metal adapter",
        },
        .capability_report = core.defaultDeviceCapabilityReport(.metal),
    };

    const bindless_ranges = [_]core.DescriptorIndexingRange{.{
        .binding = 0,
        .resource = .sampled_texture,
        .visibility = .{ .fragment = true },
        .descriptor_count = 4,
    }};

    try std.testing.expectError(core.AdvancedFeatureError.UnsupportedArgumentBuffers, device.validateDescriptorIndexingLayout(.{
        .model = .argument_buffer,
        .ranges = &bindless_ranges,
    }));
    try std.testing.expectError(core.AdvancedFeatureError.UnsupportedSparseBuffers, device.validateSparseMappingCommit(.{
        .buffers = &.{.{
            .offset = 0,
            .size = 4096,
            .page_size = 4096,
        }},
    }));
    try std.testing.expectError(core.AdvancedFeatureError.UnsupportedExternalTextures, device.validateExternalTextureDescriptor(.{
        .handle = .{
            .kind = .metal_texture,
            .value = 1,
        },
        .format = .rgba8_unorm,
        .width = 1,
        .height = 1,
    }));
    try std.testing.expectError(core.AdvancedFeatureError.UnsupportedTessellation, device.validateTessellationDescriptor(.{
        .control_point_count = 3,
        .has_control_stage = true,
        .has_evaluation_stage = true,
    }));
    try std.testing.expectError(core.AdvancedFeatureError.UnsupportedMeshShaders, device.validateMeshPipelineDescriptor(.{
        .mesh_entry_point = "mesh_main",
    }));
    try std.testing.expectError(core.AdvancedFeatureError.UnsupportedAccelerationStructures, device.validateAccelerationStructureDescriptor(.{
        .kind = .bottom_level,
        .primitive_count = 1,
    }));
    try std.testing.expectError(core.AdvancedFeatureError.UnsupportedRayTracing, device.validateRayTracingPipelineDescriptor(.{
        .shader_groups = &.{.{
            .kind = .ray_generation,
            .entry_point = "raygen",
        }},
    }));
}

test "runtime advanced bind group layout snapshots descriptor ranges" {
    var tracker = ResourceTracker{};
    var backend_runtime = BackendRuntime{
        .metal = .{
            .handle = undefined,
            .extent = .{ .width = 1, .height = 1 },
        },
    };
    var report = core.defaultDeviceCapabilityReport(.metal);
    report.features.argument_buffers = true;
    report.limits.max_bindless_descriptors_per_range = 16;
    report.limits.max_bindless_ranges_per_layout = 4;

    var device = Device{
        .allocator = std.testing.allocator,
        .tracker = &tracker,
        .backend = .metal,
        .impl = &backend_runtime,
        .adapter_info = .{
            .backend = .metal,
            .name = "test metal adapter",
        },
        .capability_report = report,
    };

    const ranges = [_]core.DescriptorIndexingRange{.{
        .binding = 3,
        .resource = .sampled_texture,
        .visibility = .{ .fragment = true },
        .descriptor_count = 8,
    }};

    var layout = try device.makeAdvancedBindGroupLayout(.{
        .label = "bindless textures",
        .model = .argument_buffer,
        .ranges = &ranges,
    });
    defer layout.deinit();

    try std.testing.expectEqual(core.Backend.metal, layout.selectedBackend());
    try std.testing.expectEqual(core.AdvancedBindingModel.argument_buffer, layout.model());
    try std.testing.expectEqual(@as(usize, 1), layout.rangeCount());
    try std.testing.expectEqual(@as(u32, 3), layout.range(0).?.binding);
    try std.testing.expectEqual(@as(usize, 1), tracker.advanced_bind_group_layouts);
}

test "runtime adapter selection validates resolved adapter info" {
    const adapter = core.AdapterInfo{
        .backend = .metal,
        .name = "Apple GPU",
        .vendor = "Apple",
    };

    try validateAdapterSelection(.{ .backend = .metal, .name = "Apple GPU" }, adapter);
    try std.testing.expectError(core.BackendSelectionError.AdapterNotFound, validateAdapterSelection(.{
        .backend = .metal,
        .name = "Other GPU",
    }, adapter));
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
        .capability_report = core.defaultDeviceCapabilityReport(.vulkan),
        .impl = undefined,
    };

    var device = context.device();
    const queue_view = context.queue();
    const descriptor_queue = try device.queueWithDescriptor(.{});
    var surface_view = context.surface();
    const swapchain_view = context.swapchain();
    const surface_swapchain_view = surface_view.swapchain();

    try std.testing.expectEqual(core.Backend.vulkan, device.selectedBackend());
    try std.testing.expectEqual(core.Backend.vulkan, queue_view.selectedBackend());
    try std.testing.expectEqual(core.QueueKind.graphics, queue_view.kind());
    try std.testing.expectEqual(core.QueueKind.graphics, descriptor_queue.kind());
    try std.testing.expectError(core.CommandEncodingError.UnsupportedMultiQueue, device.queueWithDescriptor(.{
        .kind = .compute,
        .allow_fallback = false,
    }));
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

    const compare_layout_entries = [_]core.BindGroupLayoutEntry{
        .{
            .binding = 0,
            .resource = .compare_sampler,
            .visibility = .{ .fragment = true },
        },
    };
    const copied_compare_layout_entries = try allocator.dupe(core.BindGroupLayoutEntry, compare_layout_entries[0..]);
    var compare_layout = BindGroupLayout{
        .backend = .vulkan,
        .tracker = &tracker,
        .allocator = allocator,
        .entries = copied_compare_layout_entries,
    };
    tracker.retain(.bind_group_layout);
    defer compare_layout.deinit();

    const compare_entries = [_]BindGroupEntry{.{
        .binding = 0,
        .resource = .{ .compare_sampler = &sampler },
    }};
    const materialized_compare = try materializeBindGroupEntries(allocator, .vulkan, .{
        .layout = &compare_layout,
        .entries = compare_entries[0..],
    });
    defer allocator.free(materialized_compare);
    try std.testing.expectEqual(core.BindingResourceKind.compare_sampler, materialized_compare[0].resource.resourceKind());

    const storage_layout_entries = [_]core.BindGroupLayoutEntry{
        .{
            .binding = 0,
            .resource = .storage_buffer,
            .visibility = .{ .compute = true },
        },
        .{
            .binding = 1,
            .resource = .storage_texture,
            .visibility = .{ .compute = true },
            .storage_access = .read,
        },
    };
    const copied_storage_layout_entries = try allocator.dupe(core.BindGroupLayoutEntry, storage_layout_entries[0..]);
    var storage_layout = BindGroupLayout{
        .backend = .vulkan,
        .tracker = &tracker,
        .allocator = allocator,
        .entries = copied_storage_layout_entries,
    };
    tracker.retain(.bind_group_layout);
    defer storage_layout.deinit();

    var storage_buffer = Buffer{
        .backend = .vulkan,
        .tracker = &tracker,
        .length_value = 128,
        .usage_value = .{ .storage = true },
        .impl = undefined,
    };
    const storage_entries = [_]BindGroupEntry{
        .{
            .binding = 0,
            .resource = .{ .storage_buffer = .{ .buffer = &storage_buffer, .size = 64 } },
        },
        .{
            .binding = 1,
            .resource = .{ .storage_texture = &texture_view },
        },
    };
    const materialized_storage = try materializeBindGroupEntries(allocator, .vulkan, .{
        .layout = &storage_layout,
        .entries = storage_entries[0..],
    });
    defer allocator.free(materialized_storage);
    try std.testing.expectEqual(core.ResourceUsageKind.storage_buffer_write, storage_buffer.currentUsage().?);
    try std.testing.expectEqual(core.ResourceUsageKind.storage_texture_read, texture_view.currentUsage().?);

    var non_storage_buffer = Buffer{
        .backend = .vulkan,
        .tracker = &tracker,
        .length_value = 128,
        .impl = undefined,
    };
    const invalid_storage_entries = [_]BindGroupEntry{
        .{
            .binding = 0,
            .resource = .{ .storage_buffer = .{ .buffer = &non_storage_buffer } },
        },
        .{
            .binding = 1,
            .resource = .{ .storage_texture = &texture_view },
        },
    };
    try std.testing.expectError(RuntimeError.InvalidStorageBufferUsage, materializeBindGroupEntries(allocator, .vulkan, .{
        .layout = &storage_layout,
        .entries = invalid_storage_entries[0..],
    }));

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

    const array_layout_entries = [_]core.BindGroupLayoutEntry{
        .{
            .binding = 0,
            .resource = .sampler,
            .visibility = .{ .fragment = true },
            .array_count = 2,
        },
    };
    const copied_array_layout_entries = try allocator.dupe(core.BindGroupLayoutEntry, array_layout_entries[0..]);
    var array_layout = BindGroupLayout{
        .backend = .vulkan,
        .tracker = &tracker,
        .allocator = allocator,
        .entries = copied_array_layout_entries,
    };
    tracker.retain(.bind_group_layout);
    defer array_layout.deinit();
    try std.testing.expectError(core.BindingError.UnsupportedResourceArray, materializeBindGroupEntries(allocator, .vulkan, .{
        .layout = &array_layout,
        .entries = entries[0..0],
    }));

    const dynamic_layout_entries = [_]core.BindGroupLayoutEntry{
        .{
            .binding = 0,
            .resource = .uniform_buffer,
            .visibility = .{ .vertex = true },
            .dynamic_offset = true,
        },
    };
    const copied_dynamic_layout_entries = try allocator.dupe(core.BindGroupLayoutEntry, dynamic_layout_entries[0..]);
    var dynamic_layout = BindGroupLayout{
        .backend = .vulkan,
        .tracker = &tracker,
        .allocator = allocator,
        .entries = copied_dynamic_layout_entries,
    };
    tracker.retain(.bind_group_layout);
    defer dynamic_layout.deinit();
    try std.testing.expectError(core.BindingError.UnsupportedDynamicBinding, materializeBindGroupEntries(allocator, .vulkan, .{
        .layout = &dynamic_layout,
        .entries = entries[0..0],
    }));
}

test "runtime specialization gate rejects non-empty specialization descriptors" {
    const constants = [_]core.ShaderSpecializationConstant{.{
        .id = 0,
        .name = "variant",
        .value = .{ .u32 = 1 },
    }};
    try std.testing.expectError(core.ShaderError.UnsupportedShaderSpecialization, validateRuntimeSpecialization(.{
        .module = .{ .source = .{ .slang = "shader source" } },
        .stage = .vertex,
        .specialization = .{ .constants = constants[0..] },
    }));
}

test "runtime render pipeline gate rejects unsupported raster state" {
    const module = core.ShaderModuleDescriptor{
        .source = .{ .slang = "shader source" },
    };
    const color_attachments = [_]core.RenderPipelineColorAttachmentDescriptor{.{
        .format = .rgba8_unorm,
    }};
    const descriptor = core.RenderPipelineDescriptor{
        .vertex = .{ .module = module, .stage = .vertex },
        .color_attachments = color_attachments[0..],
    };

    var wireframe = descriptor;
    wireframe.fill_mode = .lines;
    try std.testing.expectError(core.PipelineError.UnsupportedFillMode, validateRuntimeRenderPipelineShape(wireframe, .{}));

    var biased = descriptor;
    biased.depth_bias = .{ .enabled = true, .constant = 1 };
    try std.testing.expectError(core.PipelineError.UnsupportedDepthBias, validateRuntimeRenderPipelineShape(biased, .{}));

    var conservative = descriptor;
    conservative.conservative_rasterization = true;
    try std.testing.expectError(core.PipelineError.UnsupportedConservativeRasterization, validateRuntimeRenderPipelineShape(conservative, .{}));

    try validateRuntimeRenderPipelineShape(wireframe, .{ .wireframe_fill_mode = true });
    try validateRuntimeRenderPipelineShape(biased, .{ .depth_bias = true });
    try validateRuntimeRenderPipelineShape(conservative, .{ .conservative_rasterization = true });

    const blended_attachments = [_]core.RenderPipelineColorAttachmentDescriptor{.{
        .format = .rgba8_unorm,
        .blend = .{ .source_rgb_blend_factor = .source_alpha },
    }};
    var blended = descriptor;
    blended.color_attachments = blended_attachments[0..];
    try std.testing.expectError(core.PipelineError.UnsupportedBlendState, validateRuntimeRenderPipelineShape(blended, .{}));
    try validateRuntimeRenderPipelineShape(blended, .{ .blend_state = true });

    const independent_blend_attachments = [_]core.RenderPipelineColorAttachmentDescriptor{
        .{ .format = .rgba8_unorm, .blend = .{ .source_rgb_blend_factor = .source_alpha } },
        .{ .format = .rgba8_unorm, .blend = .{ .source_rgb_blend_factor = .one } },
    };
    var independent = descriptor;
    independent.color_attachments = independent_blend_attachments[0..];
    try std.testing.expectError(core.PipelineError.UnsupportedIndependentBlend, validateRuntimeRenderPipelineShape(independent, .{ .blend_state = true }));
    try validateRuntimeRenderPipelineShape(independent, .{ .blend_state = true, .independent_blend = true });

    var stencil = descriptor;
    stencil.depth_stencil = .{
        .format = .depth32_float,
        .stencil = .{ .enabled = true },
    };
    try std.testing.expectError(core.PipelineError.UnsupportedStencilState, validateRuntimeRenderPipelineShape(stencil, .{}));
    try validateRuntimeRenderPipelineShape(stencil, .{ .stencil_state = true });

    const stepped_buffers = [_]core.VertexBufferLayoutDescriptor{.{
        .stride = 8,
        .step_function = .per_instance,
        .instance_step_rate = 2,
    }};
    var stepped = descriptor;
    stepped.vertex_descriptor = .{ .buffers = stepped_buffers[0..] };
    try std.testing.expectError(core.PipelineError.UnsupportedInstanceStepRate, validateRuntimeRenderPipelineShape(stepped, .{}));
    try validateRuntimeRenderPipelineShape(stepped, .{ .vertex_instance_step_rate = true });
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

test "runtime render encoder dynamic state methods are gated" {
    var command_buffer = CommandBuffer{ .backend = .vulkan };
    const color_attachments = [_]RenderPassColorAttachmentDescriptor{.{}};
    var encoder = try command_buffer.makeRenderCommandEncoder(.{
        .color_attachments = color_attachments[0..],
    });

    try std.testing.expectError(RuntimeError.UnsupportedDynamicRenderState, encoder.setViewport(.{
        .width = 640,
        .height = 480,
    }));
    try std.testing.expectError(RuntimeError.UnsupportedDynamicRenderState, encoder.setScissorRect(.{
        .width = 640,
        .height = 480,
    }));
    try std.testing.expectError(RuntimeError.UnsupportedDynamicRenderState, encoder.setBlendColor(.{
        .red = 1,
        .alpha = 1,
    }));
    try std.testing.expectError(RuntimeError.UnsupportedDynamicRenderState, encoder.setStencilReference(.{
        .value = 1,
    }));
    try std.testing.expectError(RuntimeError.UnsupportedDynamicRenderState, encoder.setDepthBias(.{
        .enabled = true,
        .constant = 1,
    }));
    try std.testing.expectError(core.CommandEncodingError.InvalidViewport, encoder.setViewport(.{
        .width = 0,
        .height = 480,
    }));

    try encoder.endEncoding();
}

test "runtime render encoder draw variants are gated" {
    var command_buffer = CommandBuffer{ .backend = .vulkan };
    const color_attachments = [_]RenderPassColorAttachmentDescriptor{.{}};
    var encoder = try command_buffer.makeRenderCommandEncoder(.{
        .color_attachments = color_attachments[0..],
    });

    var tracker = ResourceTracker{};
    var pipeline = RenderPipelineState{
        .backend = .vulkan,
        .tracker = &tracker,
        .impl = undefined,
    };
    try encoder.setRenderPipelineState(&pipeline);

    try std.testing.expectError(core.CommandEncodingError.UnsupportedBaseInstance, encoder.drawPrimitives(.{
        .vertex_count = 3,
        .base_instance = 1,
    }));
    var index_buffer = Buffer{
        .backend = .vulkan,
        .tracker = &tracker,
        .length_value = 64,
        .impl = undefined,
    };
    try encoder.setIndexBuffer(&index_buffer);
    try std.testing.expectError(core.CommandEncodingError.UnsupportedBaseVertex, encoder.drawIndexedPrimitives(.{
        .index_count = 3,
        .base_vertex = 1,
    }));

    var indirect_buffer = Buffer{
        .backend = .vulkan,
        .tracker = &tracker,
        .length_value = 64,
        .impl = undefined,
    };
    try std.testing.expectError(core.CommandEncodingError.UnsupportedIndirectDraw, encoder.drawPrimitivesIndirect(&indirect_buffer, .{}));

    const draws = [_]core.DrawPrimitivesDescriptor{.{ .vertex_count = 3 }};
    try std.testing.expectError(core.CommandEncodingError.UnsupportedMultiDraw, encoder.drawPrimitivesMulti(.{
        .draws = draws[0..],
    }));

    try encoder.endEncoding();
}

test "runtime resources keep borrowed debug labels" {
    var tracker = ResourceTracker{};
    var buffer = Buffer{
        .backend = .vulkan,
        .tracker = &tracker,
        .label_value = "vertices",
        .length_value = 16,
        .impl = undefined,
    };

    try std.testing.expectEqualStrings("vertices", buffer.label().?);
    buffer.setLabel("renamed vertices");
    try std.testing.expectEqualStrings("renamed vertices", buffer.label().?);
    buffer.setLabel(null);
    try std.testing.expect(buffer.label() == null);
}

test "runtime buffers expose storage and cpu visibility" {
    var tracker = ResourceTracker{};
    var buffer = Buffer{
        .backend = .vulkan,
        .tracker = &tracker,
        .length_value = 16,
        .storage_mode_value = .private,
        .impl = undefined,
    };

    try std.testing.expectEqual(core.ResourceStorageMode.private, buffer.storageMode());
    try std.testing.expect(!buffer.cpuVisible());
}

test "runtime texture views expose resolved ranges" {
    var tracker = ResourceTracker{};
    var view = TextureView{
        .backend = .vulkan,
        .tracker = &tracker,
        .format_value = .rgba8_unorm,
        .dimension_value = .two_d_array,
        .usage_value = .{ .shader_read = true },
        .sample_count_value = 1,
        .width_value = 32,
        .height_value = 16,
        .base_mip_level_value = 2,
        .mip_level_count_value = 3,
        .base_array_layer_value = 1,
        .array_layer_count_value = 2,
        .impl = undefined,
    };

    try std.testing.expectEqual(core.TextureViewDimension.two_d_array, view.dimension());
    try std.testing.expectEqual(@as(u32, 2), view.baseMipLevel());
    try std.testing.expectEqual(@as(u32, 3), view.mipLevelCount());
    try std.testing.expectEqual(@as(u32, 1), view.baseArrayLayer());
    try std.testing.expectEqual(@as(u32, 2), view.arrayLayerCount());
    try std.testing.expectEqual(core.TextureViewDimension.two_d_array, view.descriptor().dimension);
}

test "runtime command objects validate debug group balance" {
    var command_buffer = CommandBuffer{ .backend = .vulkan };
    command_buffer.setLabel("frame commands");
    try std.testing.expectEqualStrings("frame commands", command_buffer.label().?);

    try command_buffer.insertDebugSignpost("frame start");
    try std.testing.expectError(core.CommandEncodingError.EmptyDebugGroupLabel, command_buffer.insertDebugSignpost(""));

    try command_buffer.pushDebugGroup("frame");
    try std.testing.expectError(core.CommandEncodingError.UnclosedDebugGroup, command_buffer.commit());
    try command_buffer.popDebugGroup();

    const color_attachments = [_]RenderPassColorAttachmentDescriptor{.{}};
    var encoder = try command_buffer.makeRenderCommandEncoder(.{
        .label = "main render",
        .color_attachments = color_attachments[0..],
    });
    try std.testing.expectEqualStrings("main render", encoder.label().?);

    try encoder.insertDebugSignpost("draw setup");
    try std.testing.expectError(core.CommandEncodingError.EmptyDebugGroupLabel, encoder.insertDebugSignpost(""));

    try encoder.pushDebugGroup("draws");
    try std.testing.expectError(core.CommandEncodingError.UnclosedDebugGroup, encoder.endEncoding());
    try encoder.popDebugGroup();
    try encoder.endEncoding();

    try command_buffer.commit();
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

    const multiple_color_attachments = [_]RenderPassColorAttachmentDescriptor{ .{}, .{} };
    try std.testing.expectError(RuntimeError.UnsupportedMultipleRenderTargets, (RenderPassDescriptor{
        .color_attachments = multiple_color_attachments[0..],
    }).validateRuntime(.vulkan));

    const transient_color_attachments = [_]RenderPassColorAttachmentDescriptor{.{
        .options = .{ .transient = true },
    }};
    try std.testing.expectError(RuntimeError.UnsupportedTransientAttachment, (RenderPassDescriptor{
        .color_attachments = transient_color_attachments[0..],
    }).validateRuntime(.vulkan));

    const drawable_color_attachments = [_]RenderPassColorAttachmentDescriptor{.{}};
    try std.testing.expectError(RuntimeError.UnsupportedStencilAttachment, (RenderPassDescriptor{
        .color_attachments = drawable_color_attachments[0..],
        .stencil_attachment = .{ .clear_stencil = 1 },
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
