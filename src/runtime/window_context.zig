const std = @import("std");
const builtin = @import("builtin");
const core = @import("../core.zig");
const build_options = @import("vkmtl_build_options");
const ShaderCompiler = @import("../shader/compiler.zig");
const ShaderReflection = @import("../shader/reflection.zig");
const MetalAccelerationStructure = @import("../backend/metal/acceleration_structure.zig");
const MetalBuffer = @import("../backend/metal/buffer.zig");
const MetalHeap = @import("../backend/metal/heap.zig");
const MetalIndirectCommandBuffer = @import("../backend/metal/indirect_command.zig");
const MetalAdvancedBindGroupBackend = @import("../backend/metal/advanced_binding.zig");
const MetalBindGroupBackend = @import("../backend/metal/bind_group.zig");
const MetalCommand = @import("../backend/metal/command.zig");
const MetalComputePipelineState = @import("../backend/metal/compute_pipeline.zig");
const MetalClearScreen = @import("../backend/metal/clear_screen.zig");
const MetalRayTracingPipelineState = @import("../backend/metal/ray_tracing_pipeline.zig");
const MetalRenderPipelineState = @import("../backend/metal/render_pipeline.zig");
const MetalQuerySet = @import("../backend/metal/query_set.zig");
const MetalSamplerState = @import("../backend/metal/sampler.zig");
const MetalShaderModule = @import("../backend/metal/shader_module.zig");
const MetalTexture = @import("../backend/metal/texture.zig");
const MetalTextureView = @import("../backend/metal/texture_view.zig");
const MetalSync = @import("../backend/metal/sync.zig");
const VulkanBindGroupBackend = @import("../backend/vulkan/bind_group.zig");
const VulkanAdvancedBindGroupBackend = @import("../backend/vulkan/advanced_binding.zig");
const VulkanAccelerationStructure = @import("../backend/vulkan/acceleration_structure.zig");
const VulkanBuffer = @import("../backend/vulkan/buffer.zig");
const VulkanHeap = @import("../backend/vulkan/heap.zig");
const VulkanCommand = @import("../backend/vulkan/command.zig");
const VulkanComputePipelineState = @import("../backend/vulkan/compute_pipeline.zig");
const VulkanClearScreen = @import("../backend/vulkan/clear_screen.zig");
const VulkanRayTracingPipelineState = @import("../backend/vulkan/ray_tracing_pipeline.zig");
const VulkanRenderPipelineState = @import("../backend/vulkan/render_pipeline.zig");
const VulkanQuerySet = @import("../backend/vulkan/query_set.zig");
const VulkanSamplerState = @import("../backend/vulkan/sampler.zig");
const VulkanShaderModule = @import("../backend/vulkan/shader_module.zig");
const VulkanTexture = @import("../backend/vulkan/texture.zig");
const VulkanTextureView = @import("../backend/vulkan/texture_view.zig");
const VulkanSync = @import("../backend/vulkan/sync.zig");

const windows_c = if (builtin.os.tag == .windows) struct {
    extern "c" fn _waccess(path: [*:0]const u16, mode: c_int) c_int;
} else struct {};

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
    resource_table,
    indirect_command_buffer,
    external_memory,
    external_buffer,
    external_semaphore,
    external_event,
    fence,
    event,
    query_set,
    heap,
    acceleration_structure,
    ray_tracing_pipeline_state,
    shader_binding_table,
    metal_ray_tracing_execution_mapping,
};

const object_cache_fingerprint_capacity = 32;
const object_cache_fingerprint_slots = core.object_cache_kind_count * object_cache_fingerprint_capacity;

const ObjectCacheLookup = struct {
    kind: core.ObjectCacheKind,
    fingerprint: u64,
    policy: core.ObjectCachePolicy,
    cache_hit: bool,
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
    advanced_bind_group_layouts: usize = 0,
    resource_tables: usize = 0,
    indirect_command_buffers: usize = 0,
    external_memories: usize = 0,
    external_buffers: usize = 0,
    external_semaphores: usize = 0,
    external_events: usize = 0,
    fences: usize = 0,
    events: usize = 0,
    query_sets: usize = 0,
    heaps: usize = 0,
    acceleration_structures: usize = 0,
    ray_tracing_pipeline_states: usize = 0,
    shader_binding_tables: usize = 0,
    metal_ray_tracing_execution_mappings: usize = 0,
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

    pub fn liveResourceCount(self: ResourceTracker) usize {
        return self.buffers +
            self.textures +
            self.texture_views +
            self.sampler_states +
            self.shader_modules +
            self.render_pipeline_states +
            self.compute_pipeline_states +
            self.bind_group_layouts +
            self.bind_groups +
            self.advanced_bind_group_layouts +
            self.resource_tables +
            self.indirect_command_buffers +
            self.external_memories +
            self.external_buffers +
            self.external_semaphores +
            self.external_events +
            self.fences +
            self.events +
            self.query_sets +
            self.heaps +
            self.acceleration_structures +
            self.ray_tracing_pipeline_states +
            self.shader_binding_tables +
            self.metal_ray_tracing_execution_mappings;
    }

    pub fn diagnosticsSnapshot(self: ResourceTracker) core.RuntimeDiagnosticsSnapshot {
        return .{
            .live_resources = self.liveResourceCount(),
            .pending_retirements = self.pending_retirements,
            .submitted_work_serial = self.submitted_work_serial,
            .completed_work_serial = self.completed_work_serial,
            .object_cache = self.object_cache_diagnostics,
        };
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
        if (policy.allowsReuse()) {
            self.rememberObjectFingerprint(kind, fingerprint);
        }
    }

    pub fn beginObjectCacheLookup(
        self: *ResourceTracker,
        kind: core.ObjectCacheKind,
        fingerprint: u64,
        policy: core.ObjectCachePolicy,
    ) ObjectCacheLookup {
        const cache_hit = policy.allowsReuse() and self.hasObjectFingerprint(kind, fingerprint);
        if (cache_hit and policy.recordsDiagnostics()) {
            self.object_cache_diagnostics.recordHit(kind);
        }
        return .{
            .kind = kind,
            .fingerprint = fingerprint,
            .policy = policy,
            .cache_hit = cache_hit,
        };
    }

    pub fn finishObjectCacheLookup(
        self: *ResourceTracker,
        lookup: ObjectCacheLookup,
        creation_time_ns: u64,
    ) void {
        self.recordObjectCreation(
            lookup.kind,
            lookup.fingerprint,
            lookup.policy,
            creation_time_ns,
        );
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
            self.advanced_bind_group_layouts != 0 or
            self.resource_tables != 0 or
            self.indirect_command_buffers != 0 or
            self.external_memories != 0 or
            self.external_buffers != 0 or
            self.external_semaphores != 0 or
            self.external_events != 0 or
            self.fences != 0 or
            self.events != 0 or
            self.query_sets != 0 or
            self.heaps != 0 or
            self.acceleration_structures != 0 or
            self.ray_tracing_pipeline_states != 0 or
            self.shader_binding_tables != 0 or
            self.metal_ray_tracing_execution_mappings != 0;
    }

    pub fn assertNoLeaks(self: ResourceTracker) void {
        if (builtin.mode == .Debug and self.hasLeaks()) {
            std.debug.panic(
                "vkmtl leaked resources before WindowContext.deinit: buffers={}, textures={}, texture_views={}, sampler_states={}, shader_modules={}, render_pipeline_states={}, compute_pipeline_states={}, bind_group_layouts={}, bind_groups={}, advanced_bind_group_layouts={}, resource_tables={}, indirect_command_buffers={}, external_memories={}, external_buffers={}, external_semaphores={}, external_events={}, fences={}, events={}, query_sets={}, heaps={}, acceleration_structures={}, ray_tracing_pipeline_states={}, shader_binding_tables={}, metal_ray_tracing_execution_mappings={}",
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
                    self.resource_tables,
                    self.indirect_command_buffers,
                    self.external_memories,
                    self.external_buffers,
                    self.external_semaphores,
                    self.external_events,
                    self.fences,
                    self.events,
                    self.query_sets,
                    self.heaps,
                    self.acceleration_structures,
                    self.ray_tracing_pipeline_states,
                    self.shader_binding_tables,
                    self.metal_ray_tracing_execution_mappings,
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
            .resource_table => &self.resource_tables,
            .indirect_command_buffer => &self.indirect_command_buffers,
            .external_memory => &self.external_memories,
            .external_buffer => &self.external_buffers,
            .external_semaphore => &self.external_semaphores,
            .external_event => &self.external_events,
            .fence => &self.fences,
            .event => &self.events,
            .query_set => &self.query_sets,
            .heap => &self.heaps,
            .acceleration_structure => &self.acceleration_structures,
            .ray_tracing_pipeline_state => &self.ray_tracing_pipeline_states,
            .shader_binding_table => &self.shader_binding_tables,
            .metal_ray_tracing_execution_mapping => &self.metal_ray_tracing_execution_mappings,
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
        .spirv_bytes => |bytes| {
            hashU64(hash, 2);
            hashBytes(hash, bytes);
        },
        .msl => |bytes| {
            hashU64(hash, 3);
            hashBytes(hash, bytes);
        },
        .artifact => |artifact| {
            hashU64(hash, 4);
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
    hashU64(hash, descriptor.resource_table_layouts.len);
    for (descriptor.resource_table_layouts) |layout| hashDescriptorIndexingLayoutDescriptor(hash, layout);
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
    hashRootConstantLayout(hash, descriptor.root_constant_layout);
    hashDriverPipelineCacheDescriptor(hash, descriptor.driver_cache);
}

fn hashMeshRenderPipelineDescriptor(hash: *u64, descriptor: core.MeshRenderPipelineDescriptor) void {
    hashProgrammableStage(hash, descriptor.mesh);
    if (descriptor.task) |task| {
        hashBool(hash, true);
        hashProgrammableStage(hash, task);
    } else {
        hashBool(hash, false);
    }
    if (descriptor.fragment) |fragment| {
        hashBool(hash, true);
        hashProgrammableStage(hash, fragment);
    } else {
        hashBool(hash, false);
    }
    hashU64(hash, descriptor.bind_group_layouts.len);
    for (descriptor.bind_group_layouts) |layout| hashBindGroupLayoutDescriptor(hash, layout);
    hashU64(hash, descriptor.resource_table_layouts.len);
    for (descriptor.resource_table_layouts) |layout| hashDescriptorIndexingLayoutDescriptor(hash, layout);
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
        hashBool(hash, attachment.blend != null);
    }
    if (descriptor.depth_stencil) |depth_stencil| {
        hashBool(hash, true);
        hashDepthStencilDescriptor(hash, depth_stencil);
    } else {
        hashBool(hash, false);
    }
    hashRootConstantLayout(hash, descriptor.root_constant_layout);
    hashDriverPipelineCacheDescriptor(hash, descriptor.driver_cache);
    hashU64(hash, descriptor.pipeline.mesh_threads_per_threadgroup);
    hashU64(hash, descriptor.pipeline.task_threads_per_threadgroup);
}

fn hashMeshPipelineDescriptor(backend: core.Backend, descriptor: core.MeshPipelineDescriptor) u64 {
    var hash = objectFingerprintStart(.render_pipeline, backend);
    hashBytes(&hash, descriptor.mesh_entry_point);
    if (descriptor.task_entry_point) |entry| {
        hashBool(&hash, true);
        hashBytes(&hash, entry);
    } else {
        hashBool(&hash, false);
    }
    hashU64(&hash, descriptor.mesh_threads_per_threadgroup);
    hashU64(&hash, descriptor.task_threads_per_threadgroup);
    return hash;
}

fn hashComputePipelineDescriptor(hash: *u64, descriptor: core.ComputePipelineDescriptor) void {
    hashProgrammableStage(hash, descriptor.compute);
    hashU64(hash, descriptor.bind_group_layouts.len);
    for (descriptor.bind_group_layouts) |layout| hashBindGroupLayoutDescriptor(hash, layout);
    hashU64(hash, descriptor.resource_table_layouts.len);
    for (descriptor.resource_table_layouts) |layout| hashDescriptorIndexingLayoutDescriptor(hash, layout);
    hashRootConstantLayout(hash, descriptor.root_constant_layout);
    hashDriverPipelineCacheDescriptor(hash, descriptor.driver_cache);
}

fn hashDriverPipelineCacheDescriptor(hash: *u64, descriptor: ?core.DriverPipelineCacheDescriptor) void {
    const cache = descriptor orelse {
        hashBool(hash, false);
        return;
    };
    hashBool(hash, true);
    hashBytes(hash, cache.path);
    hashU64(hash, @intFromEnum(cache.kind));
    hashU64(hash, @intFromEnum(cache.identity.backend));
    hashBytes(hash, cache.identity.device_id);
    hashBytes(hash, cache.identity.driver_id);
    hashBytes(hash, cache.identity.shader_hash);
    hashBytes(hash, cache.identity.schema_version);
    hashBool(hash, cache.read_only);
}

fn hashDescriptorIndexingLayoutDescriptor(hash: *u64, descriptor: core.DescriptorIndexingLayoutDescriptor) void {
    hashU64(hash, @intFromEnum(descriptor.model));
    hashU64(hash, descriptor.ranges.len);
    for (descriptor.ranges) |range| {
        hashU64(hash, range.binding);
        hashU64(hash, @intFromEnum(range.resource));
        hashBool(hash, range.visibility.vertex);
        hashBool(hash, range.visibility.fragment);
        hashBool(hash, range.visibility.compute);
        hashU64(hash, range.descriptor_count);
        hashBool(hash, range.partially_bound);
        hashBool(hash, range.update_after_bind);
    }
}

fn resourceTableLayoutFingerprint(descriptor: core.DescriptorIndexingLayoutDescriptor) u64 {
    var hash: u64 = 0xcbf29ce484222325;
    hashDescriptorIndexingLayoutDescriptor(&hash, descriptor);
    return hash;
}

fn copyResourceTableLayoutFingerprints(
    allocator: std.mem.Allocator,
    layouts: []const core.DescriptorIndexingLayoutDescriptor,
) ![]u64 {
    const hashes = try allocator.alloc(u64, layouts.len);
    for (layouts, hashes) |layout, *hash| hash.* = resourceTableLayoutFingerprint(layout);
    return hashes;
}

fn hashRootConstantLayout(hash: *u64, layout: ?core.RootConstantLayoutDescriptor) void {
    if (layout) |root_layout| {
        hashBool(hash, true);
        hashU64(hash, root_layout.ranges.len);
        for (root_layout.ranges) |range| {
            hashBool(hash, range.visibility.vertex);
            hashBool(hash, range.visibility.fragment);
            hashBool(hash, range.visibility.compute);
            hashU64(hash, range.offset);
            hashU64(hash, range.size);
        }
    } else {
        hashBool(hash, false);
    }
}

fn copyRootConstantRanges(
    allocator: std.mem.Allocator,
    layout: ?core.RootConstantLayoutDescriptor,
) ![]core.RootConstantRange {
    const root_layout = layout orelse return &.{};
    return try allocator.dupe(core.RootConstantRange, root_layout.ranges);
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
    hashBool(hash, descriptor.normalized_coordinates);
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

fn pathExists(path: []const u8) bool {
    if (path.len == 0 or path.len >= std.Io.Dir.max_path_bytes) return false;

    if (builtin.os.tag == .windows) {
        var wide_buffer: [std.Io.Dir.max_path_bytes:0]u16 = undefined;
        const wide_len = std.unicode.wtf8ToWtf16Le(
            wide_buffer[0..path.len],
            path,
        ) catch return false;
        wide_buffer[wide_len] = 0;
        return windows_c._waccess(wide_buffer[0..wide_len :0].ptr, 0) == 0;
    }

    var buffer: [std.Io.Dir.max_path_bytes:0]u8 = undefined;
    @memcpy(buffer[0..path.len], path);
    buffer[path.len] = 0;
    const sentinel_path = buffer[0..path.len :0];
    return std.c.access(sentinel_path.ptr, 0) == 0;
}

pub const Buffer = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const Impl = union(core.Backend) {
        vulkan: VulkanBuffer,
        metal: MetalBuffer,
    };

    const State = struct {
        backend: core.Backend,
        tracker: *ResourceTracker,
        label_value: ?[]const u8 = null,
        native_labels_enabled: bool = false,
        length_value: usize,
        usage_value: core.BufferUsage = .{},
        storage_mode_value: core.ResourceStorageMode = .automatic,
        usage_state: core.ResourceUsageState = .{},
        owner_queue_value: core.QueueKind = .graphics,
        heap_owner: ?*Heap.State = null,
        alive: bool = true,
        impl: Impl,
    };

    fn init(state_value: State) Buffer {
        var result: Buffer = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const Buffer) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn deinit(self: *Buffer) void {
        const state_value = self.state();
        assertAlive(state_value.alive, .buffer);
        state_value.alive = false;
        switch (state_value.impl) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        }
        if (state_value.heap_owner) |heap| {
            std.debug.assert(heap.live_resource_count != 0);
            heap.live_resource_count -= 1;
        }
        state_value.tracker.release(.buffer);
    }

    pub fn selectedBackend(self: Buffer) core.Backend {
        return self.state().backend;
    }

    pub fn length(self: Buffer) usize {
        return self.state().length_value;
    }

    pub fn label(self: Buffer) ?[]const u8 {
        return self.state().label_value;
    }

    pub fn setLabel(self: *Buffer, label_value: ?[]const u8) void {
        const state_value = self.state();
        assertAlive(state_value.alive, .buffer);
        state_value.label_value = label_value;
        if (!state_value.native_labels_enabled) return;
        switch (state_value.impl) {
            .vulkan => |*vulkan| vulkan.setLabel(label_value),
            .metal => |*metal| metal.setLabel(label_value),
        }
    }

    pub fn usage(self: Buffer) core.BufferUsage {
        return self.state().usage_value;
    }

    pub fn storageMode(self: Buffer) core.ResourceStorageMode {
        return self.state().storage_mode_value;
    }

    pub fn cpuVisible(self: Buffer) bool {
        return self.state().storage_mode_value.cpuVisible();
    }

    pub fn gpuAddress(self: Buffer) core.BufferError!u64 {
        const state_value = self.state();
        assertAlive(state_value.alive, .buffer);
        if (!state_value.usage_value.shader_device_address) {
            return core.BufferError.BufferMissingGpuAddressUsage;
        }
        return switch (state_value.impl) {
            .vulkan => |vulkan| try vulkan.gpuAddress(),
            .metal => |metal| try metal.gpuAddress(),
        };
    }

    pub fn currentUsage(self: Buffer) ?core.ResourceUsageKind {
        return self.state().usage_state.current;
    }

    pub fn usageBarrierCount(self: Buffer) usize {
        return self.state().usage_state.barrier_count;
    }

    pub fn ownerQueue(self: Buffer) core.QueueKind {
        return self.state().owner_queue_value;
    }

    fn recordUsage(self: *Buffer, next_usage: core.ResourceUsageKind) core.ResourceUsageTransition {
        return self.state().usage_state.transitionTo(next_usage);
    }

    pub fn mapRange(self: *Buffer, descriptor: core.BufferMapDescriptor) !MappedBufferRange {
        assertAlive(self.state().alive, .buffer);
        if (!self.cpuVisible()) return core.BufferError.BufferNotCpuVisible;
        try descriptor.validate(self.length());

        const impl = switch (self.state().impl) {
            .vulkan => |*vulkan| MappedBufferRange.Impl{ .vulkan = try vulkan.mapRange(descriptor) },
            .metal => |*metal| MappedBufferRange.Impl{ .metal = try metal.mapRange(descriptor) },
        };
        return MappedBufferRange.init(.{
            .backend = self.state().backend,
            .buffer = self,
            .bytes_value = switch (impl) {
                .vulkan => |range| range.bytes,
                .metal => |range| range.bytes,
            },
            .impl = impl,
        });
    }

    pub fn replaceBytes(self: *Buffer, offset: usize, bytes: []const u8) !void {
        assertAlive(self.state().alive, .buffer);
        const descriptor = core.BufferWriteDescriptor{
            .offset = offset,
            .bytes = bytes,
        };
        try descriptor.validate(self.length());
        switch (self.state().impl) {
            .vulkan => |*vulkan| try vulkan.replaceBytes(offset, bytes),
            .metal => |*metal| try metal.replaceBytes(offset, bytes),
        }
    }

    pub fn readBytes(self: *Buffer, offset: usize, destination: []u8) !void {
        assertAlive(self.state().alive, .buffer);
        const descriptor = core.BufferReadDescriptor{
            .offset = offset,
            .destination = destination,
        };
        try descriptor.validate(self.length());
        switch (self.state().impl) {
            .vulkan => |*vulkan| try vulkan.readBytes(offset, destination),
            .metal => |*metal| try metal.readBytes(offset, destination),
        }
    }
};

pub const MappedBufferRange = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const Impl = union(core.Backend) {
        vulkan: VulkanBuffer.MappedRange,
        metal: MetalBuffer.MappedRange,
    };

    const State = struct {
        backend: core.Backend,
        buffer: *Buffer,
        bytes_value: []u8,
        alive: bool = true,
        impl: Impl,
    };

    fn init(state_value: State) MappedBufferRange {
        var result: MappedBufferRange = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const MappedBufferRange) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn bytes(self: MappedBufferRange) []u8 {
        assertObjectAlive(self.state().alive, "mapped_buffer_range");
        return self.state().bytes_value;
    }

    pub fn deinit(self: *MappedBufferRange) void {
        const state_value = self.state();
        assertObjectAlive(state_value.alive, "mapped_buffer_range");
        assertAlive(state_value.buffer.state().alive, .buffer);
        switch (state_value.impl) {
            .vulkan => |range| state_value.buffer.state().impl.vulkan.unmapRange(range),
            .metal => |range| state_value.buffer.state().impl.metal.unmapRange(range) catch |err| {
                if (builtin.mode == .Debug) {
                    std.debug.panic("vkmtl failed to unmap Metal buffer: {s}", .{@errorName(err)});
                }
            },
        }
        state_value.alive = false;
    }
};

const SharedTextureUsageTracker = struct {
    allocator: std.mem.Allocator,
    reference_count: usize = 1,
    value: core.TextureSubresourceUsageTracker,

    fn init(
        allocator: std.mem.Allocator,
        descriptor: core.TextureDescriptor,
    ) !*SharedTextureUsageTracker {
        const shared = try allocator.create(SharedTextureUsageTracker);
        errdefer allocator.destroy(shared);
        shared.* = .{
            .allocator = allocator,
            .value = try core.TextureSubresourceUsageTracker.init(allocator, descriptor),
        };
        return shared;
    }

    fn retain(self: *SharedTextureUsageTracker) void {
        std.debug.assert(self.reference_count > 0);
        self.reference_count += 1;
    }

    fn release(self: *SharedTextureUsageTracker) void {
        std.debug.assert(self.reference_count > 0);
        self.reference_count -= 1;
        if (self.reference_count != 0) return;
        const allocator = self.allocator;
        self.value.deinit();
        allocator.destroy(self);
    }
};

pub const Texture = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const Impl = union(core.Backend) {
        vulkan: VulkanTexture,
        metal: MetalTexture,
    };

    const State = struct {
        backend: core.Backend,
        tracker: *ResourceTracker,
        label_value: ?[]const u8 = null,
        native_labels_enabled: bool = false,
        dimension_value: core.TextureDimension = .two_d,
        format_value: core.TextureFormat,
        usage_value: core.TextureUsage,
        storage_mode_value: core.ResourceStorageMode = .automatic,
        sample_count_value: u32,
        usage_state: core.ResourceUsageState = .{},
        subresource_usage_tracker: ?*SharedTextureUsageTracker = null,
        owner_queue_value: core.QueueKind = .graphics,
        heap_owner: ?*Heap.State = null,
        alive: bool = true,
        impl: Impl,
    };

    fn init(state_value: State) Texture {
        var result: Texture = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const Texture) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn deinit(self: *Texture) void {
        const state_value = self.state();
        assertAlive(state_value.alive, .texture);
        state_value.alive = false;
        switch (state_value.impl) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        }
        if (state_value.subresource_usage_tracker) |subresource_tracker| {
            subresource_tracker.release();
            state_value.subresource_usage_tracker = null;
        }
        if (state_value.heap_owner) |heap| {
            std.debug.assert(heap.live_resource_count != 0);
            heap.live_resource_count -= 1;
        }
        state_value.tracker.release(.texture);
    }

    pub fn selectedBackend(self: Texture) core.Backend {
        return self.state().backend;
    }

    pub fn label(self: Texture) ?[]const u8 {
        return self.state().label_value;
    }

    pub fn setLabel(self: *Texture, label_value: ?[]const u8) void {
        const state_value = self.state();
        assertAlive(state_value.alive, .texture);
        state_value.label_value = label_value;
        if (!state_value.native_labels_enabled) return;
        switch (state_value.impl) {
            .vulkan => |*vulkan| vulkan.setLabel(label_value),
            .metal => |*metal| metal.setLabel(label_value),
        }
    }

    pub fn format(self: Texture) core.TextureFormat {
        return self.state().format_value;
    }

    pub fn usage(self: Texture) core.TextureUsage {
        return self.state().usage_value;
    }

    pub fn currentUsage(self: Texture) ?core.ResourceUsageKind {
        return self.state().usage_state.current;
    }

    pub fn usageBarrierCount(self: Texture) usize {
        return self.state().usage_state.barrier_count;
    }

    pub fn ownerQueue(self: Texture) core.QueueKind {
        return self.state().owner_queue_value;
    }

    fn recordUsage(self: *Texture, next_usage: core.ResourceUsageKind) core.ResourceUsageTransition {
        const transition = self.state().usage_state.transitionTo(next_usage);
        if (self.state().subresource_usage_tracker) |subresource_tracker| {
            _ = subresource_tracker.value.transition(.{}, next_usage) catch {};
        }
        return transition;
    }

    fn recordSubresourceUsage(
        self: *Texture,
        range: core.TextureSubresourceRange,
        next_usage: core.ResourceUsageKind,
    ) core.CommandEncodingError!core.TextureUsageTransitionSummary {
        const subresource_tracker = self.state().subresource_usage_tracker orelse {
            _ = self.state().usage_state.transitionTo(next_usage);
            return .{};
        };
        const summary = try subresource_tracker.value.transition(range, next_usage);
        self.state().usage_state.current = if (textureSubresourceRangeIsFull(range, self.textureDescriptor())) next_usage else null;
        if (summary.required_barrier_count != 0) self.state().usage_state.barrier_count += 1;
        return summary;
    }

    pub fn subresourceUsage(self: Texture, mip_level: u32, array_layer: u32) ?core.ResourceUsageKind {
        const subresource_tracker = self.state().subresource_usage_tracker orelse return null;
        return subresource_tracker.value.currentUsage(mip_level, array_layer);
    }

    pub fn sampleCount(self: Texture) u32 {
        return self.state().sample_count_value;
    }

    pub fn width(self: Texture) u32 {
        return switch (self.state().impl) {
            .vulkan => |vulkan| vulkan.width(),
            .metal => |metal| metal.width(),
        };
    }

    pub fn height(self: Texture) u32 {
        return switch (self.state().impl) {
            .vulkan => |vulkan| vulkan.height(),
            .metal => |metal| metal.height(),
        };
    }

    pub fn depthOrArrayLayers(self: Texture) u32 {
        return switch (self.state().impl) {
            .vulkan => |vulkan| vulkan.depthOrArrayLayers(),
            .metal => |metal| metal.depthOrArrayLayers(),
        };
    }

    pub fn mipLevelCount(self: Texture) u32 {
        return switch (self.state().impl) {
            .vulkan => |vulkan| vulkan.mipLevelCount(),
            .metal => |metal| metal.mipLevelCount(),
        };
    }

    pub fn textureDescriptor(self: Texture) core.TextureDescriptor {
        return .{
            .format = self.state().format_value,
            .dimension = self.state().dimension_value,
            .width = self.width(),
            .height = self.height(),
            .depth_or_array_layers = self.depthOrArrayLayers(),
            .mip_level_count = self.mipLevelCount(),
            .sample_count = self.state().sample_count_value,
            .usage = self.state().usage_value,
            .storage_mode = self.state().storage_mode_value,
        };
    }

    pub fn makeTextureView(self: *Texture, descriptor: core.TextureViewDescriptor) !TextureView {
        assertAlive(self.state().alive, .texture);
        const resolved = try descriptor.resolveForTexture(.{
            .format = self.state().format_value,
            .width = self.width(),
            .height = self.height(),
            .depth_or_array_layers = self.depthOrArrayLayers(),
            .mip_level_count = self.mipLevelCount(),
            .usage = self.state().usage_value,
        });
        const impl = switch (self.state().impl) {
            .vulkan => |*vulkan| TextureView.Impl{ .vulkan = try vulkan.makeTextureView(descriptor) },
            .metal => |*metal| TextureView.Impl{ .metal = try metal.makeTextureView(descriptor) },
        };
        self.state().tracker.retain(.texture_view);
        var view = TextureView.init(.{
            .backend = self.state().backend,
            .tracker = self.state().tracker,
            .label_value = descriptor.label,
            .native_labels_enabled = true,
            .format_value = resolved.format,
            .dimension_value = resolved.dimension,
            .usage_value = self.state().usage_value,
            .storage_mode_value = self.state().storage_mode_value,
            .sample_count_value = self.state().sample_count_value,
            .subresource_usage_tracker = self.state().subresource_usage_tracker,
            .width_value = mipDimension(self.width(), resolved.base_mip_level),
            .height_value = mipDimension(self.height(), resolved.base_mip_level),
            .base_mip_level_value = resolved.base_mip_level,
            .mip_level_count_value = resolved.mip_level_count,
            .base_array_layer_value = resolved.base_array_layer,
            .array_layer_count_value = resolved.array_layer_count,
            .component_mapping_value = resolved.component_mapping,
            .owner_queue_value = self.state().owner_queue_value,
            .impl = impl,
        });
        if (self.state().subresource_usage_tracker) |subresource_tracker| subresource_tracker.retain();
        view.setLabel(descriptor.label);
        return view;
    }

    pub fn replaceRegion(
        self: *Texture,
        region: core.Region3D,
        descriptor: core.TextureReplaceRegionDescriptor,
    ) !void {
        assertAlive(self.state().alive, .texture);
        if (!self.state().storage_mode_value.cpuVisible()) {
            return core.TextureError.TextureNotCpuVisible;
        }
        switch (self.state().impl) {
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

fn ExternalResourceState(comptime Descriptor: type) type {
    return struct {
        backend: core.Backend,
        tracker: *ResourceTracker,
        descriptor_value: Descriptor,
        import_plan_value: core.ExternalInteropImportPlan,
        alive: bool = true,
    };
}

pub const ExternalMemory = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const State = ExternalResourceState(core.ExternalMemoryDescriptor);

    fn init(state_value: State) ExternalMemory {
        var result: ExternalMemory = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const ExternalMemory) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn deinit(self: *ExternalMemory) void {
        assertAlive(self.state().alive, .external_memory);
        self.state().alive = false;
        self.state().tracker.release(.external_memory);
    }

    pub fn selectedBackend(self: ExternalMemory) core.Backend {
        return self.state().backend;
    }

    pub fn descriptor(self: ExternalMemory) core.ExternalMemoryDescriptor {
        assertAlive(self.state().alive, .external_memory);
        return self.state().descriptor_value;
    }

    pub fn size(self: ExternalMemory) u64 {
        assertAlive(self.state().alive, .external_memory);
        return self.state().descriptor_value.size;
    }

    pub fn ownership(self: ExternalMemory) core.ExternalResourceOwnership {
        assertAlive(self.state().alive, .external_memory);
        return self.state().descriptor_value.ownership;
    }

    pub fn importPlan(self: ExternalMemory) core.ExternalInteropImportPlan {
        assertAlive(self.state().alive, .external_memory);
        return self.state().import_plan_value;
    }
};

pub const ExternalBuffer = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const State = ExternalResourceState(core.ExternalBufferDescriptor);

    fn init(state_value: State) ExternalBuffer {
        var result: ExternalBuffer = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const ExternalBuffer) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn deinit(self: *ExternalBuffer) void {
        assertAlive(self.state().alive, .external_buffer);
        self.state().alive = false;
        self.state().tracker.release(.external_buffer);
    }

    pub fn selectedBackend(self: ExternalBuffer) core.Backend {
        return self.state().backend;
    }

    pub fn descriptor(self: ExternalBuffer) core.ExternalBufferDescriptor {
        assertAlive(self.state().alive, .external_buffer);
        return self.state().descriptor_value;
    }

    pub fn length(self: ExternalBuffer) u64 {
        assertAlive(self.state().alive, .external_buffer);
        return self.state().descriptor_value.length;
    }

    pub fn usage(self: ExternalBuffer) core.BufferUsage {
        assertAlive(self.state().alive, .external_buffer);
        return self.state().descriptor_value.usage;
    }

    pub fn ownership(self: ExternalBuffer) core.ExternalResourceOwnership {
        assertAlive(self.state().alive, .external_buffer);
        return self.state().descriptor_value.ownership;
    }

    pub fn importPlan(self: ExternalBuffer) core.ExternalInteropImportPlan {
        assertAlive(self.state().alive, .external_buffer);
        return self.state().import_plan_value;
    }
};

pub const ExternalSemaphore = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const State = ExternalResourceState(core.ExternalSemaphoreDescriptor);

    fn init(state_value: State) ExternalSemaphore {
        var result: ExternalSemaphore = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const ExternalSemaphore) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn deinit(self: *ExternalSemaphore) void {
        assertAlive(self.state().alive, .external_semaphore);
        self.state().alive = false;
        self.state().tracker.release(.external_semaphore);
    }

    pub fn selectedBackend(self: ExternalSemaphore) core.Backend {
        return self.state().backend;
    }

    pub fn descriptor(self: ExternalSemaphore) core.ExternalSemaphoreDescriptor {
        assertAlive(self.state().alive, .external_semaphore);
        return self.state().descriptor_value;
    }

    pub fn isTimeline(self: ExternalSemaphore) bool {
        assertAlive(self.state().alive, .external_semaphore);
        return self.state().descriptor_value.timeline;
    }

    pub fn ownership(self: ExternalSemaphore) core.ExternalResourceOwnership {
        assertAlive(self.state().alive, .external_semaphore);
        return self.state().descriptor_value.ownership;
    }

    pub fn importPlan(self: ExternalSemaphore) core.ExternalInteropImportPlan {
        assertAlive(self.state().alive, .external_semaphore);
        return self.state().import_plan_value;
    }
};

pub const ExternalEvent = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const State = ExternalResourceState(core.ExternalEventDescriptor);

    fn init(state_value: State) ExternalEvent {
        var result: ExternalEvent = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const ExternalEvent) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn deinit(self: *ExternalEvent) void {
        assertAlive(self.state().alive, .external_event);
        self.state().alive = false;
        self.state().tracker.release(.external_event);
    }

    pub fn selectedBackend(self: ExternalEvent) core.Backend {
        return self.state().backend;
    }

    pub fn descriptor(self: ExternalEvent) core.ExternalEventDescriptor {
        assertAlive(self.state().alive, .external_event);
        return self.state().descriptor_value;
    }

    pub fn isShared(self: ExternalEvent) bool {
        assertAlive(self.state().alive, .external_event);
        return self.state().descriptor_value.shared;
    }

    pub fn ownership(self: ExternalEvent) core.ExternalResourceOwnership {
        assertAlive(self.state().alive, .external_event);
        return self.state().descriptor_value.ownership;
    }

    pub fn importPlan(self: ExternalEvent) core.ExternalInteropImportPlan {
        assertAlive(self.state().alive, .external_event);
        return self.state().import_plan_value;
    }
};

pub const ExternalSynchronizationPlan = struct {
    backend: core.Backend,
    wait_semaphore_count: usize = 0,
    signal_semaphore_count: usize = 0,
    wait_event_count: usize = 0,
    signal_event_count: usize = 0,
    native_wait_count: usize = 0,
    native_signal_count: usize = 0,

    pub fn isEmpty(self: ExternalSynchronizationPlan) bool {
        return self.wait_semaphore_count == 0 and
            self.signal_semaphore_count == 0 and
            self.wait_event_count == 0 and
            self.signal_event_count == 0;
    }

    pub fn hasWaits(self: ExternalSynchronizationPlan) bool {
        return self.wait_semaphore_count != 0 or self.wait_event_count != 0;
    }

    pub fn hasSignals(self: ExternalSynchronizationPlan) bool {
        return self.signal_semaphore_count != 0 or self.signal_event_count != 0;
    }

    pub fn requiresNativeInterop(self: ExternalSynchronizationPlan) bool {
        return self.native_wait_count != 0 or self.native_signal_count != 0;
    }
};

pub const ExternalSynchronizationDescriptor = struct {
    wait_semaphores: []const *ExternalSemaphore = &.{},
    signal_semaphores: []const *ExternalSemaphore = &.{},
    wait_events: []const *ExternalEvent = &.{},
    signal_events: []const *ExternalEvent = &.{},

    pub fn isEmpty(self: ExternalSynchronizationDescriptor) bool {
        return self.wait_semaphores.len == 0 and
            self.signal_semaphores.len == 0 and
            self.wait_events.len == 0 and
            self.signal_events.len == 0;
    }

    pub fn validate(self: ExternalSynchronizationDescriptor, backend: core.Backend) RuntimeError!void {
        _ = try self.plan(backend);
    }

    pub fn plan(self: ExternalSynchronizationDescriptor, backend: core.Backend) RuntimeError!ExternalSynchronizationPlan {
        var result = ExternalSynchronizationPlan{ .backend = backend };
        for (self.wait_semaphores) |semaphore| {
            assertAlive(semaphore.state().alive, .external_semaphore);
            try expectSameBackend(backend, semaphore.selectedBackend());
            result.wait_semaphore_count += 1;
            if (semaphore.importPlan().requiresNativeImport()) result.native_wait_count += 1;
        }
        for (self.signal_semaphores) |semaphore| {
            assertAlive(semaphore.state().alive, .external_semaphore);
            try expectSameBackend(backend, semaphore.selectedBackend());
            result.signal_semaphore_count += 1;
            if (semaphore.importPlan().requiresNativeImport()) result.native_signal_count += 1;
        }
        for (self.wait_events) |event| {
            assertAlive(event.state().alive, .external_event);
            try expectSameBackend(backend, event.selectedBackend());
            result.wait_event_count += 1;
            if (event.importPlan().requiresNativeImport()) result.native_wait_count += 1;
        }
        for (self.signal_events) |event| {
            assertAlive(event.state().alive, .external_event);
            try expectSameBackend(backend, event.selectedBackend());
            result.signal_event_count += 1;
            if (event.importPlan().requiresNativeImport()) result.native_signal_count += 1;
        }
        return result;
    }
};

pub const FenceWaitOperation = struct {
    fence: *Fence,
    descriptor: core.FenceWaitDescriptor = .{},
};

pub const FenceSignalOperation = struct {
    fence: *Fence,
    descriptor: core.FenceSignalDescriptor = .{},
};

pub const EventWaitOperation = struct {
    event: *Event,
    descriptor: core.EventWaitDescriptor = .{},
};

pub const EventSignalOperation = struct {
    event: *Event,
    descriptor: core.EventSignalDescriptor = .{},
};

pub const SynchronizationDescriptor = struct {
    wait_fences: []const FenceWaitOperation = &.{},
    signal_fences: []const FenceSignalOperation = &.{},
    wait_events: []const EventWaitOperation = &.{},
    signal_events: []const EventSignalOperation = &.{},

    pub fn isEmpty(self: SynchronizationDescriptor) bool {
        return self.wait_fences.len == 0 and
            self.signal_fences.len == 0 and
            self.wait_events.len == 0 and
            self.signal_events.len == 0;
    }

    pub fn validate(self: SynchronizationDescriptor, backend: core.Backend) !void {
        for (self.wait_fences) |operation| {
            assertObjectAlive(operation.fence.state().alive, "fence");
            try expectSameBackend(backend, operation.fence.selectedBackend());
            try operation.descriptor.validate(operation.fence.state().descriptor_value);
        }
        for (self.signal_fences) |operation| {
            assertObjectAlive(operation.fence.state().alive, "fence");
            try expectSameBackend(backend, operation.fence.selectedBackend());
            try operation.descriptor.validate(operation.fence.state().descriptor_value);
            if (operation.fence.state().descriptor_value.kind == .timeline and
                operation.descriptor.value < operation.fence.state().current_value)
            {
                return core.CommandEncodingError.InvalidFenceValue;
            }
        }
        for (self.wait_events) |operation| {
            assertObjectAlive(operation.event.state().alive, "event");
            try expectSameBackend(backend, operation.event.selectedBackend());
        }
        for (self.signal_events) |operation| {
            assertObjectAlive(operation.event.state().alive, "event");
            try expectSameBackend(backend, operation.event.selectedBackend());
        }
    }

    fn waitBeforeSubmit(self: SynchronizationDescriptor) !void {
        for (self.wait_fences) |operation| {
            if (operation.fence.state().impl != null) continue;
            try operation.fence.wait(operation.descriptor);
        }
        for (self.wait_events) |operation| {
            if (operation.event.state().impl != null) continue;
            try operation.event.wait(operation.descriptor);
        }
    }

    fn signalAfterSubmit(self: SynchronizationDescriptor) !void {
        for (self.signal_fences) |operation| {
            if (operation.fence.state().impl != null) {
                operation.fence.state().current_value = operation.descriptor.value;
            } else {
                try operation.fence.signal(operation.descriptor);
            }
        }
        for (self.signal_events) |operation| {
            if (operation.event.state().impl != null) {
                operation.event.state().signaled_value = operation.descriptor.signaled;
                if (!operation.descriptor.signaled) operation.event.state().generation +|= 1;
            } else {
                try operation.event.signal(operation.descriptor);
            }
        }
    }

    fn encodeNative(self: SynchronizationDescriptor, command_buffer: *CommandBuffer) !void {
        if (command_buffer.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan_command| {
                for (self.wait_fences) |operation| {
                    if (operation.fence.state().impl) |*fence_impl| switch (fence_impl.*) {
                        .vulkan => |*timeline| try vulkan_command.waitTimeline(timeline, operation.descriptor.value),
                        .metal => return RuntimeError.BackendMismatch,
                    };
                }
                for (self.signal_fences) |operation| {
                    if (operation.fence.state().impl) |*fence_impl| switch (fence_impl.*) {
                        .vulkan => |*timeline| try vulkan_command.signalTimeline(timeline, operation.descriptor.value),
                        .metal => return RuntimeError.BackendMismatch,
                    };
                }
            },
            .metal => |*metal_command| {
                for (self.wait_fences) |operation| {
                    if (operation.fence.state().impl) |*fence_impl| switch (fence_impl.*) {
                        .metal => |*event| try metal_command.waitSharedEvent(event, operation.descriptor.value),
                        .vulkan => return RuntimeError.BackendMismatch,
                    };
                }
                for (self.signal_fences) |operation| {
                    if (operation.fence.state().impl) |*fence_impl| switch (fence_impl.*) {
                        .metal => |*event| try metal_command.signalSharedEvent(event, operation.descriptor.value),
                        .vulkan => return RuntimeError.BackendMismatch,
                    };
                }
                for (self.wait_events) |operation| {
                    if (operation.event.state().impl) |*event_impl| switch (event_impl.*) {
                        .metal => |*event| try metal_command.waitSharedEvent(event, operation.event.state().generation),
                    };
                }
                for (self.signal_events) |operation| {
                    if (!operation.descriptor.signaled) continue;
                    if (operation.event.state().impl) |*event_impl| switch (event_impl.*) {
                        .metal => |*event| try metal_command.signalSharedEvent(event, operation.event.state().generation),
                    };
                }
            },
        } else return;
    }
};

pub const ExternalTexture = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const State = ExternalResourceState(core.ExternalTextureDescriptor);

    fn init(state_value: State) ExternalTexture {
        var result: ExternalTexture = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const ExternalTexture) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn deinit(self: *ExternalTexture) void {
        assertAlive(self.state().alive, .texture);
        self.state().alive = false;
        self.state().tracker.release(.texture);
    }

    pub fn selectedBackend(self: ExternalTexture) core.Backend {
        return self.state().backend;
    }

    pub fn descriptor(self: ExternalTexture) core.ExternalTextureDescriptor {
        assertAlive(self.state().alive, .texture);
        return self.state().descriptor_value;
    }

    pub fn textureDescriptor(self: ExternalTexture) core.TextureDescriptor {
        assertAlive(self.state().alive, .texture);
        return self.state().descriptor_value.textureDescriptor();
    }

    pub fn ownership(self: ExternalTexture) core.ExternalResourceOwnership {
        assertAlive(self.state().alive, .texture);
        return self.state().descriptor_value.ownership;
    }

    pub fn importPlan(self: ExternalTexture) core.ExternalInteropImportPlan {
        assertAlive(self.state().alive, .texture);
        return self.state().import_plan_value;
    }
};

pub const TextureView = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const Impl = union(core.Backend) {
        vulkan: VulkanTextureView,
        metal: MetalTextureView,
    };

    const State = struct {
        backend: core.Backend,
        tracker: *ResourceTracker,
        label_value: ?[]const u8 = null,
        native_labels_enabled: bool = false,
        format_value: core.TextureFormat,
        dimension_value: core.TextureViewDimension = .automatic,
        usage_value: core.TextureUsage,
        storage_mode_value: core.ResourceStorageMode = .automatic,
        sample_count_value: u32,
        width_value: u32,
        height_value: u32,
        base_mip_level_value: u32 = 0,
        mip_level_count_value: u32 = 1,
        base_array_layer_value: u32 = 0,
        array_layer_count_value: u32 = 1,
        component_mapping_value: core.TextureComponentMapping = .{},
        owner_queue_value: core.QueueKind = .graphics,
        usage_state: core.ResourceUsageState = .{},
        subresource_usage_tracker: ?*SharedTextureUsageTracker = null,
        alive: bool = true,
        impl: Impl,
    };

    fn init(state_value: State) TextureView {
        var result: TextureView = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const TextureView) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn deinit(self: *TextureView) void {
        const state_value = self.state();
        assertAlive(state_value.alive, .texture_view);
        state_value.alive = false;
        switch (state_value.impl) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        }
        if (state_value.subresource_usage_tracker) |subresource_tracker| {
            subresource_tracker.release();
            state_value.subresource_usage_tracker = null;
        }
        state_value.tracker.release(.texture_view);
    }

    pub fn selectedBackend(self: TextureView) core.Backend {
        return self.state().backend;
    }

    pub fn label(self: TextureView) ?[]const u8 {
        return self.state().label_value;
    }

    pub fn setLabel(self: *TextureView, label_value: ?[]const u8) void {
        const state_value = self.state();
        assertAlive(state_value.alive, .texture_view);
        state_value.label_value = label_value;
        if (!state_value.native_labels_enabled) return;
        switch (state_value.impl) {
            .vulkan => |*vulkan| vulkan.setLabel(label_value),
            .metal => |*metal| metal.setLabel(label_value),
        }
    }

    pub fn format(self: TextureView) core.TextureFormat {
        return self.state().format_value;
    }

    pub fn storageMode(self: TextureView) core.ResourceStorageMode {
        return self.state().storage_mode_value;
    }

    pub fn dimension(self: TextureView) core.TextureViewDimension {
        return self.state().dimension_value;
    }

    pub fn baseMipLevel(self: TextureView) u32 {
        return self.state().base_mip_level_value;
    }

    pub fn mipLevelCount(self: TextureView) u32 {
        return self.state().mip_level_count_value;
    }

    pub fn baseArrayLayer(self: TextureView) u32 {
        return self.state().base_array_layer_value;
    }

    pub fn arrayLayerCount(self: TextureView) u32 {
        return self.state().array_layer_count_value;
    }

    pub fn descriptor(self: TextureView) core.ResolvedTextureViewDescriptor {
        assertAlive(self.state().alive, .texture_view);
        return .{
            .format = self.state().format_value,
            .dimension = self.state().dimension_value,
            .base_mip_level = self.state().base_mip_level_value,
            .mip_level_count = self.state().mip_level_count_value,
            .base_array_layer = self.state().base_array_layer_value,
            .array_layer_count = self.state().array_layer_count_value,
            .component_mapping = self.state().component_mapping_value,
        };
    }

    pub fn usage(self: TextureView) core.TextureUsage {
        return self.state().usage_value;
    }

    pub fn currentUsage(self: TextureView) ?core.ResourceUsageKind {
        return self.state().usage_state.current;
    }

    pub fn usageBarrierCount(self: TextureView) usize {
        return self.state().usage_state.barrier_count;
    }

    pub fn ownerQueue(self: TextureView) core.QueueKind {
        return self.state().owner_queue_value;
    }

    fn recordUsage(self: *TextureView, next_usage: core.ResourceUsageKind) core.ResourceUsageTransition {
        const transition = self.state().usage_state.transitionTo(next_usage);
        if (self.state().subresource_usage_tracker) |subresource_tracker| {
            _ = subresource_tracker.value.transition(.{
                .base_mip_level = self.state().base_mip_level_value,
                .mip_level_count = self.state().mip_level_count_value,
                .base_array_layer = self.state().base_array_layer_value,
                .array_layer_count = self.state().array_layer_count_value,
            }, next_usage) catch {};
        }
        return transition;
    }

    pub fn sampleCount(self: TextureView) u32 {
        return self.state().sample_count_value;
    }

    pub fn width(self: TextureView) u32 {
        return self.state().width_value;
    }

    pub fn height(self: TextureView) u32 {
        return self.state().height_value;
    }
};

pub const SamplerState = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const Impl = union(core.Backend) {
        vulkan: VulkanSamplerState,
        metal: MetalSamplerState,
    };

    const State = struct {
        backend: core.Backend,
        tracker: *ResourceTracker,
        label_value: ?[]const u8 = null,
        native_labels_enabled: bool = false,
        alive: bool = true,
        impl: Impl,
    };

    fn init(state_value: State) SamplerState {
        var result: SamplerState = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const SamplerState) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn deinit(self: *SamplerState) void {
        const state_value = self.state();
        assertAlive(state_value.alive, .sampler_state);
        state_value.alive = false;
        switch (state_value.impl) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        }
        state_value.tracker.release(.sampler_state);
    }

    pub fn selectedBackend(self: SamplerState) core.Backend {
        return self.state().backend;
    }

    pub fn label(self: SamplerState) ?[]const u8 {
        return self.state().label_value;
    }

    pub fn setLabel(self: *SamplerState, label_value: ?[]const u8) void {
        const state_value = self.state();
        assertAlive(state_value.alive, .sampler_state);
        state_value.label_value = label_value;
        if (!state_value.native_labels_enabled) return;
        switch (state_value.impl) {
            .vulkan => |*vulkan| vulkan.setLabel(label_value),
            .metal => |*metal| metal.setLabel(label_value),
        }
    }
};

pub const Fence = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const Impl = union(core.Backend) {
        vulkan: VulkanSync.TimelineSemaphore,
        metal: MetalSync.SharedEvent,
    };

    const State = struct {
        backend: core.Backend,
        tracker: *ResourceTracker,
        label_value: ?[]const u8 = null,
        descriptor_value: core.FenceDescriptor,
        current_value: u64,
        alive: bool = true,
        impl: ?Impl = null,
    };

    fn init(state_value: State) Fence {
        var result: Fence = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const Fence) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn deinit(self: *Fence) void {
        assertObjectAlive(self.state().alive, "fence");
        if (self.state().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        };
        self.state().alive = false;
        self.state().tracker.release(.fence);
    }

    pub fn selectedBackend(self: Fence) core.Backend {
        return self.state().backend;
    }

    pub fn label(self: Fence) ?[]const u8 {
        return self.state().label_value;
    }

    pub fn setLabel(self: *Fence, label_value: ?[]const u8) void {
        assertObjectAlive(self.state().alive, "fence");
        self.state().label_value = label_value;
    }

    pub fn descriptor(self: Fence) core.FenceDescriptor {
        assertObjectAlive(self.state().alive, "fence");
        return self.state().descriptor_value;
    }

    pub fn currentValue(self: Fence) u64 {
        assertObjectAlive(self.state().alive, "fence");
        return self.state().current_value;
    }

    pub fn isSignaled(self: Fence, value: u64) bool {
        assertObjectAlive(self.state().alive, "fence");
        return switch (self.state().descriptor_value.kind) {
            .binary => self.state().current_value != 0 and value <= 1,
            .timeline => self.state().current_value >= value,
        };
    }

    pub fn signal(self: *Fence, signal_descriptor: core.FenceSignalDescriptor) !void {
        assertObjectAlive(self.state().alive, "fence");
        try signal_descriptor.validate(self.state().descriptor_value);
        if (self.state().descriptor_value.kind == .timeline and
            signal_descriptor.value < self.state().current_value)
        {
            return core.CommandEncodingError.InvalidFenceValue;
        }
        if (self.state().impl) |*impl| switch (impl.*) {
            .vulkan => |vulkan| vulkan.signal(signal_descriptor.value) catch return core.CommandEncodingError.SynchronizationBackendFailure,
            .metal => |*metal| metal.signal(signal_descriptor.value) catch return core.CommandEncodingError.SynchronizationBackendFailure,
        };
        switch (self.state().descriptor_value.kind) {
            .binary => self.state().current_value = 1,
            .timeline => self.state().current_value = signal_descriptor.value,
        }
    }

    pub fn wait(self: *Fence, wait_descriptor: core.FenceWaitDescriptor) !void {
        assertObjectAlive(self.state().alive, "fence");
        try wait_descriptor.validate(self.state().descriptor_value);
        if (self.state().impl) |impl| {
            const complete = switch (impl) {
                .vulkan => |vulkan| vulkan.wait(wait_descriptor.value, wait_descriptor.timeout_ns) catch return core.CommandEncodingError.SynchronizationBackendFailure,
                .metal => |metal| blk: {
                    metal.wait(wait_descriptor.value, wait_descriptor.timeout_ns) catch |err| switch (err) {
                        error.WaitTimeout => break :blk false,
                        else => return core.CommandEncodingError.SynchronizationBackendFailure,
                    };
                    break :blk true;
                },
            };
            if (!complete) return core.CommandEncodingError.FenceWaitTimeout;
            self.state().current_value = @max(self.state().current_value, wait_descriptor.value);
            return;
        }
        if (!self.isSignaled(wait_descriptor.value)) return core.CommandEncodingError.FenceWaitTimeout;
    }

    pub fn reset(self: *Fence) !void {
        assertObjectAlive(self.state().alive, "fence");
        switch (self.state().descriptor_value.kind) {
            .binary => self.state().current_value = 0,
            .timeline => return core.CommandEncodingError.InvalidFenceValue,
        }
    }
};

pub const Event = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const Impl = union(enum) {
        metal: MetalSync.SharedEvent,
    };

    const State = struct {
        backend: core.Backend,
        tracker: *ResourceTracker,
        label_value: ?[]const u8 = null,
        descriptor_value: core.EventDescriptor,
        signaled_value: bool = false,
        generation: u64 = 1,
        alive: bool = true,
        impl: ?Impl = null,
    };

    fn init(state_value: State) Event {
        var result: Event = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const Event) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn deinit(self: *Event) void {
        assertObjectAlive(self.state().alive, "event");
        if (self.state().impl) |*impl| switch (impl.*) {
            .metal => |*metal| metal.deinit(),
        };
        self.state().alive = false;
        self.state().tracker.release(.event);
    }

    pub fn selectedBackend(self: Event) core.Backend {
        return self.state().backend;
    }

    pub fn label(self: Event) ?[]const u8 {
        return self.state().label_value;
    }

    pub fn setLabel(self: *Event, label_value: ?[]const u8) void {
        assertObjectAlive(self.state().alive, "event");
        self.state().label_value = label_value;
    }

    pub fn descriptor(self: Event) core.EventDescriptor {
        assertObjectAlive(self.state().alive, "event");
        return self.state().descriptor_value;
    }

    pub fn isSignaled(self: Event) bool {
        assertObjectAlive(self.state().alive, "event");
        return self.state().signaled_value;
    }

    pub fn signal(self: *Event, signal_descriptor: core.EventSignalDescriptor) !void {
        assertObjectAlive(self.state().alive, "event");
        if (signal_descriptor.signaled) {
            if (self.state().impl) |*impl| switch (impl.*) {
                .metal => |*metal| metal.signal(self.state().generation) catch return core.CommandEncodingError.SynchronizationBackendFailure,
            };
        }
        self.state().signaled_value = signal_descriptor.signaled;
        if (!signal_descriptor.signaled) self.state().generation +|= 1;
    }

    pub fn wait(self: *Event, wait_descriptor: core.EventWaitDescriptor) !void {
        assertObjectAlive(self.state().alive, "event");
        if (self.state().impl) |impl| switch (impl) {
            .metal => |metal| {
                metal.wait(self.state().generation, wait_descriptor.timeout_ns) catch |err| switch (err) {
                    error.WaitTimeout => return core.CommandEncodingError.EventWaitTimeout,
                    else => return core.CommandEncodingError.SynchronizationBackendFailure,
                };
                self.state().signaled_value = true;
                return;
            },
        };
        if (!self.state().signaled_value) return core.CommandEncodingError.EventWaitTimeout;
    }

    pub fn reset(self: *Event) void {
        assertObjectAlive(self.state().alive, "event");
        self.state().signaled_value = false;
        self.state().generation +|= 1;
    }
};

pub const Heap = struct {
    _state: *anyopaque,

    const Impl = union(core.Backend) {
        vulkan: VulkanHeap,
        metal: MetalHeap,
    };

    const State = struct {
        allocator: std.mem.Allocator,
        backend: core.Backend,
        tracker: *ResourceTracker,
        label_value: ?[]const u8 = null,
        descriptor_value: core.HeapDescriptor,
        features_value: core.DeviceFeatures,
        limits_value: core.DeviceLimits,
        reserved_bytes: u64 = 0,
        live_resource_count: usize = 0,
        alive: bool = true,
        impl: ?Impl = null,
    };

    fn init(state_value: *State) Heap {
        return .{ ._state = state_value };
    }

    fn state(self: *const Heap) *State {
        return @ptrCast(@alignCast(self._state));
    }

    pub fn deinit(self: *Heap) void {
        const state_value = self.state();
        assertObjectAlive(state_value.alive, "heap");
        std.debug.assert(state_value.live_resource_count == 0);
        state_value.alive = false;
        if (state_value.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        };
        state_value.tracker.release(.heap);
        state_value.allocator.destroy(state_value);
    }

    pub fn selectedBackend(self: Heap) core.Backend {
        return self.state().backend;
    }

    pub fn label(self: Heap) ?[]const u8 {
        return self.state().label_value;
    }

    pub fn setLabel(self: *Heap, label_value: ?[]const u8) void {
        assertObjectAlive(self.state().alive, "heap");
        self.state().label_value = label_value;
    }

    pub fn descriptor(self: Heap) core.HeapDescriptor {
        return self.state().descriptor_value;
    }

    pub fn size(self: Heap) u64 {
        return self.state().descriptor_value.size;
    }

    pub fn storageMode(self: Heap) core.HeapStorageMode {
        return self.state().descriptor_value.storage_mode;
    }

    pub fn reservedBytes(self: Heap) u64 {
        return self.state().reserved_bytes;
    }

    pub fn remainingBytes(self: Heap) u64 {
        return self.size() - self.state().reserved_bytes;
    }

    pub fn reserve(self: *Heap, allocation: core.HeapAllocationDescriptor) core.HeapError!core.HeapAllocationInfo {
        assertObjectAlive(self.state().alive, "heap");
        try allocation.validate(self.state().descriptor_value);
        const offset = alignForwardU64(self.state().reserved_bytes, allocation.alignment) catch return core.HeapError.HeapOutOfMemory;
        const end = std.math.add(u64, offset, allocation.size) catch return core.HeapError.HeapOutOfMemory;
        if (end > self.size()) return core.HeapError.HeapOutOfMemory;
        self.state().reserved_bytes = end;
        return .{
            .offset = offset,
            .size = allocation.size,
            .alignment = allocation.alignment,
        };
    }

    pub fn bufferAllocationRequirements(
        self: Heap,
        buffer_descriptor: core.BufferDescriptor,
    ) !core.HeapAllocationDescriptor {
        const state_value = self.state();
        assertObjectAlive(state_value.alive, "heap");
        _ = try buffer_descriptor.validateForDevice(state_value.features_value, state_value.limits_value);
        try validateHeapBufferCompatibility(state_value.descriptor_value, buffer_descriptor);
        const impl = state_value.impl orelse return core.HeapError.UnsupportedHeaps;
        return switch (impl) {
            .vulkan => |vulkan| try vulkan.bufferAllocationRequirements(buffer_descriptor),
            .metal => |metal| try metal.bufferAllocationRequirements(buffer_descriptor),
        };
    }

    pub fn textureAllocationRequirements(
        self: Heap,
        texture_descriptor: core.TextureDescriptor,
    ) !core.HeapAllocationDescriptor {
        const state_value = self.state();
        assertObjectAlive(state_value.alive, "heap");
        try texture_descriptor.validateForLimits(state_value.limits_value);
        try validateHeapTextureCompatibility(state_value.descriptor_value, texture_descriptor);
        const impl = state_value.impl orelse return core.HeapError.UnsupportedHeaps;
        const capabilities = switch (impl) {
            .vulkan => |vulkan| vulkan.gc.formatCapabilities(texture_descriptor.format),
            .metal => |metal| metal.formatCapabilities(texture_descriptor.format),
        };
        if (!capabilities.supportsTextureDescriptor(texture_descriptor)) {
            return core.TextureError.UnsupportedTextureUsage;
        }
        return switch (impl) {
            .vulkan => |vulkan| try vulkan.textureAllocationRequirements(texture_descriptor),
            .metal => |metal| try metal.textureAllocationRequirements(texture_descriptor),
        };
    }

    pub fn makeBufferAt(
        self: *Heap,
        buffer_descriptor: core.BufferDescriptor,
        allocation: core.HeapAllocationInfo,
    ) !Buffer {
        const requirements = try self.bufferAllocationRequirements(buffer_descriptor);
        try self.validateAllocation(allocation, requirements);
        const state_value = self.state();
        const length = try buffer_descriptor.validateForDevice(state_value.features_value, state_value.limits_value);
        const heap_impl = state_value.impl orelse return core.HeapError.UnsupportedHeaps;
        const impl = switch (heap_impl) {
            .vulkan => |*vulkan| Buffer.Impl{ .vulkan = try vulkan.makeBuffer(buffer_descriptor, allocation) },
            .metal => |*metal| Buffer.Impl{ .metal = try metal.makeBuffer(buffer_descriptor, allocation) },
        };
        state_value.live_resource_count += 1;
        state_value.tracker.retain(.buffer);
        var buffer = Buffer.init(.{
            .backend = state_value.backend,
            .tracker = state_value.tracker,
            .label_value = buffer_descriptor.label,
            .native_labels_enabled = true,
            .length_value = length,
            .usage_value = buffer_descriptor.usage,
            .storage_mode_value = buffer_descriptor.storage_mode,
            .heap_owner = state_value,
            .impl = impl,
        });
        buffer.setLabel(buffer_descriptor.label);
        return buffer;
    }

    pub fn makeTextureAt(
        self: *Heap,
        texture_descriptor: core.TextureDescriptor,
        allocation: core.HeapAllocationInfo,
    ) !Texture {
        const requirements = try self.textureAllocationRequirements(texture_descriptor);
        try self.validateAllocation(allocation, requirements);
        const state_value = self.state();
        const subresource_usage_tracker = try SharedTextureUsageTracker.init(state_value.allocator, texture_descriptor);
        errdefer subresource_usage_tracker.release();
        const heap_impl = state_value.impl orelse return core.HeapError.UnsupportedHeaps;
        const impl = switch (heap_impl) {
            .vulkan => |*vulkan| Texture.Impl{ .vulkan = try vulkan.makeTexture(texture_descriptor, allocation) },
            .metal => |*metal| Texture.Impl{ .metal = try metal.makeTexture(texture_descriptor, allocation) },
        };
        state_value.live_resource_count += 1;
        state_value.tracker.retain(.texture);
        var texture = Texture.init(.{
            .backend = state_value.backend,
            .tracker = state_value.tracker,
            .label_value = texture_descriptor.label,
            .native_labels_enabled = true,
            .dimension_value = texture_descriptor.dimension,
            .format_value = texture_descriptor.format,
            .usage_value = texture_descriptor.usage,
            .storage_mode_value = texture_descriptor.storage_mode,
            .sample_count_value = texture_descriptor.sample_count,
            .subresource_usage_tracker = subresource_usage_tracker,
            .heap_owner = state_value,
            .impl = impl,
        });
        texture.setLabel(texture_descriptor.label);
        return texture;
    }

    pub fn liveResourceCount(self: Heap) usize {
        assertObjectAlive(self.state().alive, "heap");
        return self.state().live_resource_count;
    }

    fn validateAllocation(
        self: Heap,
        allocation: core.HeapAllocationInfo,
        requirements: core.HeapAllocationDescriptor,
    ) core.HeapError!void {
        try allocation.validateWithin(self.state().descriptor_value);
        const end = try allocation.end();
        if (end > self.state().reserved_bytes) return core.HeapError.HeapAllocationNotReserved;
        if (allocation.size < requirements.size or allocation.offset % requirements.alignment != 0) {
            return core.HeapError.HeapAllocationTooSmall;
        }
    }

    pub fn aliasingPlan(self: Heap, aliasing_descriptor: core.HeapAliasingDescriptor) core.HeapError!core.HeapAliasingPlan {
        assertObjectAlive(self.state().alive, "heap");
        return try aliasing_descriptor.plan(self.state().descriptor_value);
    }
};

fn validateHeapBufferCompatibility(
    heap: core.HeapDescriptor,
    descriptor: core.BufferDescriptor,
) core.HeapError!void {
    switch (heap.storage_mode) {
        .automatic, .device_local => if (descriptor.storage_mode != .private) {
            return core.HeapError.HeapResourceIncompatible;
        },
        .cpu_visible => if (descriptor.storage_mode != .automatic and descriptor.storage_mode != .shared) {
            return core.HeapError.HeapResourceIncompatible;
        },
    }
}

fn validateHeapTextureCompatibility(
    heap: core.HeapDescriptor,
    descriptor: core.TextureDescriptor,
) core.HeapError!void {
    if (heap.storage_mode == .cpu_visible or descriptor.storage_mode != .private) {
        return core.HeapError.HeapResourceIncompatible;
    }
}

const BackendPrivateAccelerationStructureHandle = struct {
    backend: core.Backend,
    kind: core.AccelerationStructureKind,
    result_size: u64,
    scratch_alignment: u64,
    driver_bound: bool = false,

    fn fromDescriptor(
        backend: core.Backend,
        descriptor: core.AccelerationStructureDescriptor,
        sizes: core.AccelerationStructureBuildSizes,
    ) BackendPrivateAccelerationStructureHandle {
        return .{
            .backend = backend,
            .kind = descriptor.kind,
            .result_size = sizes.result_size,
            .scratch_alignment = 256,
        };
    }

    fn matchesPlan(self: BackendPrivateAccelerationStructureHandle, plan: core.AccelerationStructureBuildPlan) bool {
        return self.backend == plan.backend and
            self.kind == plan.kind and
            self.result_size >= plan.result_size and
            self.scratch_alignment <= plan.scratch_alignment;
    }
};

const BackendPrivateAccelerationStructureBuildRecord = struct {
    backend: core.Backend,
    mode: core.AccelerationStructureBuildMode,
    scratch_offset: u64,
    scratch_size: u64,
    update_source_used: bool,
    command_recorded: bool,
    driver_submitted: bool = false,
};

const BackendPrivateAccelerationStructureMaintenanceRecord = struct {
    backend: core.Backend,
    operation: core.AccelerationStructureMaintenanceOperation,
    scratch_offset: u64,
    scratch_size: u64,
    destination_used: bool,
    command_recorded: bool,
    driver_submitted: bool = false,
};

pub const AccelerationStructure = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const Impl = union(core.Backend) {
        vulkan: VulkanAccelerationStructure,
        metal: MetalAccelerationStructure,
    };

    const State = struct {
        backend: core.Backend,
        tracker: *ResourceTracker,
        label_value: ?[]const u8 = null,
        descriptor_value: core.AccelerationStructureDescriptor,
        sizes_value: core.AccelerationStructureBuildSizes,
        native_handle: BackendPrivateAccelerationStructureHandle,
        last_build_record: ?BackendPrivateAccelerationStructureBuildRecord = null,
        last_maintenance_record: ?BackendPrivateAccelerationStructureMaintenanceRecord = null,
        build_count: u64 = 0,
        maintenance_count: u64 = 0,
        built_value: bool = false,
        update_capable_value: bool = false,
        compaction_capable_value: bool = false,
        alive: bool = true,
        impl: ?Impl = null,
    };

    fn init(state_value: State) AccelerationStructure {
        var result: AccelerationStructure = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const AccelerationStructure) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn deinit(self: *AccelerationStructure) void {
        assertAlive(self.state().alive, .acceleration_structure);
        self.state().alive = false;
        if (self.state().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        };
        self.state().tracker.release(.acceleration_structure);
    }

    pub fn selectedBackend(self: AccelerationStructure) core.Backend {
        return self.state().backend;
    }

    pub fn label(self: AccelerationStructure) ?[]const u8 {
        return self.state().label_value;
    }

    pub fn setLabel(self: *AccelerationStructure, label_value: ?[]const u8) void {
        assertAlive(self.state().alive, .acceleration_structure);
        self.state().label_value = label_value;
        if (self.state().impl) |*impl| switch (impl.*) {
            .vulkan => {},
            .metal => |*metal| metal.setLabel(label_value),
        };
    }

    pub fn descriptor(self: AccelerationStructure) core.AccelerationStructureDescriptor {
        assertAlive(self.state().alive, .acceleration_structure);
        return self.state().descriptor_value;
    }

    pub fn buildSizes(self: AccelerationStructure) core.AccelerationStructureBuildSizes {
        assertAlive(self.state().alive, .acceleration_structure);
        return self.state().sizes_value;
    }

    pub fn resultSize(self: AccelerationStructure) u64 {
        return self.buildSizes().result_size;
    }

    pub fn scratchSize(self: AccelerationStructure) u64 {
        return self.buildSizes().scratch_size;
    }

    pub fn updateScratchSize(self: AccelerationStructure) u64 {
        return self.buildSizes().update_scratch_size;
    }

    pub fn isBuilt(self: AccelerationStructure) bool {
        assertAlive(self.state().alive, .acceleration_structure);
        return self.state().built_value;
    }

    pub fn hasBackendPrivateHandle(self: AccelerationStructure) bool {
        assertAlive(self.state().alive, .acceleration_structure);
        if (self.state().impl) |impl| switch (impl) {
            .vulkan => |vulkan| return vulkan.hasDriverHandle(),
            .metal => |metal| return metal.hasDriverHandle(),
        };
        return self.state().native_handle.matchesPlan(.{
            .backend = self.state().backend,
            .kind = self.state().descriptor_value.kind,
            .mode = .build,
            .primitive_count = self.state().descriptor_value.primitive_count,
            .geometry_count = 1,
            .result_size = self.state().sizes_value.result_size,
            .scratch_size = self.state().sizes_value.scratch_size,
            .scratch_alignment = self.state().native_handle.scratch_alignment,
        });
    }

    pub fn backendPrivateBuildCount(self: AccelerationStructure) u64 {
        assertAlive(self.state().alive, .acceleration_structure);
        return self.state().build_count;
    }

    pub fn lastBuildRecordedBackendCommand(self: AccelerationStructure) bool {
        assertAlive(self.state().alive, .acceleration_structure);
        return if (self.state().last_build_record) |record| record.command_recorded else false;
    }

    pub fn lastBuildSubmittedToDriver(self: AccelerationStructure) bool {
        assertAlive(self.state().alive, .acceleration_structure);
        return if (self.state().last_build_record) |record| record.driver_submitted else false;
    }

    pub fn backendPrivateMaintenanceCount(self: AccelerationStructure) u64 {
        assertAlive(self.state().alive, .acceleration_structure);
        return self.state().maintenance_count;
    }

    pub fn lastMaintenanceRecordedBackendCommand(self: AccelerationStructure) bool {
        assertAlive(self.state().alive, .acceleration_structure);
        return if (self.state().last_maintenance_record) |record| record.command_recorded else false;
    }

    pub fn lastMaintenanceSubmittedToDriver(self: AccelerationStructure) bool {
        assertAlive(self.state().alive, .acceleration_structure);
        return if (self.state().last_maintenance_record) |record| record.driver_submitted else false;
    }

    fn markBuilt(
        self: *AccelerationStructure,
        plan: core.AccelerationStructureBuildPlan,
        resources: AccelerationStructureBuildResources,
        command_recorded: bool,
        driver_submitted: bool,
    ) core.AdvancedFeatureError!void {
        assertAlive(self.state().alive, .acceleration_structure);
        if (!self.state().native_handle.matchesPlan(plan)) {
            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
        }
        self.state().built_value = true;
        self.state().update_capable_value = self.state().update_capable_value or plan.allow_update;
        self.state().compaction_capable_value = self.state().compaction_capable_value or plan.allow_compaction;
        self.state().build_count += 1;
        const required_scratch = if (plan.mode == .update and plan.update_scratch_size != 0) plan.update_scratch_size else plan.scratch_size;
        self.state().last_build_record = .{
            .backend = plan.backend,
            .mode = plan.mode,
            .scratch_offset = resources.scratch_offset,
            .scratch_size = required_scratch,
            .update_source_used = resources.update_source != null,
            .command_recorded = command_recorded,
            .driver_submitted = driver_submitted,
        };
    }

    fn markMaintained(
        self: *AccelerationStructure,
        plan: core.AccelerationStructureMaintenancePlan,
        resources: AccelerationStructureMaintenanceResources,
        command_recorded: bool,
        driver_submitted: bool,
    ) void {
        assertAlive(self.state().alive, .acceleration_structure);
        self.state().maintenance_count += 1;
        self.state().last_maintenance_record = .{
            .backend = plan.backend,
            .operation = plan.operation,
            .scratch_offset = resources.scratch_offset,
            .scratch_size = plan.scratch_size,
            .destination_used = resources.destination != null,
            .command_recorded = command_recorded,
            .driver_submitted = driver_submitted,
        };
        if (plan.operation == .compact) {
            const destination = resources.destination orelse unreachable;
            destination.state().built_value = true;
        }
    }
};

pub const AccelerationStructureGeometryResources = union(core.AccelerationStructureGeometryKind) {
    triangles: TriangleGeometryResources,
    aabbs: AabbGeometryResources,
    instances: void,

    pub const TriangleGeometryResources = struct {
        descriptor: core.AccelerationStructureGeometryDescriptor,
        vertex_buffer: *Buffer,
        index_buffer: ?*Buffer = null,
    };

    pub const AabbGeometryResources = struct {
        descriptor: core.AccelerationStructureGeometryDescriptor,
        buffer: *Buffer,
    };

    fn descriptor(self: AccelerationStructureGeometryResources) core.AccelerationStructureGeometryDescriptor {
        return switch (self) {
            .triangles => |triangles| triangles.descriptor,
            .aabbs => |aabbs| aabbs.descriptor,
            .instances => .{ .kind = .instances, .primitive_count = 1 },
        };
    }

    fn primitiveCount(self: AccelerationStructureGeometryResources) u32 {
        return self.descriptor().primitive_count;
    }

    fn validate(
        self: AccelerationStructureGeometryResources,
        backend: core.Backend,
    ) core.AdvancedFeatureError!void {
        const geometry_descriptor = self.descriptor();
        try geometry_descriptor.validate();
        switch (self) {
            .triangles => |triangles| {
                if (geometry_descriptor.kind != .triangles) return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
                try validateBuildInputBuffer(backend, triangles.vertex_buffer);
                const vertex_stride = geometry_descriptor.resolvedVertexStride();
                const vertex_count = geometry_descriptor.resolvedVertexCount();
                const vertex_bytes = @as(u64, vertex_stride) * @as(u64, vertex_count);
                try validateBuildInputRange(triangles.vertex_buffer, geometry_descriptor.vertex_buffer_offset, vertex_bytes);
                if (geometry_descriptor.index_type != .none) {
                    const index_buffer = triangles.index_buffer orelse return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
                    try validateBuildInputBuffer(backend, index_buffer);
                    const index_bytes = @as(u64, geometry_descriptor.index_type.byteSize()) *
                        @as(u64, geometry_descriptor.resolvedIndexCount());
                    try validateBuildInputRange(index_buffer, geometry_descriptor.index_buffer_offset, index_bytes);
                }
            },
            .aabbs => |aabbs| {
                if (geometry_descriptor.kind != .aabbs) return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
                try validateBuildInputBuffer(backend, aabbs.buffer);
                const bytes = @as(u64, geometry_descriptor.aabb_stride) * @as(u64, geometry_descriptor.primitive_count);
                try validateBuildInputRange(aabbs.buffer, geometry_descriptor.aabb_buffer_offset, bytes);
            },
            .instances => {},
        }
    }

    fn recordUsage(self: AccelerationStructureGeometryResources) void {
        switch (self) {
            .triangles => |triangles| {
                _ = triangles.vertex_buffer.recordUsage(.acceleration_structure_build_input);
                if (triangles.index_buffer) |index_buffer| {
                    _ = index_buffer.recordUsage(.acceleration_structure_build_input);
                }
            },
            .aabbs => |aabbs| {
                _ = aabbs.buffer.recordUsage(.acceleration_structure_build_input);
            },
            .instances => {},
        }
    }
};

pub const AccelerationStructureBuildResources = struct {
    result: *AccelerationStructure,
    scratch: *Buffer,
    update_source: ?*AccelerationStructure = null,
    instance_source: ?*AccelerationStructure = null,
    instance_sources: []const *AccelerationStructure = &.{},
    geometries: []const AccelerationStructureGeometryResources = &.{},
    scratch_offset: u64 = 0,

    pub fn validate(
        self: AccelerationStructureBuildResources,
        backend: core.Backend,
        plan: core.AccelerationStructureBuildPlan,
    ) core.AdvancedFeatureError!void {
        assertAlive(self.result.state().alive, .acceleration_structure);
        assertAlive(self.scratch.state().alive, .buffer);
        if (self.result.selectedBackend() != backend or self.scratch.selectedBackend() != backend) {
            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
        }
        if (plan.kind == .top_level) {
            if (self.instance_sources.len != 0) {
                if (self.instance_sources.len != plan.primitive_count) {
                    return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
                }
                for (self.instance_sources) |instance_source| {
                    try validateBottomLevelInstanceSource(backend, instance_source);
                }
            } else {
                const instance_source = self.instance_source orelse return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
                try validateBottomLevelInstanceSource(backend, instance_source);
            }
        } else if (self.geometries.len != 0) {
            if (self.geometries.len != plan.geometry_count) {
                return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
            }
            var primitive_count: u32 = 0;
            for (self.geometries) |geometry| {
                try geometry.validate(backend);
                primitive_count +|= geometry.primitiveCount();
            }
            if (primitive_count != plan.primitive_count) {
                return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
            }
        }
        if (!self.scratch.state().usage_value.acceleration_structure_scratch) {
            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
        }
        if (plan.scratch_alignment != 0 and self.scratch_offset % plan.scratch_alignment != 0) {
            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
        }
        const required_scratch = if (plan.mode == .update and plan.update_scratch_size != 0) plan.update_scratch_size else plan.scratch_size;
        const scratch_end = std.math.add(u64, self.scratch_offset, required_scratch) catch {
            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
        };
        if (scratch_end > @as(u64, @intCast(self.scratch.length()))) {
            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
        }
        if (self.result.state().descriptor_value.kind != plan.kind or
            self.result.state().descriptor_value.primitive_count != plan.primitive_count or
            self.result.resultSize() < plan.result_size)
        {
            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
        }
        if (plan.requiresUpdateSource()) {
            const source = self.update_source orelse return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
            assertAlive(source.state().alive, .acceleration_structure);
            if (source.selectedBackend() != backend or
                source.state().descriptor_value.kind != plan.kind or
                !source.isBuilt() or
                !source.state().update_capable_value)
            {
                return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
            }
        }
    }
};

pub const AccelerationStructureMaintenanceResources = struct {
    source: *AccelerationStructure,
    destination: ?*AccelerationStructure = null,
    scratch: ?*Buffer = null,
    scratch_offset: u64 = 0,

    pub fn validate(
        self: AccelerationStructureMaintenanceResources,
        backend: core.Backend,
        plan: core.AccelerationStructureMaintenancePlan,
    ) core.AdvancedFeatureError!void {
        assertAlive(self.source.state().alive, .acceleration_structure);
        if (plan.backend != backend or self.source.selectedBackend() != backend or !self.source.isBuilt()) {
            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
        }
        const source_descriptor = self.source.descriptor();
        if (source_descriptor.kind != plan.kind or
            source_descriptor.primitive_count != plan.primitive_count or
            self.source.resultSize() < plan.source_result_size)
        {
            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
        }
        if (plan.requires_allow_update and !self.source.state().update_capable_value) {
            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
        }
        if (plan.operation == .compact and !self.source.state().compaction_capable_value) {
            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
        }

        if (plan.operation == .compact) {
            const destination = self.destination orelse return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
            assertAlive(destination.state().alive, .acceleration_structure);
            if (destination == self.source or destination.selectedBackend() != backend) {
                return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
            }
            const destination_descriptor = destination.descriptor();
            if (destination_descriptor.kind != plan.kind or
                destination_descriptor.primitive_count != plan.primitive_count or
                destination.resultSize() < plan.compacted_size_upper_bound or
                self.scratch != null or self.scratch_offset != 0)
            {
                return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
            }
            return;
        }

        if (self.destination != null) return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
        const scratch = self.scratch orelse return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
        assertAlive(scratch.state().alive, .buffer);
        if (scratch.selectedBackend() != backend or !scratch.state().usage_value.acceleration_structure_scratch) {
            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
        }
        if (plan.scratch_alignment != 0 and self.scratch_offset % plan.scratch_alignment != 0) {
            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
        }
        const scratch_end = std.math.add(u64, self.scratch_offset, plan.scratch_size) catch {
            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
        };
        if (scratch_end > @as(u64, @intCast(scratch.length()))) {
            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
        }
    }
};

fn validateBottomLevelInstanceSource(
    backend: core.Backend,
    instance_source: *AccelerationStructure,
) core.AdvancedFeatureError!void {
    assertAlive(instance_source.state().alive, .acceleration_structure);
    if (instance_source.selectedBackend() != backend or
        instance_source.state().descriptor_value.kind != .bottom_level or
        !instance_source.isBuilt())
    {
        return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
    }
}

fn validateBuildInputBuffer(
    backend: core.Backend,
    buffer: *Buffer,
) core.AdvancedFeatureError!void {
    assertAlive(buffer.state().alive, .buffer);
    if (buffer.selectedBackend() != backend or !buffer.state().usage_value.acceleration_structure_build_input) {
        return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
    }
}

fn validateBuildInputRange(
    buffer: *Buffer,
    offset: u64,
    size: u64,
) core.AdvancedFeatureError!void {
    const end = std.math.add(u64, offset, size) catch {
        return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
    };
    if (end > @as(u64, @intCast(buffer.length()))) {
        return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
    }
}

const BackendPrivateRayTracingPipelineHandle = struct {
    backend: core.Backend,
    shader_group_count: u32,
    function_table_entries: u32,
    max_recursion_depth: u32,
    driver_bound: bool = false,

    fn fromLowering(
        backend: core.Backend,
        descriptor: core.RayTracingPipelineDescriptor,
        lowering: core.RayTracingPipelineLowering,
    ) BackendPrivateRayTracingPipelineHandle {
        return .{
            .backend = backend,
            .shader_group_count = @intCast(descriptor.shader_groups.len),
            .function_table_entries = lowering.functionTableEntryCount(),
            .max_recursion_depth = lowering.maxRecursionDepth(),
        };
    }
};

pub const RayTracingPipelineState = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const Impl = union(core.Backend) {
        vulkan: VulkanRayTracingPipelineState,
        metal: MetalRayTracingPipelineState,
    };

    const State = struct {
        backend: core.Backend,
        tracker: *ResourceTracker,
        allocator: std.mem.Allocator,
        label_value: ?[]const u8 = null,
        descriptor_value: core.RayTracingPipelineDescriptor,
        alive: bool = true,
        lowering: core.RayTracingPipelineLowering,
        native_handle: BackendPrivateRayTracingPipelineHandle,
        impl: ?Impl = null,
    };

    fn init(state_value: State) RayTracingPipelineState {
        var result: RayTracingPipelineState = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const RayTracingPipelineState) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn deinit(self: *RayTracingPipelineState) void {
        const state_value = self.state();
        assertAlive(state_value.alive, .ray_tracing_pipeline_state);
        state_value.alive = false;
        if (state_value.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        };
        state_value.allocator.free(state_value.descriptor_value.shader_groups);
        state_value.tracker.release(.ray_tracing_pipeline_state);
    }

    pub fn selectedBackend(self: RayTracingPipelineState) core.Backend {
        return self.state().backend;
    }

    pub fn label(self: RayTracingPipelineState) ?[]const u8 {
        return self.state().label_value;
    }

    pub fn setLabel(self: *RayTracingPipelineState, label_value: ?[]const u8) void {
        const state_value = self.state();
        assertAlive(state_value.alive, .ray_tracing_pipeline_state);
        state_value.label_value = label_value;
        if (state_value.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.setLabel(label_value),
            .metal => |*metal| metal.setLabel(label_value),
        };
    }

    pub fn descriptor(self: RayTracingPipelineState) core.RayTracingPipelineDescriptor {
        assertAlive(self.state().alive, .ray_tracing_pipeline_state);
        return self.state().descriptor_value;
    }

    fn lowering(self: RayTracingPipelineState) core.RayTracingPipelineLowering {
        assertAlive(self.state().alive, .ray_tracing_pipeline_state);
        return self.state().lowering;
    }

    pub fn maxRecursionDepth(self: RayTracingPipelineState) u32 {
        return self.lowering().maxRecursionDepth();
    }

    pub fn functionTableEntryCount(self: RayTracingPipelineState) u32 {
        return self.lowering().functionTableEntryCount();
    }

    pub fn hasBackendPrivatePipelineHandle(self: RayTracingPipelineState) bool {
        assertAlive(self.state().alive, .ray_tracing_pipeline_state);
        const state_value = self.state();
        if (state_value.impl) |impl| switch (impl) {
            .vulkan => {},
            .metal => |metal| return metal.hasDriverHandle(),
        };
        return state_value.native_handle.backend == state_value.backend and
            state_value.native_handle.shader_group_count == state_value.descriptor_value.shader_groups.len and
            state_value.native_handle.function_table_entries == self.functionTableEntryCount() and
            state_value.native_handle.max_recursion_depth == self.maxRecursionDepth();
    }

    pub fn backendPrivateShaderGroupCount(self: RayTracingPipelineState) u32 {
        assertAlive(self.state().alive, .ray_tracing_pipeline_state);
        return self.state().native_handle.shader_group_count;
    }

    pub fn backendPrivatePipelineBoundToDriver(self: RayTracingPipelineState) bool {
        assertAlive(self.state().alive, .ray_tracing_pipeline_state);
        return self.state().native_handle.driver_bound;
    }

    fn vulkanImpl(self: *RayTracingPipelineState) ?*VulkanRayTracingPipelineState {
        if (self.state().impl) |*impl| return switch (impl.*) {
            .vulkan => |*vulkan| vulkan,
            .metal => null,
        };
        return null;
    }

    fn metalImpl(self: *RayTracingPipelineState) ?*MetalRayTracingPipelineState {
        if (self.state().impl) |*impl| return switch (impl.*) {
            .vulkan => null,
            .metal => |*metal| metal,
        };
        return null;
    }
};

const BackendPrivateShaderBindingTableRecords = struct {
    backend: core.Backend,
    stride: u64,
    total_size: u64,
    record_count: u32,
    device_address_required: bool,
    driver_bound: bool = false,

    fn fromLayout(
        backend: core.Backend,
        descriptor: core.ShaderBindingTableDescriptor,
        layout: core.ShaderBindingTableLayout,
    ) BackendPrivateShaderBindingTableRecords {
        return .{
            .backend = backend,
            .stride = descriptor.stride,
            .total_size = layout.total_size,
            .record_count = descriptor.ray_generation_count +
                descriptor.miss_count +
                descriptor.hit_count +
                descriptor.callable_count,
            .device_address_required = backend == .vulkan,
        };
    }
};

const BackendPrivateRayDispatchRecord = struct {
    backend: core.Backend,
    width: u32,
    height: u32,
    depth: u32,
    total_rays: u64,
    sbt_size: u64,
    command_recorded: bool,
    driver_submitted: bool = false,
};

pub const ShaderBindingTable = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const State = struct {
        backend: core.Backend,
        tracker: *ResourceTracker,
        label_value: ?[]const u8 = null,
        descriptor_value: core.ShaderBindingTableDescriptor,
        layout_value: core.ShaderBindingTableLayout,
        limits_value: core.DeviceLimits,
        native_records: BackendPrivateShaderBindingTableRecords,
        last_dispatch_record: ?BackendPrivateRayDispatchRecord = null,
        dispatch_count: u64 = 0,
        alive: bool = true,
    };

    fn init(state_value: State) ShaderBindingTable {
        var result: ShaderBindingTable = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const ShaderBindingTable) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn deinit(self: *ShaderBindingTable) void {
        assertAlive(self.state().alive, .shader_binding_table);
        self.state().alive = false;
        self.state().tracker.release(.shader_binding_table);
    }

    pub fn selectedBackend(self: ShaderBindingTable) core.Backend {
        return self.state().backend;
    }

    pub fn label(self: ShaderBindingTable) ?[]const u8 {
        return self.state().label_value;
    }

    pub fn setLabel(self: *ShaderBindingTable, label_value: ?[]const u8) void {
        assertAlive(self.state().alive, .shader_binding_table);
        self.state().label_value = label_value;
    }

    pub fn descriptor(self: ShaderBindingTable) core.ShaderBindingTableDescriptor {
        assertAlive(self.state().alive, .shader_binding_table);
        return self.state().descriptor_value;
    }

    pub fn layout(self: ShaderBindingTable) core.ShaderBindingTableLayout {
        assertAlive(self.state().alive, .shader_binding_table);
        return self.state().layout_value;
    }

    pub fn size(self: ShaderBindingTable) u64 {
        return self.layout().total_size;
    }

    pub fn dispatchCount(self: ShaderBindingTable) u64 {
        assertAlive(self.state().alive, .shader_binding_table);
        return self.state().dispatch_count;
    }

    pub fn hasBackendPrivateRecords(self: ShaderBindingTable) bool {
        assertAlive(self.state().alive, .shader_binding_table);
        return self.state().native_records.backend == self.state().backend and
            self.state().native_records.stride == self.state().descriptor_value.stride and
            self.state().native_records.total_size == self.state().layout_value.total_size;
    }

    pub fn backendPrivateRecordCount(self: ShaderBindingTable) u32 {
        assertAlive(self.state().alive, .shader_binding_table);
        return self.state().native_records.record_count;
    }

    pub fn backendPrivateRecordsBoundToDriver(self: ShaderBindingTable) bool {
        assertAlive(self.state().alive, .shader_binding_table);
        return self.state().native_records.driver_bound;
    }

    pub fn lastDispatchRecordedBackendCommand(self: ShaderBindingTable) bool {
        assertAlive(self.state().alive, .shader_binding_table);
        return if (self.state().last_dispatch_record) |record| record.command_recorded else false;
    }

    pub fn lastDispatchSubmittedToDriver(self: ShaderBindingTable) bool {
        assertAlive(self.state().alive, .shader_binding_table);
        return if (self.state().last_dispatch_record) |record| record.driver_submitted else false;
    }

    fn validateForPipeline(
        self: ShaderBindingTable,
        pipeline: RayTracingPipelineState,
    ) core.AdvancedFeatureError!void {
        const lowering = pipeline.lowering();
        const sbt_descriptor = self.state().descriptor_value;
        if (sbt_descriptor.ray_generation_count < lowering.rayGenerationGroupCount() or
            sbt_descriptor.miss_count < lowering.missGroupCount() or
            sbt_descriptor.hit_count < lowering.hitGroupCount() or
            sbt_descriptor.callable_count < lowering.callableGroupCount())
        {
            return core.AdvancedFeatureError.InvalidShaderBindingTable;
        }
    }

    fn dispatchPlan(
        self: ShaderBindingTable,
        pipeline: RayTracingPipelineState,
        dispatch_descriptor: core.RayDispatchDescriptor,
    ) core.AdvancedFeatureError!core.RayDispatchPlan {
        try self.validateForPipeline(pipeline);
        return try core.RayDispatchPlan.fromDescriptors(
            self.state().descriptor_value,
            dispatch_descriptor,
            .{ .ray_tracing = true },
            self.state().limits_value,
        );
    }

    fn recordDispatch(
        self: *ShaderBindingTable,
        plan: core.RayDispatchPlan,
        command_recorded: bool,
        driver_submitted: bool,
    ) void {
        self.state().dispatch_count += 1;
        self.state().last_dispatch_record = .{
            .backend = self.state().backend,
            .width = plan.width,
            .height = plan.height,
            .depth = plan.depth,
            .total_rays = plan.total_rays,
            .sbt_size = plan.sbt_size,
            .command_recorded = command_recorded,
            .driver_submitted = driver_submitted,
        };
        if (driver_submitted) self.state().native_records.driver_bound = true;
    }
};

pub const RayTracingDrawableResources = struct {
    acceleration_structure: *AccelerationStructure,
    output: *TextureView,

    fn validate(
        self: RayTracingDrawableResources,
        backend: core.Backend,
    ) core.AdvancedFeatureError!void {
        assertAlive(self.acceleration_structure.state().alive, .acceleration_structure);
        assertAlive(self.output.state().alive, .texture_view);
        if (self.acceleration_structure.selectedBackend() != backend or self.output.selectedBackend() != backend) {
            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
        }
        const valid_kind = switch (backend) {
            .vulkan => self.acceleration_structure.state().descriptor_value.kind == .top_level,
            .metal => self.acceleration_structure.state().descriptor_value.kind == .bottom_level or
                self.acceleration_structure.state().descriptor_value.kind == .top_level,
        };
        if (!valid_kind or !self.acceleration_structure.isBuilt()) {
            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
        }
    }
};

const BackendPrivateMetalRayTracingTables = struct {
    function_table_entries: u32,
    intersection_function_count: u32,
    acceleration_structure_slots: u32,
    function_table_populated: bool,
    intersection_table_populated: bool,
    driver_bound: bool = false,

    fn fromPlan(plan: core.MetalRayTracingMappingPlan) BackendPrivateMetalRayTracingTables {
        return .{
            .function_table_entries = plan.function_table_entries,
            .intersection_function_count = plan.intersection_function_count,
            .acceleration_structure_slots = if (plan.requires_acceleration_structure_resources) 1 else 0,
            .function_table_populated = plan.requires_function_table,
            .intersection_table_populated = plan.requires_intersection_function_table,
        };
    }
};

pub const MetalRayTracingExecutionMapping = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const State = struct {
        backend: core.Backend = .metal,
        tracker: *ResourceTracker,
        allocator: std.mem.Allocator,
        label_value: ?[]const u8 = null,
        descriptor_value: core.MetalRayTracingMappingDescriptor,
        plan_value: core.MetalRayTracingMappingPlan,
        native_tables: BackendPrivateMetalRayTracingTables,
        alive: bool = true,
    };

    fn init(state_value: State) MetalRayTracingExecutionMapping {
        var result: MetalRayTracingExecutionMapping = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const MetalRayTracingExecutionMapping) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn deinit(self: *MetalRayTracingExecutionMapping) void {
        assertAlive(self.state().alive, .metal_ray_tracing_execution_mapping);
        self.state().alive = false;
        self.state().allocator.free(self.state().descriptor_value.pipeline.shader_groups);
        self.state().allocator.free(self.state().descriptor_value.intersections);
        self.state().tracker.release(.metal_ray_tracing_execution_mapping);
    }

    pub fn selectedBackend(self: MetalRayTracingExecutionMapping) core.Backend {
        return self.state().backend;
    }

    pub fn label(self: MetalRayTracingExecutionMapping) ?[]const u8 {
        return self.state().label_value;
    }

    pub fn descriptor(self: MetalRayTracingExecutionMapping) core.MetalRayTracingMappingDescriptor {
        assertAlive(self.state().alive, .metal_ray_tracing_execution_mapping);
        return self.state().descriptor_value;
    }

    pub fn plan(self: MetalRayTracingExecutionMapping) core.MetalRayTracingMappingPlan {
        assertAlive(self.state().alive, .metal_ray_tracing_execution_mapping);
        return self.state().plan_value;
    }

    pub fn functionTableEntryCount(self: MetalRayTracingExecutionMapping) u32 {
        return self.plan().function_table_entries;
    }

    pub fn intersectionFunctionCount(self: MetalRayTracingExecutionMapping) u32 {
        return self.plan().intersection_function_count;
    }

    pub fn requiresIntersectionFunctionTable(self: MetalRayTracingExecutionMapping) bool {
        return self.plan().requires_intersection_function_table;
    }

    pub fn hasBackendPrivateFunctionTables(self: MetalRayTracingExecutionMapping) bool {
        assertAlive(self.state().alive, .metal_ray_tracing_execution_mapping);
        return self.state().native_tables.driver_bound and
            self.state().native_tables.function_table_populated and
            (!self.requiresIntersectionFunctionTable() or self.state().native_tables.intersection_table_populated) and
            self.state().native_tables.function_table_entries == self.functionTableEntryCount() and
            self.state().native_tables.intersection_function_count == self.intersectionFunctionCount();
    }

    pub fn backendPrivateAccelerationStructureSlots(self: MetalRayTracingExecutionMapping) u32 {
        assertAlive(self.state().alive, .metal_ray_tracing_execution_mapping);
        return self.state().native_tables.acceleration_structure_slots;
    }

    pub fn backendPrivateMetalTablesBoundToDriver(self: MetalRayTracingExecutionMapping) bool {
        assertAlive(self.state().alive, .metal_ray_tracing_execution_mapping);
        return self.state().native_tables.driver_bound;
    }
};

fn alignForwardU64(value: u64, alignment: u64) !u64 {
    if (alignment == 0) return error.InvalidAlignment;
    const remainder = value % alignment;
    if (remainder == 0) return value;
    return try std.math.add(u64, value, alignment - remainder);
}

pub const QuerySet = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const Impl = union(core.Backend) {
        vulkan: VulkanQuerySet,
        metal: MetalQuerySet,
    };

    const State = struct {
        backend: core.Backend,
        tracker: *ResourceTracker,
        allocator: std.mem.Allocator,
        label_value: ?[]const u8 = null,
        descriptor_value: core.QuerySetDescriptor,
        result_source_value: core.TimestampQuerySource = .unavailable,
        values: []u64,
        available: []bool,
        active_occlusion_query: ?u32 = null,
        active_occlusion_encoder: ?*const anyopaque = null,
        pending_command_borrows: usize = 0,
        timestamp_counter: u64 = 1,
        alive: bool = true,
        impl: ?Impl = null,
    };

    fn init(state_value: State) QuerySet {
        var result: QuerySet = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const QuerySet) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn deinit(self: *QuerySet) void {
        assertObjectAlive(self.state().alive, "query_set");
        std.debug.assert(self.state().active_occlusion_query == null);
        if (self.hasPendingNativeWork()) {
            if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) @panic("vkmtl query_set deinit before command buffer completion");
            return;
        }
        if (self.state().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        };
        self.state().alive = false;
        self.state().allocator.free(self.state().values);
        self.state().allocator.free(self.state().available);
        self.state().tracker.release(.query_set);
    }

    pub fn selectedBackend(self: QuerySet) core.Backend {
        return self.state().backend;
    }

    pub fn label(self: QuerySet) ?[]const u8 {
        return self.state().label_value;
    }

    pub fn setLabel(self: *QuerySet, label_value: ?[]const u8) void {
        assertObjectAlive(self.state().alive, "query_set");
        self.state().label_value = label_value;
        if (self.state().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.setLabel(label_value),
            .metal => |*metal| metal.setLabel(label_value),
        };
    }

    pub fn descriptor(self: QuerySet) core.QuerySetDescriptor {
        assertObjectAlive(self.state().alive, "query_set");
        return self.state().descriptor_value;
    }

    pub fn resultSource(self: QuerySet) core.TimestampQuerySource {
        assertObjectAlive(self.state().alive, "query_set");
        return self.state().result_source_value;
    }

    pub fn reset(self: *QuerySet) void {
        assertObjectAlive(self.state().alive, "query_set");
        std.debug.assert(self.state().active_occlusion_query == null);
        if (self.hasPendingNativeWork()) {
            if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) @panic("vkmtl query_set reset before command buffer completion");
            return;
        }
        if (self.state().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.reset(),
            .metal => |*metal| metal.reset(),
        };
        @memset(self.state().values, 0);
        @memset(self.state().available, false);
        self.state().active_occlusion_query = null;
        self.state().active_occlusion_encoder = null;
        self.state().timestamp_counter = 1;
    }

    pub fn beginOcclusionQuery(self: *QuerySet, query_index: u32) core.QueryError!void {
        assertObjectAlive(self.state().alive, "query_set");
        if (self.state().impl != null) return core.QueryError.QueryNotReady;
        try self.prepareBeginOcclusionQuery(query_index);
        self.markBeginOcclusionQuery(query_index, null);
    }

    fn prepareBeginOcclusionQuery(self: *QuerySet, query_index: u32) core.QueryError!void {
        assertObjectAlive(self.state().alive, "query_set");
        try self.validateQueryType(.occlusion);
        try self.validateQueryIndex(query_index);
        if (self.state().active_occlusion_query != null) return core.QueryError.QueryNotReady;
        if (self.state().available[query_index]) return core.QueryError.QueryNotReady;
    }

    fn markBeginOcclusionQuery(
        self: *QuerySet,
        query_index: u32,
        encoder_identity: ?*const anyopaque,
    ) void {
        self.state().active_occlusion_query = query_index;
        self.state().active_occlusion_encoder = encoder_identity;
    }

    pub fn endOcclusionQuery(self: *QuerySet) core.QueryError!void {
        assertObjectAlive(self.state().alive, "query_set");
        if (self.state().impl != null) return core.QueryError.QueryNotReady;
        const query_index = try self.prepareEndOcclusionQuery();
        self.markEndOcclusionQuery(query_index);
    }

    fn prepareEndOcclusionQuery(self: *QuerySet) core.QueryError!u32 {
        assertObjectAlive(self.state().alive, "query_set");
        try self.validateQueryType(.occlusion);
        return self.state().active_occlusion_query orelse return core.QueryError.QueryNotReady;
    }

    fn markEndOcclusionQuery(self: *QuerySet, query_index: u32) void {
        if (self.state().impl == null) self.state().values[query_index] = 1;
        self.state().available[query_index] = true;
        self.state().active_occlusion_query = null;
        self.state().active_occlusion_encoder = null;
    }

    pub fn writeTimestamp(self: *QuerySet, query_index: u32) core.QueryError!void {
        assertObjectAlive(self.state().alive, "query_set");
        if (self.state().impl != null) return core.QueryError.QueryNotReady;
        try self.prepareTimestamp(query_index);
        self.markTimestamp(query_index);
    }

    fn prepareTimestamp(self: *QuerySet, query_index: u32) core.QueryError!void {
        assertObjectAlive(self.state().alive, "query_set");
        try self.validateQueryType(.timestamp);
        try self.validateQueryIndex(query_index);
        if (self.state().available[query_index]) return core.QueryError.QueryNotReady;
    }

    fn markTimestamp(self: *QuerySet, query_index: u32) void {
        if (self.state().impl == null) {
            self.state().values[query_index] = self.state().timestamp_counter;
            self.state().timestamp_counter += 1;
        }
        self.state().available[query_index] = true;
    }

    pub fn readback(self: *QuerySet, readback_descriptor: core.QueryReadbackDescriptor) core.QueryError!void {
        assertObjectAlive(self.state().alive, "query_set");
        try readback_descriptor.validate(self.state().descriptor_value);
        const first: usize = @intCast(readback_descriptor.first_query);
        const count: usize = @intCast(readback_descriptor.query_count);
        try self.requireAvailable(first, count);
        if (self.state().impl) |*impl| return switch (impl.*) {
            .vulkan => |*vulkan| vulkan.readback(
                readback_descriptor.first_query,
                readback_descriptor.query_count,
                readback_descriptor.destination[0..count],
            ),
            .metal => |*metal| metal.readback(
                readback_descriptor.first_query,
                readback_descriptor.query_count,
                readback_descriptor.destination[0..count],
            ),
        };
        @memcpy(readback_descriptor.destination[0..count], self.state().values[first..][0..count]);
    }

    fn validateQueryType(self: QuerySet, expected: core.QueryType) core.QueryError!void {
        if (self.state().descriptor_value.query_type != expected) return core.QueryError.QueryTypeMismatch;
    }

    fn validateQueryIndex(self: QuerySet, query_index: u32) core.QueryError!void {
        if (query_index >= self.state().descriptor_value.count) return core.QueryError.InvalidQueryRange;
    }

    fn requireAvailable(self: QuerySet, first: usize, count: usize) core.QueryError!void {
        for (self.state().available[first..][0..count]) |available| {
            if (!available) return core.QueryError.QueryNotReady;
        }
    }

    fn hasPendingNativeWork(self: *QuerySet) bool {
        if (self.state().pending_command_borrows != 0) return true;
        if (self.state().impl == null) return false;
        var scratch = [_]u64{0};
        for (self.state().available, 0..) |available, index| {
            if (!available) continue;
            const result = if (self.state().impl) |*impl| switch (impl.*) {
                .vulkan => |*vulkan| vulkan.readback(@intCast(index), 1, scratch[0..]),
                .metal => |*metal| metal.readback(@intCast(index), 1, scratch[0..]),
            } else unreachable;
            result catch |err| {
                if (err == core.QueryError.QueryNotReady) return true;
            };
        }
        return false;
    }

    fn requireReadyForResolve(self: *QuerySet, first_query: u32, query_count: u32) core.QueryError!void {
        const first: usize = @intCast(first_query);
        const count: usize = @intCast(query_count);
        try self.requireAvailable(first, count);
        if (self.state().impl == null) return;

        const scratch = self.state().allocator.alloc(u64, count) catch return core.QueryError.QueryBackendFailure;
        defer self.state().allocator.free(scratch);
        try self.readback(.{
            .first_query = first_query,
            .query_count = query_count,
            .destination = scratch,
        });
    }
};

pub const ShaderModule = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const Impl = union(core.Backend) {
        vulkan: VulkanShaderModule,
        metal: MetalShaderModule,
    };

    const State = struct {
        backend: core.Backend,
        tracker: *ResourceTracker,
        label_value: ?[]const u8 = null,
        native_labels_enabled: bool = false,
        alive: bool = true,
        impl: Impl,
    };

    fn init(state_value: State) ShaderModule {
        var result: ShaderModule = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const ShaderModule) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn deinit(self: *ShaderModule) void {
        const state_value = self.state();
        assertAlive(state_value.alive, .shader_module);
        state_value.alive = false;
        switch (state_value.impl) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        }
        state_value.tracker.release(.shader_module);
    }

    pub fn selectedBackend(self: ShaderModule) core.Backend {
        return self.state().backend;
    }

    pub fn label(self: ShaderModule) ?[]const u8 {
        return self.state().label_value;
    }

    pub fn setLabel(self: *ShaderModule, label_value: ?[]const u8) void {
        const state_value = self.state();
        assertAlive(state_value.alive, .shader_module);
        state_value.label_value = label_value;
        if (!state_value.native_labels_enabled) return;
        switch (state_value.impl) {
            .vulkan => |*vulkan| vulkan.setLabel(label_value),
            .metal => |*metal| metal.setLabel(label_value),
        }
    }
};

pub const RenderPipelineState = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const Impl = union(core.Backend) {
        vulkan: VulkanRenderPipelineState,
        metal: MetalRenderPipelineState,
    };

    const Kind = enum {
        ordinary,
        tessellation,
        mesh,
    };

    const State = struct {
        backend: core.Backend,
        tracker: *ResourceTracker,
        allocator: ?std.mem.Allocator = null,
        label_value: ?[]const u8 = null,
        native_labels_enabled: bool = false,
        root_constant_ranges: []core.RootConstantRange = &.{},
        resource_table_layout_base: u32 = 0,
        resource_table_layout_hashes: []u64 = &.{},
        kind: Kind = .ordinary,
        tessellation: ?core.TessellationDescriptor = null,
        mesh_pipeline_hash: u64 = 0,
        mesh_limits: core.DeviceLimits = .{},
        alive: bool = true,
        impl: Impl,
    };

    fn init(state_value: State) RenderPipelineState {
        var result: RenderPipelineState = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const RenderPipelineState) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn deinit(self: *RenderPipelineState) void {
        const state_value = self.state();
        assertAlive(state_value.alive, .render_pipeline_state);
        state_value.alive = false;
        switch (state_value.impl) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        }
        if (state_value.allocator) |allocator| {
            allocator.free(state_value.root_constant_ranges);
            allocator.free(state_value.resource_table_layout_hashes);
        }
        state_value.tracker.release(.render_pipeline_state);
    }

    pub fn selectedBackend(self: RenderPipelineState) core.Backend {
        return self.state().backend;
    }

    pub fn label(self: RenderPipelineState) ?[]const u8 {
        return self.state().label_value;
    }

    pub fn rootConstantLayout(self: RenderPipelineState) ?core.RootConstantLayoutDescriptor {
        if (self.state().root_constant_ranges.len == 0) return null;
        return .{ .ranges = self.state().root_constant_ranges };
    }

    fn resourceTableLayoutBase(self: RenderPipelineState) u32 {
        return self.state().resource_table_layout_base;
    }

    fn resourceTableLayoutHashes(self: RenderPipelineState) []const u64 {
        return self.state().resource_table_layout_hashes;
    }

    fn kind(self: RenderPipelineState) Kind {
        return self.state().kind;
    }

    fn tessellationDescriptor(self: RenderPipelineState) ?core.TessellationDescriptor {
        return self.state().tessellation;
    }

    fn meshPipelineHash(self: RenderPipelineState) u64 {
        return self.state().mesh_pipeline_hash;
    }

    fn meshLimits(self: RenderPipelineState) core.DeviceLimits {
        return self.state().mesh_limits;
    }

    pub fn setLabel(self: *RenderPipelineState, label_value: ?[]const u8) void {
        const state_value = self.state();
        assertAlive(state_value.alive, .render_pipeline_state);
        state_value.label_value = label_value;
        if (!state_value.native_labels_enabled) return;
        switch (state_value.impl) {
            .vulkan => |*vulkan| vulkan.setLabel(label_value),
            .metal => |*metal| metal.setLabel(label_value),
        }
    }
};

pub const ComputePipelineState = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const Impl = union(core.Backend) {
        vulkan: VulkanComputePipelineState,
        metal: MetalComputePipelineState,
    };

    const State = struct {
        backend: core.Backend,
        tracker: *ResourceTracker,
        allocator: ?std.mem.Allocator = null,
        label_value: ?[]const u8 = null,
        native_labels_enabled: bool = false,
        root_constant_ranges: []core.RootConstantRange = &.{},
        resource_table_layout_base: u32 = 0,
        resource_table_layout_hashes: []u64 = &.{},
        alive: bool = true,
        impl: Impl,
    };

    fn init(state_value: State) ComputePipelineState {
        var result: ComputePipelineState = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const ComputePipelineState) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn deinit(self: *ComputePipelineState) void {
        const state_value = self.state();
        assertAlive(state_value.alive, .compute_pipeline_state);
        state_value.alive = false;
        switch (state_value.impl) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        }
        if (state_value.allocator) |allocator| {
            allocator.free(state_value.root_constant_ranges);
            allocator.free(state_value.resource_table_layout_hashes);
        }
        state_value.tracker.release(.compute_pipeline_state);
    }

    pub fn selectedBackend(self: ComputePipelineState) core.Backend {
        return self.state().backend;
    }

    pub fn label(self: ComputePipelineState) ?[]const u8 {
        return self.state().label_value;
    }

    pub fn rootConstantLayout(self: ComputePipelineState) ?core.RootConstantLayoutDescriptor {
        if (self.state().root_constant_ranges.len == 0) return null;
        return .{ .ranges = self.state().root_constant_ranges };
    }

    fn resourceTableLayoutBase(self: ComputePipelineState) u32 {
        return self.state().resource_table_layout_base;
    }

    fn resourceTableLayoutHashes(self: ComputePipelineState) []const u64 {
        return self.state().resource_table_layout_hashes;
    }

    pub fn setLabel(self: *ComputePipelineState, label_value: ?[]const u8) void {
        const state_value = self.state();
        assertAlive(state_value.alive, .compute_pipeline_state);
        state_value.label_value = label_value;
        if (!state_value.native_labels_enabled) return;
        switch (state_value.impl) {
            .vulkan => |*vulkan| vulkan.setLabel(label_value),
            .metal => |*metal| metal.setLabel(label_value),
        }
    }
};

pub const BindGroupLayout = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const Impl = union(core.Backend) {
        vulkan: VulkanBindGroupBackend.VulkanBindGroupLayout,
        metal: MetalBindGroupBackend.MetalBindGroupLayout,
    };

    const State = struct {
        backend: core.Backend,
        tracker: *ResourceTracker,
        allocator: std.mem.Allocator,
        label_value: ?[]const u8 = null,
        alive: bool = true,
        entries: []core.BindGroupLayoutEntry,
        impl: ?Impl = null,
    };

    fn init(state_value: State) BindGroupLayout {
        var result: BindGroupLayout = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const BindGroupLayout) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn deinit(self: *BindGroupLayout) void {
        const state_value = self.state();
        assertAlive(state_value.alive, .bind_group_layout);
        state_value.alive = false;
        if (state_value.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        };
        state_value.allocator.free(state_value.entries);
        state_value.tracker.release(.bind_group_layout);
    }

    pub fn selectedBackend(self: BindGroupLayout) core.Backend {
        return self.state().backend;
    }

    pub fn label(self: BindGroupLayout) ?[]const u8 {
        return self.state().label_value;
    }

    pub fn setLabel(self: *BindGroupLayout, label_value: ?[]const u8) void {
        assertAlive(self.state().alive, .bind_group_layout);
        self.state().label_value = label_value;
    }

    pub fn descriptor(self: BindGroupLayout) core.BindGroupLayoutDescriptor {
        assertAlive(self.state().alive, .bind_group_layout);
        return .{ .label = self.state().label_value, .entries = self.state().entries };
    }
};

pub const AdvancedBindGroupLayout = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const Impl = union(core.Backend) {
        vulkan: VulkanAdvancedBindGroupBackend,
        metal: MetalAdvancedBindGroupBackend,
    };

    const State = struct {
        backend: core.Backend,
        tracker: *ResourceTracker,
        allocator: std.mem.Allocator,
        label_value: ?[]const u8 = null,
        model_value: core.AdvancedBindingModel,
        ranges: []core.DescriptorIndexingRange,
        alive: bool = true,
        impl: ?Impl = null,
    };

    fn init(state_value: State) AdvancedBindGroupLayout {
        var result: AdvancedBindGroupLayout = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const AdvancedBindGroupLayout) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn deinit(self: *AdvancedBindGroupLayout) void {
        const state_value = self.state();
        assertObjectAlive(state_value.alive, "advanced_bind_group_layout");
        state_value.alive = false;
        if (state_value.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        };
        state_value.allocator.free(state_value.ranges);
        state_value.tracker.release(.advanced_bind_group_layout);
    }

    pub fn selectedBackend(self: AdvancedBindGroupLayout) core.Backend {
        return self.state().backend;
    }

    pub fn label(self: AdvancedBindGroupLayout) ?[]const u8 {
        return self.state().label_value;
    }

    pub fn model(self: AdvancedBindGroupLayout) core.AdvancedBindingModel {
        return self.state().model_value;
    }

    pub fn rangeCount(self: AdvancedBindGroupLayout) usize {
        return self.state().ranges.len;
    }

    pub fn range(self: AdvancedBindGroupLayout, index: usize) ?core.DescriptorIndexingRange {
        if (index >= self.state().ranges.len) return null;
        return self.state().ranges[index];
    }

    pub fn totalDescriptorCount(self: AdvancedBindGroupLayout) u32 {
        var count: u32 = 0;
        for (self.state().ranges) |descriptor_range| count +|= descriptor_range.descriptor_count;
        return count;
    }

    pub fn resourceDescriptorCount(
        self: AdvancedBindGroupLayout,
        resource: core.BindingResourceKind,
    ) u32 {
        var count: u32 = 0;
        for (self.state().ranges) |descriptor_range| {
            if (descriptor_range.resource == resource) count +|= descriptor_range.descriptor_count;
        }
        return count;
    }

    pub fn usesPartiallyBoundRanges(self: AdvancedBindGroupLayout) bool {
        for (self.state().ranges) |descriptor_range| {
            if (descriptor_range.partially_bound) return true;
        }
        return false;
    }

    pub fn usesUpdateAfterBindRanges(self: AdvancedBindGroupLayout) bool {
        for (self.state().ranges) |descriptor_range| {
            if (descriptor_range.update_after_bind) return true;
        }
        return false;
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
                assertAlive(binding.buffer.state().alive, .buffer);
                try expectSameBackend(expected_backend, binding.buffer.selectedBackend());
            },
            .storage_texture => |texture_view| {
                assertAlive(texture_view.state().alive, .texture_view);
                try expectSameBackend(expected_backend, texture_view.selectedBackend());
            },
            .sampled_texture => |texture_view| {
                assertAlive(texture_view.state().alive, .texture_view);
                try expectSameBackend(expected_backend, texture_view.selectedBackend());
            },
            .sampler, .compare_sampler => |sampler_state| {
                assertAlive(sampler_state.state().alive, .sampler_state);
                try expectSameBackend(expected_backend, sampler_state.selectedBackend());
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
    resources: []const BindGroupResource = &.{},

    fn resourceCount(self: BindGroupEntry) u32 {
        if (self.resources.len != 0) return @intCast(self.resources.len);
        return 1;
    }

    fn resourceAt(self: BindGroupEntry, index: usize) BindGroupResource {
        if (self.resources.len != 0) return self.resources[index];
        std.debug.assert(index == 0);
        return self.resource;
    }
};

pub const BindGroupDescriptor = struct {
    label: ?[]const u8 = null,
    layout: *BindGroupLayout,
    entries: []const BindGroupEntry = &.{},
};

pub const ResourceTableDescriptor = struct {
    label: ?[]const u8 = null,
    layout: *AdvancedBindGroupLayout,
    allow_partially_bound: bool = false,
    allow_update_after_bind: bool = false,
};

pub const ResourceTableUpdateDescriptor = struct {
    slot: core.ResourceTableSlot,
    resource: BindGroupResource,
};

pub const ResourceTable = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const Impl = union(core.Backend) {
        vulkan: VulkanAdvancedBindGroupBackend.ResourceTable,
        metal: MetalAdvancedBindGroupBackend.ResourceTable,
    };

    const State = struct {
        backend: core.Backend,
        tracker: *ResourceTracker,
        allocator: std.mem.Allocator,
        label_value: ?[]const u8 = null,
        alive: bool = true,
        model_value: core.AdvancedBindingModel,
        ranges: []core.DescriptorIndexingRange,
        slots: []?BindGroupResource,
        allow_update_after_bind: bool = false,
        bound_count: u64 = 0,
        impl: ?Impl = null,
    };

    fn init(state_value: State) ResourceTable {
        var result: ResourceTable = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const ResourceTable) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn deinit(self: *ResourceTable) void {
        const state_value = self.state();
        assertObjectAlive(state_value.alive, "resource_table");
        state_value.alive = false;
        if (state_value.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        };
        state_value.allocator.free(state_value.slots);
        state_value.allocator.free(state_value.ranges);
        state_value.tracker.release(.resource_table);
    }

    pub fn selectedBackend(self: ResourceTable) core.Backend {
        return self.state().backend;
    }

    pub fn label(self: ResourceTable) ?[]const u8 {
        return self.state().label_value;
    }

    pub fn model(self: ResourceTable) core.AdvancedBindingModel {
        return self.state().model_value;
    }

    pub fn slotCount(self: ResourceTable) usize {
        return self.state().slots.len;
    }

    pub fn visibility(self: ResourceTable) core.ShaderVisibility {
        var out = core.ShaderVisibility{};
        for (self.state().ranges) |range| {
            out.vertex = out.vertex or range.visibility.vertex;
            out.fragment = out.fragment or range.visibility.fragment;
            out.compute = out.compute or range.visibility.compute;
        }
        return out;
    }

    pub fn supportsRenderEncoding(self: ResourceTable) bool {
        const stages = self.visibility();
        return stages.vertex or stages.fragment;
    }

    pub fn supportsComputeEncoding(self: ResourceTable) bool {
        return self.visibility().compute;
    }

    fn layoutFingerprint(self: ResourceTable) u64 {
        return resourceTableLayoutFingerprint(.{
            .model = self.state().model_value,
            .ranges = self.state().ranges,
        });
    }

    pub fn update(self: *ResourceTable, descriptor: ResourceTableUpdateDescriptor) !void {
        assertObjectAlive(self.state().alive, "resource_table");
        const resolved = try self.resolveSlot(descriptor.slot);
        if (self.state().bound_count != 0 and (!self.state().allow_update_after_bind or !resolved.range.update_after_bind)) {
            return core.BindingError.ResourceTableUpdateAfterBindUnsupported;
        }
        if (descriptor.resource.resourceKind() != resolved.range.resource) {
            return core.BindingError.BindingResourceKindMismatch;
        }
        try validateResourceTableResource(descriptor.resource, self.state().backend);
        if (self.state().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.update(descriptor.slot, vulkanResourceForResourceTable(descriptor.resource)),
            .metal => |*metal| if (metal.handle != null) try metal.update(
                descriptor.slot,
                metalResourceForResourceTable(descriptor.resource),
            ),
        };
        self.state().slots[resolved.index] = descriptor.resource;
    }

    pub fn clear(self: *ResourceTable, slot: core.ResourceTableSlot) !void {
        assertObjectAlive(self.state().alive, "resource_table");
        const resolved = try self.resolveSlot(slot);
        if (self.state().bound_count != 0 and (!self.state().allow_update_after_bind or !resolved.range.update_after_bind)) {
            return core.BindingError.ResourceTableUpdateAfterBindUnsupported;
        }
        if (self.state().bound_count != 0 and self.state().backend == .vulkan) {
            return core.BindingError.ResourceTableUpdateAfterBindUnsupported;
        }
        if (self.state().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.clear(slot),
            .metal => |*metal| try metal.clear(slot),
        };
        self.state().slots[resolved.index] = null;
    }

    pub fn isSlotBound(self: ResourceTable, slot: core.ResourceTableSlot) !bool {
        assertObjectAlive(self.state().alive, "resource_table");
        const resolved = try self.resolveSlot(slot);
        return self.state().slots[resolved.index] != null;
    }

    pub fn validateReadyForBinding(self: ResourceTable) core.BindingError!void {
        assertObjectAlive(self.state().alive, "resource_table");
        var base: usize = 0;
        for (self.state().ranges) |range| {
            for (0..range.descriptor_count) |array_index| {
                if (self.state().slots[base + array_index] == null and !range.partially_bound) {
                    return core.BindingError.MissingResourceTableBinding;
                }
            }
            base += range.descriptor_count;
        }
    }

    pub fn markBoundForCommands(self: *ResourceTable) core.BindingError!void {
        try self.validateReadyForBinding();
        self.state().bound_count += 1;
    }

    const ResolvedSlot = struct {
        index: usize,
        range: core.DescriptorIndexingRange,
    };

    fn resolveSlot(self: ResourceTable, slot: core.ResourceTableSlot) core.BindingError!ResolvedSlot {
        var base: usize = 0;
        for (self.state().ranges) |range| {
            if (range.binding == slot.binding) {
                if (slot.array_element >= range.descriptor_count) return core.BindingError.InvalidResourceTableSlot;
                return .{
                    .index = base + slot.array_element,
                    .range = range,
                };
            }
            base += range.descriptor_count;
        }
        return core.BindingError.InvalidResourceTableSlot;
    }
};

const IndirectEncodedCommand = union(core.IndirectCommandKind) {
    render: core.DrawPrimitivesDescriptor,
    compute: core.DispatchThreadgroupsDescriptor,
};

pub const IndirectCommandBuffer = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const Impl = union(core.Backend) {
        vulkan: void,
        metal: MetalIndirectCommandBuffer,
    };

    const State = struct {
        backend: core.Backend,
        tracker: *ResourceTracker,
        allocator: std.mem.Allocator,
        label_value: ?[]const u8 = null,
        kind_value: core.IndirectCommandKind,
        limits_value: core.DeviceLimits,
        commands: []?IndirectEncodedCommand,
        alive: bool = true,
        impl: Impl,
    };

    fn init(state_value: State) IndirectCommandBuffer {
        var result: IndirectCommandBuffer = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const IndirectCommandBuffer) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn deinit(self: *IndirectCommandBuffer) void {
        const state_value = self.state();
        assertObjectAlive(state_value.alive, "indirect_command_buffer");
        state_value.alive = false;
        switch (state_value.impl) {
            .vulkan => {},
            .metal => |*metal_buffer| metal_buffer.deinit(),
        }
        state_value.allocator.free(state_value.commands);
        state_value.tracker.release(.indirect_command_buffer);
    }

    pub fn selectedBackend(self: IndirectCommandBuffer) core.Backend {
        return self.state().backend;
    }

    pub fn label(self: IndirectCommandBuffer) ?[]const u8 {
        return self.state().label_value;
    }

    pub fn setLabel(self: *IndirectCommandBuffer, label_value: ?[]const u8) void {
        assertObjectAlive(self.state().alive, "indirect_command_buffer");
        self.state().label_value = label_value;
        switch (self.state().impl) {
            .vulkan => {},
            .metal => |*metal_buffer| metal_buffer.setLabel(label_value),
        }
    }

    pub fn kind(self: IndirectCommandBuffer) core.IndirectCommandKind {
        return self.state().kind_value;
    }

    pub fn maxCommandCount(self: IndirectCommandBuffer) u32 {
        return @intCast(self.state().commands.len);
    }

    pub fn encodedCommandCount(self: IndirectCommandBuffer) u32 {
        var count: u32 = 0;
        for (self.state().commands) |command| if (command != null) {
            count += 1;
        };
        return count;
    }

    pub fn isCommandEncoded(self: IndirectCommandBuffer, command_index: u32) core.CommandEncodingError!bool {
        if (command_index >= self.state().commands.len) return core.CommandEncodingError.InvalidIndirectCommandRange;
        return self.state().commands[command_index] != null;
    }

    pub fn reset(self: *IndirectCommandBuffer, range: core.IndirectCommandRange) !void {
        assertObjectAlive(self.state().alive, "indirect_command_buffer");
        try range.validate(self.maxCommandCount());
        switch (self.state().impl) {
            .vulkan => {},
            .metal => |*metal_buffer| try metal_buffer.reset(range),
        }
        @memset(self.state().commands[range.location..][0..range.count], null);
    }

    pub fn encodeDrawPrimitives(
        self: *IndirectCommandBuffer,
        command_index: u32,
        descriptor: core.DrawPrimitivesDescriptor,
    ) !void {
        assertObjectAlive(self.state().alive, "indirect_command_buffer");
        if (self.kind() != .render) return core.CommandEncodingError.InvalidIndirectCommandKind;
        try self.validateCommandIndex(command_index);
        try descriptor.validate();
        switch (self.state().impl) {
            .vulkan => {},
            .metal => |*metal_buffer| try metal_buffer.encodeDraw(command_index, descriptor),
        }
        self.state().commands[command_index] = .{ .render = descriptor };
    }

    pub fn encodeDispatchThreadgroups(
        self: *IndirectCommandBuffer,
        command_index: u32,
        descriptor: core.DispatchThreadgroupsDescriptor,
    ) !void {
        assertObjectAlive(self.state().alive, "indirect_command_buffer");
        if (self.kind() != .compute) return core.CommandEncodingError.InvalidIndirectCommandKind;
        try self.validateCommandIndex(command_index);
        try descriptor.validateForLimits(self.state().limits_value);
        switch (self.state().impl) {
            .vulkan => {},
            .metal => |*metal_buffer| try metal_buffer.encodeDispatch(command_index, descriptor),
        }
        self.state().commands[command_index] = .{ .compute = descriptor };
    }

    fn validateCommandIndex(self: IndirectCommandBuffer, command_index: u32) core.CommandEncodingError!void {
        if (command_index >= self.state().commands.len) return core.CommandEncodingError.InvalidIndirectCommandRange;
    }

    fn validateExecution(self: IndirectCommandBuffer, kind_value: core.IndirectCommandKind, range: core.IndirectCommandRange) core.CommandEncodingError!void {
        if (self.kind() != kind_value) return core.CommandEncodingError.InvalidIndirectCommandKind;
        try range.validate(self.maxCommandCount());
        for (self.state().commands[range.location..][0..range.count]) |command| {
            if (command == null) return core.CommandEncodingError.MissingIndirectCommand;
        }
    }
};

pub fn makeIndirectCommandBuffer(
    device: *Device,
    descriptor: core.IndirectCommandBufferDescriptor,
) !IndirectCommandBuffer {
    try descriptor.validate(device.features(), device.limits());
    const commands = try device.state().allocator.alloc(?IndirectEncodedCommand, descriptor.max_command_count);
    errdefer device.state().allocator.free(commands);
    @memset(commands, null);
    const impl: IndirectCommandBuffer.Impl = switch (device.state().impl) {
        .vulkan => .{ .vulkan = {} },
        .metal => |*metal| .{ .metal = try MetalIndirectCommandBuffer.init(metal, descriptor) },
    };
    device.state().tracker.retain(.indirect_command_buffer);
    var result = IndirectCommandBuffer.init(.{
        .backend = device.selectedBackend(),
        .tracker = device.state().tracker,
        .allocator = device.state().allocator,
        .label_value = descriptor.label,
        .kind_value = descriptor.kind,
        .limits_value = device.limits(),
        .commands = commands,
        .impl = impl,
    });
    result.setLabel(descriptor.label);
    return result;
}

pub const BindGroup = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const Impl = union(core.Backend) {
        vulkan: VulkanBindGroupBackend.VulkanBindGroup,
        metal: MetalBindGroupBackend.MetalBindGroup,
    };

    const State = struct {
        backend: core.Backend,
        tracker: *ResourceTracker,
        allocator: std.mem.Allocator,
        label_value: ?[]const u8 = null,
        alive: bool = true,
        layout_entries: []const core.BindGroupLayoutEntry = &.{},
        entries: []core.BindGroupEntry,
        impl: ?Impl = null,
    };

    fn init(state_value: State) BindGroup {
        var result: BindGroup = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const BindGroup) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn deinit(self: *BindGroup) void {
        const state_value = self.state();
        assertAlive(state_value.alive, .bind_group);
        state_value.alive = false;
        if (state_value.impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        };
        state_value.allocator.free(state_value.layout_entries);
        state_value.allocator.free(state_value.entries);
        state_value.tracker.release(.bind_group);
    }

    pub fn selectedBackend(self: BindGroup) core.Backend {
        return self.state().backend;
    }

    pub fn label(self: BindGroup) ?[]const u8 {
        return self.state().label_value;
    }

    pub fn setLabel(self: *BindGroup, label_value: ?[]const u8) void {
        assertAlive(self.state().alive, .bind_group);
        self.state().label_value = label_value;
    }

    pub fn entryForBinding(self: BindGroup, binding: u32) ?core.BindGroupEntry {
        assertAlive(self.state().alive, .bind_group);
        for (self.state().entries) |entry| {
            if (entry.binding == binding) return entry;
        }
        return null;
    }

    pub fn layoutDescriptor(self: BindGroup) core.BindGroupLayoutDescriptor {
        assertAlive(self.state().alive, .bind_group);
        return .{ .entries = self.state().layout_entries };
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
        switch (self.target) {
            .current_drawable => {
                if (self.resolve_target != null) return RuntimeError.InvalidRenderPassAttachment;
                if (self.load_action != .clear or self.store_action != .store) {
                    return RuntimeError.UnsupportedRenderPassAttachmentAction;
                }
            },
            .texture_view => |texture_view| {
                assertAlive(texture_view.state().alive, .texture_view);
                try expectSameBackend(backend, texture_view.selectedBackend());
                if (!texture_view.usage().render_attachment or !core.isColorFormat(texture_view.format())) {
                    return RuntimeError.InvalidRenderPassAttachment;
                }
                if (texture_view.storageMode() == .memoryless and
                    (self.load_action == .load or self.store_action == .store))
                {
                    return RuntimeError.UnsupportedRenderPassAttachmentAction;
                }
                if (self.resolve_target) |resolve_target| {
                    assertAlive(resolve_target.state().alive, .texture_view);
                    try expectSameBackend(backend, resolve_target.selectedBackend());
                    if (!resolve_target.usage().render_attachment or !core.isColorFormat(resolve_target.format())) {
                        return RuntimeError.InvalidRenderPassAttachment;
                    }
                    if (resolve_target.storageMode() == .memoryless) {
                        return RuntimeError.UnsupportedRenderPassAttachmentAction;
                    }
                    (core.TextureResolveDescriptor{ .aspect = .color }).validate(
                        textureViewTextureDescriptor(texture_view),
                        textureViewTextureDescriptor(resolve_target),
                        defaultCommandFormatCapabilities(backend, texture_view.format()),
                    ) catch return RuntimeError.InvalidRenderPassAttachment;
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
    resolve_target: ?*TextureView = null,
    load_action: core.LoadAction = .clear,
    store_action: core.StoreAction = .dont_care,
    clear_depth: f32 = 1.0,
    options: core.RenderPassAttachmentOptions = .{},

    fn validateRuntime(self: RenderPassDepthAttachmentDescriptor, backend: core.Backend) !void {
        try self.toCore().validate();
        if (self.resolve_target != null) return core.CommandEncodingError.UnsupportedTextureResolve;
        switch (self.target) {
            .current_drawable => {
                if (self.load_action != .clear or self.store_action != .dont_care) {
                    return RuntimeError.UnsupportedRenderPassAttachmentAction;
                }
            },
            .texture_view => |texture_view| {
                assertAlive(texture_view.state().alive, .texture_view);
                try expectSameBackend(backend, texture_view.selectedBackend());
                if (!texture_view.usage().render_attachment or !core.isDepthFormat(texture_view.format())) {
                    return RuntimeError.InvalidRenderPassAttachment;
                }
                if (texture_view.storageMode() == .memoryless and
                    (self.load_action == .load or self.store_action == .store))
                {
                    return RuntimeError.UnsupportedRenderPassAttachmentAction;
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
    resolve_target: ?*TextureView = null,
    load_action: core.LoadAction = .clear,
    store_action: core.StoreAction = .dont_care,
    clear_stencil: u32 = 0,
    options: core.RenderPassAttachmentOptions = .{},

    fn validateRuntime(self: RenderPassStencilAttachmentDescriptor, backend: core.Backend) !void {
        try self.toCore().validate();
        if (self.resolve_target != null) return core.CommandEncodingError.UnsupportedTextureResolve;
        switch (self.target) {
            .current_drawable => {
                if (self.load_action != .clear or self.store_action != .dont_care or self.clear_stencil != 0) {
                    return RuntimeError.UnsupportedRenderPassAttachmentAction;
                }
            },
            .texture_view => |texture_view| {
                assertAlive(texture_view.state().alive, .texture_view);
                try expectSameBackend(backend, texture_view.selectedBackend());
                if (!texture_view.usage().render_attachment or !core.isStencilFormat(texture_view.format())) {
                    return RuntimeError.InvalidRenderPassAttachment;
                }
                if (texture_view.storageMode() == .memoryless and
                    (self.load_action == .load or self.store_action == .store))
                {
                    return RuntimeError.UnsupportedRenderPassAttachmentAction;
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
    /// The occlusion query set whose native storage is bound for this pass.
    /// It must remain alive until the command buffer has completed.
    occlusion_query_set: ?*QuerySet = null,

    fn validateRuntime(self: RenderPassDescriptor, backend: core.Backend) !void {
        if (self.color_attachments.len == 0) return core.CommandEncodingError.MissingColorAttachment;
        if (self.color_attachments.len > core.default_max_color_attachments) return RuntimeError.UnsupportedMultipleRenderTargets;
        for (self.color_attachments) |attachment| {
            try attachment.validateRuntime(backend);
        }
        try validateColorAttachmentCompatibility(self.color_attachments);
        if (self.depth_attachment) |depth_attachment| {
            try depth_attachment.validateRuntime(backend);
            for (self.color_attachments) |color_attachment| {
                try validateAttachmentExtents(color_attachment, depth_attachment);
                try validateAttachmentSampleCounts(color_attachment, depth_attachment);
            }
        }
        if (self.stencil_attachment) |stencil_attachment| {
            try stencil_attachment.validateRuntime(backend);
            const depth_attachment = self.depth_attachment orelse return RuntimeError.UnsupportedStencilAttachment;
            try validateDepthStencilAttachmentCompatibility(depth_attachment, stencil_attachment);
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

fn validateColorAttachmentCompatibility(color_attachments: []const RenderPassColorAttachmentDescriptor) RuntimeError!void {
    if (color_attachments.len <= 1) return;
    const first_view = switch (color_attachments[0].target) {
        .current_drawable => return RuntimeError.InvalidRenderPassAttachment,
        .texture_view => |texture_view| texture_view,
    };
    for (color_attachments[1..]) |attachment| {
        const view = switch (attachment.target) {
            .current_drawable => return RuntimeError.InvalidRenderPassAttachment,
            .texture_view => |texture_view| texture_view,
        };
        if (view.width() != first_view.width() or view.height() != first_view.height()) {
            return RuntimeError.InvalidRenderPassAttachment;
        }
        if (view.sampleCount() != first_view.sampleCount()) {
            return RuntimeError.InvalidRenderPassAttachment;
        }
    }
}

fn validateDepthStencilAttachmentCompatibility(
    depth: RenderPassDepthAttachmentDescriptor,
    stencil: RenderPassStencilAttachmentDescriptor,
) RuntimeError!void {
    switch (depth.target) {
        .current_drawable => switch (stencil.target) {
            .current_drawable => return RuntimeError.UnsupportedStencilAttachment,
            .texture_view => return RuntimeError.UnsupportedStencilAttachment,
        },
        .texture_view => |depth_view| switch (stencil.target) {
            .current_drawable => return RuntimeError.UnsupportedStencilAttachment,
            .texture_view => |stencil_view| {
                if (depth_view != stencil_view or !core.isDepthStencilFormat(depth_view.format())) {
                    return RuntimeError.UnsupportedStencilAttachment;
                }
            },
        },
    }
}

fn textureViewTextureDescriptor(view: *const TextureView) core.TextureDescriptor {
    return .{
        .format = view.format(),
        .width = view.width(),
        .height = view.height(),
        .depth_or_array_layers = view.arrayLayerCount(),
        .mip_level_count = view.mipLevelCount(),
        .sample_count = view.sampleCount(),
        .usage = view.usage(),
        .storage_mode = view.storageMode(),
    };
}

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
    var color_attachments: [core.default_max_color_attachments]VulkanCommand.RenderPassColorAttachmentDescriptor = undefined;
    for (descriptor.color_attachments, 0..) |attachment, i| {
        color_attachments[i] = .{
            .target = vulkanColorAttachmentTarget(attachment.target),
            .resolve_target = vulkanResolveAttachmentTarget(attachment.resolve_target),
            .load_action = attachment.load_action,
            .store_action = attachment.store_action,
            .clear_color = attachment.clear_color,
        };
    }
    return .{
        .label = descriptor.label,
        .color_attachments = color_attachments,
        .color_attachment_count = descriptor.color_attachments.len,
        .depth_attachment = if (descriptor.depth_attachment) |depth_attachment| .{
            .target = vulkanDepthAttachmentTarget(depth_attachment.target),
            .load_action = depth_attachment.load_action,
            .store_action = depth_attachment.store_action,
            .clear_depth = depth_attachment.clear_depth,
        } else null,
        .stencil_attachment = if (descriptor.stencil_attachment) |stencil_attachment| .{
            .load_action = stencil_attachment.load_action,
            .store_action = stencil_attachment.store_action,
            .clear_stencil = stencil_attachment.clear_stencil,
        } else null,
    };
}

fn vulkanColorAttachmentTarget(target: RenderPassColorAttachmentTarget) VulkanCommand.RenderPassColorAttachmentTarget {
    return switch (target) {
        .current_drawable => .current_drawable,
        .texture_view => |texture_view| .{ .texture_view = &texture_view.state().impl.vulkan },
    };
}

fn vulkanResolveAttachmentTarget(target: ?*TextureView) ?*const @import("../backend/vulkan/texture_view.zig") {
    return if (target) |texture_view| &texture_view.state().impl.vulkan else null;
}

fn vulkanDepthAttachmentTarget(target: RenderPassDepthAttachmentTarget) VulkanCommand.RenderPassDepthAttachmentTarget {
    return switch (target) {
        .current_drawable => .current_drawable,
        .texture_view => |texture_view| .{ .texture_view = &texture_view.state().impl.vulkan },
    };
}

fn metalRenderPassDescriptor(descriptor: RenderPassDescriptor) MetalCommand.RenderPassDescriptor {
    var color_attachments: [core.default_max_color_attachments]MetalCommand.RenderPassColorAttachmentDescriptor = undefined;
    for (descriptor.color_attachments, 0..) |attachment, i| {
        color_attachments[i] = .{
            .target = metalColorAttachmentTarget(attachment.target),
            .resolve_target = metalResolveAttachmentTarget(attachment.resolve_target),
            .load_action = attachment.load_action,
            .store_action = attachment.store_action,
            .clear_color = attachment.clear_color,
        };
    }
    return .{
        .label = descriptor.label,
        .color_attachments = color_attachments,
        .color_attachment_count = descriptor.color_attachments.len,
        .depth_attachment = if (descriptor.depth_attachment) |depth_attachment| .{
            .target = metalDepthAttachmentTarget(depth_attachment.target),
            .load_action = depth_attachment.load_action,
            .store_action = depth_attachment.store_action,
            .clear_depth = depth_attachment.clear_depth,
        } else null,
        .stencil_attachment = if (descriptor.stencil_attachment) |stencil_attachment| .{
            .load_action = stencil_attachment.load_action,
            .store_action = stencil_attachment.store_action,
            .clear_stencil = stencil_attachment.clear_stencil,
        } else null,
        .occlusion_query_set = metalOcclusionQuerySet(descriptor.occlusion_query_set),
    };
}

fn metalOcclusionQuerySet(query_set: ?*QuerySet) ?*const MetalQuerySet {
    const set = query_set orelse return null;
    if (set.state().impl) |*impl| return switch (impl.*) {
        .vulkan => null,
        .metal => |*metal| metal,
    };
    return null;
}

fn metalColorAttachmentTarget(target: RenderPassColorAttachmentTarget) MetalCommand.RenderPassColorAttachmentTarget {
    return switch (target) {
        .current_drawable => .current_drawable,
        .texture_view => |texture_view| .{ .texture_view = &texture_view.state().impl.metal },
    };
}

fn metalResolveAttachmentTarget(target: ?*TextureView) ?*const @import("../backend/metal/texture_view.zig") {
    return if (target) |texture_view| &texture_view.state().impl.metal else null;
}

fn metalDepthAttachmentTarget(target: RenderPassDepthAttachmentTarget) MetalCommand.RenderPassDepthAttachmentTarget {
    return switch (target) {
        .current_drawable => .current_drawable,
        .texture_view => |texture_view| .{ .texture_view = &texture_view.state().impl.metal },
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

fn insertNativeCommandsForEncoder(
    command_buffer: *CommandBuffer,
    expected_encoder: core.NativeCommandEncoderKind,
    descriptor: core.NativeCommandInsertionDescriptor,
) !void {
    try descriptor.validateForEncoder(expected_encoder, command_buffer.privateState().features_value);
    const view = command_buffer.privateState().native_handle_view orelse return core.AdvancedFeatureError.UnsupportedNativeCommandInsertion;
    descriptor.callback.?(descriptor.context, view);
}

pub const CommandBuffer = struct {
    _state: [@sizeOf(PrivateState)]u8 align(@alignOf(PrivateState)),

    const Impl = union(core.Backend) {
        vulkan: VulkanCommand.CommandBuffer,
        metal: MetalCommand.CommandBuffer,
    };

    const PrivateState = struct {
        backend: core.Backend,
        tracker: ?*ResourceTracker = null,
        runtime_impl: ?*BackendRuntime = null,
        label_value: ?[]const u8 = null,
        alive: bool = true,
        uses_current_drawable_pass: bool = false,
        presentation_available: bool = true,
        queue_kind_value: core.QueueKind = .graphics,
        features_value: core.DeviceFeatures = .{},
        limits_value: core.DeviceLimits = .{},
        native_handle_view: ?core.NativeHandleView = null,
        lifecycle_callback: ?core.CommandBufferLifecycleCallback = null,
        lifecycle_context: ?*anyopaque = null,
        lifecycle_status_value: std.atomic.Value(core.CommandBufferLifecycleStatus) = .init(.encoding),
        debug: core.CommandBufferDebugState = .{},
        debug_groups: core.DebugGroupStack = .{},
        borrowed_query_sets: std.ArrayList(*QuerySet) = .empty,
        borrowed_query_sets_allocator: ?std.mem.Allocator = null,
        impl: ?Impl = null,
    };

    fn init(state_value: PrivateState) CommandBuffer {
        var result: CommandBuffer = undefined;
        result.privateState().* = state_value;
        return result;
    }

    fn privateState(self: *const CommandBuffer) *PrivateState {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    const LifecycleThunkContext = struct {
        command_buffer: *CommandBuffer,
    };

    fn lifecycleThunk(context: ?*anyopaque, status: core.CommandBufferLifecycleStatus) callconv(.c) void {
        const thunk: *LifecycleThunkContext = @ptrCast(@alignCast(context orelse return));
        thunk.command_buffer.notifyLifecycle(status);
    }

    fn notifyLifecycle(self: *CommandBuffer, status: core.CommandBufferLifecycleStatus) void {
        self.privateState().lifecycle_status_value.store(status, .release);
        if (self.privateState().lifecycle_callback) |callback| {
            callback(self.privateState().lifecycle_context, status);
        }
    }

    fn retainQuerySetForResolve(self: *CommandBuffer, query_set: *QuerySet) !void {
        const state_value = self.privateState();
        if (state_value.tracker) |tracker| {
            if (tracker != query_set.state().tracker) return RuntimeError.BackendMismatch;
        }

        const allocator = state_value.borrowed_query_sets_allocator orelse query_set.state().allocator;
        try state_value.borrowed_query_sets.append(allocator, query_set);
        if (state_value.borrowed_query_sets_allocator == null) {
            state_value.borrowed_query_sets_allocator = allocator;
        }
        query_set.state().pending_command_borrows += 1;
    }

    fn rollbackQuerySetResolveBorrow(self: *CommandBuffer, query_set: *QuerySet) void {
        const state_value = self.privateState();
        std.debug.assert(state_value.borrowed_query_sets.items.len != 0);
        std.debug.assert(state_value.borrowed_query_sets.items[state_value.borrowed_query_sets.items.len - 1] == query_set);
        state_value.borrowed_query_sets.items.len -= 1;
        std.debug.assert(query_set.state().pending_command_borrows != 0);
        query_set.state().pending_command_borrows -= 1;

        if (state_value.borrowed_query_sets.items.len == 0) {
            state_value.borrowed_query_sets.deinit(state_value.borrowed_query_sets_allocator.?);
            state_value.borrowed_query_sets = .empty;
            state_value.borrowed_query_sets_allocator = null;
        }
    }

    fn releaseQuerySetResolveBorrows(self: *CommandBuffer) void {
        const state_value = self.privateState();
        for (state_value.borrowed_query_sets.items) |query_set| {
            assertObjectAlive(query_set.state().alive, "query_set");
            std.debug.assert(query_set.state().pending_command_borrows != 0);
            query_set.state().pending_command_borrows -= 1;
        }
        if (state_value.borrowed_query_sets_allocator) |allocator| {
            state_value.borrowed_query_sets.deinit(allocator);
        }
        state_value.borrowed_query_sets = .empty;
        state_value.borrowed_query_sets_allocator = null;
    }

    pub fn makeRenderCommandEncoder(
        self: *CommandBuffer,
        descriptor: RenderPassDescriptor,
    ) !RenderCommandEncoder {
        assertObjectAlive(self.privateState().alive, "command_buffer");
        if (self.privateState().queue_kind_value != .graphics) return core.CommandEncodingError.InvalidQueueCapability;
        if (descriptor.colorTargetUsesCurrentDrawable() and !self.privateState().presentation_available) {
            return RuntimeError.UnsupportedBackendForPresentation;
        }
        try descriptor.validateRuntime(self.privateState().backend);
        if (descriptor.occlusion_query_set) |query_set| {
            assertObjectAlive(query_set.state().alive, "query_set");
            try expectSameBackend(self.privateState().backend, query_set.selectedBackend());
            if (self.privateState().tracker != query_set.state().tracker) return RuntimeError.BackendMismatch;
            try query_set.validateQueryType(.occlusion);
            if (query_set.state().active_occlusion_query != null) return core.QueryError.QueryNotReady;
        }
        validateRenderPassOwnership(self.privateState().queue_kind_value, descriptor) catch |err| return err;
        recordRenderPassUsage(descriptor);

        var core_color_attachments: [core.default_max_color_attachments]core.RenderPassColorAttachmentDescriptor = undefined;
        for (descriptor.color_attachments, 0..) |attachment, i| {
            core_color_attachments[i] = attachment.toCore();
        }
        const core_depth_attachment = if (descriptor.depth_attachment) |depth_attachment| depth_attachment.toCore() else null;
        const core_descriptor = core.RenderPassDescriptor{
            .label = descriptor.label,
            .color_attachments = core_color_attachments[0..descriptor.color_attachments.len],
            .depth_attachment = core_depth_attachment,
            .stencil_attachment = if (descriptor.stencil_attachment) |stencil_attachment| stencil_attachment.toCore() else null,
        };

        const debug_encoder = try self.privateState().debug.makeRenderCommandEncoder(core_descriptor);
        errdefer self.privateState().debug.state = .ready;
        self.privateState().uses_current_drawable_pass = descriptor.colorTargetUsesCurrentDrawable();

        const encoder_impl: ?RenderCommandEncoder.Impl = if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| .{ .vulkan = try vulkan.makeRenderCommandEncoder(vulkanRenderPassDescriptor(descriptor)) },
            .metal => |*metal| .{ .metal = try metal.makeRenderCommandEncoder(metalRenderPassDescriptor(descriptor)) },
        } else null;

        var encoder = RenderCommandEncoder.init(.{
            .backend = self.privateState().backend,
            .command_buffer = self,
            .label_value = descriptor.label,
            .debug = debug_encoder,
            .occlusion_query_set = descriptor.occlusion_query_set,
            .impl = encoder_impl,
        });
        encoder.setLabel(descriptor.label);
        return encoder;
    }

    pub fn makeBlitCommandEncoder(self: *CommandBuffer) !BlitCommandEncoder {
        assertObjectAlive(self.privateState().alive, "command_buffer");

        const debug_encoder = try self.privateState().debug.makeBlitCommandEncoder();
        errdefer self.privateState().debug.state = .ready;
        self.privateState().uses_current_drawable_pass = false;

        const encoder_impl: ?BlitCommandEncoder.Impl = if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| .{ .vulkan = try vulkan.makeBlitCommandEncoder() },
            .metal => |*metal| .{ .metal = try metal.makeBlitCommandEncoder() },
        } else null;

        return BlitCommandEncoder.init(.{
            .backend = self.privateState().backend,
            .command_buffer = self,
            .debug = debug_encoder,
            .impl = encoder_impl,
        });
    }

    pub fn makeComputeCommandEncoder(self: *CommandBuffer) !ComputeCommandEncoder {
        assertObjectAlive(self.privateState().alive, "command_buffer");
        if (self.privateState().queue_kind_value == .transfer) return core.CommandEncodingError.InvalidQueueCapability;

        const debug_encoder = try self.privateState().debug.makeComputeCommandEncoder();
        errdefer self.privateState().debug.state = .ready;
        self.privateState().uses_current_drawable_pass = false;

        const encoder_impl: ?ComputeCommandEncoder.Impl = if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| .{ .vulkan = try vulkan.makeComputeCommandEncoder() },
            .metal => |*metal| .{ .metal = try metal.makeComputeCommandEncoder() },
        } else null;

        return ComputeCommandEncoder.init(.{
            .backend = self.privateState().backend,
            .command_buffer = self,
            .debug = debug_encoder,
            .impl = encoder_impl,
        });
    }

    pub fn presentDrawable(self: *CommandBuffer) !void {
        try self.presentDrawableWithDescriptor(.{});
    }

    pub fn presentDrawableWithDescriptor(self: *CommandBuffer, descriptor: core.PresentDrawableDescriptor) !void {
        assertObjectAlive(self.privateState().alive, "command_buffer");
        if (!self.privateState().presentation_available) return RuntimeError.UnsupportedBackendForPresentation;
        if (!self.privateState().uses_current_drawable_pass) return RuntimeError.PresentRequiresCurrentDrawable;
        const resolved = try descriptor.resolve(self.privateState().features_value);
        try self.privateState().debug.presentDrawable();
        switch (self.privateState().impl orelse return) {
            .vulkan => |*vulkan| try vulkan.presentDrawableWithDescriptor(resolved),
            .metal => |*metal| try metal.presentDrawableWithDescriptor(resolved),
        }
    }

    pub fn encodeAccelerationStructureBuild(
        self: *CommandBuffer,
        plan: core.AccelerationStructureBuildPlan,
        resources: AccelerationStructureBuildResources,
    ) !void {
        assertObjectAlive(self.privateState().alive, "command_buffer");
        if (self.privateState().debug.state != .ready) return core.CommandEncodingError.InvalidCommandBufferState;
        if (self.privateState().queue_kind_value == .transfer) return core.CommandEncodingError.InvalidQueueCapability;
        try resources.validate(self.privateState().backend, plan);
        _ = resources.scratch.recordUsage(.acceleration_structure_scratch);
        for (resources.geometries) |geometry| geometry.recordUsage();
        var driver_submitted = false;
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| {
                if (resources.result.state().impl) |*result_impl| switch (result_impl.*) {
                    .vulkan => |*vulkan_as| {
                        const scratch_impl = switch (resources.scratch.state().impl) {
                            .vulkan => |*vulkan_scratch| vulkan_scratch,
                            .metal => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
                        };
                        const update_source_impl = if (resources.update_source) |source| switch (source.state().impl orelse {
                            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
                        }) {
                            .vulkan => |*vulkan_source| vulkan_source,
                            .metal => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
                        } else null;
                        const instance_source_impl = if (resources.instance_source) |source| switch (source.state().impl orelse {
                            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
                        }) {
                            .vulkan => |*vulkan_source| vulkan_source,
                            .metal => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
                        } else null;
                        var vulkan_instance_source_buffer: [64]*const VulkanAccelerationStructure = undefined;
                        if (resources.instance_sources.len > vulkan_instance_source_buffer.len) {
                            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
                        }
                        for (resources.instance_sources, 0..) |source, source_index| {
                            vulkan_instance_source_buffer[source_index] = switch (source.state().impl orelse {
                                return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
                            }) {
                                .vulkan => |*vulkan_source| vulkan_source,
                                .metal => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
                            };
                        }
                        const instance_source_impls = vulkan_instance_source_buffer[0..resources.instance_sources.len];
                        var vulkan_geometry_buffer: [64]VulkanAccelerationStructure.GeometryInput = undefined;
                        if (resources.geometries.len > vulkan_geometry_buffer.len) {
                            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
                        }
                        for (resources.geometries, 0..) |geometry, geometry_index| {
                            vulkan_geometry_buffer[geometry_index] = switch (geometry) {
                                .triangles => |triangles| .{ .triangles = .{
                                    .descriptor = triangles.descriptor,
                                    .vertex_buffer = switch (triangles.vertex_buffer.state().impl) {
                                        .vulkan => |*vertex_buffer| vertex_buffer,
                                        .metal => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
                                    },
                                    .index_buffer = if (triangles.index_buffer) |index_buffer| switch (index_buffer.state().impl) {
                                        .vulkan => |*vulkan_index_buffer| vulkan_index_buffer,
                                        .metal => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
                                    } else null,
                                } },
                                .aabbs => |aabbs| .{ .aabbs = .{
                                    .descriptor = aabbs.descriptor,
                                    .buffer = switch (aabbs.buffer.state().impl) {
                                        .vulkan => |*buffer| buffer,
                                        .metal => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
                                    },
                                } },
                                .instances => .{ .instances = {} },
                            };
                        }
                        const vulkan_geometries = vulkan_geometry_buffer[0..resources.geometries.len];
                        try vulkan.encodeAccelerationStructureBuild(
                            plan,
                            vulkan_as,
                            scratch_impl,
                            resources.scratch_offset,
                            update_source_impl,
                            instance_source_impl,
                            instance_source_impls,
                            vulkan_geometries,
                        );
                        driver_submitted = true;
                    },
                    .metal => {},
                };
            },
            .metal => |*metal| {
                if (resources.result.state().impl) |*result_impl| switch (result_impl.*) {
                    .vulkan => {},
                    .metal => |*metal_as| {
                        const scratch_impl = switch (resources.scratch.state().impl) {
                            .vulkan => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
                            .metal => |*metal_scratch| metal_scratch,
                        };
                        const update_source_impl = if (resources.update_source) |source| switch (source.state().impl orelse {
                            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
                        }) {
                            .vulkan => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
                            .metal => |*metal_source| metal_source,
                        } else null;
                        const instance_source_impl = if (resources.instance_source) |source| switch (source.state().impl orelse {
                            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
                        }) {
                            .vulkan => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
                            .metal => |*metal_source| metal_source,
                        } else null;
                        var metal_instance_source_buffer: [64]*const MetalAccelerationStructure = undefined;
                        if (resources.instance_sources.len > metal_instance_source_buffer.len) {
                            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
                        }
                        for (resources.instance_sources, 0..) |source, source_index| {
                            metal_instance_source_buffer[source_index] = switch (source.state().impl orelse {
                                return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
                            }) {
                                .vulkan => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
                                .metal => |*metal_source| metal_source,
                            };
                        }
                        const instance_source_impls = metal_instance_source_buffer[0..resources.instance_sources.len];
                        var metal_geometry_buffer: [64]MetalAccelerationStructure.GeometryInput = undefined;
                        if (resources.geometries.len > metal_geometry_buffer.len) {
                            return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
                        }
                        for (resources.geometries, 0..) |geometry, geometry_index| {
                            metal_geometry_buffer[geometry_index] = switch (geometry) {
                                .triangles => |triangles| .{ .triangles = .{
                                    .descriptor = triangles.descriptor,
                                    .vertex_buffer = switch (triangles.vertex_buffer.state().impl) {
                                        .vulkan => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
                                        .metal => |*vertex_buffer| vertex_buffer,
                                    },
                                    .index_buffer = if (triangles.index_buffer) |index_buffer| switch (index_buffer.state().impl) {
                                        .vulkan => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
                                        .metal => |*metal_index_buffer| metal_index_buffer,
                                    } else null,
                                } },
                                .aabbs => |aabbs| .{ .aabbs = .{
                                    .descriptor = aabbs.descriptor,
                                    .buffer = switch (aabbs.buffer.state().impl) {
                                        .vulkan => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
                                        .metal => |*buffer| buffer,
                                    },
                                } },
                                .instances => .{ .instances = {} },
                            };
                        }
                        const metal_geometries = metal_geometry_buffer[0..resources.geometries.len];
                        try metal.encodeAccelerationStructureBuild(
                            plan,
                            metal_as,
                            scratch_impl,
                            resources.scratch_offset,
                            update_source_impl,
                            instance_source_impl,
                            instance_source_impls,
                            metal_geometries,
                        );
                        driver_submitted = true;
                    },
                };
            },
        };
        try resources.result.markBuilt(plan, resources, self.privateState().impl != null, driver_submitted);
    }

    pub fn encodeAccelerationStructureMaintenance(
        self: *CommandBuffer,
        plan: core.AccelerationStructureMaintenancePlan,
        resources: AccelerationStructureMaintenanceResources,
    ) !void {
        assertObjectAlive(self.privateState().alive, "command_buffer");
        if (self.privateState().debug.state != .ready) return core.CommandEncodingError.InvalidCommandBufferState;
        if (self.privateState().queue_kind_value == .transfer) return core.CommandEncodingError.InvalidQueueCapability;
        try resources.validate(self.privateState().backend, plan);
        if (resources.scratch) |scratch| _ = scratch.recordUsage(.acceleration_structure_scratch);

        var driver_submitted = false;
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| {
                const source = switch (resources.source.state().impl orelse {
                    return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
                }) {
                    .vulkan => |*value| value,
                    .metal => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
                };
                const destination = if (resources.destination) |value| switch (value.state().impl orelse {
                    return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
                }) {
                    .vulkan => |*native| native,
                    .metal => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
                } else null;
                const scratch = if (resources.scratch) |value| switch (value.state().impl) {
                    .vulkan => |*native| native,
                    .metal => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
                } else null;
                try vulkan.encodeAccelerationStructureMaintenance(
                    plan,
                    source,
                    destination,
                    scratch,
                    resources.scratch_offset,
                );
                driver_submitted = true;
            },
            .metal => |*metal| {
                const source = switch (resources.source.state().impl orelse {
                    return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
                }) {
                    .vulkan => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
                    .metal => |*value| value,
                };
                const destination = if (resources.destination) |value| switch (value.state().impl orelse {
                    return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
                }) {
                    .vulkan => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
                    .metal => |*native| native,
                } else null;
                const scratch = if (resources.scratch) |value| switch (value.state().impl) {
                    .vulkan => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
                    .metal => |*native| native,
                } else null;
                try metal.encodeAccelerationStructureMaintenance(
                    plan,
                    source,
                    destination,
                    scratch,
                    resources.scratch_offset,
                );
                driver_submitted = true;
            },
        };
        resources.source.markMaintained(
            plan,
            resources,
            self.privateState().impl != null,
            driver_submitted,
        );
    }

    pub fn dispatchRays(
        self: *CommandBuffer,
        pipeline: *RayTracingPipelineState,
        shader_binding_table: *ShaderBindingTable,
        descriptor: core.RayDispatchDescriptor,
    ) !core.RayDispatchPlan {
        assertObjectAlive(self.privateState().alive, "command_buffer");
        assertAlive(pipeline.state().alive, .ray_tracing_pipeline_state);
        assertAlive(shader_binding_table.state().alive, .shader_binding_table);
        if (self.privateState().debug.state != .ready) return core.CommandEncodingError.InvalidCommandBufferState;
        if (self.privateState().queue_kind_value == .transfer) return core.CommandEncodingError.InvalidQueueCapability;
        try expectSameBackend(self.privateState().backend, pipeline.selectedBackend());
        try expectSameBackend(self.privateState().backend, shader_binding_table.selectedBackend());
        const plan = try shader_binding_table.dispatchPlan(pipeline.*, descriptor);
        var driver_submitted = false;
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| {
                if (pipeline.vulkanImpl()) |vulkan_pipeline| {
                    try vulkan.traceRays(vulkan_pipeline, descriptor);
                    driver_submitted = true;
                }
            },
            .metal => {},
        };
        shader_binding_table.recordDispatch(plan, self.privateState().impl != null, driver_submitted);
        return plan;
    }

    pub fn dispatchRaysToDrawable(
        self: *CommandBuffer,
        pipeline: *RayTracingPipelineState,
        shader_binding_table: *ShaderBindingTable,
        descriptor: core.RayDispatchDescriptor,
        resources: RayTracingDrawableResources,
    ) !core.RayDispatchPlan {
        assertObjectAlive(self.privateState().alive, "command_buffer");
        if (!self.privateState().presentation_available) return RuntimeError.UnsupportedBackendForPresentation;
        assertAlive(pipeline.state().alive, .ray_tracing_pipeline_state);
        assertAlive(shader_binding_table.state().alive, .shader_binding_table);
        if (self.privateState().debug.state != .ready) return core.CommandEncodingError.InvalidCommandBufferState;
        if (self.privateState().queue_kind_value == .transfer) return core.CommandEncodingError.InvalidQueueCapability;
        try expectSameBackend(self.privateState().backend, pipeline.selectedBackend());
        try expectSameBackend(self.privateState().backend, shader_binding_table.selectedBackend());
        try resources.validate(self.privateState().backend);
        const plan = try shader_binding_table.dispatchPlan(pipeline.*, descriptor);
        var driver_submitted = false;
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| {
                const vulkan_pipeline = pipeline.vulkanImpl() orelse {
                    return core.AdvancedFeatureError.InvalidRayTracingPipeline;
                };
                const vulkan_as = switch (resources.acceleration_structure.state().impl orelse {
                    return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
                }) {
                    .vulkan => |*acceleration_structure| acceleration_structure,
                    .metal => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
                };
                const vulkan_output = switch (resources.output.state().impl) {
                    .vulkan => |*output| output,
                    .metal => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
                };
                try vulkan.traceRaysToDrawable(vulkan_pipeline, vulkan_as, vulkan_output, descriptor);
                self.privateState().uses_current_drawable_pass = true;
                driver_submitted = true;
            },
            .metal => |*metal| {
                const metal_pipeline = pipeline.metalImpl() orelse {
                    return core.AdvancedFeatureError.InvalidRayTracingPipeline;
                };
                const metal_as = switch (resources.acceleration_structure.state().impl orelse {
                    return core.AdvancedFeatureError.InvalidAccelerationStructureResources;
                }) {
                    .vulkan => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
                    .metal => |*acceleration_structure| acceleration_structure,
                };
                switch (resources.output.state().impl) {
                    .vulkan => return core.AdvancedFeatureError.InvalidAccelerationStructureResources,
                    .metal => {},
                }
                try metal.traceRaysToDrawable(metal_pipeline, metal_as, descriptor);
                self.privateState().uses_current_drawable_pass = true;
                driver_submitted = true;
            },
        };
        shader_binding_table.recordDispatch(plan, self.privateState().impl != null, driver_submitted);
        return plan;
    }

    pub fn label(self: CommandBuffer) ?[]const u8 {
        return self.privateState().label_value;
    }

    pub fn state(self: CommandBuffer) core.CommandBufferState {
        return self.privateState().debug.status();
    }

    pub fn lifecycleStatus(self: CommandBuffer) core.CommandBufferLifecycleStatus {
        return self.privateState().lifecycle_status_value.load(.acquire);
    }

    pub fn queueKind(self: CommandBuffer) core.QueueKind {
        return self.privateState().queue_kind_value;
    }

    pub fn setLabel(self: *CommandBuffer, label_value: ?[]const u8) void {
        assertObjectAlive(self.privateState().alive, "command_buffer");
        self.privateState().label_value = label_value;
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.setLabel(label_value),
            .metal => |*metal| metal.setLabel(label_value),
        };
    }

    pub fn pushDebugGroup(self: *CommandBuffer, label_value: []const u8) !void {
        assertObjectAlive(self.privateState().alive, "command_buffer");
        if (self.privateState().debug.status() != .ready) return core.CommandEncodingError.InvalidCommandBufferState;
        try self.privateState().debug_groups.push(label_value);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.pushDebugGroup(label_value),
            .metal => |*metal| metal.pushDebugGroup(label_value),
        };
    }

    pub fn popDebugGroup(self: *CommandBuffer) !void {
        assertObjectAlive(self.privateState().alive, "command_buffer");
        if (self.privateState().debug.status() != .ready) return core.CommandEncodingError.InvalidCommandBufferState;
        try self.privateState().debug_groups.pop();
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.popDebugGroup(),
            .metal => |*metal| metal.popDebugGroup(),
        };
    }

    pub fn insertDebugSignpost(self: *CommandBuffer, label_value: []const u8) !void {
        assertObjectAlive(self.privateState().alive, "command_buffer");
        try self.privateState().debug.insertDebugSignpost(.{ .label = label_value });
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.insertDebugSignpost(label_value),
            .metal => |*metal| metal.insertDebugSignpost(label_value),
        };
    }

    pub fn commit(self: *CommandBuffer) !void {
        assertObjectAlive(self.privateState().alive, "command_buffer");
        try self.privateState().debug_groups.requireEmpty();
        try self.privateState().debug.commit();
        const work_serial = if (self.privateState().tracker) |tracker| tracker.submitWork() else 0;
        var lifecycle_context = LifecycleThunkContext{ .command_buffer = self };
        switch (self.privateState().impl orelse {
            self.notifyLifecycle(.scheduled);
            self.privateState().alive = false;
            if (self.privateState().tracker) |tracker| tracker.completeWork(work_serial);
            self.releaseQuerySetResolveBorrows();
            self.notifyLifecycle(.completed);
            return;
        }) {
            .vulkan => |*vulkan| {
                vulkan.commit(lifecycleThunk, &lifecycle_context) catch |err| {
                    if (self.lifecycleStatus() != .failed) self.notifyLifecycle(.failed);
                    return err;
                };
                vulkan.deinit();
            },
            .metal => |*metal| {
                metal.commit(lifecycleThunk, &lifecycle_context) catch |err| {
                    if (self.lifecycleStatus() != .failed) self.notifyLifecycle(.failed);
                    return err;
                };
                metal.deinit();
            },
        }
        if (self.privateState().tracker) |tracker| tracker.completeWork(work_serial);
        self.releaseQuerySetResolveBorrows();
        self.privateState().alive = false;
    }

    pub fn commitWithExternalSynchronization(
        self: *CommandBuffer,
        descriptor: ExternalSynchronizationDescriptor,
    ) !void {
        _ = try descriptor.plan(self.privateState().backend);
        try self.commit();
    }

    pub fn commitWithSynchronization(
        self: *CommandBuffer,
        descriptor: SynchronizationDescriptor,
    ) !void {
        try descriptor.validate(self.privateState().backend);
        try descriptor.waitBeforeSubmit();
        try descriptor.encodeNative(self);
        try self.commit();
        try descriptor.signalAfterSubmit();
    }

    pub fn selectedBackend(self: CommandBuffer) core.Backend {
        return self.privateState().backend;
    }
};

pub const BlitCommandEncoder = struct {
    _state: [@sizeOf(PrivateState)]u8 align(@alignOf(PrivateState)),

    const Impl = union(core.Backend) {
        vulkan: VulkanCommand.BlitCommandEncoder,
        metal: MetalCommand.BlitCommandEncoder,
    };

    const PrivateState = struct {
        backend: core.Backend,
        command_buffer: *CommandBuffer,
        label_value: ?[]const u8 = null,
        alive: bool = true,
        debug: core.BlitCommandEncoderDebugState = .{},
        debug_groups: core.DebugGroupStack = .{},
        impl: ?Impl = null,
    };

    fn init(state_value: PrivateState) BlitCommandEncoder {
        var result: BlitCommandEncoder = undefined;
        result.privateState().* = state_value;
        return result;
    }

    fn privateState(self: *const BlitCommandEncoder) *PrivateState {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn copyBufferToBuffer(
        self: *BlitCommandEncoder,
        source: *Buffer,
        destination: *Buffer,
        descriptor: core.CopyBufferToBufferDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "blit_command_encoder");
        assertAlive(source.state().alive, .buffer);
        assertAlive(destination.state().alive, .buffer);
        try expectSameBackend(self.privateState().backend, source.selectedBackend());
        try expectSameBackend(self.privateState().backend, destination.selectedBackend());
        if (!source.state().usage_value.copy_source) return core.CommandEncodingError.InvalidCopyBufferUsage;
        if (!destination.state().usage_value.copy_destination) return core.CommandEncodingError.InvalidCopyBufferUsage;
        try ensureBufferOwnedByQueue(self.privateState().command_buffer.privateState().queue_kind_value, source);
        try ensureBufferOwnedByQueue(self.privateState().command_buffer.privateState().queue_kind_value, destination);
        try self.privateState().debug.copyBufferToBuffer(descriptor, source.length(), destination.length());
        _ = source.recordUsage(.copy_source);
        _ = destination.recordUsage(.copy_destination);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.copyBufferToBuffer(&source.state().impl.vulkan, &destination.state().impl.vulkan, descriptor),
            .metal => |*metal| try metal.copyBufferToBuffer(&source.state().impl.metal, &destination.state().impl.metal, descriptor),
        };
    }

    pub fn copyBufferToTexture(
        self: *BlitCommandEncoder,
        source: *Buffer,
        destination: *Texture,
        descriptor: core.CopyBufferToTextureDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "blit_command_encoder");
        assertAlive(source.state().alive, .buffer);
        assertAlive(destination.state().alive, .texture);
        try expectSameBackend(self.privateState().backend, source.selectedBackend());
        try expectSameBackend(self.privateState().backend, destination.selectedBackend());
        if (!source.state().usage_value.copy_source) return core.CommandEncodingError.InvalidCopyBufferUsage;
        if (!destination.state().usage_value.copy_destination) return core.CommandEncodingError.InvalidCopyTextureUsage;
        try ensureBufferOwnedByQueue(self.privateState().command_buffer.privateState().queue_kind_value, source);
        try ensureTextureOwnedByQueue(self.privateState().command_buffer.privateState().queue_kind_value, destination);
        const resolved = try self.privateState().debug.copyBufferToTextureWithRequirements(
            descriptor,
            source.length(),
            destination.textureDescriptor(),
            core.TextureCopyLayoutRequirements.fromLimits(self.privateState().command_buffer.privateState().limits_value),
        );
        _ = source.recordUsage(.copy_source);
        _ = try destination.recordSubresourceUsage(
            copySubresourceRange(destination.textureDescriptor(), resolved.mip_level, resolved.slice, 1),
            .copy_destination,
        );
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.copyBufferToTexture(&source.state().impl.vulkan, &destination.state().impl.vulkan, resolved),
            .metal => |*metal| try metal.copyBufferToTexture(&source.state().impl.metal, &destination.state().impl.metal, resolved),
        };
    }

    pub fn copyTextureToBuffer(
        self: *BlitCommandEncoder,
        source: *Texture,
        destination: *Buffer,
        descriptor: core.CopyTextureToBufferDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "blit_command_encoder");
        assertAlive(source.state().alive, .texture);
        assertAlive(destination.state().alive, .buffer);
        try expectSameBackend(self.privateState().backend, source.selectedBackend());
        try expectSameBackend(self.privateState().backend, destination.selectedBackend());
        if (!source.state().usage_value.copy_source) return core.CommandEncodingError.InvalidCopyTextureUsage;
        if (!destination.state().usage_value.copy_destination) return core.CommandEncodingError.InvalidCopyBufferUsage;
        try ensureTextureOwnedByQueue(self.privateState().command_buffer.privateState().queue_kind_value, source);
        try ensureBufferOwnedByQueue(self.privateState().command_buffer.privateState().queue_kind_value, destination);
        const resolved = try self.privateState().debug.copyTextureToBufferWithRequirements(
            descriptor,
            source.textureDescriptor(),
            destination.length(),
            core.TextureCopyLayoutRequirements.fromLimits(self.privateState().command_buffer.privateState().limits_value),
        );
        _ = try source.recordSubresourceUsage(
            copySubresourceRange(source.textureDescriptor(), resolved.mip_level, resolved.slice, 1),
            .copy_source,
        );
        _ = destination.recordUsage(.copy_destination);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.copyTextureToBuffer(&source.state().impl.vulkan, &destination.state().impl.vulkan, resolved),
            .metal => |*metal| try metal.copyTextureToBuffer(&source.state().impl.metal, &destination.state().impl.metal, resolved),
        };
    }

    pub fn copyTextureToTexture(
        self: *BlitCommandEncoder,
        source: *Texture,
        destination: *Texture,
        descriptor: core.CopyTextureToTextureDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "blit_command_encoder");
        assertAlive(source.state().alive, .texture);
        assertAlive(destination.state().alive, .texture);
        try expectSameBackend(self.privateState().backend, source.selectedBackend());
        try expectSameBackend(self.privateState().backend, destination.selectedBackend());
        if (!source.state().usage_value.copy_source) return core.CommandEncodingError.InvalidCopyTextureUsage;
        if (!destination.state().usage_value.copy_destination) return core.CommandEncodingError.InvalidCopyTextureUsage;
        try ensureTextureOwnedByQueue(self.privateState().command_buffer.privateState().queue_kind_value, source);
        try ensureTextureOwnedByQueue(self.privateState().command_buffer.privateState().queue_kind_value, destination);
        const resolved = try self.privateState().debug.copyTextureToTexture(
            descriptor,
            source.textureDescriptor(),
            destination.textureDescriptor(),
        );
        _ = try source.recordSubresourceUsage(
            copySubresourceRange(source.textureDescriptor(), resolved.source_mip_level, resolved.source_slice, resolved.slice_count),
            .copy_source,
        );
        _ = try destination.recordSubresourceUsage(
            copySubresourceRange(destination.textureDescriptor(), resolved.destination_mip_level, resolved.destination_slice, resolved.slice_count),
            .copy_destination,
        );
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.copyTextureToTexture(&source.state().impl.vulkan, &destination.state().impl.vulkan, resolved),
            .metal => |*metal| try metal.copyTextureToTexture(&source.state().impl.metal, &destination.state().impl.metal, resolved),
        };
    }

    pub fn blitTexture(
        self: *BlitCommandEncoder,
        source: *Texture,
        destination: *Texture,
        descriptor: core.BlitTextureDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "blit_command_encoder");
        assertAlive(source.state().alive, .texture);
        assertAlive(destination.state().alive, .texture);
        try expectSameBackend(self.privateState().backend, source.selectedBackend());
        try expectSameBackend(self.privateState().backend, destination.selectedBackend());
        if (!source.state().usage_value.copy_source) return core.CommandEncodingError.InvalidCopyTextureUsage;
        if (!destination.state().usage_value.copy_destination) return core.CommandEncodingError.InvalidCopyTextureUsage;
        try ensureTextureOwnedByQueue(self.privateState().command_buffer.privateState().queue_kind_value, source);
        try ensureTextureOwnedByQueue(self.privateState().command_buffer.privateState().queue_kind_value, destination);
        const source_caps = commandFormatCapabilities(self.privateState().command_buffer, source.format());
        const destination_caps = commandFormatCapabilities(self.privateState().command_buffer, destination.format());
        const resolved = try self.privateState().debug.blitTexture(
            descriptor,
            source.textureDescriptor(),
            destination.textureDescriptor(),
            source_caps,
            destination_caps,
        );
        _ = try source.recordSubresourceUsage(
            copySubresourceRange(source.textureDescriptor(), resolved.source_mip_level, resolved.source_slice, resolved.slice_count),
            .copy_source,
        );
        _ = try destination.recordSubresourceUsage(
            copySubresourceRange(destination.textureDescriptor(), resolved.destination_mip_level, resolved.destination_slice, resolved.slice_count),
            .copy_destination,
        );
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.blitTexture(&source.state().impl.vulkan, &destination.state().impl.vulkan, resolved),
            .metal => |*metal| try metal.blitTexture(&source.state().impl.metal, &destination.state().impl.metal, resolved),
        };
    }

    pub fn fillBuffer(
        self: *BlitCommandEncoder,
        buffer: *Buffer,
        descriptor: core.FillBufferDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "blit_command_encoder");
        assertAlive(buffer.state().alive, .buffer);
        try expectSameBackend(self.privateState().backend, buffer.selectedBackend());
        if (!buffer.state().usage_value.copy_destination) return core.CommandEncodingError.InvalidCopyBufferUsage;
        try ensureBufferOwnedByQueue(self.privateState().command_buffer.privateState().queue_kind_value, buffer);
        try self.privateState().debug.fillBuffer(descriptor, buffer.length());
        _ = buffer.recordUsage(.copy_destination);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.fillBuffer(&buffer.state().impl.vulkan, descriptor),
            .metal => |*metal| try metal.fillBuffer(&buffer.state().impl.metal, descriptor),
        };
    }

    pub fn generateMipmaps(
        self: *BlitCommandEncoder,
        texture: *Texture,
        descriptor: core.GenerateMipmapsDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "blit_command_encoder");
        assertAlive(texture.state().alive, .texture);
        try expectSameBackend(self.privateState().backend, texture.selectedBackend());
        try ensureTextureOwnedByQueue(self.privateState().command_buffer.privateState().queue_kind_value, texture);
        const resolved = try descriptor.resolveForTexture(texture.textureDescriptor());
        if (!isFullGenerateMipmapsRange(texture.textureDescriptor(), resolved)) {
            return core.TextureError.UnsupportedMipmapGeneration;
        }
        _ = texture.recordUsage(.copy_source);
        _ = texture.recordUsage(.copy_destination);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.generateMipmaps(&texture.state().impl.vulkan, resolved),
            .metal => |*metal| try metal.generateMipmaps(&texture.state().impl.metal, resolved),
        };
        _ = texture.recordUsage(.sampled_texture);
    }

    pub fn bufferBarrier(
        self: *BlitCommandEncoder,
        buffer: *Buffer,
        descriptor: core.BufferBarrierDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "blit_command_encoder");
        try ensureBufferOwnedByQueue(self.privateState().command_buffer.privateState().queue_kind_value, buffer);
        try recordBufferBarrier(self.privateState().backend, self.privateState().command_buffer.privateState().features_value, buffer, descriptor);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.bufferBarrier(&buffer.state().impl.vulkan, descriptor),
            .metal => |*metal| try metal.bufferBarrier(&buffer.state().impl.metal, descriptor),
        };
    }

    pub fn textureBarrier(
        self: *BlitCommandEncoder,
        texture: *Texture,
        descriptor: core.TextureBarrierDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "blit_command_encoder");
        try ensureTextureOwnedByQueue(self.privateState().command_buffer.privateState().queue_kind_value, texture);
        try recordTextureBarrier(self.privateState().backend, self.privateState().command_buffer.privateState().features_value, texture, descriptor);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.textureBarrier(&texture.state().impl.vulkan, descriptor),
            .metal => |*metal| try metal.textureBarrier(&texture.state().impl.metal, descriptor),
        };
    }

    pub fn bufferOwnershipTransfer(
        self: *BlitCommandEncoder,
        buffer: *Buffer,
        descriptor: core.QueueOwnershipTransferDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "blit_command_encoder");
        if (self.privateState().command_buffer.privateState().queue_kind_value != descriptor.source) return core.CommandEncodingError.InvalidQueueOwnershipState;
        try recordBufferOwnershipTransfer(self.privateState().command_buffer.privateState().features_value, buffer, descriptor);
    }

    pub fn textureOwnershipTransfer(
        self: *BlitCommandEncoder,
        texture: *Texture,
        descriptor: core.QueueOwnershipTransferDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "blit_command_encoder");
        if (self.privateState().command_buffer.privateState().queue_kind_value != descriptor.source) return core.CommandEncodingError.InvalidQueueOwnershipState;
        try recordTextureOwnershipTransfer(self.privateState().command_buffer.privateState().features_value, texture, descriptor);
    }

    pub fn writeTimestamp(self: *BlitCommandEncoder, query_set: *QuerySet, query_index: u32) !void {
        assertObjectAlive(self.privateState().alive, "blit_command_encoder");
        assertObjectAlive(query_set.state().alive, "query_set");
        try expectSameBackend(self.privateState().backend, query_set.selectedBackend());
        if (self.privateState().command_buffer.privateState().tracker != query_set.state().tracker) {
            return RuntimeError.BackendMismatch;
        }
        try query_set.prepareTimestamp(query_index);
        if (query_set.state().impl) |*query_impl| {
            if (self.privateState().impl) |*encoder_impl| switch (encoder_impl.*) {
                .vulkan => |*vulkan| switch (query_impl.*) {
                    .vulkan => |*query| vulkan.writeTimestamp(query, query_index),
                    .metal => unreachable,
                },
                .metal => |*metal| switch (query_impl.*) {
                    .vulkan => unreachable,
                    .metal => |*query| try metal.writeTimestamp(query, query_index),
                },
            };
        }
        query_set.markTimestamp(query_index);
    }

    pub fn insertNativeCommands(self: *BlitCommandEncoder, descriptor: core.NativeCommandInsertionDescriptor) !void {
        assertObjectAlive(self.privateState().alive, "blit_command_encoder");
        try insertNativeCommandsForEncoder(self.privateState().command_buffer, .blit, descriptor);
    }

    pub fn resolveQuerySet(
        self: *BlitCommandEncoder,
        query_set: *QuerySet,
        destination: *Buffer,
        descriptor: core.QueryResolveDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "blit_command_encoder");
        assertObjectAlive(query_set.state().alive, "query_set");
        assertAlive(destination.state().alive, .buffer);
        try expectSameBackend(self.privateState().backend, query_set.selectedBackend());
        try expectSameBackend(self.privateState().backend, destination.selectedBackend());
        const command_tracker = self.privateState().command_buffer.privateState().tracker;
        if (command_tracker != query_set.state().tracker or command_tracker != destination.state().tracker) {
            return RuntimeError.BackendMismatch;
        }
        if (!destination.state().usage_value.copy_destination) return core.CommandEncodingError.InvalidCopyBufferUsage;
        try ensureBufferOwnedByQueue(self.privateState().command_buffer.privateState().queue_kind_value, destination);
        try descriptor.validate(query_set.state().descriptor_value, self.privateState().command_buffer.privateState().limits_value);
        const first: usize = @intCast(descriptor.first_query);
        const count: usize = @intCast(descriptor.query_count);
        try query_set.requireReadyForResolve(descriptor.first_query, descriptor.query_count);
        const byte_count = std.math.mul(u64, descriptor.query_count, @sizeOf(u64)) catch return core.QueryError.InvalidQueryRange;
        const end = std.math.add(u64, descriptor.destination_offset, byte_count) catch return core.QueryError.InvalidQueryRange;
        if (end > destination.length()) return core.QueryError.InvalidQueryRange;
        try self.privateState().command_buffer.retainQuerySetForResolve(query_set);
        errdefer self.privateState().command_buffer.rollbackQuerySetResolveBorrow(query_set);
        if (query_set.state().impl) |*query_impl| {
            if (self.privateState().impl) |*encoder_impl| switch (encoder_impl.*) {
                .vulkan => |*vulkan| switch (query_impl.*) {
                    .vulkan => |*query| vulkan.resolveQuerySet(query, &destination.state().impl.vulkan, descriptor),
                    .metal => unreachable,
                },
                .metal => |*metal| switch (query_impl.*) {
                    .vulkan => unreachable,
                    .metal => |*query| try metal.resolveQuerySet(query, &destination.state().impl.metal, descriptor),
                },
            };
        } else {
            try destination.replaceBytes(
                @intCast(descriptor.destination_offset),
                std.mem.sliceAsBytes(query_set.state().values[first..][0..count]),
            );
        }
        _ = destination.recordUsage(.copy_destination);
    }

    pub fn endEncoding(self: *BlitCommandEncoder) !void {
        assertObjectAlive(self.privateState().alive, "blit_command_encoder");
        try self.privateState().debug_groups.requireEmpty();
        try self.privateState().debug.endEncoding(&self.privateState().command_buffer.privateState().debug);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.endEncoding(),
            .metal => |*metal| {
                try metal.endEncoding();
                metal.deinit();
            },
        };
        self.privateState().alive = false;
    }

    pub fn label(self: BlitCommandEncoder) ?[]const u8 {
        return self.privateState().label_value;
    }

    pub fn setLabel(self: *BlitCommandEncoder, label_value: ?[]const u8) void {
        assertObjectAlive(self.privateState().alive, "blit_command_encoder");
        self.privateState().label_value = label_value;
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.setLabel(label_value),
            .metal => |*metal| metal.setLabel(label_value),
        };
    }

    pub fn pushDebugGroup(self: *BlitCommandEncoder, label_value: []const u8) !void {
        assertObjectAlive(self.privateState().alive, "blit_command_encoder");
        try self.privateState().debug_groups.push(label_value);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.pushDebugGroup(label_value),
            .metal => |*metal| metal.pushDebugGroup(label_value),
        };
    }

    pub fn popDebugGroup(self: *BlitCommandEncoder) !void {
        assertObjectAlive(self.privateState().alive, "blit_command_encoder");
        try self.privateState().debug_groups.pop();
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.popDebugGroup(),
            .metal => |*metal| metal.popDebugGroup(),
        };
    }

    pub fn insertDebugSignpost(self: *BlitCommandEncoder, label_value: []const u8) !void {
        assertObjectAlive(self.privateState().alive, "blit_command_encoder");
        try self.privateState().debug.insertDebugSignpost(.{ .label = label_value });
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.insertDebugSignpost(label_value),
            .metal => |*metal| metal.insertDebugSignpost(label_value),
        };
    }

    pub fn selectedBackend(self: BlitCommandEncoder) core.Backend {
        return self.privateState().backend;
    }
};

fn isFullGenerateMipmapsRange(
    texture: core.TextureDescriptor,
    descriptor: core.ResolvedGenerateMipmapsDescriptor,
) bool {
    const layer_count: u32 = switch (texture.dimension) {
        .one_d, .two_d => texture.depth_or_array_layers,
        .three_d => 1,
    };
    return descriptor.base_mip_level == 0 and
        descriptor.mip_level_count == texture.mip_level_count and
        descriptor.base_array_layer == 0 and
        descriptor.array_layer_count == layer_count;
}

fn commandFormatCapabilities(command_buffer: *const CommandBuffer, format: core.TextureFormat) core.FormatCapabilities {
    if (command_buffer.privateState().runtime_impl) |runtime_impl| {
        return switch (runtime_impl.*) {
            .vulkan => |*vulkan| vulkan.formatCapabilities(format),
            .metal => |*metal| metal.formatCapabilities(format),
        };
    }

    return defaultCommandFormatCapabilities(command_buffer.privateState().backend, format);
}

fn defaultCommandFormatCapabilities(backend: core.Backend, format: core.TextureFormat) core.FormatCapabilities {
    var capabilities = core.defaultFormatCapabilities(format);
    if (backend == .metal) {
        capabilities.blit_source = false;
        capabilities.blit_destination = false;
    }
    return capabilities;
}

fn copySubresourceRange(
    texture: core.TextureDescriptor,
    mip_level: u32,
    slice: u32,
    slice_count: u32,
) core.TextureSubresourceRange {
    return .{
        .base_mip_level = mip_level,
        .mip_level_count = 1,
        .base_array_layer = if (texture.dimension == .three_d) 0 else slice,
        .array_layer_count = if (texture.dimension == .three_d) 1 else slice_count,
    };
}

fn textureSubresourceRangeIsFull(
    range: core.TextureSubresourceRange,
    texture: core.TextureDescriptor,
) bool {
    const resolved = range.resolve(texture) catch return false;
    const layer_count: u32 = if (texture.dimension == .three_d) 1 else texture.depth_or_array_layers;
    return resolved.base_mip_level == 0 and
        resolved.mip_level_count == texture.mip_level_count and
        resolved.base_array_layer == 0 and
        resolved.array_layer_count == layer_count;
}

fn validateResourceTablePipelineBinding(
    table: ResourceTable,
    binding: core.ResourceTableBinding,
    layout_base: u32,
    layout_hashes: []const u64,
) core.BindingError!void {
    if (binding.index < layout_base) return core.BindingError.ResourceTablePipelineLayoutMismatch;
    const local_index = binding.index - layout_base;
    if (local_index >= layout_hashes.len) return core.BindingError.ResourceTablePipelineLayoutMismatch;
    if (layout_hashes[local_index] != table.layoutFingerprint()) {
        return core.BindingError.ResourceTablePipelineLayoutMismatch;
    }
}

pub const ComputeCommandEncoder = struct {
    _state: [@sizeOf(PrivateState)]u8 align(@alignOf(PrivateState)),

    const Impl = union(core.Backend) {
        vulkan: VulkanCommand.ComputeCommandEncoder,
        metal: MetalCommand.ComputeCommandEncoder,
    };

    const PrivateState = struct {
        backend: core.Backend,
        command_buffer: *CommandBuffer,
        label_value: ?[]const u8 = null,
        alive: bool = true,
        debug: core.ComputeCommandEncoderDebugState = .{},
        debug_groups: core.DebugGroupStack = .{},
        active_root_constant_layout: ?core.RootConstantLayoutDescriptor = null,
        active_resource_table_layout_base: u32 = 0,
        active_resource_table_layout_count: u32 = 0,
        active_resource_table_layout_hashes: [core.default_max_bind_group_slots]u64 = @splat(0),
        impl: ?Impl = null,
    };

    fn init(state_value: PrivateState) ComputeCommandEncoder {
        var result: ComputeCommandEncoder = undefined;
        result.privateState().* = state_value;
        return result;
    }

    fn privateState(self: *const ComputeCommandEncoder) *PrivateState {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn setComputePipelineState(
        self: *ComputeCommandEncoder,
        pipeline: *ComputePipelineState,
    ) !void {
        assertObjectAlive(self.privateState().alive, "compute_command_encoder");
        assertAlive(pipeline.state().alive, .compute_pipeline_state);
        try expectSameBackend(self.privateState().backend, pipeline.selectedBackend());
        try self.privateState().debug.setComputePipelineState();
        self.privateState().active_root_constant_layout = pipeline.rootConstantLayout();
        self.privateState().active_resource_table_layout_base = pipeline.resourceTableLayoutBase();
        self.privateState().active_resource_table_layout_count = @intCast(pipeline.resourceTableLayoutHashes().len);
        @memcpy(
            self.privateState().active_resource_table_layout_hashes[0..pipeline.resourceTableLayoutHashes().len],
            pipeline.resourceTableLayoutHashes(),
        );
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.setComputePipelineState(&pipeline.state().impl.vulkan),
            .metal => |*metal| try metal.setComputePipelineState(&pipeline.state().impl.metal),
        };
    }

    pub fn setBindGroup(
        self: *ComputeCommandEncoder,
        bind_group: *BindGroup,
        binding: core.BindGroupBinding,
    ) !void {
        assertObjectAlive(self.privateState().alive, "compute_command_encoder");
        assertAlive(bind_group.state().alive, .bind_group);
        try expectSameBackend(self.privateState().backend, bind_group.selectedBackend());
        try validateDynamicOffsetsForBindGroup(bind_group.*, binding);
        try self.privateState().debug.setBindGroup(binding);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.setBindGroup(&bind_group.state().impl.?.vulkan, binding),
            .metal => |*metal| try metal.setBindGroup(&bind_group.state().impl.?.metal, binding),
        };
    }

    pub fn setResourceTable(
        self: *ComputeCommandEncoder,
        table: *ResourceTable,
        binding: core.ResourceTableBinding,
    ) !void {
        assertObjectAlive(self.privateState().alive, "compute_command_encoder");
        assertObjectAlive(table.state().alive, "resource_table");
        try expectSameBackend(self.privateState().backend, table.selectedBackend());
        try binding.validate();
        if (!table.supportsComputeEncoding()) return core.BindingError.ResourceTableVisibilityMismatch;
        try table.validateReadyForBinding();
        try validateResourceTablePipelineBinding(
            table.*,
            binding,
            self.privateState().active_resource_table_layout_base,
            self.privateState().active_resource_table_layout_hashes[0..self.privateState().active_resource_table_layout_count],
        );
        try self.privateState().debug.setResourceTable(binding);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.setResourceTable(&table.state().impl.?.vulkan, binding),
            .metal => |*metal| try metal.setResourceTable(&table.state().impl.?.metal, binding),
        };
        try table.markBoundForCommands();
    }

    pub fn setRootConstants(
        self: *ComputeCommandEncoder,
        descriptor: core.RootConstantWriteDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "compute_command_encoder");
        const range = try validateRootConstantWriteForStages(
            self.privateState().active_root_constant_layout,
            descriptor,
            .{ .compute = true },
        );
        try self.privateState().debug.setRootConstants();
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.setRootConstants(descriptor, range.visibility),
            .metal => |*metal| try metal.setRootConstants(descriptor, range.visibility),
        };
    }

    pub fn dispatchThreadgroups(
        self: *ComputeCommandEncoder,
        descriptor: core.DispatchThreadgroupsDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "compute_command_encoder");
        try self.privateState().debug.dispatchThreadgroups(descriptor);
        try descriptor.validateForLimits(core.defaultDeviceLimits(self.privateState().backend));
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.dispatchThreadgroups(descriptor),
            .metal => |*metal| try metal.dispatchThreadgroups(descriptor),
        };
    }

    pub fn dispatchThreads(
        self: *ComputeCommandEncoder,
        descriptor: core.DispatchThreadsDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "compute_command_encoder");
        const resolved = try self.privateState().debug.dispatchThreads(
            descriptor,
            core.defaultDeviceLimits(self.privateState().backend),
        );
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.dispatchThreadgroups(resolved),
            .metal => |*metal| try metal.dispatchThreadgroups(resolved),
        };
    }

    pub fn dispatchThreadgroupsIndirect(
        self: *ComputeCommandEncoder,
        indirect_buffer: *Buffer,
        descriptor: core.DispatchThreadgroupsIndirectDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "compute_command_encoder");
        assertAlive(indirect_buffer.state().alive, .buffer);
        try expectSameBackend(self.privateState().backend, indirect_buffer.selectedBackend());
        if (!indirect_buffer.state().usage_value.indirect) return core.CommandEncodingError.InvalidIndirectBufferUsage;
        try ensureBufferOwnedByQueue(self.privateState().command_buffer.privateState().queue_kind_value, indirect_buffer);
        try self.privateState().debug.dispatchThreadgroupsIndirect(
            descriptor,
            indirect_buffer.length(),
            .{ .compute_dispatch_indirect = true },
            core.defaultDeviceLimits(self.privateState().backend),
        );
        _ = indirect_buffer.recordUsage(.indirect_buffer);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.dispatchThreadgroupsIndirect(&indirect_buffer.state().impl.vulkan, descriptor),
            .metal => |*metal| try metal.dispatchThreadgroupsIndirect(&indirect_buffer.state().impl.metal, descriptor),
        };
    }

    pub fn executeIndirectCommands(
        self: *ComputeCommandEncoder,
        buffer: *IndirectCommandBuffer,
        range: core.IndirectCommandRange,
    ) !void {
        assertObjectAlive(self.privateState().alive, "compute_command_encoder");
        assertObjectAlive(buffer.state().alive, "indirect_command_buffer");
        try expectSameBackend(self.privateState().backend, buffer.selectedBackend());
        try buffer.validateExecution(.compute, range);
        const commands = buffer.state().commands[range.location..][0..range.count];
        for (commands) |command| try self.privateState().debug.dispatchThreadgroups(command.?.compute);

        var native_executed = false;
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => {},
            .metal => |*metal| switch (buffer.state().impl) {
                .metal => |*metal_buffer| native_executed = try metal.executeIndirectCommands(metal_buffer, range),
                .vulkan => unreachable,
            },
        };
        if (native_executed) return;
        for (commands) |command| {
            const descriptor = command.?.compute;
            if (self.privateState().impl) |*impl| switch (impl.*) {
                .vulkan => |*vulkan| try vulkan.dispatchThreadgroups(descriptor),
                .metal => |*metal| try metal.dispatchThreadgroups(descriptor),
            };
        }
    }

    pub fn bufferBarrier(
        self: *ComputeCommandEncoder,
        buffer: *Buffer,
        descriptor: core.BufferBarrierDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "compute_command_encoder");
        try ensureBufferOwnedByQueue(self.privateState().command_buffer.privateState().queue_kind_value, buffer);
        try recordBufferBarrier(self.privateState().backend, self.privateState().command_buffer.privateState().features_value, buffer, descriptor);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.bufferBarrier(&buffer.state().impl.vulkan, descriptor),
            .metal => |*metal| try metal.bufferBarrier(&buffer.state().impl.metal, descriptor),
        };
    }

    pub fn textureBarrier(
        self: *ComputeCommandEncoder,
        texture: *Texture,
        descriptor: core.TextureBarrierDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "compute_command_encoder");
        try ensureTextureOwnedByQueue(self.privateState().command_buffer.privateState().queue_kind_value, texture);
        try recordTextureBarrier(self.privateState().backend, self.privateState().command_buffer.privateState().features_value, texture, descriptor);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.textureBarrier(&texture.state().impl.vulkan, descriptor),
            .metal => |*metal| try metal.textureBarrier(&texture.state().impl.metal, descriptor),
        };
    }

    pub fn bufferOwnershipTransfer(
        self: *ComputeCommandEncoder,
        buffer: *Buffer,
        descriptor: core.QueueOwnershipTransferDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "compute_command_encoder");
        if (self.privateState().command_buffer.privateState().queue_kind_value != descriptor.source) return core.CommandEncodingError.InvalidQueueOwnershipState;
        try recordBufferOwnershipTransfer(self.privateState().command_buffer.privateState().features_value, buffer, descriptor);
    }

    pub fn textureOwnershipTransfer(
        self: *ComputeCommandEncoder,
        texture: *Texture,
        descriptor: core.QueueOwnershipTransferDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "compute_command_encoder");
        if (self.privateState().command_buffer.privateState().queue_kind_value != descriptor.source) return core.CommandEncodingError.InvalidQueueOwnershipState;
        try recordTextureOwnershipTransfer(self.privateState().command_buffer.privateState().features_value, texture, descriptor);
    }

    pub fn writeTimestamp(self: *ComputeCommandEncoder, query_set: *QuerySet, query_index: u32) !void {
        assertObjectAlive(self.privateState().alive, "compute_command_encoder");
        assertObjectAlive(query_set.state().alive, "query_set");
        try expectSameBackend(self.privateState().backend, query_set.selectedBackend());
        if (self.privateState().command_buffer.privateState().tracker != query_set.state().tracker) {
            return RuntimeError.BackendMismatch;
        }
        try query_set.prepareTimestamp(query_index);
        if (query_set.state().impl) |*query_impl| {
            if (self.privateState().impl) |*encoder_impl| switch (encoder_impl.*) {
                .vulkan => |*vulkan| switch (query_impl.*) {
                    .vulkan => |*query| vulkan.writeTimestamp(query, query_index),
                    .metal => unreachable,
                },
                .metal => |*metal| switch (query_impl.*) {
                    .vulkan => unreachable,
                    .metal => |*query| try metal.writeTimestamp(query, query_index),
                },
            };
        }
        query_set.markTimestamp(query_index);
    }

    pub fn insertNativeCommands(self: *ComputeCommandEncoder, descriptor: core.NativeCommandInsertionDescriptor) !void {
        assertObjectAlive(self.privateState().alive, "compute_command_encoder");
        try insertNativeCommandsForEncoder(self.privateState().command_buffer, .compute, descriptor);
    }

    pub fn endEncoding(self: *ComputeCommandEncoder) !void {
        assertObjectAlive(self.privateState().alive, "compute_command_encoder");
        try self.privateState().debug_groups.requireEmpty();
        try self.privateState().debug.endEncoding(&self.privateState().command_buffer.privateState().debug);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.endEncoding(),
            .metal => |*metal| {
                try metal.endEncoding();
                metal.deinit();
            },
        };
        self.privateState().alive = false;
    }

    pub fn label(self: ComputeCommandEncoder) ?[]const u8 {
        return self.privateState().label_value;
    }

    pub fn setLabel(self: *ComputeCommandEncoder, label_value: ?[]const u8) void {
        assertObjectAlive(self.privateState().alive, "compute_command_encoder");
        self.privateState().label_value = label_value;
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.setLabel(label_value),
            .metal => |*metal| metal.setLabel(label_value),
        };
    }

    pub fn pushDebugGroup(self: *ComputeCommandEncoder, label_value: []const u8) !void {
        assertObjectAlive(self.privateState().alive, "compute_command_encoder");
        try self.privateState().debug_groups.push(label_value);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.pushDebugGroup(label_value),
            .metal => |*metal| metal.pushDebugGroup(label_value),
        };
    }

    pub fn popDebugGroup(self: *ComputeCommandEncoder) !void {
        assertObjectAlive(self.privateState().alive, "compute_command_encoder");
        try self.privateState().debug_groups.pop();
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.popDebugGroup(),
            .metal => |*metal| metal.popDebugGroup(),
        };
    }

    pub fn insertDebugSignpost(self: *ComputeCommandEncoder, label_value: []const u8) !void {
        assertObjectAlive(self.privateState().alive, "compute_command_encoder");
        try self.privateState().debug.insertDebugSignpost(.{ .label = label_value });
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.insertDebugSignpost(label_value),
            .metal => |*metal| metal.insertDebugSignpost(label_value),
        };
    }

    pub fn selectedBackend(self: ComputeCommandEncoder) core.Backend {
        return self.privateState().backend;
    }
};

pub const RenderCommandEncoder = struct {
    _state: [@sizeOf(PrivateState)]u8 align(@alignOf(PrivateState)),

    const Impl = union(core.Backend) {
        vulkan: VulkanCommand.RenderCommandEncoder,
        metal: MetalCommand.RenderCommandEncoder,
    };

    const PrivateState = struct {
        backend: core.Backend,
        command_buffer: *CommandBuffer,
        label_value: ?[]const u8 = null,
        alive: bool = true,
        debug: core.RenderCommandEncoderDebugState = .{},
        debug_groups: core.DebugGroupStack = .{},
        active_root_constant_layout: ?core.RootConstantLayoutDescriptor = null,
        active_resource_table_layout_base: u32 = 0,
        active_resource_table_layout_count: u32 = 0,
        active_resource_table_layout_hashes: [core.default_max_bind_group_slots]u64 = @splat(0),
        active_pipeline_kind: RenderPipelineState.Kind = .ordinary,
        active_tessellation: ?core.TessellationDescriptor = null,
        active_mesh_pipeline_hash: u64 = 0,
        active_mesh_limits: core.DeviceLimits = .{},
        occlusion_query_set: ?*QuerySet = null,
        impl: ?Impl = null,
    };

    fn init(state_value: PrivateState) RenderCommandEncoder {
        var result: RenderCommandEncoder = undefined;
        result.privateState().* = state_value;
        return result;
    }

    fn privateState(self: *const RenderCommandEncoder) *PrivateState {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn setRenderPipelineState(
        self: *RenderCommandEncoder,
        pipeline: *RenderPipelineState,
    ) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        assertAlive(pipeline.state().alive, .render_pipeline_state);
        try expectSameBackend(self.privateState().backend, pipeline.selectedBackend());
        try self.privateState().debug.setRenderPipelineState();
        self.privateState().active_root_constant_layout = pipeline.rootConstantLayout();
        self.privateState().active_resource_table_layout_base = pipeline.resourceTableLayoutBase();
        self.privateState().active_resource_table_layout_count = @intCast(pipeline.resourceTableLayoutHashes().len);
        self.privateState().active_pipeline_kind = pipeline.kind();
        self.privateState().active_tessellation = pipeline.tessellationDescriptor();
        self.privateState().active_mesh_pipeline_hash = pipeline.meshPipelineHash();
        self.privateState().active_mesh_limits = pipeline.meshLimits();
        @memcpy(
            self.privateState().active_resource_table_layout_hashes[0..pipeline.resourceTableLayoutHashes().len],
            pipeline.resourceTableLayoutHashes(),
        );
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.setRenderPipelineState(&pipeline.state().impl.vulkan),
            .metal => |*metal| try metal.setRenderPipelineState(&pipeline.state().impl.metal),
        };
    }

    pub fn setVertexBuffer(
        self: *RenderCommandEncoder,
        buffer: *Buffer,
        binding: core.VertexBufferBinding,
    ) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        assertAlive(buffer.state().alive, .buffer);
        try expectSameBackend(self.privateState().backend, buffer.selectedBackend());
        try ensureBufferOwnedByQueue(self.privateState().command_buffer.privateState().queue_kind_value, buffer);
        try self.privateState().debug.setVertexBuffer(binding);
        _ = buffer.recordUsage(.vertex_buffer);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.setVertexBuffer(&buffer.state().impl.vulkan, binding),
            .metal => |*metal| try metal.setVertexBuffer(&buffer.state().impl.metal, binding),
        };
    }

    pub fn setIndexBuffer(self: *RenderCommandEncoder, buffer: *Buffer) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        assertAlive(buffer.state().alive, .buffer);
        try expectSameBackend(self.privateState().backend, buffer.selectedBackend());
        try ensureBufferOwnedByQueue(self.privateState().command_buffer.privateState().queue_kind_value, buffer);
        try self.privateState().debug.setIndexBuffer();
        _ = buffer.recordUsage(.index_buffer);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.setIndexBuffer(&buffer.state().impl.vulkan),
            .metal => |*metal| try metal.setIndexBuffer(&buffer.state().impl.metal),
        };
    }

    pub fn setBindGroup(
        self: *RenderCommandEncoder,
        bind_group: *BindGroup,
        binding: core.BindGroupBinding,
    ) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        assertAlive(bind_group.state().alive, .bind_group);
        try expectSameBackend(self.privateState().backend, bind_group.selectedBackend());
        try validateDynamicOffsetsForBindGroup(bind_group.*, binding);
        try self.privateState().debug.setBindGroup(binding);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.setBindGroup(&bind_group.state().impl.?.vulkan, binding),
            .metal => |*metal| try metal.setBindGroup(&bind_group.state().impl.?.metal, binding),
        };
    }

    pub fn setResourceTable(
        self: *RenderCommandEncoder,
        table: *ResourceTable,
        binding: core.ResourceTableBinding,
    ) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        assertObjectAlive(table.state().alive, "resource_table");
        try expectSameBackend(self.privateState().backend, table.selectedBackend());
        try binding.validate();
        if (!table.supportsRenderEncoding()) return core.BindingError.ResourceTableVisibilityMismatch;
        try table.validateReadyForBinding();
        try validateResourceTablePipelineBinding(
            table.*,
            binding,
            self.privateState().active_resource_table_layout_base,
            self.privateState().active_resource_table_layout_hashes[0..self.privateState().active_resource_table_layout_count],
        );
        try self.privateState().debug.setResourceTable(binding);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.setResourceTable(&table.state().impl.?.vulkan, binding),
            .metal => |*metal| try metal.setResourceTable(&table.state().impl.?.metal, binding),
        };
        try table.markBoundForCommands();
    }

    pub fn setRootConstants(
        self: *RenderCommandEncoder,
        descriptor: core.RootConstantWriteDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        const range = try validateRootConstantWriteForStages(
            self.privateState().active_root_constant_layout,
            descriptor,
            .{ .vertex = true, .fragment = true },
        );
        try self.privateState().debug.setRootConstants();
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.setRootConstants(descriptor, range.visibility),
            .metal => |*metal| try metal.setRootConstants(descriptor, range.visibility),
        };
    }

    pub fn setViewport(self: *RenderCommandEncoder, viewport: core.Viewport) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        try self.privateState().debug.setViewport(viewport);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.setViewport(viewport),
            .metal => |*metal| try metal.setViewport(viewport),
        };
    }

    pub fn setScissorRect(self: *RenderCommandEncoder, rect: core.ScissorRect) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        try self.privateState().debug.setScissorRect(rect);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.setScissorRect(rect),
            .metal => |*metal| try metal.setScissorRect(rect),
        };
    }

    pub fn setBlendColor(self: *RenderCommandEncoder, color: core.BlendColor) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        try self.privateState().debug.setBlendColor(color);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.setBlendColor(color),
            .metal => |*metal| try metal.setBlendColor(color),
        };
    }

    pub fn setStencilReference(self: *RenderCommandEncoder, reference: core.StencilReference) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        try self.privateState().debug.setStencilReference(reference);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.setStencilReference(reference),
            .metal => |*metal| try metal.setStencilReference(reference),
        };
    }

    pub fn setDepthBias(self: *RenderCommandEncoder, descriptor: core.DepthBiasDescriptor) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        try self.privateState().debug.setDepthBias(descriptor);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.setDepthBias(descriptor),
            .metal => |*metal| try metal.setDepthBias(descriptor),
        };
    }

    pub fn beginOcclusionQuery(self: *RenderCommandEncoder, query_set: *QuerySet, query_index: u32) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        assertObjectAlive(query_set.state().alive, "query_set");
        try expectSameBackend(self.privateState().backend, query_set.selectedBackend());
        try query_set.validateQueryType(.occlusion);
        if (self.privateState().occlusion_query_set != query_set) return core.CommandEncodingError.InvalidRenderCommandEncoderState;
        try query_set.prepareBeginOcclusionQuery(query_index);
        if (query_set.state().impl) |*query_impl| {
            if (self.privateState().impl) |*encoder_impl| switch (encoder_impl.*) {
                .vulkan => |*vulkan| switch (query_impl.*) {
                    .vulkan => |*query| vulkan.beginOcclusionQuery(query, query_index),
                    .metal => unreachable,
                },
                .metal => |*metal| switch (query_impl.*) {
                    .vulkan => unreachable,
                    .metal => |*query| try metal.beginOcclusionQuery(query, query_index),
                },
            };
        }
        query_set.markBeginOcclusionQuery(query_index, @ptrCast(self.privateState()));
    }

    pub fn endOcclusionQuery(self: *RenderCommandEncoder, query_set: *QuerySet) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        assertObjectAlive(query_set.state().alive, "query_set");
        try expectSameBackend(self.privateState().backend, query_set.selectedBackend());
        if (self.privateState().occlusion_query_set != query_set) return core.CommandEncodingError.InvalidRenderCommandEncoderState;
        if (query_set.state().active_occlusion_encoder != @as(*const anyopaque, @ptrCast(self.privateState()))) {
            return core.CommandEncodingError.InvalidRenderCommandEncoderState;
        }
        const query_index = try query_set.prepareEndOcclusionQuery();
        if (query_set.state().impl) |*query_impl| {
            if (self.privateState().impl) |*encoder_impl| switch (encoder_impl.*) {
                .vulkan => |*vulkan| switch (query_impl.*) {
                    .vulkan => |*query| vulkan.endOcclusionQuery(query, query_index),
                    .metal => unreachable,
                },
                .metal => |*metal| switch (query_impl.*) {
                    .vulkan => unreachable,
                    .metal => |*query| try metal.endOcclusionQuery(query),
                },
            };
        }
        query_set.markEndOcclusionQuery(query_index);
    }

    pub fn writeTimestamp(self: *RenderCommandEncoder, query_set: *QuerySet, query_index: u32) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        assertObjectAlive(query_set.state().alive, "query_set");
        try expectSameBackend(self.privateState().backend, query_set.selectedBackend());
        if (self.privateState().command_buffer.privateState().tracker != query_set.state().tracker) {
            return RuntimeError.BackendMismatch;
        }
        try query_set.prepareTimestamp(query_index);
        if (query_set.state().impl) |*query_impl| {
            if (self.privateState().impl) |*encoder_impl| switch (encoder_impl.*) {
                .vulkan => |*vulkan| switch (query_impl.*) {
                    .vulkan => |*query| vulkan.writeTimestamp(query, query_index),
                    .metal => unreachable,
                },
                .metal => |*metal| switch (query_impl.*) {
                    .vulkan => unreachable,
                    .metal => |*query| try metal.writeTimestamp(query, query_index),
                },
            };
        }
        query_set.markTimestamp(query_index);
    }

    pub fn insertNativeCommands(self: *RenderCommandEncoder, descriptor: core.NativeCommandInsertionDescriptor) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        try insertNativeCommandsForEncoder(self.privateState().command_buffer, .render, descriptor);
    }

    pub fn drawPrimitives(
        self: *RenderCommandEncoder,
        descriptor: core.DrawPrimitivesDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        try self.privateState().debug.drawPrimitives(descriptor);
        try validateDrawPrimitivesLowering(descriptor, .{ .draw_base_instance = true });
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.drawPrimitives(descriptor),
            .metal => |*metal| try metal.drawPrimitives(descriptor),
        };
    }

    pub fn drawTessellationPatches(
        self: *RenderCommandEncoder,
        descriptor: core.TessellationPatchDrawDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        if (self.privateState().active_pipeline_kind != .tessellation) {
            return core.CommandEncodingError.InvalidRenderCommandEncoderState;
        }
        const pipeline_tessellation = self.privateState().active_tessellation orelse
            return core.CommandEncodingError.InvalidRenderCommandEncoderState;
        if (pipeline_tessellation.control_point_count != descriptor.tessellation.control_point_count or
            pipeline_tessellation.domain != descriptor.tessellation.domain or
            pipeline_tessellation.partition_mode != descriptor.tessellation.partition_mode)
        {
            return core.AdvancedFeatureError.InvalidTessellationPatchDraw;
        }
        const plan = try core.TessellationDrawPlan.fromDescriptor(
            self.privateState().backend,
            descriptor,
            .{ .tessellation = true },
            .{ .max_tessellation_control_points = pipeline_tessellation.control_point_count },
        );
        const lowering = try core.vulkanTessellationDrawLowering(plan);
        try self.privateState().debug.drawPrimitives(.{
            .vertex_start = lowering.first_vertex,
            .vertex_count = lowering.draw_vertex_count,
            .instance_count = lowering.draw_instance_count,
            .base_instance = lowering.first_instance,
        });
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.drawTessellationPatches(descriptor),
            .metal => return core.AdvancedFeatureError.UnsupportedTessellation,
        };
    }

    pub fn drawMeshThreadgroups(
        self: *RenderCommandEncoder,
        descriptor: core.MeshDispatchDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        if (self.privateState().active_pipeline_kind != .mesh or
            self.privateState().active_mesh_pipeline_hash != hashMeshPipelineDescriptor(self.privateState().backend, descriptor.pipeline))
        {
            return core.CommandEncodingError.InvalidRenderCommandEncoderState;
        }
        const limits = self.privateState().active_mesh_limits;
        const features = core.DeviceFeatures{
            .mesh_shaders = true,
            .task_shaders = descriptor.pipeline.task_entry_point != null,
        };
        _ = try core.MeshDispatchPlan.fromDescriptor(
            self.privateState().backend,
            descriptor,
            features,
            limits,
        );
        try self.privateState().debug.drawPrimitives(.{ .vertex_count = 1 });
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.drawMeshThreadgroups(descriptor, limits),
            .metal => |*metal| try metal.drawMeshThreadgroups(descriptor, limits),
        };
    }

    pub fn executeIndirectCommands(
        self: *RenderCommandEncoder,
        buffer: *IndirectCommandBuffer,
        range: core.IndirectCommandRange,
    ) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        assertObjectAlive(buffer.state().alive, "indirect_command_buffer");
        try expectSameBackend(self.privateState().backend, buffer.selectedBackend());
        try buffer.validateExecution(.render, range);
        const commands = buffer.state().commands[range.location..][0..range.count];
        for (commands) |command| try self.privateState().debug.drawPrimitives(command.?.render);

        var native_executed = false;
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => {},
            .metal => |*metal| switch (buffer.state().impl) {
                .metal => |*metal_buffer| native_executed = try metal.executeIndirectCommands(metal_buffer, range),
                .vulkan => unreachable,
            },
        };
        if (native_executed) return;
        for (commands) |command| {
            const descriptor = command.?.render;
            if (self.privateState().impl) |*impl| switch (impl.*) {
                .vulkan => |*vulkan| try vulkan.drawPrimitives(descriptor),
                .metal => |*metal| try metal.drawPrimitives(descriptor),
            };
        }
    }

    pub fn drawIndexedPrimitives(
        self: *RenderCommandEncoder,
        descriptor: core.DrawIndexedPrimitivesDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        try self.privateState().debug.drawIndexedPrimitives(descriptor);
        try validateDrawIndexedPrimitivesLowering(descriptor, .{
            .draw_base_vertex = true,
            .draw_base_instance = true,
        });
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.drawIndexedPrimitives(descriptor),
            .metal => |*metal| try metal.drawIndexedPrimitives(descriptor),
        };
    }

    pub fn drawPrimitivesIndirect(
        self: *RenderCommandEncoder,
        indirect_buffer: *Buffer,
        descriptor: core.DrawPrimitivesIndirectDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        assertAlive(indirect_buffer.state().alive, .buffer);
        try expectSameBackend(self.privateState().backend, indirect_buffer.selectedBackend());
        if (!indirect_buffer.state().usage_value.indirect) return core.CommandEncodingError.InvalidIndirectBufferUsage;
        try ensureBufferOwnedByQueue(self.privateState().command_buffer.privateState().queue_kind_value, indirect_buffer);
        try self.privateState().debug.drawPrimitivesIndirect(descriptor);
        try validateIndirectDrawRange(descriptor.buffer_offset, descriptor.draw_count, descriptor.stride, indirect_buffer.length(), 16);
        _ = indirect_buffer.recordUsage(.indirect_buffer);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| {
                var draw = descriptor;
                draw.draw_count = 1;
                draw.stride = 0;
                for (0..@as(usize, @intCast(descriptor.draw_count))) |draw_index| {
                    draw.buffer_offset = descriptor.buffer_offset + @as(u64, @intCast(draw_index)) * indirectDrawStride(descriptor.stride, 16);
                    try vulkan.drawPrimitivesIndirect(&indirect_buffer.state().impl.vulkan, draw);
                }
            },
            .metal => |*metal| {
                var draw = descriptor;
                draw.draw_count = 1;
                draw.stride = 0;
                for (0..@as(usize, @intCast(descriptor.draw_count))) |draw_index| {
                    draw.buffer_offset = descriptor.buffer_offset + @as(u64, @intCast(draw_index)) * indirectDrawStride(descriptor.stride, 16);
                    try metal.drawPrimitivesIndirect(&indirect_buffer.state().impl.metal, draw);
                }
            },
        };
    }

    pub fn drawIndexedPrimitivesIndirect(
        self: *RenderCommandEncoder,
        indirect_buffer: *Buffer,
        descriptor: core.DrawIndexedPrimitivesIndirectDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        assertAlive(indirect_buffer.state().alive, .buffer);
        try expectSameBackend(self.privateState().backend, indirect_buffer.selectedBackend());
        if (!indirect_buffer.state().usage_value.indirect) return core.CommandEncodingError.InvalidIndirectBufferUsage;
        try ensureBufferOwnedByQueue(self.privateState().command_buffer.privateState().queue_kind_value, indirect_buffer);
        try self.privateState().debug.drawIndexedPrimitivesIndirect(descriptor);
        try validateIndirectDrawRange(descriptor.buffer_offset, descriptor.draw_count, descriptor.stride, indirect_buffer.length(), 20);
        _ = indirect_buffer.recordUsage(.indirect_buffer);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| {
                var draw = descriptor;
                draw.draw_count = 1;
                draw.stride = 0;
                for (0..@as(usize, @intCast(descriptor.draw_count))) |draw_index| {
                    draw.buffer_offset = descriptor.buffer_offset + @as(u64, @intCast(draw_index)) * indirectDrawStride(descriptor.stride, 20);
                    try vulkan.drawIndexedPrimitivesIndirect(&indirect_buffer.state().impl.vulkan, draw);
                }
            },
            .metal => |*metal| {
                var draw = descriptor;
                draw.draw_count = 1;
                draw.stride = 0;
                for (0..@as(usize, @intCast(descriptor.draw_count))) |draw_index| {
                    draw.buffer_offset = descriptor.buffer_offset + @as(u64, @intCast(draw_index)) * indirectDrawStride(descriptor.stride, 20);
                    try metal.drawIndexedPrimitivesIndirect(&indirect_buffer.state().impl.metal, draw);
                }
            },
        };
    }

    pub fn drawPrimitivesMulti(
        self: *RenderCommandEncoder,
        descriptor: core.MultiDrawPrimitivesDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        try self.privateState().debug.drawPrimitivesMulti(descriptor);
        for (descriptor.draws) |draw| {
            try self.drawPrimitives(draw);
        }
    }

    pub fn drawIndexedPrimitivesMulti(
        self: *RenderCommandEncoder,
        descriptor: core.MultiDrawIndexedPrimitivesDescriptor,
    ) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        try self.privateState().debug.drawIndexedPrimitivesMulti(descriptor);
        for (descriptor.draws) |draw| {
            try self.drawIndexedPrimitives(draw);
        }
    }

    pub fn endEncoding(self: *RenderCommandEncoder) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        if (self.privateState().occlusion_query_set) |query_set| {
            assertObjectAlive(query_set.state().alive, "query_set");
            if (query_set.state().active_occlusion_query != null) return core.QueryError.QueryNotReady;
        }
        try self.privateState().debug_groups.requireEmpty();
        try self.privateState().debug.endEncoding(&self.privateState().command_buffer.privateState().debug);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| try vulkan.endEncoding(),
            .metal => |*metal| {
                try metal.endEncoding();
                metal.deinit();
            },
        };
        self.privateState().alive = false;
    }

    pub fn label(self: RenderCommandEncoder) ?[]const u8 {
        return self.privateState().label_value;
    }

    pub fn setLabel(self: *RenderCommandEncoder, label_value: ?[]const u8) void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        self.privateState().label_value = label_value;
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.setLabel(label_value),
            .metal => |*metal| metal.setLabel(label_value),
        };
    }

    pub fn pushDebugGroup(self: *RenderCommandEncoder, label_value: []const u8) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        try self.privateState().debug_groups.push(label_value);
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.pushDebugGroup(label_value),
            .metal => |*metal| metal.pushDebugGroup(label_value),
        };
    }

    pub fn popDebugGroup(self: *RenderCommandEncoder) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        try self.privateState().debug_groups.pop();
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.popDebugGroup(),
            .metal => |*metal| metal.popDebugGroup(),
        };
    }

    pub fn insertDebugSignpost(self: *RenderCommandEncoder, label_value: []const u8) !void {
        assertObjectAlive(self.privateState().alive, "render_command_encoder");
        try self.privateState().debug.insertDebugSignpost(.{ .label = label_value });
        if (self.privateState().impl) |*impl| switch (impl.*) {
            .vulkan => |*vulkan| vulkan.insertDebugSignpost(label_value),
            .metal => |*metal| metal.insertDebugSignpost(label_value),
        };
    }

    pub fn selectedBackend(self: RenderCommandEncoder) core.Backend {
        return self.privateState().backend;
    }
};

pub const WindowContextOptions = struct {
    app_name: [*:0]const u8,
    backend: core.BackendPreference = .auto,
    adapter_selection: core.AdapterSelectionDescriptor = .{},
    debug_backend_override: ?core.Backend = null,
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
    UnsupportedRenderPassAttachmentAction,
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

const RuntimeState = struct {
    allocator: std.mem.Allocator,
    tracker: *ResourceTracker,
    backend: core.Backend,
    presentation_available: bool = true,
    surface_descriptor: core.SurfaceDescriptor,
    presentation_descriptor: core.PresentationDescriptor,
    adapter_info: core.AdapterInfo,
    capability_report: core.DeviceCapabilityReport,
    native_gpu_timestamp_queries: bool = false,
    owned_adapter_name: ?[]u8 = null,
    impl: BackendRuntime,
};

fn runtimeState(pointer: *anyopaque) *RuntimeState {
    return @ptrCast(@alignCast(pointer));
}

pub const Surface = struct {
    _state: *anyopaque,

    fn state(self: Surface) *RuntimeState {
        return runtimeState(self._state);
    }

    pub fn selectedBackend(self: Surface) core.Backend {
        return self.state().backend;
    }

    pub fn descriptor(self: Surface) core.SurfaceDescriptor {
        return self.state().surface_descriptor;
    }

    pub fn provider(self: Surface) ?core.SurfaceProvider {
        const source = self.state().surface_descriptor.source orelse return null;
        return source.provider;
    }

    pub fn swapchain(self: *Surface) Swapchain {
        return .{ ._state = self._state };
    }
};

pub const Swapchain = struct {
    _state: *anyopaque,

    fn state(self: Swapchain) *RuntimeState {
        return runtimeState(self._state);
    }

    pub fn selectedBackend(self: Swapchain) core.Backend {
        return self.state().backend;
    }

    pub fn presentationDescriptor(self: Swapchain) core.PresentationDescriptor {
        return self.state().presentation_descriptor;
    }

    pub fn extent(self: Swapchain) core.Extent2D {
        return self.state().presentation_descriptor.extent;
    }

    pub fn resize(self: *Swapchain, new_extent: core.Extent2D) !void {
        switch (self.state().impl) {
            .vulkan => |*vulkan| try vulkan.resize(new_extent),
            .metal => |*metal| try metal.resize(new_extent),
        }
        if (!new_extent.isZero()) {
            self.state().presentation_descriptor.extent = new_extent;
        }
    }

    pub fn clear(self: *Swapchain, color: ClearColor) !void {
        switch (self.state().impl) {
            .vulkan => |*vulkan| try vulkan.clear(color),
            .metal => |*metal| try metal.clear(color),
        }
    }
};

pub const Queue = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const State = struct {
        runtime: *anyopaque,
        label: ?[]const u8 = null,
        kind: core.QueueKind = .graphics,
    };

    fn init(state_value: State) Queue {
        var result: Queue = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const Queue) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    fn runtime(self: Queue) *RuntimeState {
        return runtimeState(self.state().runtime);
    }

    pub fn selectedBackend(self: Queue) core.Backend {
        return self.runtime().backend;
    }

    pub fn kind(self: Queue) core.QueueKind {
        return self.state().kind;
    }

    pub fn label(self: Queue) ?[]const u8 {
        return self.state().label;
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
            self.runtime().capability_report.features,
        );
        const impl = switch (self.runtime().impl) {
            .vulkan => |*vulkan| CommandBuffer.Impl{ .vulkan = try vulkan.makeCommandBuffer(self.state().kind) },
            .metal => |*metal| CommandBuffer.Impl{ .metal = try metal.makeCommandBuffer(self.state().kind) },
        };
        var command_buffer = CommandBuffer.init(.{
            .backend = self.runtime().backend,
            .tracker = self.runtime().tracker,
            .runtime_impl = &self.runtime().impl,
            .presentation_available = self.runtime().presentation_available,
            .label_value = descriptor.label,
            .queue_kind_value = self.state().kind,
            .features_value = self.runtime().capability_report.features,
            .limits_value = self.runtime().capability_report.limits,
            .lifecycle_callback = descriptor.lifecycle_callback,
            .lifecycle_context = descriptor.lifecycle_context,
            .debug = debug,
            .impl = impl,
        });
        command_buffer.setLabel(descriptor.label);
        return command_buffer;
    }
};

pub const Device = struct {
    _state: *anyopaque,

    fn state(self: Device) *RuntimeState {
        return runtimeState(self._state);
    }

    pub fn selectedBackend(self: Device) core.Backend {
        return self.state().backend;
    }

    pub fn adapterInfo(self: Device) core.AdapterInfo {
        return self.state().adapter_info;
    }

    pub fn features(self: Device) core.DeviceFeatures {
        return self.state().capability_report.features;
    }

    pub fn nativeFeatures(self: Device) core.DeviceFeatures {
        return self.state().capability_report.native_features;
    }

    pub fn limits(self: Device) core.DeviceLimits {
        return self.state().capability_report.limits;
    }

    pub fn capabilityReport(self: Device) core.DeviceCapabilityReport {
        return self.state().capability_report;
    }

    fn validateDescriptorIndexingLayout(self: Device, descriptor: core.DescriptorIndexingLayoutDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.features(), self.limits());
    }

    fn planResourceTablePressure(self: Device, descriptor: core.ResourceTablePressureDescriptor) core.AdvancedFeatureError!core.ResourceTablePressurePlan {
        return try descriptor.plan(self.features(), self.limits());
    }

    fn validateSparseMappingCommit(self: Device, descriptor: core.SparseMappingCommitDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.features(), self.limits());
    }

    fn planSparseMappingCommit(self: Device, descriptor: core.SparseMappingCommitDescriptor) core.AdvancedFeatureError!core.SparseMappingCommitPlan {
        return try descriptor.plan(self.nativeFeatures(), self.limits());
    }

    fn planSparseResidencyChurn(self: Device, descriptor: core.SparseResidencyChurnDescriptor) core.AdvancedFeatureError!core.SparseResidencyChurnPlan {
        return try descriptor.plan(self.nativeFeatures(), self.limits());
    }

    fn validateSparseBufferDescriptor(self: Device, descriptor: core.SparseBufferDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.features(), self.limits());
    }

    fn planSparseBufferLowering(self: Device, descriptor: core.SparseBufferDescriptor) core.AdvancedFeatureError!core.SparseBufferLowering {
        return try core.SparseBufferLowering.fromDescriptor(
            self.state().backend,
            descriptor,
            self.nativeFeatures(),
            self.limits(),
        );
    }

    fn validateSparseTextureDescriptor(self: Device, descriptor: core.SparseTextureDescriptor) (core.AdvancedFeatureError || core.TextureError)!void {
        try descriptor.validate(self.features(), self.limits());
    }

    fn planSparseTextureLowering(self: Device, descriptor: core.SparseTextureDescriptor) (core.AdvancedFeatureError || core.TextureError)!core.SparseTextureLowering {
        return try core.SparseTextureLowering.fromDescriptor(
            self.state().backend,
            descriptor,
            self.nativeFeatures(),
            self.limits(),
        );
    }

    fn validateExternalTextureDescriptor(self: Device, descriptor: core.ExternalTextureDescriptor) (core.AdvancedFeatureError || core.TextureError)!void {
        try descriptor.validate(self.state().backend, self.features());
    }

    fn validateExternalMemoryDescriptor(self: Device, descriptor: core.ExternalMemoryDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.state().backend, self.features());
    }

    fn validateExternalBufferDescriptor(self: Device, descriptor: core.ExternalBufferDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.state().backend, self.features());
    }

    fn validateExternalSemaphoreDescriptor(self: Device, descriptor: core.ExternalSemaphoreDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.state().backend, self.features());
    }

    fn validateExternalEventDescriptor(self: Device, descriptor: core.ExternalEventDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.state().backend, self.features());
    }

    fn planExternalMemoryImportForPlatform(self: Device, platform: core.ExternalInteropPlatform, descriptor: core.ExternalMemoryDescriptor) core.AdvancedFeatureError!core.ExternalInteropImportPlan {
        return try core.planExternalMemoryImport(
            self.state().backend,
            platform,
            descriptor,
            self.features(),
            self.nativeFeatures(),
        );
    }

    fn planExternalBufferImportForPlatform(self: Device, platform: core.ExternalInteropPlatform, descriptor: core.ExternalBufferDescriptor) core.AdvancedFeatureError!core.ExternalInteropImportPlan {
        return try core.planExternalBufferImport(
            self.state().backend,
            platform,
            descriptor,
            self.features(),
            self.nativeFeatures(),
        );
    }

    fn planExternalTextureImportForPlatform(self: Device, platform: core.ExternalInteropPlatform, descriptor: core.ExternalTextureDescriptor) (core.AdvancedFeatureError || core.TextureError)!core.ExternalInteropImportPlan {
        return try core.planExternalTextureImport(
            self.state().backend,
            platform,
            descriptor,
            self.features(),
            self.nativeFeatures(),
        );
    }

    fn planExternalTextureUsageForPlatform(self: Device, platform: core.ExternalInteropPlatform, descriptor: core.ExternalTextureUsageDescriptor) (core.AdvancedFeatureError || core.TextureError)!core.ExternalTextureUsagePlan {
        return try descriptor.validate(
            self.state().backend,
            platform,
            self.features(),
            self.nativeFeatures(),
        );
    }

    fn planExternalSemaphoreImportForPlatform(self: Device, platform: core.ExternalInteropPlatform, descriptor: core.ExternalSemaphoreDescriptor) core.AdvancedFeatureError!core.ExternalInteropImportPlan {
        return try core.planExternalSemaphoreImport(
            self.state().backend,
            platform,
            descriptor,
            self.features(),
            self.nativeFeatures(),
        );
    }

    fn planExternalEventImportForPlatform(self: Device, platform: core.ExternalInteropPlatform, descriptor: core.ExternalEventDescriptor) core.AdvancedFeatureError!core.ExternalInteropImportPlan {
        return try core.planExternalEventImport(
            self.state().backend,
            platform,
            descriptor,
            self.features(),
            self.nativeFeatures(),
        );
    }

    fn diagnoseExternalInteropImportForPlatform(
        self: Device,
        platform: core.ExternalInteropPlatform,
        resource: core.ExternalInteropResourceKind,
        handle: core.ExternalHandleDescriptor,
    ) core.ExternalInteropImportDiagnostic {
        return core.diagnoseExternalInteropImport(
            self.state().backend,
            platform,
            self.features(),
            self.nativeFeatures(),
            resource,
            handle,
        );
    }

    fn planExternalMemoryImport(self: Device, descriptor: core.ExternalMemoryDescriptor) core.AdvancedFeatureError!core.ExternalInteropImportPlan {
        return try self.planExternalMemoryImportForPlatform(core.ExternalInteropPlatform.native(), descriptor);
    }

    fn planExternalBufferImport(self: Device, descriptor: core.ExternalBufferDescriptor) core.AdvancedFeatureError!core.ExternalInteropImportPlan {
        return try self.planExternalBufferImportForPlatform(core.ExternalInteropPlatform.native(), descriptor);
    }

    fn planExternalTextureImport(self: Device, descriptor: core.ExternalTextureDescriptor) (core.AdvancedFeatureError || core.TextureError)!core.ExternalInteropImportPlan {
        return try self.planExternalTextureImportForPlatform(core.ExternalInteropPlatform.native(), descriptor);
    }

    fn planExternalTextureUsage(self: Device, descriptor: core.ExternalTextureUsageDescriptor) (core.AdvancedFeatureError || core.TextureError)!core.ExternalTextureUsagePlan {
        return try self.planExternalTextureUsageForPlatform(core.ExternalInteropPlatform.native(), descriptor);
    }

    fn planExternalSemaphoreImport(self: Device, descriptor: core.ExternalSemaphoreDescriptor) core.AdvancedFeatureError!core.ExternalInteropImportPlan {
        return try self.planExternalSemaphoreImportForPlatform(core.ExternalInteropPlatform.native(), descriptor);
    }

    fn planExternalEventImport(self: Device, descriptor: core.ExternalEventDescriptor) core.AdvancedFeatureError!core.ExternalInteropImportPlan {
        return try self.planExternalEventImportForPlatform(core.ExternalInteropPlatform.native(), descriptor);
    }

    fn diagnoseExternalInteropImport(
        self: Device,
        resource: core.ExternalInteropResourceKind,
        handle: core.ExternalHandleDescriptor,
    ) core.ExternalInteropImportDiagnostic {
        return self.diagnoseExternalInteropImportForPlatform(
            core.ExternalInteropPlatform.native(),
            resource,
            handle,
        );
    }

    fn externalInteropCapabilityMatrix(self: Device) core.ExternalInteropCapabilityMatrix {
        return self.externalInteropCapabilityMatrixForPlatform(core.ExternalInteropPlatform.native());
    }

    fn externalInteropCapabilityMatrixForPlatform(self: Device, platform: core.ExternalInteropPlatform) core.ExternalInteropCapabilityMatrix {
        return core.externalInteropCapabilityMatrix(
            self.state().backend,
            platform,
            self.features(),
            self.nativeFeatures(),
        );
    }

    fn validateNativeCommandInsertionDescriptor(self: Device, descriptor: core.NativeCommandInsertionDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.features());
    }

    fn planNativeAdvancedClosure(self: Device, descriptor: core.NativeAdvancedClosureDescriptor) core.NativeAdvancedClosurePlan {
        _ = self;
        return core.NativeAdvancedClosurePlan.fromDescriptor(descriptor);
    }

    fn validateTessellationDescriptor(self: Device, descriptor: core.TessellationDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.features(), self.limits());
    }

    fn planTessellationLowering(self: Device, descriptor: core.TessellationDescriptor) core.AdvancedFeatureError!core.TessellationLowering {
        return try core.TessellationLowering.fromDescriptor(
            self.state().backend,
            descriptor,
            self.nativeFeatures(),
            self.limits(),
        );
    }

    fn validateTessellationPatchDrawDescriptor(self: Device, descriptor: core.TessellationPatchDrawDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.features(), self.limits());
    }

    fn planTessellationPatchDraw(self: Device, descriptor: core.TessellationPatchDrawDescriptor) core.AdvancedFeatureError!core.TessellationDrawPlan {
        return try core.TessellationDrawPlan.fromDescriptor(
            self.state().backend,
            descriptor,
            self.nativeFeatures(),
            self.limits(),
        );
    }

    fn planVulkanTessellationPatchDraw(self: Device, descriptor: core.TessellationPatchDrawDescriptor) core.AdvancedFeatureError!core.VulkanTessellationDrawLowering {
        if (self.state().backend != .vulkan) return core.AdvancedFeatureError.UnsupportedTessellation;
        const plan = try self.planTessellationPatchDraw(descriptor);
        return try core.vulkanTessellationDrawLowering(plan);
    }

    fn planMetalTessellationPatchDraw(self: Device, descriptor: core.TessellationPatchDrawDescriptor) core.AdvancedFeatureError!core.MetalTessellationDrawLowering {
        if (self.state().backend != .metal) return core.AdvancedFeatureError.UnsupportedTessellation;
        const plan = try self.planTessellationPatchDraw(descriptor);
        return try core.metalTessellationDrawLowering(plan);
    }

    fn validateMeshPipelineDescriptor(self: Device, descriptor: core.MeshPipelineDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.features(), self.limits());
    }

    fn planMeshPipelineLowering(self: Device, descriptor: core.MeshPipelineDescriptor) core.AdvancedFeatureError!core.MeshPipelineLowering {
        return try core.MeshPipelineLowering.fromDescriptor(
            self.state().backend,
            descriptor,
            self.nativeFeatures(),
            self.limits(),
        );
    }

    fn validateMeshDispatchDescriptor(self: Device, descriptor: core.MeshDispatchDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.features(), self.limits());
    }

    fn planMeshDispatch(self: Device, descriptor: core.MeshDispatchDescriptor) core.AdvancedFeatureError!core.MeshDispatchPlan {
        return try core.MeshDispatchPlan.fromDescriptor(
            self.state().backend,
            descriptor,
            self.nativeFeatures(),
            self.limits(),
        );
    }

    fn planVulkanMeshDispatch(self: Device, descriptor: core.MeshDispatchDescriptor) core.AdvancedFeatureError!core.VulkanMeshDispatchLowering {
        if (self.state().backend != .vulkan) return core.AdvancedFeatureError.UnsupportedMeshShaders;
        const plan = try self.planMeshDispatch(descriptor);
        return try core.vulkanMeshDispatchLowering(plan);
    }

    fn planMetalMeshDispatch(self: Device, descriptor: core.MeshDispatchDescriptor) core.AdvancedFeatureError!core.MetalMeshDispatchLowering {
        if (self.state().backend != .metal) return core.AdvancedFeatureError.UnsupportedMeshShaders;
        const plan = try self.planMeshDispatch(descriptor);
        return try core.metalMeshDispatchLowering(plan);
    }

    fn validateAccelerationStructureDescriptor(self: Device, descriptor: core.AccelerationStructureDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.features());
    }

    fn planAccelerationStructureBuild(self: Device, descriptor: core.AccelerationStructureBuildDescriptor) core.AdvancedFeatureError!core.AccelerationStructureBuildPlan {
        var plan = try core.AccelerationStructureBuildPlan.fromDescriptor(
            self.state().backend,
            descriptor,
            self.nativeFeatures(),
        );
        if (self.state().capability_report.source == .vulkan_query or self.state().capability_report.source == .metal_query) {
            var sizing_descriptor = descriptor.acceleration_structure;
            sizing_descriptor.allow_update = sizing_descriptor.allow_update or descriptor.flags.allow_update;
            switch (self.state().impl) {
                .vulkan => |*vulkan| {
                    const sizes = try vulkan.accelerationStructureBuildSizes(sizing_descriptor, descriptor.flags);
                    plan.result_size = sizes.result_size;
                    plan.scratch_size = std.mem.alignForward(u64, sizes.scratch_size, descriptor.scratch_alignment);
                    plan.update_scratch_size = if (descriptor.mode == .update or
                        descriptor.acceleration_structure.allow_update or
                        descriptor.flags.allow_update)
                        std.mem.alignForward(u64, sizes.update_scratch_size, descriptor.scratch_alignment)
                    else
                        0;
                },
                .metal => |*metal| {
                    const sizes = try metal.accelerationStructureBuildSizes(sizing_descriptor);
                    plan.result_size = sizes.result_size;
                    plan.scratch_size = std.mem.alignForward(u64, sizes.scratch_size, descriptor.scratch_alignment);
                    plan.update_scratch_size = if (descriptor.mode == .update or
                        descriptor.acceleration_structure.allow_update or
                        descriptor.flags.allow_update)
                        std.mem.alignForward(u64, sizes.update_scratch_size, descriptor.scratch_alignment)
                    else
                        0;
                },
            }
        }
        return plan;
    }

    fn planAccelerationStructureMaintenance(
        self: Device,
        descriptor: core.AccelerationStructureMaintenanceDescriptor,
    ) core.AdvancedFeatureError!core.AccelerationStructureMaintenancePlan {
        var plan = try core.AccelerationStructureMaintenancePlan.fromDescriptor(
            self.state().backend,
            descriptor,
            self.nativeFeatures(),
        );
        if (self.state().capability_report.source == .vulkan_query or self.state().capability_report.source == .metal_query) {
            const sizes = switch (self.state().impl) {
                .vulkan => |*vulkan| try vulkan.accelerationStructureBuildSizes(
                    descriptor.acceleration_structure,
                    .{
                        .allow_update = descriptor.acceleration_structure.allow_update,
                        .allow_compaction = descriptor.operation == .compact,
                    },
                ),
                .metal => |*metal| try metal.accelerationStructureBuildSizes(descriptor.acceleration_structure),
            };
            if (descriptor.operation != .compact) {
                plan.scratch_size = std.mem.alignForward(u64, sizes.update_scratch_size, descriptor.scratch_alignment);
            }
            if (descriptor.source_result_size == 0) plan.source_result_size = sizes.result_size;
            if (descriptor.operation == .compact and descriptor.compacted_size_hint == null) {
                plan.compacted_size_upper_bound = plan.source_result_size;
            }
        }
        return plan;
    }

    fn planTopLevelAccelerationStructureLayout(
        self: Device,
        descriptor: core.TopLevelAccelerationStructureLayoutDescriptor,
    ) core.AdvancedFeatureError!core.TopLevelAccelerationStructureLayoutPlan {
        return try descriptor.plan(
            self.state().backend,
            self.nativeFeatures(),
            self.limits(),
        );
    }

    pub fn makeAccelerationStructure(self: *Device, descriptor: core.AccelerationStructureDescriptor) core.AdvancedFeatureError!AccelerationStructure {
        try descriptor.validate(self.nativeFeatures());
        var sizes = core.estimateAccelerationStructureBuildSizes(descriptor);
        var impl: ?AccelerationStructure.Impl = null;
        if (self.state().capability_report.source == .vulkan_query or self.state().capability_report.source == .metal_query) {
            switch (self.state().impl) {
                .vulkan => |*vulkan| {
                    var acceleration_structure = try vulkan.makeAccelerationStructure(descriptor);
                    sizes = acceleration_structure.buildSizes();
                    impl = .{ .vulkan = acceleration_structure };
                },
                .metal => |*metal| {
                    var acceleration_structure = try metal.makeAccelerationStructure(descriptor);
                    sizes = acceleration_structure.buildSizes();
                    impl = .{ .metal = acceleration_structure };
                },
            }
        }
        self.state().tracker.retain(.acceleration_structure);
        return AccelerationStructure.init(.{
            .backend = self.state().backend,
            .tracker = self.state().tracker,
            .label_value = descriptor.label,
            .descriptor_value = descriptor,
            .sizes_value = sizes,
            .native_handle = BackendPrivateAccelerationStructureHandle.fromDescriptor(
                self.state().backend,
                descriptor,
                sizes,
            ),
            .impl = impl,
        });
    }

    fn validateRayTracingPipelineDescriptor(self: Device, descriptor: core.RayTracingPipelineDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.features(), self.limits());
    }

    fn planRayTracingPipelineLowering(self: Device, descriptor: core.RayTracingPipelineDescriptor) core.AdvancedFeatureError!core.RayTracingPipelineLowering {
        const metal_intersections: []const core.MetalIntersectionFunctionDescriptor = &.{};
        return try core.RayTracingPipelineLowering.fromDescriptor(
            self.state().backend,
            descriptor,
            metal_intersections,
            self.nativeFeatures(),
            self.limits(),
        );
    }

    pub fn makeRayTracingPipelineState(self: *Device, descriptor: core.RayTracingPipelineDescriptor) !RayTracingPipelineState {
        const metal_intersections: []const core.MetalIntersectionFunctionDescriptor = &.{};
        const lowering = try core.RayTracingPipelineLowering.fromDescriptor(
            self.state().backend,
            descriptor,
            metal_intersections,
            self.features(),
            self.limits(),
        );
        const shader_groups = try self.state().allocator.dupe(core.RayTracingShaderGroupDescriptor, descriptor.shader_groups);
        errdefer self.state().allocator.free(shader_groups);
        var impl: ?RayTracingPipelineState.Impl = null;
        errdefer if (impl) |*pipeline_impl| switch (pipeline_impl.*) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        };
        switch (self.state().impl) {
            .vulkan => |*vulkan| {
                if (self.state().backend == .vulkan and descriptor.hasNativeShaderStages()) {
                    impl = .{ .vulkan = try vulkan.makeRayTracingPipelineState(descriptor) };
                }
            },
            .metal => |*metal| {
                if (self.state().backend == .metal) {
                    impl = .{ .metal = try metal.makeRayTracingPipelineState(self.state().allocator, descriptor) };
                }
            },
        }
        var native_handle = BackendPrivateRayTracingPipelineHandle.fromLowering(
            self.state().backend,
            descriptor,
            lowering,
        );
        native_handle.driver_bound = impl != null;
        self.state().tracker.retain(.ray_tracing_pipeline_state);
        return RayTracingPipelineState.init(.{
            .backend = self.state().backend,
            .tracker = self.state().tracker,
            .allocator = self.state().allocator,
            .label_value = descriptor.label,
            .descriptor_value = .{
                .label = descriptor.label,
                .shader_groups = shader_groups,
                .max_recursion_depth = descriptor.max_recursion_depth,
            },
            .lowering = lowering,
            .native_handle = native_handle,
            .impl = impl,
        });
    }

    fn planMetalRayTracingMapping(self: Device, descriptor: core.MetalRayTracingMappingDescriptor) core.AdvancedFeatureError!core.MetalRayTracingMappingPlan {
        if (self.state().backend != .metal) return core.AdvancedFeatureError.UnsupportedRayTracing;
        return try core.MetalRayTracingMappingPlan.fromDescriptor(
            descriptor,
            self.features(),
            self.limits(),
        );
    }

    fn makeMetalRayTracingExecutionMapping(self: *Device, descriptor: core.MetalRayTracingMappingDescriptor) !MetalRayTracingExecutionMapping {
        if (self.state().backend != .metal) return core.AdvancedFeatureError.UnsupportedRayTracing;
        const plan = try core.MetalRayTracingMappingPlan.fromDescriptor(
            descriptor,
            self.features(),
            self.limits(),
        );
        const shader_groups = try self.state().allocator.dupe(core.RayTracingShaderGroupDescriptor, descriptor.pipeline.shader_groups);
        errdefer self.state().allocator.free(shader_groups);
        const intersections = try self.state().allocator.dupe(core.MetalIntersectionFunctionDescriptor, descriptor.intersections);
        errdefer self.state().allocator.free(intersections);

        self.state().tracker.retain(.metal_ray_tracing_execution_mapping);
        return MetalRayTracingExecutionMapping.init(.{
            .tracker = self.state().tracker,
            .allocator = self.state().allocator,
            .label_value = descriptor.function_table_label,
            .descriptor_value = .{
                .pipeline = .{
                    .label = descriptor.pipeline.label,
                    .shader_groups = shader_groups,
                    .max_recursion_depth = descriptor.pipeline.max_recursion_depth,
                },
                .intersections = intersections,
                .function_table_label = descriptor.function_table_label,
            },
            .plan_value = plan,
            .native_tables = BackendPrivateMetalRayTracingTables.fromPlan(plan),
        });
    }

    fn validateShaderBindingTableDescriptor(self: Device, descriptor: core.ShaderBindingTableDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.features(), self.limits());
    }

    pub fn makeShaderBindingTable(self: *Device, descriptor: core.ShaderBindingTableDescriptor) core.AdvancedFeatureError!ShaderBindingTable {
        const layout = try core.ShaderBindingTableLayout.fromDescriptor(
            descriptor,
            self.features(),
            self.limits(),
        );
        self.state().tracker.retain(.shader_binding_table);
        return ShaderBindingTable.init(.{
            .backend = self.state().backend,
            .tracker = self.state().tracker,
            .descriptor_value = descriptor,
            .layout_value = layout,
            .limits_value = self.limits(),
            .native_records = BackendPrivateShaderBindingTableRecords.fromLayout(
                self.state().backend,
                descriptor,
                layout,
            ),
        });
    }

    fn planComplexShaderBindingTable(
        self: Device,
        descriptor: core.ComplexShaderBindingTableDescriptor,
    ) core.AdvancedFeatureError!core.ComplexShaderBindingTablePlan {
        return try core.ComplexShaderBindingTablePlan.fromDescriptor(
            descriptor,
            self.nativeFeatures(),
            self.limits(),
        );
    }

    fn planRayDispatch(
        self: Device,
        sbt: core.ShaderBindingTableDescriptor,
        dispatch: core.RayDispatchDescriptor,
    ) core.AdvancedFeatureError!core.RayDispatchPlan {
        return try core.RayDispatchPlan.fromDescriptors(
            sbt,
            dispatch,
            self.nativeFeatures(),
            self.limits(),
        );
    }

    fn planRayQuery(self: Device, descriptor: core.RayQueryDescriptor) core.AdvancedFeatureError!core.RayQueryPlan {
        return try core.RayQueryPlan.fromDescriptor(
            self.state().backend,
            descriptor,
            self.nativeFeatures(),
            self.limits(),
        );
    }

    fn planRayTracingStress(self: Device, descriptor: core.RayTracingStressDescriptor) core.AdvancedFeatureError!core.RayTracingStressPlan {
        return try core.RayTracingStressPlan.fromDescriptor(
            self.state().backend,
            descriptor,
            self.nativeFeatures(),
            self.limits(),
        );
    }

    fn validateDriverPipelineCacheDescriptor(self: Device, descriptor: core.DriverPipelineCacheDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.features(), self.limits());
    }

    fn validateNativeDriverPipelineCacheDescriptor(self: Device, descriptor: core.DriverPipelineCacheDescriptor) core.AdvancedFeatureError!void {
        try descriptor.validate(self.nativeFeatures(), self.limits());
    }

    fn planDriverPipelineCache(self: Device, descriptor: core.DriverPipelineCacheDescriptor) !core.DriverPipelineCachePlan {
        try self.validateNativeDriverPipelineCacheDescriptor(descriptor);
        return try core.DriverPipelineCachePlan.fromDescriptor(
            descriptor,
            pathExists(descriptor.path),
            self.nativeFeatures(),
            self.limits(),
        );
    }

    fn planRuntimeCache(self: Device, descriptor: core.RuntimeCachePlanDescriptor) !core.RuntimeCachePlan {
        if (descriptor.manifest.backend != self.state().backend) return core.ObjectCacheError.InvalidObjectCacheKey;
        return try core.RuntimeCachePlan.fromDescriptor(self.state().allocator, descriptor);
    }

    fn planPipelineArtifactCache(self: Device, descriptor: core.PipelineArtifactCachePlanDescriptor) core.ObjectCacheError!core.PipelineArtifactCachePlan {
        if (descriptor.manifest.backend != self.state().backend) return core.ObjectCacheError.InvalidObjectCacheKey;
        return try core.PipelineArtifactCachePlan.fromDescriptor(descriptor);
    }

    fn planBackendParitySemantics(
        self: Device,
        descriptor: core.BackendParitySemanticsDescriptor,
    ) core.StabilityRunError!core.BackendParitySemanticsPlan {
        var resolved = descriptor;
        resolved.backend = self.state().backend;
        return try core.BackendParitySemanticsPlan.fromDescriptor(resolved);
    }

    pub fn getFormatCaps(self: Device, format: core.TextureFormat) core.FormatCapabilities {
        return switch (self.state().impl) {
            .vulkan => |*vulkan| vulkan.formatCapabilities(format),
            .metal => |*metal| metal.formatCapabilities(format),
        };
    }

    fn objectCacheDiagnostics(self: Device) core.ObjectCacheDiagnostics {
        return self.state().tracker.objectCacheDiagnostics();
    }

    fn runtimeDiagnostics(self: Device) core.RuntimeDiagnosticsSnapshot {
        return self.state().tracker.diagnosticsSnapshot();
    }

    fn syncCapabilities(self: Device) core.SyncCapabilities {
        return core.SyncCapabilities.fromFeatures(self.features());
    }

    fn writeCaptureName(
        self: Device,
        descriptor: core.CaptureNameDescriptor,
        buffer: []u8,
    ) core.CommandEncodingError![]const u8 {
        var resolved = descriptor;
        if (resolved.backend == null) resolved.backend = self.state().backend;
        return try resolved.write(buffer);
    }

    pub fn makeFence(self: *Device, descriptor: core.FenceDescriptor) !Fence {
        try descriptor.validate(self.features());
        const native_source = self.state().capability_report.source == .vulkan_query or
            self.state().capability_report.source == .metal_query;
        const impl: ?Fence.Impl = if (descriptor.kind == .timeline and native_source) switch (self.state().impl) {
            .vulkan => |*vulkan| .{ .vulkan = try vulkan.makeTimelineSemaphore(descriptor.initial_value) },
            .metal => |*metal| .{ .metal = try metal.makeSharedEvent(descriptor.initial_value) },
        } else null;
        self.state().tracker.retain(.fence);
        return Fence.init(.{
            .backend = self.state().backend,
            .tracker = self.state().tracker,
            .label_value = descriptor.label,
            .descriptor_value = descriptor,
            .current_value = descriptor.initial_value,
            .impl = impl,
        });
    }

    pub fn makeEvent(self: *Device, descriptor: core.EventDescriptor) !Event {
        try descriptor.validate(self.features());
        const native_source = self.state().capability_report.source == .vulkan_query or
            self.state().capability_report.source == .metal_query;
        const impl: ?Event.Impl = if (descriptor.shared and native_source) switch (self.state().impl) {
            .vulkan => null,
            .metal => |*metal| .{ .metal = try metal.makeSharedEvent(0) },
        } else null;
        self.state().tracker.retain(.event);
        return Event.init(.{
            .backend = self.state().backend,
            .tracker = self.state().tracker,
            .label_value = descriptor.label,
            .descriptor_value = descriptor,
            .impl = impl,
        });
    }

    pub fn makeQuerySet(self: *Device, descriptor: core.QuerySetDescriptor) !QuerySet {
        try descriptor.validate(self.features());
        const count: usize = @intCast(descriptor.count);
        const values = try self.state().allocator.alloc(u64, count);
        errdefer self.state().allocator.free(values);
        const available = try self.state().allocator.alloc(bool, count);
        errdefer self.state().allocator.free(available);
        @memset(values, 0);
        @memset(available, false);

        var impl: ?QuerySet.Impl = null;
        const capability_source = self.state().capability_report.source;
        if (capability_source == .vulkan_query or capability_source == .metal_query) {
            const native_query = switch (self.state().impl) {
                .vulkan => |*vulkan| if (try vulkan.makeQuerySet(descriptor)) |query|
                    QuerySet.Impl{ .vulkan = query }
                else
                    null,
                .metal => |*metal| if (try metal.makeQuerySet(descriptor)) |query|
                    QuerySet.Impl{ .metal = query }
                else
                    null,
            };
            impl = native_query;
        }

        self.state().tracker.retain(.query_set);
        var result = QuerySet.init(.{
            .backend = self.state().backend,
            .tracker = self.state().tracker,
            .allocator = self.state().allocator,
            .label_value = descriptor.label,
            .descriptor_value = descriptor,
            .result_source_value = if (descriptor.query_type == .timestamp)
                if (impl != null) .native_gpu else .logical_sequence
            else
                .unavailable,
            .values = values,
            .available = available,
            .impl = impl,
        });
        result.setLabel(descriptor.label);
        return result;
    }

    pub fn makeHeap(self: *Device, descriptor: core.HeapDescriptor) !Heap {
        try descriptor.validate(self.features());
        const native_source = self.state().capability_report.source == .vulkan_query or
            self.state().capability_report.source == .metal_query;
        var impl: ?Heap.Impl = if (native_source) switch (self.state().impl) {
            .vulkan => |*vulkan| Heap.Impl{ .vulkan = try vulkan.makeHeap(descriptor) },
            .metal => |*metal| Heap.Impl{ .metal = try metal.makeHeap(descriptor) },
        } else null;
        errdefer if (impl) |*native| switch (native.*) {
            .vulkan => |*vulkan| vulkan.deinit(),
            .metal => |*metal| metal.deinit(),
        };
        const state_value = try self.state().allocator.create(Heap.State);
        errdefer self.state().allocator.destroy(state_value);
        state_value.* = .{
            .allocator = self.state().allocator,
            .backend = self.state().backend,
            .tracker = self.state().tracker,
            .label_value = descriptor.label,
            .descriptor_value = descriptor,
            .features_value = self.features(),
            .limits_value = self.limits(),
            .impl = impl,
        };
        self.state().tracker.retain(.heap);
        return Heap.init(state_value);
    }

    fn memoryBudgetReport(self: Device, descriptor: core.MemoryBudgetDescriptor) core.MemoryBudgetError!core.MemoryBudgetReport {
        var resolved = descriptor;
        resolved.native_budget_available = false;
        const native_source = self.state().capability_report.source == .vulkan_query or
            self.state().capability_report.source == .metal_query;
        if (native_source and self.features().memory_budget) {
            switch (self.state().impl) {
                .vulkan => |*vulkan| if (vulkan.gc.memoryBudget()) |budget| {
                    applyNativeMemoryBudget(&resolved, budget.budget_bytes, budget.used_bytes);
                },
                .metal => |*metal| if (metal.memoryBudget()) |budget| {
                    applyNativeMemoryBudget(&resolved, budget.budget_bytes, budget.used_bytes);
                },
            }
        }
        return try resolved.report();
    }

    fn applyNativeMemoryBudget(
        descriptor: *core.MemoryBudgetDescriptor,
        budget_bytes: u64,
        used_bytes: u64,
    ) void {
        descriptor.budget_bytes = budget_bytes;
        descriptor.explicit_usage_bytes = used_bytes;
        descriptor.heap_reserved_bytes = 0;
        descriptor.transient_peak_bytes = 0;
        descriptor.sparse_resident_bytes = 0;
        descriptor.native_budget_available = true;
    }

    fn transientAllocationDiagnostics(
        self: Device,
        resources: []const core.TransientResourceDescriptor,
    ) error{InvalidResourceBarrierRange}!core.TransientAllocationDiagnostics {
        _ = self;
        return try core.TransientAllocationDiagnostics.analyze(resources);
    }

    pub fn queue(self: *Device) Queue {
        return self.queueView(null, .graphics);
    }

    fn queueView(self: *Device, label: ?[]const u8, kind: core.QueueKind) Queue {
        return Queue.init(.{
            .runtime = self._state,
            .label = label,
            .kind = kind,
        });
    }

    fn queueCapabilities(self: Device) core.QueueCapabilities {
        return core.QueueCapabilities.fromFeatures(self.features());
    }

    fn presentModeSupport(self: Device) core.PresentModeSupport {
        if (!self.state().presentation_available) {
            return .{ .fifo = false, .mailbox = false, .immediate = false };
        }
        return core.defaultPresentModeSupport(self.state().backend);
    }

    fn resolvePresentMode(self: Device, requested: core.PresentMode) core.PresentModeResolution {
        return self.presentModeSupport().resolveWithDiagnostics(requested);
    }

    pub fn queueWithDescriptor(self: *Device, descriptor: core.QueueDescriptor) !Queue {
        const plan = try self.planQueue(descriptor);
        return self.queueView(descriptor.label, plan.resolved);
    }

    fn planQueue(self: Device, descriptor: core.QueueDescriptor) core.CommandEncodingError!core.QueueSelectionPlan {
        return try core.QueueSelectionPlan.fromDescriptor(
            descriptor,
            self.features(),
            self.queueCapabilities(),
        );
    }

    fn makeSurfaceCollection(self: Device) core.SurfaceCollection {
        return core.SurfaceCollection.init(self.state().allocator, self.state().backend);
    }

    pub fn compileRenderShader(
        self: *Device,
        name: []const u8,
        source: []const u8,
        options: ShaderCompiler.RenderShaderOptions,
    ) !ShaderCompiler.CompiledRenderShader {
        return try ShaderCompiler.compileRenderShader(
            self.state().allocator,
            name,
            source,
            options,
        );
    }

    pub fn compileComputeShader(
        self: *Device,
        name: []const u8,
        source: []const u8,
        options: ShaderCompiler.ComputeShaderOptions,
    ) !ShaderCompiler.CompiledComputeShader {
        return try ShaderCompiler.compileComputeShader(
            self.state().allocator,
            name,
            source,
            options,
        );
    }

    pub fn compileRayTracingShader(
        self: *Device,
        name: []const u8,
        source: []const u8,
        options: ShaderCompiler.RayTracingShaderOptions,
    ) !ShaderCompiler.CompiledRayTracingShader {
        return try ShaderCompiler.compileRayTracingShader(
            self.state().allocator,
            name,
            source,
            options,
        );
    }

    pub fn makeBuffer(self: *Device, descriptor: core.BufferDescriptor) !Buffer {
        const length = try descriptor.validateForDevice(self.features(), self.limits());
        const impl = switch (self.state().impl) {
            .vulkan => |*vulkan| Buffer.Impl{ .vulkan = try vulkan.makeBuffer(descriptor) },
            .metal => |*metal| Buffer.Impl{ .metal = try metal.makeBuffer(descriptor) },
        };
        self.state().tracker.retain(.buffer);
        var buffer = Buffer.init(.{
            .backend = self.state().backend,
            .tracker = self.state().tracker,
            .label_value = descriptor.label,
            .native_labels_enabled = true,
            .length_value = length,
            .usage_value = descriptor.usage,
            .storage_mode_value = descriptor.storage_mode,
            .impl = impl,
        });
        buffer.setLabel(descriptor.label);
        return buffer;
    }

    pub fn makeShaderModule(self: *Device, descriptor: core.ShaderModuleDescriptor) !ShaderModule {
        var fingerprint = objectFingerprintStart(.shader_module, self.state().backend);
        hashShaderModuleDescriptor(&fingerprint, descriptor);
        const lookup = self.state().tracker.beginObjectCacheLookup(.shader_module, fingerprint, descriptor.cache_policy);
        const timer_start = objectCreationTimerStart();
        const impl = switch (self.state().impl) {
            .vulkan => |*vulkan| ShaderModule.Impl{ .vulkan = try vulkan.makeShaderModule(descriptor) },
            .metal => |*metal| ShaderModule.Impl{ .metal = try metal.makeShaderModule(self.state().allocator, descriptor) },
        };
        const elapsed_ns = objectCreationElapsedNs(timer_start);
        self.state().tracker.retain(.shader_module);
        self.state().tracker.finishObjectCacheLookup(lookup, elapsed_ns);
        var shader_module = ShaderModule.init(.{
            .backend = self.state().backend,
            .tracker = self.state().tracker,
            .label_value = descriptor.label,
            .native_labels_enabled = true,
            .impl = impl,
        });
        shader_module.setLabel(descriptor.label);
        return shader_module;
    }

    pub fn makeRenderPipelineState(self: *Device, descriptor: core.RenderPipelineDescriptor) !RenderPipelineState {
        try descriptor.validate();
        if (descriptor.bind_group_layouts.len + descriptor.resource_table_layouts.len > self.limits().max_bind_group_slots) {
            return core.CommandEncodingError.InvalidBindGroupIndex;
        }
        for (descriptor.resource_table_layouts) |layout| try layout.validate(self.features(), self.limits());
        if (descriptor.driver_cache) |cache| try cache.validate(self.features(), self.limits());
        try validateRuntimeRenderPipelineShape(descriptor, self.features());
        try validateRuntimeRootConstantLayout(descriptor.root_constant_layout, self.features(), self.limits());
        try validateRuntimeSpecialization(descriptor.vertex, self.features());
        if (descriptor.fragment) |fragment| try validateRuntimeSpecialization(fragment, self.features());
        try ShaderReflection.validateRenderPipelineDescriptor(self.state().allocator, descriptor);
        const root_constant_ranges = try copyRootConstantRanges(self.state().allocator, descriptor.root_constant_layout);
        errdefer self.state().allocator.free(root_constant_ranges);
        const resource_table_layout_hashes = try copyResourceTableLayoutFingerprints(
            self.state().allocator,
            descriptor.resource_table_layouts,
        );
        errdefer self.state().allocator.free(resource_table_layout_hashes);
        var fingerprint = objectFingerprintStart(.render_pipeline, self.state().backend);
        hashRenderPipelineDescriptor(&fingerprint, descriptor);
        const lookup = self.state().tracker.beginObjectCacheLookup(.render_pipeline, fingerprint, descriptor.cache_policy);
        const timer_start = objectCreationTimerStart();
        const impl = switch (self.state().impl) {
            .vulkan => |*vulkan| RenderPipelineState.Impl{ .vulkan = try vulkan.makeRenderPipelineState(descriptor) },
            .metal => |*metal| RenderPipelineState.Impl{ .metal = try metal.makeRenderPipelineState(self.state().allocator, descriptor) },
        };
        const elapsed_ns = objectCreationElapsedNs(timer_start);
        self.state().tracker.retain(.render_pipeline_state);
        self.state().tracker.finishObjectCacheLookup(lookup, elapsed_ns);
        var pipeline = RenderPipelineState.init(.{
            .backend = self.state().backend,
            .tracker = self.state().tracker,
            .allocator = self.state().allocator,
            .label_value = descriptor.label,
            .native_labels_enabled = true,
            .root_constant_ranges = root_constant_ranges,
            .resource_table_layout_base = @intCast(descriptor.bind_group_layouts.len),
            .resource_table_layout_hashes = resource_table_layout_hashes,
            .impl = impl,
        });
        pipeline.setLabel(descriptor.label);
        return pipeline;
    }

    pub fn makeComputePipelineState(self: *Device, descriptor: core.ComputePipelineDescriptor) !ComputePipelineState {
        try descriptor.validate();
        if (descriptor.bind_group_layouts.len + descriptor.resource_table_layouts.len > self.limits().max_bind_group_slots) {
            return core.CommandEncodingError.InvalidBindGroupIndex;
        }
        for (descriptor.resource_table_layouts) |layout| try layout.validate(self.features(), self.limits());
        if (descriptor.driver_cache) |cache| try cache.validate(self.features(), self.limits());
        try validateRuntimeRootConstantLayout(descriptor.root_constant_layout, self.features(), self.limits());
        try validateRuntimeSpecialization(descriptor.compute, self.features());
        try ShaderReflection.validateComputePipelineDescriptor(self.state().allocator, descriptor);
        const root_constant_ranges = try copyRootConstantRanges(self.state().allocator, descriptor.root_constant_layout);
        errdefer self.state().allocator.free(root_constant_ranges);
        const resource_table_layout_hashes = try copyResourceTableLayoutFingerprints(
            self.state().allocator,
            descriptor.resource_table_layouts,
        );
        errdefer self.state().allocator.free(resource_table_layout_hashes);
        var fingerprint = objectFingerprintStart(.compute_pipeline, self.state().backend);
        hashComputePipelineDescriptor(&fingerprint, descriptor);
        const lookup = self.state().tracker.beginObjectCacheLookup(.compute_pipeline, fingerprint, descriptor.cache_policy);
        const timer_start = objectCreationTimerStart();
        const impl = switch (self.state().impl) {
            .vulkan => |*vulkan| ComputePipelineState.Impl{ .vulkan = try vulkan.makeComputePipelineState(descriptor) },
            .metal => |*metal| ComputePipelineState.Impl{ .metal = try metal.makeComputePipelineState(self.state().allocator, descriptor) },
        };
        const elapsed_ns = objectCreationElapsedNs(timer_start);
        self.state().tracker.retain(.compute_pipeline_state);
        self.state().tracker.finishObjectCacheLookup(lookup, elapsed_ns);
        var pipeline = ComputePipelineState.init(.{
            .backend = self.state().backend,
            .tracker = self.state().tracker,
            .allocator = self.state().allocator,
            .label_value = descriptor.label,
            .native_labels_enabled = true,
            .root_constant_ranges = root_constant_ranges,
            .resource_table_layout_base = @intCast(descriptor.bind_group_layouts.len),
            .resource_table_layout_hashes = resource_table_layout_hashes,
            .impl = impl,
        });
        pipeline.setLabel(descriptor.label);
        return pipeline;
    }

    pub fn makeBindGroupLayout(self: *Device, descriptor: core.BindGroupLayoutDescriptor) !BindGroupLayout {
        try descriptor.validate();
        try validateFirstSliceBindGroupLayout(descriptor);
        var fingerprint = objectFingerprintStart(.bind_group_layout, self.state().backend);
        hashBindGroupLayoutDescriptor(&fingerprint, descriptor);
        const lookup = self.state().tracker.beginObjectCacheLookup(.bind_group_layout, fingerprint, descriptor.cache_policy);
        const timer_start = objectCreationTimerStart();

        const entries = try self.state().allocator.dupe(core.BindGroupLayoutEntry, descriptor.entries);
        errdefer self.state().allocator.free(entries);

        const impl = switch (self.state().impl) {
            .vulkan => |*vulkan| BindGroupLayout.Impl{
                .vulkan = try VulkanBindGroupBackend.VulkanBindGroupLayout.init(
                    vulkan.gc,
                    self.state().allocator,
                    descriptor,
                ),
            },
            .metal => BindGroupLayout.Impl{
                .metal = try MetalBindGroupBackend.MetalBindGroupLayout.init(
                    self.state().allocator,
                    descriptor,
                ),
            },
        };

        const elapsed_ns = objectCreationElapsedNs(timer_start);
        self.state().tracker.retain(.bind_group_layout);
        self.state().tracker.finishObjectCacheLookup(lookup, elapsed_ns);
        return BindGroupLayout.init(.{
            .backend = self.state().backend,
            .tracker = self.state().tracker,
            .allocator = self.state().allocator,
            .label_value = descriptor.label,
            .entries = entries,
            .impl = impl,
        });
    }

    pub fn makeAdvancedBindGroupLayout(self: *Device, descriptor: core.DescriptorIndexingLayoutDescriptor) !AdvancedBindGroupLayout {
        try descriptor.validate(self.features(), self.limits());
        const ranges = try self.state().allocator.dupe(core.DescriptorIndexingRange, descriptor.ranges);
        errdefer self.state().allocator.free(ranges);
        const impl: ?AdvancedBindGroupLayout.Impl = switch (self.state().impl) {
            .vulkan => |*vulkan| .{ .vulkan = try VulkanAdvancedBindGroupBackend.init(vulkan.gc, self.state().allocator, descriptor) },
            .metal => |*metal| .{ .metal = try MetalAdvancedBindGroupBackend.init(metal, self.state().allocator, descriptor) },
        };

        self.state().tracker.retain(.advanced_bind_group_layout);
        return AdvancedBindGroupLayout.init(.{
            .backend = self.state().backend,
            .tracker = self.state().tracker,
            .allocator = self.state().allocator,
            .label_value = descriptor.label,
            .model_value = descriptor.model,
            .ranges = ranges,
            .impl = impl,
        });
    }

    pub fn makeResourceTable(self: *Device, descriptor: ResourceTableDescriptor) !ResourceTable {
        assertObjectAlive(descriptor.layout.state().alive, "advanced_bind_group_layout");
        try expectSameBackend(self.state().backend, descriptor.layout.selectedBackend());
        if (descriptor.layout.usesPartiallyBoundRanges() and !descriptor.allow_partially_bound) {
            return core.BindingError.ResourceTablePartiallyBoundUnsupported;
        }
        if (descriptor.layout.usesUpdateAfterBindRanges() and !descriptor.allow_update_after_bind) {
            return core.BindingError.ResourceTableUpdateAfterBindUnsupported;
        }

        const ranges = try self.state().allocator.dupe(core.DescriptorIndexingRange, descriptor.layout.state().ranges);
        errdefer self.state().allocator.free(ranges);

        const slots = try self.state().allocator.alloc(?BindGroupResource, descriptor.layout.totalDescriptorCount());
        errdefer self.state().allocator.free(slots);
        @memset(slots, null);

        const impl: ?ResourceTable.Impl = switch (descriptor.layout.state().impl.?) {
            .vulkan => |*vulkan| .{ .vulkan = try VulkanAdvancedBindGroupBackend.ResourceTable.init(vulkan) },
            .metal => |*metal| .{ .metal = try MetalAdvancedBindGroupBackend.ResourceTable.init(metal) },
        };

        self.state().tracker.retain(.resource_table);
        return ResourceTable.init(.{
            .backend = self.state().backend,
            .tracker = self.state().tracker,
            .allocator = self.state().allocator,
            .label_value = descriptor.label,
            .model_value = descriptor.layout.state().model_value,
            .ranges = ranges,
            .slots = slots,
            .allow_update_after_bind = descriptor.allow_update_after_bind,
            .impl = impl,
        });
    }

    pub fn makeBindGroup(self: *Device, descriptor: BindGroupDescriptor) !BindGroup {
        const entries = try materializeBindGroupEntries(self.state().allocator, self.state().backend, descriptor);
        errdefer self.state().allocator.free(entries);

        const layout_entries = try self.state().allocator.dupe(core.BindGroupLayoutEntry, descriptor.layout.state().entries);
        errdefer self.state().allocator.free(layout_entries);

        const impl = switch (self.state().impl) {
            .vulkan => |*vulkan| bind_group_impl: {
                const vulkan_entries = try materializeVulkanBindGroupEntries(self.state().allocator, descriptor.entries);
                defer vulkan_entries.deinit(self.state().allocator);

                break :bind_group_impl BindGroup.Impl{
                    .vulkan = try VulkanBindGroupBackend.VulkanBindGroup.init(
                        vulkan.gc,
                        self.state().allocator,
                        &descriptor.layout.state().impl.?.vulkan,
                        vulkan_entries.entries,
                    ),
                };
            },
            .metal => bind_group_impl: {
                const metal_entries = try materializeMetalBindGroupEntries(self.state().allocator, descriptor.entries);
                defer metal_entries.deinit(self.state().allocator);

                break :bind_group_impl BindGroup.Impl{
                    .metal = try MetalBindGroupBackend.MetalBindGroup.init(
                        self.state().allocator,
                        &descriptor.layout.state().impl.?.metal,
                        metal_entries.entries,
                    ),
                };
            },
        };

        self.state().tracker.retain(.bind_group);
        return BindGroup.init(.{
            .backend = self.state().backend,
            .tracker = self.state().tracker,
            .allocator = self.state().allocator,
            .label_value = descriptor.label,
            .layout_entries = layout_entries,
            .entries = entries,
            .impl = impl,
        });
    }

    pub fn makeTexture(self: *Device, descriptor: core.TextureDescriptor) !Texture {
        try descriptor.validateForLimits(self.limits());
        if (descriptor.storage_mode == .memoryless and !self.features().memoryless_attachments) {
            return core.TextureError.UnsupportedMemorylessStorage;
        }
        if (!self.getFormatCaps(descriptor.format).supportsTextureDescriptor(descriptor)) {
            return core.TextureError.UnsupportedTextureUsage;
        }
        const subresource_usage_tracker = try SharedTextureUsageTracker.init(self.state().allocator, descriptor);
        errdefer subresource_usage_tracker.release();
        const impl = switch (self.state().impl) {
            .vulkan => |*vulkan| Texture.Impl{ .vulkan = try vulkan.makeTexture(descriptor) },
            .metal => |*metal| Texture.Impl{ .metal = try metal.makeTexture(descriptor) },
        };
        self.state().tracker.retain(.texture);
        var texture = Texture.init(.{
            .backend = self.state().backend,
            .tracker = self.state().tracker,
            .label_value = descriptor.label,
            .native_labels_enabled = true,
            .dimension_value = descriptor.dimension,
            .format_value = descriptor.format,
            .usage_value = descriptor.usage,
            .storage_mode_value = descriptor.storage_mode,
            .sample_count_value = descriptor.sample_count,
            .subresource_usage_tracker = subresource_usage_tracker,
            .impl = impl,
        });
        texture.setLabel(descriptor.label);
        return texture;
    }

    pub fn makeExternalMemory(self: *Device, descriptor: core.ExternalMemoryDescriptor) !ExternalMemory {
        try self.validateExternalMemoryDescriptor(descriptor);
        const import_plan = try self.planExternalMemoryImport(descriptor);
        self.state().tracker.retain(.external_memory);
        return ExternalMemory.init(.{
            .backend = self.state().backend,
            .tracker = self.state().tracker,
            .descriptor_value = descriptor,
            .import_plan_value = import_plan,
        });
    }

    pub fn makeExternalBuffer(self: *Device, descriptor: core.ExternalBufferDescriptor) !ExternalBuffer {
        try self.validateExternalBufferDescriptor(descriptor);
        const import_plan = try self.planExternalBufferImport(descriptor);
        self.state().tracker.retain(.external_buffer);
        return ExternalBuffer.init(.{
            .backend = self.state().backend,
            .tracker = self.state().tracker,
            .descriptor_value = descriptor,
            .import_plan_value = import_plan,
        });
    }

    pub fn makeExternalSemaphore(self: *Device, descriptor: core.ExternalSemaphoreDescriptor) !ExternalSemaphore {
        try self.validateExternalSemaphoreDescriptor(descriptor);
        const import_plan = try self.planExternalSemaphoreImport(descriptor);
        self.state().tracker.retain(.external_semaphore);
        return ExternalSemaphore.init(.{
            .backend = self.state().backend,
            .tracker = self.state().tracker,
            .descriptor_value = descriptor,
            .import_plan_value = import_plan,
        });
    }

    pub fn makeExternalEvent(self: *Device, descriptor: core.ExternalEventDescriptor) !ExternalEvent {
        try self.validateExternalEventDescriptor(descriptor);
        const import_plan = try self.planExternalEventImport(descriptor);
        self.state().tracker.retain(.external_event);
        return ExternalEvent.init(.{
            .backend = self.state().backend,
            .tracker = self.state().tracker,
            .descriptor_value = descriptor,
            .import_plan_value = import_plan,
        });
    }

    pub fn makeExternalTexture(self: *Device, descriptor: core.ExternalTextureDescriptor) !ExternalTexture {
        try self.validateExternalTextureDescriptor(descriptor);
        const import_plan = try self.planExternalTextureImport(descriptor);
        self.state().tracker.retain(.texture);
        return ExternalTexture.init(.{
            .backend = self.state().backend,
            .tracker = self.state().tracker,
            .descriptor_value = descriptor,
            .import_plan_value = import_plan,
        });
    }

    pub fn makeSamplerState(self: *Device, descriptor: core.SamplerDescriptor) !SamplerState {
        try descriptor.validateForDevice(self.features(), self.limits());
        var fingerprint = objectFingerprintStart(.sampler, self.state().backend);
        hashSamplerDescriptor(&fingerprint, descriptor);
        const lookup = self.state().tracker.beginObjectCacheLookup(.sampler, fingerprint, descriptor.cache_policy);
        const timer_start = objectCreationTimerStart();
        const impl = switch (self.state().impl) {
            .vulkan => |*vulkan| SamplerState.Impl{ .vulkan = try vulkan.makeSamplerState(descriptor) },
            .metal => |*metal| SamplerState.Impl{ .metal = try metal.makeSamplerState(descriptor) },
        };
        const elapsed_ns = objectCreationElapsedNs(timer_start);
        self.state().tracker.retain(.sampler_state);
        self.state().tracker.finishObjectCacheLookup(lookup, elapsed_ns);
        var sampler = SamplerState.init(.{
            .backend = self.state().backend,
            .tracker = self.state().tracker,
            .label_value = descriptor.label,
            .native_labels_enabled = true,
            .impl = impl,
        });
        sampler.setLabel(descriptor.label);
        return sampler;
    }
};

pub const validateDescriptorIndexingLayout = Device.validateDescriptorIndexingLayout;
pub const planResourceTablePressure = Device.planResourceTablePressure;

pub fn compileTessellationShader(
    device: *Device,
    name: []const u8,
    source: []const u8,
    options: ShaderCompiler.TessellationShaderOptions,
) !ShaderCompiler.CompiledTessellationShader {
    return ShaderCompiler.compileTessellationShader(device.state().allocator, name, source, options);
}

pub fn compileMeshShader(
    device: *Device,
    name: []const u8,
    source: []const u8,
    options: ShaderCompiler.MeshShaderOptions,
) !ShaderCompiler.CompiledMeshShader {
    return ShaderCompiler.compileMeshShader(device.state().allocator, name, source, options);
}

pub fn makeTessellationRenderPipelineState(
    device: *Device,
    descriptor: core.TessellationRenderPipelineDescriptor,
) !RenderPipelineState {
    try descriptor.validate(device.features(), device.limits());
    const render = descriptor.render;
    if (render.bind_group_layouts.len + render.resource_table_layouts.len > device.limits().max_bind_group_slots) {
        return core.CommandEncodingError.InvalidBindGroupIndex;
    }
    for (render.resource_table_layouts) |layout| try layout.validate(device.features(), device.limits());
    if (render.driver_cache) |cache| try cache.validate(device.features(), device.limits());
    try validateRuntimeRenderPipelineShape(render, device.features());
    try validateRuntimeRootConstantLayout(render.root_constant_layout, device.features(), device.limits());
    try validateRuntimeSpecialization(render.vertex, device.features());
    try validateRuntimeSpecialization(descriptor.control, device.features());
    try validateRuntimeSpecialization(descriptor.evaluation, device.features());
    if (render.fragment) |fragment| try validateRuntimeSpecialization(fragment, device.features());
    try ShaderReflection.validateRenderPipelineDescriptor(device.state().allocator, render);

    const root_constant_ranges = try copyRootConstantRanges(device.state().allocator, render.root_constant_layout);
    errdefer device.state().allocator.free(root_constant_ranges);
    const resource_table_layout_hashes = try copyResourceTableLayoutFingerprints(
        device.state().allocator,
        render.resource_table_layouts,
    );
    errdefer device.state().allocator.free(resource_table_layout_hashes);

    var fingerprint = objectFingerprintStart(.render_pipeline, device.state().backend);
    hashRenderPipelineDescriptor(&fingerprint, render);
    hashProgrammableStage(&fingerprint, descriptor.control);
    hashProgrammableStage(&fingerprint, descriptor.evaluation);
    hashU64(&fingerprint, descriptor.tessellation.control_point_count);
    hashU64(&fingerprint, @intFromEnum(descriptor.tessellation.domain));
    hashU64(&fingerprint, @intFromEnum(descriptor.tessellation.partition_mode));
    const lookup = device.state().tracker.beginObjectCacheLookup(.render_pipeline, fingerprint, render.cache_policy);
    const timer_start = objectCreationTimerStart();
    const impl = switch (device.state().impl) {
        .vulkan => |*vulkan| RenderPipelineState.Impl{
            .vulkan = try vulkan.makeTessellationRenderPipelineState(descriptor),
        },
        .metal => return core.AdvancedFeatureError.UnsupportedTessellation,
    };
    const elapsed_ns = objectCreationElapsedNs(timer_start);
    device.state().tracker.retain(.render_pipeline_state);
    device.state().tracker.finishObjectCacheLookup(lookup, elapsed_ns);
    var pipeline = RenderPipelineState.init(.{
        .backend = device.state().backend,
        .tracker = device.state().tracker,
        .allocator = device.state().allocator,
        .label_value = render.label,
        .native_labels_enabled = true,
        .root_constant_ranges = root_constant_ranges,
        .resource_table_layout_base = @intCast(render.bind_group_layouts.len),
        .resource_table_layout_hashes = resource_table_layout_hashes,
        .kind = .tessellation,
        .tessellation = descriptor.tessellation,
        .impl = impl,
    });
    pipeline.setLabel(render.label);
    return pipeline;
}

pub fn makeMeshRenderPipelineState(
    device: *Device,
    descriptor: core.MeshRenderPipelineDescriptor,
) !RenderPipelineState {
    try descriptor.validate(device.features(), device.limits());
    if (descriptor.bind_group_layouts.len + descriptor.resource_table_layouts.len > device.limits().max_bind_group_slots) {
        return core.CommandEncodingError.InvalidBindGroupIndex;
    }
    for (descriptor.resource_table_layouts) |layout| try layout.validate(device.features(), device.limits());
    if (descriptor.driver_cache) |cache| try cache.validate(device.features(), device.limits());
    try validateRuntimeMeshPipelineShape(descriptor, device.features());
    try validateRuntimeRootConstantLayout(descriptor.root_constant_layout, device.features(), device.limits());
    try validateRuntimeSpecialization(descriptor.mesh, device.features());
    if (descriptor.task) |task| try validateRuntimeSpecialization(task, device.features());
    if (descriptor.fragment) |fragment| try validateRuntimeSpecialization(fragment, device.features());

    const root_constant_ranges = try copyRootConstantRanges(device.state().allocator, descriptor.root_constant_layout);
    errdefer device.state().allocator.free(root_constant_ranges);
    const resource_table_layout_hashes = try copyResourceTableLayoutFingerprints(
        device.state().allocator,
        descriptor.resource_table_layouts,
    );
    errdefer device.state().allocator.free(resource_table_layout_hashes);

    var fingerprint = objectFingerprintStart(.render_pipeline, device.state().backend);
    hashMeshRenderPipelineDescriptor(&fingerprint, descriptor);
    const lookup = device.state().tracker.beginObjectCacheLookup(.render_pipeline, fingerprint, descriptor.cache_policy);
    const timer_start = objectCreationTimerStart();
    const impl = switch (device.state().impl) {
        .vulkan => |*vulkan| RenderPipelineState.Impl{
            .vulkan = try vulkan.makeMeshRenderPipelineState(descriptor),
        },
        .metal => |*metal| RenderPipelineState.Impl{
            .metal = try metal.makeMeshRenderPipelineState(device.state().allocator, descriptor),
        },
    };
    const elapsed_ns = objectCreationElapsedNs(timer_start);
    device.state().tracker.retain(.render_pipeline_state);
    device.state().tracker.finishObjectCacheLookup(lookup, elapsed_ns);
    var pipeline = RenderPipelineState.init(.{
        .backend = device.state().backend,
        .tracker = device.state().tracker,
        .allocator = device.state().allocator,
        .label_value = descriptor.label,
        .native_labels_enabled = true,
        .root_constant_ranges = root_constant_ranges,
        .resource_table_layout_base = @intCast(descriptor.bind_group_layouts.len),
        .resource_table_layout_hashes = resource_table_layout_hashes,
        .kind = .mesh,
        .mesh_pipeline_hash = hashMeshPipelineDescriptor(device.state().backend, descriptor.pipeline),
        .mesh_limits = device.limits(),
        .impl = impl,
    });
    pipeline.setLabel(descriptor.label);
    return pipeline;
}

pub const validateSparseMappingCommit = Device.validateSparseMappingCommit;
pub const planSparseMappingCommit = Device.planSparseMappingCommit;
pub const planSparseResidencyChurn = Device.planSparseResidencyChurn;
pub const validateSparseBufferDescriptor = Device.validateSparseBufferDescriptor;
pub const planSparseBufferLowering = Device.planSparseBufferLowering;
pub const validateSparseTextureDescriptor = Device.validateSparseTextureDescriptor;
pub const planSparseTextureLowering = Device.planSparseTextureLowering;
pub const transientAllocationDiagnostics = Device.transientAllocationDiagnostics;

pub const validateExternalTextureDescriptor = Device.validateExternalTextureDescriptor;
pub const validateExternalMemoryDescriptor = Device.validateExternalMemoryDescriptor;
pub const validateExternalBufferDescriptor = Device.validateExternalBufferDescriptor;
pub const validateExternalSemaphoreDescriptor = Device.validateExternalSemaphoreDescriptor;
pub const validateExternalEventDescriptor = Device.validateExternalEventDescriptor;
pub const planExternalMemoryImportForPlatform = Device.planExternalMemoryImportForPlatform;
pub const planExternalBufferImportForPlatform = Device.planExternalBufferImportForPlatform;
pub const planExternalTextureImportForPlatform = Device.planExternalTextureImportForPlatform;
pub const planExternalTextureUsageForPlatform = Device.planExternalTextureUsageForPlatform;
pub const planExternalSemaphoreImportForPlatform = Device.planExternalSemaphoreImportForPlatform;
pub const planExternalEventImportForPlatform = Device.planExternalEventImportForPlatform;
pub const diagnoseExternalInteropImportForPlatform = Device.diagnoseExternalInteropImportForPlatform;
pub const planExternalMemoryImport = Device.planExternalMemoryImport;
pub const planExternalBufferImport = Device.planExternalBufferImport;
pub const planExternalTextureImport = Device.planExternalTextureImport;
pub const planExternalTextureUsage = Device.planExternalTextureUsage;
pub const planExternalSemaphoreImport = Device.planExternalSemaphoreImport;
pub const planExternalEventImport = Device.planExternalEventImport;
pub const diagnoseExternalInteropImport = Device.diagnoseExternalInteropImport;
pub const externalInteropCapabilityMatrix = Device.externalInteropCapabilityMatrix;
pub const externalInteropCapabilityMatrixForPlatform = Device.externalInteropCapabilityMatrixForPlatform;

pub const validateTessellationDescriptor = Device.validateTessellationDescriptor;
pub const validateTessellationPatchDrawDescriptor = Device.validateTessellationPatchDrawDescriptor;
pub const planTessellationPatchDraw = Device.planTessellationPatchDraw;
pub const validateMeshPipelineDescriptor = Device.validateMeshPipelineDescriptor;
pub const validateMeshDispatchDescriptor = Device.validateMeshDispatchDescriptor;
pub const planMeshDispatch = Device.planMeshDispatch;

pub const validateAccelerationStructureDescriptor = Device.validateAccelerationStructureDescriptor;
pub const planAccelerationStructureBuild = Device.planAccelerationStructureBuild;
pub const planAccelerationStructureMaintenance = Device.planAccelerationStructureMaintenance;
pub const planTopLevelAccelerationStructureLayout = Device.planTopLevelAccelerationStructureLayout;
pub const validateRayTracingPipelineDescriptor = Device.validateRayTracingPipelineDescriptor;
pub const validateShaderBindingTableDescriptor = Device.validateShaderBindingTableDescriptor;
pub const planComplexShaderBindingTable = Device.planComplexShaderBindingTable;
pub const planRayDispatch = Device.planRayDispatch;
pub const planRayQuery = Device.planRayQuery;
pub const planRayTracingStress = Device.planRayTracingStress;

pub const validateDriverPipelineCacheDescriptor = Device.validateDriverPipelineCacheDescriptor;
pub const planDriverPipelineCache = Device.planDriverPipelineCache;
pub const planRuntimeCache = Device.planRuntimeCache;
pub const planPipelineArtifactCache = Device.planPipelineArtifactCache;
pub const planBackendParitySemantics = Device.planBackendParitySemantics;
pub const objectCacheDiagnostics = Device.objectCacheDiagnostics;
pub const runtimeDiagnostics = Device.runtimeDiagnostics;
pub const writeCaptureName = Device.writeCaptureName;
pub const memoryBudgetReport = Device.memoryBudgetReport;

pub const validateNativeCommandInsertionDescriptor = Device.validateNativeCommandInsertionDescriptor;
pub const planVulkanTessellationPatchDraw = Device.planVulkanTessellationPatchDraw;
pub const planVulkanMeshDispatch = Device.planVulkanMeshDispatch;
pub const planMetalTessellationPatchDraw = Device.planMetalTessellationPatchDraw;
pub const planMetalMeshDispatch = Device.planMetalMeshDispatch;
pub const planMetalRayTracingMapping = Device.planMetalRayTracingMapping;
pub const makeMetalRayTracingExecutionMapping = Device.makeMetalRayTracingExecutionMapping;

pub const queueCapabilities = Device.queueCapabilities;
pub const planQueue = Device.planQueue;
pub const syncCapabilities = Device.syncCapabilities;
pub const presentModeSupport = Device.presentModeSupport;
pub const resolvePresentMode = Device.resolvePresentMode;
pub const makeSurfaceCollection = Device.makeSurfaceCollection;

pub const CaptureScope = struct {
    _state: [@sizeOf(State)]u8 align(@alignOf(State)),

    const Impl = union(core.Backend) {
        vulkan: void,
        metal: *MetalClearScreen,
    };

    const State = struct {
        backend: core.Backend,
        label_value: []const u8,
        active: bool = true,
        impl: Impl,
    };

    fn init(state_value: State) CaptureScope {
        var result: CaptureScope = undefined;
        result.state().* = state_value;
        return result;
    }

    fn state(self: *const CaptureScope) *State {
        return @ptrCast(@alignCast(@constCast(&self._state)));
    }

    pub fn selectedBackend(self: CaptureScope) core.Backend {
        return self.state().backend;
    }

    pub fn label(self: CaptureScope) []const u8 {
        return self.state().label_value;
    }

    pub fn isActive(self: CaptureScope) bool {
        return self.state().active;
    }

    pub fn end(self: *CaptureScope) core.CaptureError!void {
        if (!self.state().active) return core.CaptureError.CaptureNotActive;
        switch (self.state().impl) {
            .vulkan => return core.CaptureError.UnsupportedCapture,
            .metal => |metal| try metal.endCapture(),
        }
        self.state().active = false;
    }

    pub fn deinit(self: *CaptureScope) void {
        if (!self.state().active) return;
        self.end() catch {};
    }
};

pub fn debugMarkerCapabilities(device: Device) core.DebugMarkerCapabilities {
    return core.DebugMarkerCapabilities.fromFeatures(device.selectedBackend(), device.features());
}

pub fn captureCapabilities(device: Device) core.CaptureCapabilities {
    return core.CaptureCapabilities.forBackend(device.selectedBackend());
}

pub fn beginCaptureScope(
    device: *Device,
    descriptor: core.CaptureScopeDescriptor,
) (core.CaptureError || core.CommandEncodingError)!CaptureScope {
    try descriptor.validate(captureCapabilities(device.*));
    return switch (device.state().impl) {
        .vulkan => core.CaptureError.UnsupportedCapture,
        .metal => |*metal| blk: {
            try metal.beginCapture();
            break :blk CaptureScope.init(.{
                .backend = .metal,
                .label_value = descriptor.label,
                .impl = .{ .metal = metal },
            });
        },
    };
}

pub fn profilingCapabilities(device: Device) core.ProfilingCapabilities {
    var result = core.ProfilingCapabilities.fromFeatures(device.selectedBackend(), device.features());
    const source = device.capabilityReport().source;
    if ((source == .vulkan_query or source == .metal_query) and device.state().native_gpu_timestamp_queries) {
        result.timestamp_source = .native_gpu;
        result.native_gpu_timestamps = true;
    }
    return result;
}

pub fn planProfiling(
    device: Device,
    descriptor: core.ProfilingPlanDescriptor,
) core.QueryError!core.ProfilingPlan {
    return try descriptor.resolve(profilingCapabilities(device));
}

pub fn issueReport(
    device: Device,
    descriptor: core.IssueReportDescriptor,
) core.CommandEncodingError!core.IssueReportSnapshot {
    try descriptor.validate();
    const failure_name = if (descriptor.failure) |failure| @errorName(failure) else null;
    const failure_category = if (descriptor.failure) |failure| core.classifyError(failure) else null;
    return .{
        .backend = device.selectedBackend(),
        .adapter_name = device.adapterInfo().name,
        .capability_source = device.capabilityReport().source,
        .operation = descriptor.operation,
        .object_kind = descriptor.object_kind,
        .object_label = descriptor.object_label,
        .failure_name = failure_name,
        .failure_category = failure_category,
        .features = device.features(),
        .native_features = device.nativeFeatures(),
        .limits = device.limits(),
        .debug_markers = debugMarkerCapabilities(device),
        .capture = captureCapabilities(device),
        .profiling = profilingCapabilities(device),
        .runtime = device.runtimeDiagnostics(),
    };
}

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
            .ray_tracing = vulkan.rayTracingDiagnostics(),
        },
        .metal => |*metal| .{
            .backend = .metal,
            .source = .metal_query,
            .features = metal.features(),
            .native_features = metal.nativeFeatures(),
            .limits = metal.limits(),
            .ray_tracing = .{
                .backend = .metal,
                .supported = metal.nativeFeatures().ray_tracing,
                .blocker = if (metal.nativeFeatures().ray_tracing) .none else .not_evaluated,
            },
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

pub fn initHeadlessRuntime(
    allocator: std.mem.Allocator,
    app_name: [*:0]const u8,
    requested_backend: core.BackendPreference,
    requested_adapter: core.AdapterSelectionDescriptor,
    requested_debug_override: ?core.Backend,
) !*anyopaque {
    const tracker = try allocator.create(ResourceTracker);
    errdefer allocator.destroy(tracker);
    tracker.* = .{};

    const backend_preference: core.BackendPreference = if (build_options.force_vulkan) .vulkan else requested_backend;
    var adapter_selection = requested_adapter;
    if (build_options.force_vulkan) adapter_selection.backend = .vulkan;
    const debug_backend_override: ?core.Backend = if (build_options.force_vulkan) null else requested_debug_override;
    const backend = try core.selectBackend(.{
        .preference = backend_preference,
        .adapter_selection = adapter_selection,
        .debug_override = debug_backend_override,
    });

    var impl: BackendRuntime = switch (backend) {
        .vulkan => .{ .vulkan = try VulkanClearScreen.initHeadless(allocator, app_name) },
        .metal => .{ .metal = try MetalClearScreen.initHeadless() },
    };
    errdefer deinitBackendRuntime(&impl);

    const adapter_info = try resolveAdapterInfo(allocator, &impl);
    errdefer adapter_info.deinit(allocator);
    try validateAdapterSelection(adapter_selection, adapter_info.info);
    var capability_report = resolveCapabilityReport(&impl);
    capability_report.features.native_handles = false;
    capability_report.features.scheduled_presentation = false;
    capability_report.features.minimum_duration_presentation = false;
    const native_gpu_timestamp_queries = switch (impl) {
        .vulkan => |*vulkan| vulkan.supportsNativeTimestampQueries(),
        .metal => |*metal| metal.supportsNativeTimestampQueries(),
    };

    const state_value = try allocator.create(RuntimeState);
    errdefer allocator.destroy(state_value);
    state_value.* = .{
        .allocator = allocator,
        .tracker = tracker,
        .backend = backend,
        .presentation_available = false,
        .surface_descriptor = .{},
        .presentation_descriptor = .{ .extent = .{ .width = 0, .height = 0 } },
        .adapter_info = adapter_info.info,
        .capability_report = capability_report,
        .native_gpu_timestamp_queries = native_gpu_timestamp_queries,
        .owned_adapter_name = adapter_info.owned_name,
        .impl = impl,
    };
    return state_value;
}

pub fn deinitRuntime(pointer: *anyopaque) void {
    const state_value = runtimeState(pointer);
    const allocator = state_value.allocator;
    state_value.tracker.completeAllWork();
    state_value.tracker.assertNoLeaks();
    deinitBackendRuntime(&state_value.impl);
    if (state_value.owned_adapter_name) |name| allocator.free(name);
    allocator.destroy(state_value.tracker);
    allocator.destroy(state_value);
}

pub fn runtimeSelectedBackend(pointer: *anyopaque) core.Backend {
    return runtimeState(pointer).backend;
}

pub fn runtimeAdapterInfo(pointer: *anyopaque) core.AdapterInfo {
    return runtimeState(pointer).adapter_info;
}

pub fn runtimeDevice(pointer: *anyopaque) Device {
    return .{ ._state = pointer };
}

pub fn runtimeQueue(pointer: *anyopaque) Queue {
    var device_view = runtimeDevice(pointer);
    return device_view.queue();
}

pub const WindowContext = struct {
    _state: *anyopaque,

    fn state(self: WindowContext) *RuntimeState {
        return runtimeState(self._state);
    }

    pub fn init(allocator: std.mem.Allocator, options: WindowContextOptions) !WindowContext {
        const tracker = try allocator.create(ResourceTracker);
        errdefer allocator.destroy(tracker);
        tracker.* = .{};

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
        const native_gpu_timestamp_queries = switch (impl) {
            .vulkan => |*vulkan| vulkan.supportsNativeTimestampQueries(),
            .metal => |*metal| metal.supportsNativeTimestampQueries(),
        };

        const state_value = try allocator.create(RuntimeState);
        errdefer allocator.destroy(state_value);
        state_value.* = .{
            .allocator = allocator,
            .tracker = tracker,
            .backend = backend,
            .presentation_available = true,
            .surface_descriptor = options.surface,
            .presentation_descriptor = options.presentation,
            .adapter_info = adapter_info.info,
            .capability_report = capability_report,
            .native_gpu_timestamp_queries = native_gpu_timestamp_queries,
            .owned_adapter_name = adapter_info.owned_name,
            .impl = impl,
        };

        return .{ ._state = state_value };
    }

    pub fn deinit(self: *WindowContext) void {
        deinitRuntime(self._state);
        self._state = undefined;
    }

    pub fn selectedBackend(self: WindowContext) core.Backend {
        return self.state().backend;
    }

    pub fn adapterInfo(self: WindowContext) core.AdapterInfo {
        return self.state().adapter_info;
    }

    pub fn nativeHandles(self: *WindowContext) !core.NativeHandles {
        return switch (self.state().impl) {
            .vulkan => |*vulkan| vulkan.nativeHandles(),
            .metal => |*metal| try metal.nativeHandles(),
        };
    }

    pub fn nativeHandleView(self: *WindowContext) !core.NativeHandleView {
        return core.nativeHandleView(try self.nativeHandles());
    }

    pub fn device(self: *WindowContext) Device {
        return .{ ._state = self._state };
    }

    pub fn queue(self: *WindowContext) Queue {
        var device_view = self.device();
        return device_view.queue();
    }

    pub fn surface(self: *WindowContext) Surface {
        return .{ ._state = self._state };
    }

    pub fn swapchain(self: *WindowContext) Swapchain {
        return .{ ._state = self._state };
    }
};

fn materializeBindGroupEntries(
    allocator: std.mem.Allocator,
    backend: core.Backend,
    descriptor: BindGroupDescriptor,
) ![]core.BindGroupEntry {
    assertAlive(descriptor.layout.state().alive, .bind_group_layout);
    try expectSameBackend(backend, descriptor.layout.selectedBackend());
    const layout_descriptor = descriptor.layout.descriptor();
    try validateFirstSliceBindGroupLayout(layout_descriptor);

    const entries = try allocator.alloc(core.BindGroupEntry, descriptor.entries.len);
    errdefer allocator.free(entries);

    for (descriptor.entries, entries) |entry, *out| {
        const layout_entry = layout_descriptor.entryForBinding(entry.binding) orelse {
            return core.BindingError.ExtraBindGroupEntry;
        };
        if (entry.resourceCount() != layout_entry.array_count) return core.BindingError.InvalidBindGroupResourceCount;
        for (0..entry.resourceCount()) |resource_index| {
            const resource = entry.resourceAt(resource_index);
            if (resource.resourceKind() != layout_entry.resource) {
                return core.BindingError.BindingResourceKindMismatch;
            }
            try resource.validateRuntimeResource(backend);
            try validateAndRecordStorageAccess(resource, layout_entry);
        }
        out.* = .{
            .binding = entry.binding,
            .resource = entry.resourceAt(0).toCoreResource(),
        };
    }

    try (core.BindGroupDescriptor{
        .layout = layout_descriptor,
        .entries = entries,
    }).validate();

    return entries;
}

fn recordBufferBarrier(
    backend: core.Backend,
    features: core.DeviceFeatures,
    buffer: *Buffer,
    descriptor: core.BufferBarrierDescriptor,
) !void {
    assertAlive(buffer.state().alive, .buffer);
    try expectSameBackend(backend, buffer.selectedBackend());
    try descriptor.validate(buffer.length(), features);
    _ = try buffer.state().usage_state.applyExplicitBarrier(descriptor.before, descriptor.after);
}

fn recordTextureBarrier(
    backend: core.Backend,
    features: core.DeviceFeatures,
    texture: *Texture,
    descriptor: core.TextureBarrierDescriptor,
) !void {
    assertAlive(texture.state().alive, .texture);
    try expectSameBackend(backend, texture.selectedBackend());
    const texture_descriptor = texture.textureDescriptor();
    try descriptor.validate(texture_descriptor, features);
    if (texture.state().subresource_usage_tracker) |subresource_tracker| {
        const summary = try subresource_tracker.value.applyExplicitBarrier(
            descriptor.subresourceRange(),
            descriptor.before,
            descriptor.after,
        );
        texture.state().usage_state.current = if (textureSubresourceRangeIsFull(descriptor.subresourceRange(), texture_descriptor))
            descriptor.after
        else
            null;
        if (summary.required_barrier_count != 0) texture.state().usage_state.barrier_count += 1;
    } else {
        _ = try texture.state().usage_state.applyExplicitBarrier(descriptor.before, descriptor.after);
    }
}

fn recordBufferOwnershipTransfer(
    features: core.DeviceFeatures,
    buffer: *Buffer,
    descriptor: core.QueueOwnershipTransferDescriptor,
) !void {
    assertAlive(buffer.state().alive, .buffer);
    try descriptor.validate(features);
    if (buffer.state().owner_queue_value != descriptor.source) return core.CommandEncodingError.InvalidQueueOwnershipState;
    if (descriptor.before == descriptor.after) {
        if (buffer.state().usage_state.current) |current| {
            if (current != descriptor.before) return core.CommandEncodingError.InvalidResourceBarrierState;
        }
        _ = buffer.state().usage_state.transitionTo(descriptor.after);
    } else {
        _ = try buffer.state().usage_state.applyExplicitBarrier(descriptor.before, descriptor.after);
    }
    buffer.state().owner_queue_value = descriptor.destination;
}

fn recordTextureOwnershipTransfer(
    features: core.DeviceFeatures,
    texture: *Texture,
    descriptor: core.QueueOwnershipTransferDescriptor,
) !void {
    assertAlive(texture.state().alive, .texture);
    try descriptor.validate(features);
    if (texture.state().owner_queue_value != descriptor.source) return core.CommandEncodingError.InvalidQueueOwnershipState;
    if (texture.state().subresource_usage_tracker) |subresource_tracker| {
        const summary = if (descriptor.before == descriptor.after)
            try subresource_tracker.value.transition(.{}, descriptor.after)
        else
            try subresource_tracker.value.applyExplicitBarrier(.{}, descriptor.before, descriptor.after);
        texture.state().usage_state.current = descriptor.after;
        if (summary.required_barrier_count != 0) texture.state().usage_state.barrier_count += 1;
    } else {
        if (descriptor.before == descriptor.after) {
            if (texture.state().usage_state.current) |current| {
                if (current != descriptor.before) return core.CommandEncodingError.InvalidResourceBarrierState;
            }
            _ = texture.state().usage_state.transitionTo(descriptor.after);
        } else {
            _ = try texture.state().usage_state.applyExplicitBarrier(descriptor.before, descriptor.after);
        }
    }
    texture.state().owner_queue_value = descriptor.destination;
}

fn ensureBufferOwnedByQueue(queue: core.QueueKind, buffer: *const Buffer) core.CommandEncodingError!void {
    if (buffer.state().owner_queue_value != queue) return core.CommandEncodingError.InvalidQueueOwnershipState;
}

fn ensureTextureOwnedByQueue(queue: core.QueueKind, texture: *const Texture) core.CommandEncodingError!void {
    if (texture.state().owner_queue_value != queue) return core.CommandEncodingError.InvalidQueueOwnershipState;
}

fn ensureTextureViewOwnedByQueue(queue: core.QueueKind, texture_view: *const TextureView) core.CommandEncodingError!void {
    if (texture_view.ownerQueue() != queue) return core.CommandEncodingError.InvalidQueueOwnershipState;
}

fn validateRenderPassOwnership(queue: core.QueueKind, descriptor: RenderPassDescriptor) core.CommandEncodingError!void {
    for (descriptor.color_attachments) |attachment| {
        switch (attachment.target) {
            .current_drawable => {},
            .texture_view => |texture_view| try ensureTextureViewOwnedByQueue(queue, texture_view),
        }
        if (attachment.resolve_target) |resolve_target| {
            try ensureTextureViewOwnedByQueue(queue, resolve_target);
        }
    }
    if (descriptor.depth_attachment) |depth_attachment| {
        switch (depth_attachment.target) {
            .current_drawable => {},
            .texture_view => |texture_view| try ensureTextureViewOwnedByQueue(queue, texture_view),
        }
    }
    if (descriptor.stencil_attachment) |stencil_attachment| {
        switch (stencil_attachment.target) {
            .current_drawable => {},
            .texture_view => |texture_view| try ensureTextureViewOwnedByQueue(queue, texture_view),
        }
    }
}

fn validateDynamicOffsetsForBindGroup(
    bind_group: BindGroup,
    binding: core.BindGroupBinding,
) core.BindingError!void {
    try (core.DynamicOffsetList{ .offsets = binding.dynamic_offsets }).validate(
        bind_group.layoutDescriptor(),
        core.defaultDeviceLimits(bind_group.selectedBackend()),
    );
}

fn validateAndRecordStorageAccess(
    resource: BindGroupResource,
    layout_entry: core.BindGroupLayoutEntry,
) !void {
    const access = layout_entry.resolvedStorageAccess() orelse return;
    switch (resource) {
        .storage_buffer => |binding| {
            if (!binding.buffer.state().usage_value.storage) return RuntimeError.InvalidStorageBufferUsage;
            if (access.requiresWrite()) {
                _ = binding.buffer.recordUsage(.storage_buffer_write);
            } else {
                _ = binding.buffer.recordUsage(.storage_buffer_read);
            }
        },
        .storage_texture => |texture_view| {
            if (access.requiresRead() and !texture_view.state().usage_value.shader_read) {
                return RuntimeError.InvalidStorageTextureUsage;
            }
            if (access.requiresWrite() and !texture_view.state().usage_value.shader_write) {
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

fn validateResourceTableResource(
    resource: BindGroupResource,
    expected_backend: core.Backend,
) !void {
    if (!resourceTableResourceAlive(resource)) return core.BindingError.InvalidResourceTableResource;
    try expectSameBackend(expected_backend, switch (resource) {
        .uniform_buffer => |binding| binding.buffer.selectedBackend(),
        .storage_buffer => |binding| binding.buffer.selectedBackend(),
        .storage_texture => |texture_view| texture_view.selectedBackend(),
        .sampled_texture => |texture_view| texture_view.selectedBackend(),
        .sampler => |sampler_state| sampler_state.selectedBackend(),
        .compare_sampler => |sampler_state| sampler_state.selectedBackend(),
    });
}

fn resourceTableResourceAlive(resource: BindGroupResource) bool {
    return switch (resource) {
        .uniform_buffer => |binding| binding.buffer.state().alive,
        .storage_buffer => |binding| binding.buffer.state().alive,
        .storage_texture => |texture_view| texture_view.state().alive,
        .sampled_texture => |texture_view| texture_view.state().alive,
        .sampler => |sampler_state| sampler_state.state().alive,
        .compare_sampler => |sampler_state| sampler_state.state().alive,
    };
}

fn validateFirstSliceBindGroupLayout(descriptor: core.BindGroupLayoutDescriptor) core.BindingError!void {
    _ = descriptor;
}

fn validateRuntimeSpecialization(
    stage: core.ProgrammableStageDescriptor,
    features: core.DeviceFeatures,
) core.ShaderError!void {
    try stage.specialization.validate(features);
}

fn validateRuntimeRootConstantLayout(
    layout: ?core.RootConstantLayoutDescriptor,
    features: core.DeviceFeatures,
    limits: core.DeviceLimits,
) core.RootConstantError!void {
    if (layout) |root_layout| try root_layout.validate(features, limits);
}

fn validateRootConstantWriteForStages(
    layout: ?core.RootConstantLayoutDescriptor,
    descriptor: core.RootConstantWriteDescriptor,
    stages: core.ShaderVisibility,
) core.RootConstantError!core.RootConstantRange {
    const root_layout = layout orelse return core.RootConstantError.MissingRootConstantRange;
    if (descriptor.bytes.len == 0) return core.RootConstantError.EmptyRootConstantWrite;
    if (descriptor.bytes.len > std.math.maxInt(u32)) return core.RootConstantError.RootConstantRangeTooLarge;
    const byte_count: u32 = @intCast(descriptor.bytes.len);
    const alignment: u32 = 4;
    if (descriptor.offset % alignment != 0 or byte_count % alignment != 0) {
        return core.RootConstantError.InvalidRootConstantAlignment;
    }
    for (root_layout.ranges) |range| {
        if (!rootConstantRangeContainsWrite(range, descriptor)) continue;
        if (!rootConstantVisibilityIntersects(range.visibility, stages)) {
            return core.RootConstantError.RootConstantVisibilityMismatch;
        }
        return range;
    }
    return core.RootConstantError.RootConstantWriteOutOfRange;
}

fn rootConstantRangeContainsWrite(
    range: core.RootConstantRange,
    descriptor: core.RootConstantWriteDescriptor,
) bool {
    if (descriptor.bytes.len == 0 or descriptor.bytes.len > std.math.maxInt(u32)) return false;
    const byte_count: u32 = @intCast(descriptor.bytes.len);
    const range_end = std.math.add(u32, range.offset, range.size) catch return false;
    const write_end = std.math.add(u32, descriptor.offset, byte_count) catch return false;
    return descriptor.offset >= range.offset and write_end <= range_end;
}

fn rootConstantVisibilityIntersects(
    lhs: core.ShaderVisibility,
    rhs: core.ShaderVisibility,
) bool {
    return (lhs.vertex and rhs.vertex) or
        (lhs.fragment and rhs.fragment) or
        (lhs.compute and rhs.compute);
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

fn validateRuntimeMeshPipelineShape(
    descriptor: core.MeshRenderPipelineDescriptor,
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

fn validateIndirectDrawBuffer(offset: u64, buffer_length: usize, argument_size: u64) core.CommandEncodingError!void {
    const end = std.math.add(u64, offset, argument_size) catch return core.CommandEncodingError.InvalidIndirectBufferUsage;
    if (end > buffer_length) return core.CommandEncodingError.InvalidIndirectBufferUsage;
}

fn validateIndirectDrawRange(
    offset: u64,
    draw_count: u32,
    stride: u32,
    buffer_length: usize,
    argument_size: u64,
) core.CommandEncodingError!void {
    const draw_stride = indirectDrawStride(stride, argument_size);
    const last_draw = std.math.sub(u64, draw_count, 1) catch return core.CommandEncodingError.InvalidIndirectBufferUsage;
    const last_offset = std.math.add(
        u64,
        offset,
        std.math.mul(u64, last_draw, draw_stride) catch return core.CommandEncodingError.InvalidIndirectBufferUsage,
    ) catch return core.CommandEncodingError.InvalidIndirectBufferUsage;
    try validateIndirectDrawBuffer(last_offset, buffer_length, argument_size);
}

fn indirectDrawStride(stride: u32, default_stride: u64) u64 {
    return if (stride == 0) default_stride else stride;
}

const VulkanMaterializedBindGroupEntries = struct {
    entries: []VulkanBindGroupBackend.VulkanBindGroup.Entry,
    resources: []VulkanBindGroupBackend.VulkanBindGroup.Resource = &.{},

    fn deinit(self: VulkanMaterializedBindGroupEntries, allocator: std.mem.Allocator) void {
        allocator.free(self.resources);
        allocator.free(self.entries);
    }
};

fn materializeVulkanBindGroupEntries(
    allocator: std.mem.Allocator,
    entries: []const BindGroupEntry,
) !VulkanMaterializedBindGroupEntries {
    const vulkan_entries = try allocator.alloc(VulkanBindGroupBackend.VulkanBindGroup.Entry, entries.len);
    errdefer allocator.free(vulkan_entries);
    const resources = try allocator.alloc(VulkanBindGroupBackend.VulkanBindGroup.Resource, bindGroupArrayResourceCount(entries));
    errdefer allocator.free(resources);

    var resource_index: usize = 0;
    for (entries, vulkan_entries) |entry, *out| {
        const resource = vulkanResourceForBindGroupResource(entry.resourceAt(0));
        out.* = .{
            .binding = entry.binding,
            .resource = resource,
        };
        if (entry.resources.len == 0) continue;

        const start = resource_index;
        for (entry.resources) |array_resource| {
            resources[resource_index] = vulkanResourceForBindGroupResource(array_resource);
            resource_index += 1;
        }
        out.resources = resources[start..resource_index];
    }

    return .{ .entries = vulkan_entries, .resources = resources };
}

fn vulkanResourceForBindGroupResource(resource: BindGroupResource) VulkanBindGroupBackend.VulkanBindGroup.Resource {
    return switch (resource) {
        .uniform_buffer => |binding| .{
            .uniform_buffer = .{
                .buffer = &binding.buffer.state().impl.vulkan,
                .offset = binding.offset,
                .size = binding.size,
            },
        },
        .storage_buffer => |binding| .{
            .storage_buffer = .{
                .buffer = &binding.buffer.state().impl.vulkan,
                .offset = binding.offset,
                .size = binding.size,
            },
        },
        .storage_texture => |texture_view| .{
            .storage_texture = &texture_view.state().impl.vulkan,
        },
        .sampled_texture => |texture_view| .{
            .sampled_texture = &texture_view.state().impl.vulkan,
        },
        .sampler => |sampler_state| .{
            .sampler = &sampler_state.state().impl.vulkan,
        },
        .compare_sampler => |sampler_state| .{
            .compare_sampler = &sampler_state.state().impl.vulkan,
        },
    };
}

fn vulkanResourceForResourceTable(resource: BindGroupResource) VulkanAdvancedBindGroupBackend.ResourceTable.Resource {
    return switch (resource) {
        .uniform_buffer => |binding| .{ .uniform_buffer = .{
            .buffer = &binding.buffer.state().impl.vulkan,
            .offset = binding.offset,
            .size = binding.size,
        } },
        .storage_buffer => |binding| .{ .storage_buffer = .{
            .buffer = &binding.buffer.state().impl.vulkan,
            .offset = binding.offset,
            .size = binding.size,
        } },
        .storage_texture => |view| .{ .storage_texture = &view.state().impl.vulkan },
        .sampled_texture => |view| .{ .sampled_texture = &view.state().impl.vulkan },
        .sampler => |sampler| .{ .sampler = &sampler.state().impl.vulkan },
        .compare_sampler => |sampler| .{ .compare_sampler = &sampler.state().impl.vulkan },
    };
}

const MetalMaterializedBindGroupEntries = struct {
    entries: []MetalBindGroupBackend.MetalBindGroup.Entry,
    resources: []MetalBindGroupBackend.MetalBindGroup.Resource = &.{},

    fn deinit(self: MetalMaterializedBindGroupEntries, allocator: std.mem.Allocator) void {
        allocator.free(self.resources);
        allocator.free(self.entries);
    }
};

fn materializeMetalBindGroupEntries(
    allocator: std.mem.Allocator,
    entries: []const BindGroupEntry,
) !MetalMaterializedBindGroupEntries {
    const metal_entries = try allocator.alloc(MetalBindGroupBackend.MetalBindGroup.Entry, entries.len);
    errdefer allocator.free(metal_entries);
    const resources = try allocator.alloc(MetalBindGroupBackend.MetalBindGroup.Resource, bindGroupArrayResourceCount(entries));
    errdefer allocator.free(resources);

    var resource_index: usize = 0;
    for (entries, metal_entries) |entry, *out| {
        const resource = metalResourceForBindGroupResource(entry.resourceAt(0));
        out.* = .{
            .binding = entry.binding,
            .resource = resource,
        };
        if (entry.resources.len == 0) continue;

        const start = resource_index;
        for (entry.resources) |array_resource| {
            resources[resource_index] = metalResourceForBindGroupResource(array_resource);
            resource_index += 1;
        }
        out.resources = resources[start..resource_index];
    }

    return .{ .entries = metal_entries, .resources = resources };
}

fn metalResourceForBindGroupResource(resource: BindGroupResource) MetalBindGroupBackend.MetalBindGroup.Resource {
    return switch (resource) {
        .uniform_buffer => |binding| .{
            .uniform_buffer = .{
                .buffer = &binding.buffer.state().impl.metal,
                .offset = binding.offset,
                .size = binding.size,
            },
        },
        .storage_buffer => |binding| .{
            .storage_buffer = .{
                .buffer = &binding.buffer.state().impl.metal,
                .offset = binding.offset,
                .size = binding.size,
            },
        },
        .storage_texture => |texture_view| .{
            .storage_texture = &texture_view.state().impl.metal,
        },
        .sampled_texture => |texture_view| .{
            .sampled_texture = &texture_view.state().impl.metal,
        },
        .sampler => |sampler_state| .{
            .sampler = &sampler_state.state().impl.metal,
        },
        .compare_sampler => |sampler_state| .{
            .compare_sampler = &sampler_state.state().impl.metal,
        },
    };
}

fn metalResourceForResourceTable(resource: BindGroupResource) MetalAdvancedBindGroupBackend.ResourceTable.Resource {
    return switch (resource) {
        .uniform_buffer => |binding| .{ .uniform_buffer = .{
            .buffer = &binding.buffer.state().impl.metal,
            .offset = binding.offset,
            .size = binding.size,
        } },
        .storage_buffer => |binding| .{ .storage_buffer = .{
            .buffer = &binding.buffer.state().impl.metal,
            .offset = binding.offset,
            .size = binding.size,
        } },
        .storage_texture => |view| .{ .storage_texture = &view.state().impl.metal },
        .sampled_texture => |view| .{ .sampled_texture = &view.state().impl.metal },
        .sampler => |sampler| .{ .sampler = &sampler.state().impl.metal },
        .compare_sampler => |sampler| .{ .compare_sampler = &sampler.state().impl.metal },
    };
}

fn bindGroupArrayResourceCount(entries: []const BindGroupEntry) usize {
    var count: usize = 0;
    for (entries) |entry| {
        if (entry.resources.len != 0) count += entry.resources.len;
    }
    return count;
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
        .resource_table => "resource_table",
        .indirect_command_buffer => "indirect_command_buffer",
        .external_memory => "external_memory",
        .external_buffer => "external_buffer",
        .external_semaphore => "external_semaphore",
        .external_event => "external_event",
        .fence => "fence",
        .event => "event",
        .query_set => "query_set",
        .heap => "heap",
        .acceleration_structure => "acceleration_structure",
        .ray_tracing_pipeline_state => "ray_tracing_pipeline_state",
        .shader_binding_table => "shader_binding_table",
        .metal_ray_tracing_execution_mapping => "metal_ray_tracing_execution_mapping",
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

fn mipDimension(base: u32, level: u32) u32 {
    var value = base;
    var i: u32 = 0;
    while (i < level and value > 1) : (i += 1) {
        value /= 2;
    }
    return value;
}

fn testRuntimeState(
    allocator: std.mem.Allocator,
    tracker: *ResourceTracker,
    backend: core.Backend,
    impl: *BackendRuntime,
    adapter_name: []const u8,
    capability_report: core.DeviceCapabilityReport,
) RuntimeState {
    return .{
        .allocator = allocator,
        .tracker = tracker,
        .backend = backend,
        .surface_descriptor = undefined,
        .presentation_descriptor = undefined,
        .adapter_info = .{
            .backend = backend,
            .name = adapter_name,
        },
        .capability_report = capability_report,
        .impl = impl.*,
    };
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

test "resource tracker records cache lookups and opt out policy" {
    var tracker = ResourceTracker{};

    const first = tracker.beginObjectCacheLookup(.sampler, 99, .{});
    try std.testing.expect(!first.cache_hit);
    tracker.finishObjectCacheLookup(first, 11);

    const second = tracker.beginObjectCacheLookup(.sampler, 99, .{});
    try std.testing.expect(second.cache_hit);
    tracker.finishObjectCacheLookup(second, 5);

    const diagnostics_only = tracker.beginObjectCacheLookup(.sampler, 111, .{ .mode = .diagnostics_only });
    try std.testing.expect(!diagnostics_only.cache_hit);
    tracker.finishObjectCacheLookup(diagnostics_only, 7);
    const diagnostics_only_again = tracker.beginObjectCacheLookup(.sampler, 111, .{ .mode = .diagnostics_only });
    try std.testing.expect(!diagnostics_only_again.cache_hit);

    const sampler_stats = tracker.objectCacheDiagnostics().stats(.sampler);
    try std.testing.expectEqual(@as(u64, 1), sampler_stats.hits);
    try std.testing.expectEqual(@as(u64, 3), sampler_stats.creation_attempts);
    try std.testing.expectEqual(@as(u64, 1), sampler_stats.equivalent_recreations);
    try std.testing.expectEqual(@as(u64, 1), sampler_stats.reuse_bypassed_creations);
}

test "resource tracker exposes runtime diagnostics snapshot" {
    var tracker = ResourceTracker{};
    tracker.retain(.buffer);
    tracker.retain(.texture);
    const serial = tracker.submitWork();
    tracker.release(.buffer);
    tracker.recordObjectCreation(.shader_module, 77, .{}, 31);

    const snapshot = tracker.diagnosticsSnapshot();
    try std.testing.expectEqual(@as(usize, 1), snapshot.live_resources);
    try std.testing.expectEqual(@as(usize, 1), snapshot.pending_retirements);
    try std.testing.expectEqual(@as(u64, serial), snapshot.submitted_work_serial);
    try std.testing.expectEqual(@as(u64, 0), snapshot.completed_work_serial);
    try std.testing.expect(snapshot.hasPendingGpuWork());
    try std.testing.expect(snapshot.hasLiveResources());
    try std.testing.expectEqual(@as(u64, 1), snapshot.object_cache.shader_modules.creation_attempts);

    tracker.completeWork(serial);
    try std.testing.expectEqual(@as(usize, 0), tracker.diagnosticsSnapshot().pending_retirements);
}

test "runtime blit encoder records buffer usage transitions" {
    var tracker = ResourceTracker{};
    var command_buffer = CommandBuffer.init(.{ .backend = .vulkan });
    var encoder = BlitCommandEncoder.init(.{
        .backend = .vulkan,
        .command_buffer = &command_buffer,
    });
    const source_state = Buffer.State{
        .backend = .vulkan,
        .tracker = &tracker,
        .impl = undefined,

        .length_value = 4,
        .usage_value = .{ .copy_source = true },
    };
    var source = Buffer.init(source_state);
    const destination_state = Buffer.State{
        .backend = .vulkan,
        .tracker = &tracker,
        .impl = undefined,

        .length_value = 4,
        .usage_value = .{ .copy_destination = true },
    };
    var destination = Buffer.init(destination_state);

    try encoder.copyBufferToBuffer(&source, &destination, .{ .size = 4 });

    try std.testing.expectEqual(core.ResourceUsageKind.copy_source, source.currentUsage().?);
    try std.testing.expectEqual(core.ResourceUsageKind.copy_destination, destination.currentUsage().?);
}

test "runtime texture views share subresource usage across passes" {
    const descriptor = core.TextureDescriptor{
        .format = .rgba8_unorm,
        .width = 8,
        .height = 8,
        .depth_or_array_layers = 2,
        .mip_level_count = 2,
        .usage = .{ .shader_read = true, .render_attachment = true },
    };
    var subresource_tracker = SharedTextureUsageTracker{
        .allocator = std.testing.allocator,
        .value = try core.TextureSubresourceUsageTracker.init(std.testing.allocator, descriptor),
    };
    defer subresource_tracker.value.deinit();
    var tracker = ResourceTracker{};
    var mip_zero = TextureView.init(.{
        .backend = .metal,
        .tracker = &tracker,
        .format_value = .rgba8_unorm,
        .usage_value = descriptor.usage,
        .sample_count_value = 1,
        .width_value = 8,
        .height_value = 8,
        .base_mip_level_value = 0,
        .mip_level_count_value = 1,
        .base_array_layer_value = 0,
        .array_layer_count_value = 1,
        .subresource_usage_tracker = &subresource_tracker,
        .impl = undefined,
    });
    var mip_one = TextureView.init(.{
        .backend = .metal,
        .tracker = &tracker,
        .format_value = .rgba8_unorm,
        .usage_value = descriptor.usage,
        .sample_count_value = 1,
        .width_value = 4,
        .height_value = 4,
        .base_mip_level_value = 1,
        .mip_level_count_value = 1,
        .base_array_layer_value = 1,
        .array_layer_count_value = 1,
        .subresource_usage_tracker = &subresource_tracker,
        .impl = undefined,
    });

    _ = mip_zero.recordUsage(.render_attachment_write);
    _ = mip_one.recordUsage(.sampled_texture);
    try std.testing.expectEqual(core.ResourceUsageKind.render_attachment_write, subresource_tracker.value.currentUsage(0, 0).?);
    try std.testing.expectEqual(core.ResourceUsageKind.sampled_texture, subresource_tracker.value.currentUsage(1, 1).?);
    try std.testing.expect(subresource_tracker.value.currentUsage(0, 1) == null);
}

test "Period 42 shared texture usage state outlives its source owner" {
    const shared = try SharedTextureUsageTracker.init(std.testing.allocator, .{
        .format = .rgba8_unorm,
        .width = 4,
        .height = 4,
        .usage = .{ .shader_read = true, .copy_destination = true },
    });
    shared.retain();
    shared.release();
    defer shared.release();

    _ = try shared.value.transition(.{}, .copy_destination);
    try std.testing.expectEqual(core.ResourceUsageKind.copy_destination, shared.value.currentUsage(0, 0).?);
}

test "runtime compute encoder lowers valid dispatch indirect and validates usage" {
    var tracker = ResourceTracker{};
    var command_buffer = CommandBuffer.init(.{ .backend = .vulkan });
    var encoder = ComputeCommandEncoder.init(.{
        .backend = .vulkan,
        .command_buffer = &command_buffer,
        .debug = .{ .pipeline_set = true },
    });
    const indirect_buffer_state = Buffer.State{
        .backend = .vulkan,
        .tracker = &tracker,
        .impl = undefined,

        .length_value = 16,
        .usage_value = .{ .indirect = true },
    };
    var indirect_buffer = Buffer.init(indirect_buffer_state);
    const storage_buffer_state = Buffer.State{
        .backend = .vulkan,
        .tracker = &tracker,
        .impl = undefined,

        .length_value = 16,
        .usage_value = .{ .storage = true },
    };
    var storage_buffer = Buffer.init(storage_buffer_state);

    try encoder.dispatchThreadgroupsIndirect(&indirect_buffer, .{});
    try std.testing.expectEqual(core.ResourceUsageKind.indirect_buffer, indirect_buffer.currentUsage().?);
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
    var device_state = testRuntimeState(
        std.testing.allocator,
        &tracker,
        .metal,
        &backend_runtime,
        "test metal adapter",
        core.defaultDeviceCapabilityReport(.metal),
    );
    device_state.adapter_info.vendor = "Test Vendor";
    const device = Device{ ._state = &device_state };

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
    var device_state = testRuntimeState(std.testing.allocator, &tracker, .metal, &backend_runtime, "test metal adapter", core.defaultDeviceCapabilityReport(.metal));
    const device = Device{ ._state = &device_state };

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

test "runtime device plans sparse buffer lowering from native capabilities" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.features.sparse_buffers = false;
    report.native_features.sparse_buffers = true;
    report.limits.sparse_buffer_page_size = 4096;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test sparse adapter", report);
    const device = Device{ ._state = &device_state };

    const descriptor = core.SparseBufferDescriptor{
        .size = 8192,
    };
    try std.testing.expectError(core.AdvancedFeatureError.UnsupportedSparseBuffers, device.validateSparseBufferDescriptor(descriptor));

    const lowering = try device.planSparseBufferLowering(descriptor);
    try std.testing.expectEqual(core.SparseBufferLoweringMode.vulkan_sparse_binding, lowering.mode);
    try std.testing.expectEqual(@as(u64, 2), lowering.page_count);
}

test "runtime device plans sparse texture lowering from native capabilities" {
    var tracker = ResourceTracker{};
    var backend_runtime = BackendRuntime{
        .metal = .{
            .handle = undefined,
            .extent = .{ .width = 1, .height = 1 },
        },
    };
    var report = core.defaultDeviceCapabilityReport(.metal);
    report.features.tiled_textures = false;
    report.native_features.tiled_textures = true;
    report.limits.sparse_texture_page_width = 64;
    report.limits.sparse_texture_page_height = 64;
    report.limits.sparse_texture_page_depth = 1;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .metal, &backend_runtime, "test tiled adapter", report);
    const device = Device{ ._state = &device_state };

    const descriptor = core.SparseTextureDescriptor{
        .kind = .tiled_texture,
        .texture = .{
            .format = .rgba8_unorm,
            .width = 130,
            .height = 129,
            .usage = .{ .shader_read = true },
        },
        .page_extent = .{ .width = 64, .height = 64, .depth = 1 },
    };
    try std.testing.expectError(core.AdvancedFeatureError.UnsupportedTiledTextures, device.validateSparseTextureDescriptor(descriptor));

    const lowering = try device.planSparseTextureLowering(descriptor);
    try std.testing.expectEqual(core.SparseTextureLoweringMode.metal_tiled_texture, lowering.mode);
    try std.testing.expectEqual(@as(u32, 3), lowering.page_grid.width);
    try std.testing.expectEqual(@as(u32, 3), lowering.page_grid.height);
}

test "runtime device plans sparse mapping commits from native capabilities" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.features.sparse_buffers = false;
    report.native_features.sparse_buffers = true;
    report.limits.sparse_buffer_page_size = 4096;
    report.limits.max_sparse_regions_per_commit = 2;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test sparse commit adapter", report);
    const device = Device{ ._state = &device_state };

    const descriptor = core.SparseMappingCommitDescriptor{
        .buffers = &.{.{
            .offset = 0,
            .size = 8192,
        }},
    };
    try std.testing.expectError(core.AdvancedFeatureError.UnsupportedSparseBuffers, device.validateSparseMappingCommit(descriptor));

    const plan = try device.planSparseMappingCommit(descriptor);
    try std.testing.expectEqual(@as(usize, 1), plan.total_regions);
    try std.testing.expectEqual(@as(usize, 1), plan.buffer_commits);
    try std.testing.expectEqual(@as(u64, 8192), plan.buffer_bytes);

    const churn = try device.planSparseResidencyChurn(.{
        .iterations = 2,
        .commit = descriptor,
        .evict = .{
            .buffers = &.{.{
                .offset = 0,
                .size = 8192,
                .residency = .evicted,
            }},
        },
    });
    try std.testing.expectEqual(@as(u32, 2), churn.iterations);
    try std.testing.expectEqual(@as(u64, 2), churn.total_commit_regions);
    try std.testing.expectEqual(@as(u64, 2), churn.total_evict_regions);
    try std.testing.expectEqual(@as(u64, 8192), churn.peak_buffer_bytes);
    try std.testing.expect(churn.has_evictions);
}

test "runtime device plans tessellation lowering from native capabilities" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.metal);
    report.features.tessellation = false;
    report.native_features.tessellation = true;
    report.limits.max_tessellation_control_points = 16;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .metal, &backend_runtime, "test tessellation adapter", report);
    const device = Device{ ._state = &device_state };

    const descriptor = core.TessellationDescriptor{
        .control_point_count = 4,
        .domain = .quad,
        .partition_mode = .fractional_even,
        .has_control_stage = true,
        .has_evaluation_stage = true,
    };
    try std.testing.expectError(core.AdvancedFeatureError.UnsupportedTessellation, device.validateTessellationDescriptor(descriptor));

    const lowering = try device.planTessellationLowering(descriptor);
    try std.testing.expectEqual(@as(u32, 4), lowering.patchControlPoints());
    try std.testing.expectEqual(core.TessellationDomain.quad, lowering.domain());
    try std.testing.expect(lowering.requiresFactorBuffer());
}

test "runtime device plans tessellation patch draws from native capabilities" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.features.tessellation = false;
    report.native_features.tessellation = true;
    report.limits.max_tessellation_control_points = 32;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test tessellation patch draw adapter", report);
    const device = Device{ ._state = &device_state };

    const descriptor = core.TessellationPatchDrawDescriptor{
        .tessellation = .{
            .control_point_count = 3,
            .control_stage = .{ .entry_point = "tc_main" },
            .evaluation_stage = .{ .entry_point = "te_main" },
        },
        .patch_count = 8,
        .instance_count = 2,
    };
    try std.testing.expectError(core.AdvancedFeatureError.UnsupportedTessellation, device.validateTessellationPatchDrawDescriptor(descriptor));

    const plan = try device.planTessellationPatchDraw(descriptor);
    try std.testing.expectEqual(@as(u32, 3), plan.patchControlPoints());
    try std.testing.expectEqual(@as(u64, 16), plan.total_patches);
    try std.testing.expect(!plan.requiresFactorBuffer());
}

test "runtime device plans Vulkan tessellation patch draw lowering" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.native_features.tessellation = true;
    report.limits.max_tessellation_control_points = 32;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test vulkan tessellation draw adapter", report);
    const device = Device{ ._state = &device_state };

    const lowering = try device.planVulkanTessellationPatchDraw(.{
        .tessellation = .{
            .control_point_count = 4,
            .has_control_stage = true,
            .has_evaluation_stage = true,
        },
        .patch_count = 7,
        .base_patch = 1,
    });
    try std.testing.expectEqual(@as(u32, 28), lowering.draw_vertex_count);
    try std.testing.expectEqual(@as(u32, 4), lowering.first_vertex);
}

test "runtime device plans Metal tessellation factor buffer ownership" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.metal);
    report.native_features.tessellation = true;
    report.limits.max_tessellation_control_points = 16;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .metal, &backend_runtime, "test metal tessellation draw adapter", report);
    const device = Device{ ._state = &device_state };

    const lowering = try device.planMetalTessellationPatchDraw(.{
        .tessellation = .{
            .control_point_count = 4,
            .domain = .quad,
            .has_control_stage = true,
            .has_evaluation_stage = true,
        },
        .patch_count = 4,
        .factor_buffer = .{ .stride = 32, .patch_count = 4 },
    });
    try std.testing.expectEqual(core.MetalTessellationFactorBufferOwnership.application_provided, lowering.factor_buffer_ownership);
    try std.testing.expectEqual(@as(u32, 32), lowering.factor_buffer.stride);
}

test "runtime device plans mesh lowering from native capabilities" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.features.mesh_shaders = false;
    report.features.task_shaders = false;
    report.native_features.mesh_shaders = true;
    report.native_features.task_shaders = true;
    report.limits.max_mesh_threads_per_threadgroup = 128;
    report.limits.max_task_threads_per_threadgroup = 64;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test mesh adapter", report);
    const device = Device{ ._state = &device_state };

    const descriptor = core.MeshPipelineDescriptor{
        .mesh_entry_point = "ms_main",
        .task_entry_point = "ts_main",
        .mesh_threads_per_threadgroup = 64,
        .task_threads_per_threadgroup = 32,
    };
    try std.testing.expectError(core.AdvancedFeatureError.UnsupportedMeshShaders, device.validateMeshPipelineDescriptor(descriptor));

    const lowering = try device.planMeshPipelineLowering(descriptor);
    try std.testing.expectEqualStrings("ms_main", lowering.meshEntryPoint());
    try std.testing.expectEqualStrings("ts_main", lowering.taskEntryPoint().?);
    try std.testing.expectEqual(@as(u32, 64), lowering.meshThreadsPerThreadgroup());
    try std.testing.expectEqual(@as(u32, 32), lowering.taskThreadsPerThreadgroup());
    try std.testing.expect(lowering.hasTaskStage());
}

test "runtime device plans Vulkan mesh dispatch from native capabilities" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.features.mesh_shaders = false;
    report.native_features.mesh_shaders = true;
    report.limits.max_mesh_threads_per_threadgroup = 128;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test vulkan mesh dispatch adapter", report);
    const device = Device{ ._state = &device_state };

    const descriptor = core.MeshDispatchDescriptor{
        .pipeline = .{
            .mesh_entry_point = "mesh_main",
            .mesh_threads_per_threadgroup = 64,
        },
        .threadgroup_count_x = 5,
        .threadgroup_count_y = 2,
    };
    try std.testing.expectError(core.AdvancedFeatureError.UnsupportedMeshShaders, device.validateMeshDispatchDescriptor(descriptor));

    const lowering = try device.planVulkanMeshDispatch(descriptor);
    try std.testing.expectEqual(@as(u32, 5), lowering.group_count_x);
    try std.testing.expectEqual(@as(u32, 2), lowering.group_count_y);
    try std.testing.expectEqual(@as(u64, 10), lowering.total_threadgroups);
}

test "runtime device plans Metal mesh dispatch from native capabilities" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.metal);
    report.features.mesh_shaders = false;
    report.features.task_shaders = false;
    report.native_features.mesh_shaders = true;
    report.native_features.task_shaders = true;
    report.limits.max_mesh_threads_per_threadgroup = 64;
    report.limits.max_task_threads_per_threadgroup = 16;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .metal, &backend_runtime, "test metal mesh dispatch adapter", report);
    const device = Device{ ._state = &device_state };

    const descriptor = core.MeshDispatchDescriptor{
        .pipeline = .{
            .mesh_entry_point = "mesh_main",
            .task_entry_point = "object_main",
            .mesh_threads_per_threadgroup = 32,
            .task_threads_per_threadgroup = 8,
        },
        .threadgroup_count_x = 3,
    };
    try std.testing.expectError(core.AdvancedFeatureError.UnsupportedMeshShaders, device.validateMeshDispatchDescriptor(descriptor));

    const lowering = try device.planMetalMeshDispatch(descriptor);
    try std.testing.expectEqualStrings("object_main", lowering.object_entry_point.?);
    try std.testing.expectEqual(@as(u32, 3), lowering.group_count_x);
    try std.testing.expectEqual(@as(u64, 3), lowering.total_threadgroups);
}

test "runtime device plans acceleration structure builds from native capabilities" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.features.acceleration_structures = false;
    report.native_features.acceleration_structures = true;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test acceleration adapter", report);
    const device = Device{ ._state = &device_state };

    const descriptor = core.AccelerationStructureBuildDescriptor{
        .acceleration_structure = .{
            .kind = .bottom_level,
            .primitive_count = 2,
            .allow_update = true,
        },
        .geometries = &.{.{
            .kind = .triangles,
            .primitive_count = 2,
            .vertex_stride = 24,
        }},
        .mode = .update,
        .scratch_alignment = 512,
    };
    try std.testing.expectError(core.AdvancedFeatureError.UnsupportedAccelerationStructures, device.validateAccelerationStructureDescriptor(descriptor.acceleration_structure));

    const plan = try device.planAccelerationStructureBuild(descriptor);
    try std.testing.expectEqual(core.Backend.vulkan, plan.backend);
    try std.testing.expectEqual(core.AccelerationStructureBuildMode.update, plan.mode);
    try std.testing.expectEqual(@as(u32, 2), plan.primitive_count);
    try std.testing.expect(plan.update_scratch_size > 0);
}

test "runtime device plans acceleration structure maintenance from native capabilities" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.features.acceleration_structures = false;
    report.native_features.acceleration_structures = true;
    report.native_features.acceleration_structure_update = true;
    report.native_features.acceleration_structure_refit = true;
    report.native_features.acceleration_structure_compaction = true;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test acceleration maintenance adapter", report);
    const device = Device{ ._state = &device_state };

    const descriptor = core.AccelerationStructureMaintenanceDescriptor{
        .acceleration_structure = .{
            .kind = .bottom_level,
            .primitive_count = 4,
            .allow_update = true,
        },
        .operation = .refit,
        .scratch_alignment = 512,
    };
    try std.testing.expectError(core.AdvancedFeatureError.UnsupportedAccelerationStructures, device.validateAccelerationStructureDescriptor(descriptor.acceleration_structure));

    const plan = try device.planAccelerationStructureMaintenance(descriptor);
    try std.testing.expectEqual(core.Backend.vulkan, plan.backend);
    try std.testing.expectEqual(core.AccelerationStructureMaintenanceOperation.refit, plan.operation);
    try std.testing.expectEqual(@as(u32, 4), plan.primitive_count);
    try std.testing.expect(plan.requires_allow_update);
    try std.testing.expect(plan.scratch_size > 0);

    const compact_plan = try device.planAccelerationStructureMaintenance(.{
        .acceleration_structure = descriptor.acceleration_structure,
        .operation = .compact,
        .source_result_size = 4096,
        .compacted_size_hint = 2048,
    });
    try std.testing.expect(compact_plan.isCompaction());
    try std.testing.expect(compact_plan.requires_destination_as);
    try std.testing.expectEqual(@as(u64, 2048), compact_plan.compacted_size_upper_bound);
}

test "runtime device plans top level acceleration structure instance layouts from native capabilities" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.features.acceleration_structures = false;
    report.native_features.acceleration_structures = true;
    report.native_features.ray_tracing_procedural_geometry = true;
    report.native_features.ray_tracing_custom_intersection = true;
    report.limits.max_acceleration_structure_instances = 64;
    report.limits.max_shader_binding_table_records = 16;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test many instance adapter", report);
    const device = Device{ ._state = &device_state };

    const instances = [_]core.TopLevelAccelerationStructureInstanceDescriptor{
        .{
            .geometry_kind = .triangles,
            .custom_index = 1,
            .material_index = 1,
        },
        .{
            .geometry_kind = .aabbs,
            .instance_mask = 0x3f,
            .shader_binding_table_record_offset = 3,
            .material_index = 2,
        },
    };
    const plan = try device.planTopLevelAccelerationStructureLayout(.{
        .instances = instances[0..],
        .allow_mixed_geometry = true,
        .material_table_entries = 4,
    });
    try std.testing.expectEqual(core.Backend.vulkan, plan.backend);
    try std.testing.expectEqual(@as(u32, 2), plan.instance_count);
    try std.testing.expectEqual(@as(u32, 1), plan.triangle_instances);
    try std.testing.expectEqual(@as(u32, 1), plan.procedural_instances);
    try std.testing.expect(plan.requires_procedural_geometry);
    try std.testing.expect(plan.requires_custom_intersection);
    try std.testing.expectEqual(@as(u32, 3), plan.max_shader_binding_table_record_offset);
}

test "runtime encodes acceleration structure build resources from native capabilities" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.features.acceleration_structures = false;
    report.native_features.acceleration_structures = true;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test acceleration build adapter", report);
    var device = Device{ ._state = &device_state };

    const descriptor = core.AccelerationStructureDescriptor{
        .label = "blas",
        .kind = .bottom_level,
        .primitive_count = 1,
    };
    var acceleration_structure = try device.makeAccelerationStructure(descriptor);
    defer acceleration_structure.deinit();
    try std.testing.expectEqual(@as(usize, 1), tracker.acceleration_structures);
    try std.testing.expectEqualStrings("blas", acceleration_structure.label().?);
    try std.testing.expect(acceleration_structure.hasBackendPrivateHandle());
    try std.testing.expectEqual(@as(u64, 0), acceleration_structure.backendPrivateBuildCount());

    const plan = try device.planAccelerationStructureBuild(.{
        .acceleration_structure = descriptor,
        .geometries = &.{.{
            .kind = .triangles,
            .primitive_count = 1,
            .vertex_stride = 24,
        }},
    });
    const scratch_state = Buffer.State{
        .backend = .vulkan,
        .tracker = &tracker,
        .impl = undefined,

        .length_value = @intCast(plan.scratch_size),
        .usage_value = .{ .acceleration_structure_scratch = true },
    };
    var scratch = Buffer.init(scratch_state);
    var bad_scratch = scratch;
    bad_scratch.state().usage_value = .{ .storage = true };

    try std.testing.expectError(
        core.AdvancedFeatureError.InvalidAccelerationStructureResources,
        (AccelerationStructureBuildResources{
            .result = &acceleration_structure,
            .scratch = &bad_scratch,
        }).validate(.vulkan, plan),
    );
    try std.testing.expectError(
        core.AdvancedFeatureError.InvalidAccelerationStructureResources,
        (AccelerationStructureBuildResources{
            .result = &acceleration_structure,
            .scratch = &scratch,
            .scratch_offset = 1,
        }).validate(.vulkan, plan),
    );

    var command_buffer = CommandBuffer.init(.{
        .backend = .vulkan,
        .queue_kind_value = .compute,
    });
    try command_buffer.encodeAccelerationStructureBuild(plan, .{
        .result = &acceleration_structure,
        .scratch = &scratch,
    });
    try std.testing.expect(acceleration_structure.isBuilt());
    try std.testing.expectEqual(@as(u64, 1), acceleration_structure.backendPrivateBuildCount());
    try std.testing.expect(!acceleration_structure.lastBuildRecordedBackendCommand());
    try std.testing.expect(!acceleration_structure.lastBuildSubmittedToDriver());
    try std.testing.expectEqual(core.ResourceUsageKind.acceleration_structure_scratch, scratch.currentUsage().?);
}

test "runtime encodes acceleration structure refit and compaction resources" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.native_features.acceleration_structures = true;
    report.native_features.acceleration_structure_update = true;
    report.native_features.acceleration_structure_refit = true;
    report.native_features.acceleration_structure_compaction = true;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test acceleration maintenance adapter", report);
    var device = Device{ ._state = &device_state };
    const descriptor = core.AccelerationStructureDescriptor{
        .kind = .bottom_level,
        .primitive_count = 1,
        .allow_update = true,
    };
    var source = try device.makeAccelerationStructure(descriptor);
    defer source.deinit();
    var destination = try device.makeAccelerationStructure(descriptor);
    defer destination.deinit();

    const build_plan = try device.planAccelerationStructureBuild(.{
        .acceleration_structure = descriptor,
        .flags = .{ .allow_update = true },
    });
    var scratch = Buffer.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .impl = undefined,
        .length_value = @intCast(@max(build_plan.scratch_size, build_plan.update_scratch_size)),
        .usage_value = .{ .acceleration_structure_scratch = true },
    });
    var command_buffer = CommandBuffer.init(.{
        .backend = .vulkan,
        .queue_kind_value = .compute,
    });
    try command_buffer.encodeAccelerationStructureBuild(build_plan, .{
        .result = &source,
        .scratch = &scratch,
    });

    const refit_plan = try device.planAccelerationStructureMaintenance(.{
        .acceleration_structure = descriptor,
        .operation = .refit,
    });
    try command_buffer.encodeAccelerationStructureMaintenance(refit_plan, .{
        .source = &source,
        .scratch = &scratch,
    });
    try std.testing.expectEqual(@as(u64, 1), source.backendPrivateMaintenanceCount());
    try std.testing.expect(!source.lastMaintenanceRecordedBackendCommand());
    try std.testing.expect(!source.lastMaintenanceSubmittedToDriver());

    const compact_plan = try device.planAccelerationStructureMaintenance(.{
        .acceleration_structure = descriptor,
        .operation = .compact,
        .source_result_size = source.resultSize(),
        .compacted_size_hint = destination.resultSize(),
    });
    try std.testing.expectError(
        core.AdvancedFeatureError.InvalidAccelerationStructureResources,
        command_buffer.encodeAccelerationStructureMaintenance(compact_plan, .{
            .source = &source,
            .destination = &destination,
        }),
    );
    const compactable_build_plan = try device.planAccelerationStructureBuild(.{
        .acceleration_structure = descriptor,
        .flags = .{ .allow_update = true, .allow_compaction = true },
    });
    try command_buffer.encodeAccelerationStructureBuild(compactable_build_plan, .{
        .result = &source,
        .scratch = &scratch,
    });
    try command_buffer.encodeAccelerationStructureMaintenance(compact_plan, .{
        .source = &source,
        .destination = &destination,
    });
    try std.testing.expect(destination.isBuilt());
    try std.testing.expectEqual(@as(u64, 2), source.backendPrivateMaintenanceCount());
}

test "runtime validates acceleration structure mesh build input buffers" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.features.acceleration_structures = false;
    report.native_features.acceleration_structures = true;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test acceleration mesh adapter", report);
    var device = Device{ ._state = &device_state };

    const geometry = core.AccelerationStructureGeometryDescriptor{
        .kind = .triangles,
        .primitive_count = 1,
        .vertex_count = 3,
        .vertex_stride = 12,
    };
    const descriptor = core.AccelerationStructureDescriptor{
        .label = "mesh blas",
        .kind = .bottom_level,
        .primitive_count = 1,
    };
    var acceleration_structure = try device.makeAccelerationStructure(descriptor);
    defer acceleration_structure.deinit();
    const plan = try device.planAccelerationStructureBuild(.{
        .acceleration_structure = descriptor,
        .geometries = &.{geometry},
    });

    const scratch_state = Buffer.State{
        .backend = .vulkan,
        .tracker = &tracker,
        .impl = undefined,

        .length_value = @intCast(plan.scratch_size),
        .usage_value = .{ .acceleration_structure_scratch = true },
    };
    var scratch = Buffer.init(scratch_state);
    const vertex_buffer_state = Buffer.State{
        .backend = .vulkan,
        .tracker = &tracker,
        .impl = undefined,

        .length_value = 36,
        .usage_value = .{ .acceleration_structure_build_input = true },
    };
    var vertex_buffer = Buffer.init(vertex_buffer_state);
    var bad_vertex_buffer = vertex_buffer;
    bad_vertex_buffer.state().usage_value = .{ .vertex = true };

    const geometry_resources = [_]AccelerationStructureGeometryResources{.{
        .triangles = .{
            .descriptor = geometry,
            .vertex_buffer = &vertex_buffer,
        },
    }};
    try (AccelerationStructureBuildResources{
        .result = &acceleration_structure,
        .scratch = &scratch,
        .geometries = geometry_resources[0..],
    }).validate(.vulkan, plan);

    const bad_geometry_resources = [_]AccelerationStructureGeometryResources{.{
        .triangles = .{
            .descriptor = geometry,
            .vertex_buffer = &bad_vertex_buffer,
        },
    }};
    try std.testing.expectError(core.AdvancedFeatureError.InvalidAccelerationStructureResources, (AccelerationStructureBuildResources{
        .result = &acceleration_structure,
        .scratch = &scratch,
        .geometries = bad_geometry_resources[0..],
    }).validate(.vulkan, plan));
}

test "runtime device plans ray tracing pipeline lowering from native capabilities" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.features.ray_tracing = false;
    report.native_features.ray_tracing = true;
    report.limits.max_ray_tracing_recursion_depth = 2;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test ray tracing adapter", report);
    const device = Device{ ._state = &device_state };

    const groups = [_]core.RayTracingShaderGroupDescriptor{
        .{ .kind = .ray_generation, .entry_point = "raygen" },
        .{ .kind = .miss, .entry_point = "miss" },
        .{ .kind = .hit, .entry_point = "closest_hit" },
    };
    const descriptor = core.RayTracingPipelineDescriptor{
        .shader_groups = groups[0..],
        .max_recursion_depth = 2,
    };
    try std.testing.expectError(core.AdvancedFeatureError.UnsupportedRayTracing, device.validateRayTracingPipelineDescriptor(descriptor));

    const lowering = try device.planRayTracingPipelineLowering(descriptor);
    try std.testing.expectEqual(@as(u32, 2), lowering.maxRecursionDepth());
    try std.testing.expectEqual(@as(u32, 1), lowering.rayGenerationGroupCount());
    try std.testing.expectEqual(@as(u32, 1), lowering.hitGroupCount());
    try std.testing.expectEqual(@as(u32, 3), lowering.functionTableEntryCount());
}

test "runtime creates ray tracing pipeline states from usable capabilities" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = .{ .vulkan = undefined };
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.features.ray_tracing = true;
    report.native_features.ray_tracing = true;
    report.limits.max_ray_tracing_recursion_depth = 2;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test ray tracing pipeline adapter", report);
    var device = Device{ ._state = &device_state };

    const groups = [_]core.RayTracingShaderGroupDescriptor{
        .{ .kind = .ray_generation, .entry_point = "raygen" },
        .{ .kind = .miss, .entry_point = "miss" },
        .{ .kind = .hit, .entry_point = "closest_hit" },
    };
    const descriptor = core.RayTracingPipelineDescriptor{
        .label = "rt pipeline",
        .shader_groups = groups[0..],
        .max_recursion_depth = 2,
    };
    try device.validateRayTracingPipelineDescriptor(descriptor);

    var pipeline = try device.makeRayTracingPipelineState(descriptor);
    defer pipeline.deinit();
    try std.testing.expectEqual(@as(usize, 1), tracker.ray_tracing_pipeline_states);
    try std.testing.expectEqualStrings("rt pipeline", pipeline.label().?);
    try std.testing.expectEqual(@as(u32, 2), pipeline.maxRecursionDepth());
    try std.testing.expectEqual(@as(u32, 3), pipeline.functionTableEntryCount());
    try std.testing.expect(pipeline.hasBackendPrivatePipelineHandle());
    try std.testing.expectEqual(@as(u32, 3), pipeline.backendPrivateShaderGroupCount());
    try std.testing.expect(!pipeline.backendPrivatePipelineBoundToDriver());
    try std.testing.expectEqual(@as(usize, 3), pipeline.descriptor().shader_groups.len);
}

test "runtime device plans ray dispatch from native capabilities" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.features.ray_tracing = false;
    report.native_features.ray_tracing = true;
    report.limits.shader_binding_table_alignment = 64;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test ray dispatch adapter", report);
    const device = Device{ ._state = &device_state };

    const sbt = core.ShaderBindingTableDescriptor{
        .stride = 64,
        .ray_generation_count = 1,
        .miss_count = 1,
        .hit_count = 1,
    };
    try std.testing.expectError(core.AdvancedFeatureError.UnsupportedRayTracing, device.validateShaderBindingTableDescriptor(sbt));

    const plan = try device.planRayDispatch(sbt, .{
        .width = 8,
        .height = 4,
    });
    try std.testing.expectEqual(@as(u64, 32), plan.total_rays);
    try std.testing.expectEqual(@as(u64, 192), plan.sbt_size);
}

test "runtime plans complex shader binding tables through device" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.features.ray_tracing = false;
    report.native_features.ray_tracing = true;
    report.native_features.ray_tracing_callable_shaders = true;
    report.native_features.ray_tracing_procedural_geometry = true;
    report.native_features.ray_tracing_custom_intersection = true;
    report.limits.shader_binding_table_alignment = 64;
    report.limits.max_shader_binding_table_records = 12;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test complex sbt adapter", report);
    const device = Device{ ._state = &device_state };

    const ranges = [_]core.ShaderBindingTableHitGroupRangeDescriptor{
        .{ .first_record = 0, .record_count = 1 },
        .{ .hit_group_kind = .procedural, .first_record = 1, .record_count = 1 },
    };
    const plan = try device.planComplexShaderBindingTable(.{
        .table = .{
            .stride = 64,
            .ray_generation_count = 1,
            .miss_count = 2,
            .hit_count = 2,
            .callable_count = 2,
        },
        .hit_group_ranges = ranges[0..],
    });
    try std.testing.expectEqual(@as(u32, 7), plan.total_records);
    try std.testing.expectEqual(@as(u32, 2), plan.callable_records);
    try std.testing.expect(plan.hasCallableRecords());
    try std.testing.expect(plan.requires_custom_intersection);
    try std.testing.expect(plan.coversAllHitRecords());
}

test "runtime creates shader binding tables and dispatches rays" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = .{ .vulkan = undefined };
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.features.ray_tracing = true;
    report.native_features.ray_tracing = true;
    report.limits.max_ray_tracing_recursion_depth = 2;
    report.limits.shader_binding_table_alignment = 64;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test ray dispatch adapter", report);
    var device = Device{ ._state = &device_state };

    const groups = [_]core.RayTracingShaderGroupDescriptor{
        .{ .kind = .ray_generation, .entry_point = "raygen" },
        .{ .kind = .miss, .entry_point = "miss" },
        .{ .kind = .hit, .entry_point = "closest_hit" },
    };
    var pipeline = try device.makeRayTracingPipelineState(.{
        .shader_groups = groups[0..],
        .max_recursion_depth = 1,
    });
    defer pipeline.deinit();

    var too_small_table = try device.makeShaderBindingTable(.{
        .stride = 64,
        .ray_generation_count = 1,
        .miss_count = 1,
        .hit_count = 0,
    });
    defer too_small_table.deinit();

    var command_buffer = CommandBuffer.init(.{
        .backend = .vulkan,
        .queue_kind_value = .compute,
    });
    try std.testing.expectError(
        core.AdvancedFeatureError.InvalidShaderBindingTable,
        command_buffer.dispatchRays(&pipeline, &too_small_table, .{
            .width = 8,
            .height = 4,
        }),
    );

    var shader_binding_table = try device.makeShaderBindingTable(.{
        .stride = 64,
        .ray_generation_count = 1,
        .miss_count = 1,
        .hit_count = 1,
    });
    defer shader_binding_table.deinit();
    try std.testing.expectEqual(@as(usize, 2), tracker.shader_binding_tables);
    try std.testing.expectEqual(@as(u64, 192), shader_binding_table.size());
    try std.testing.expect(shader_binding_table.hasBackendPrivateRecords());
    try std.testing.expectEqual(@as(u32, 3), shader_binding_table.backendPrivateRecordCount());
    try std.testing.expect(!shader_binding_table.backendPrivateRecordsBoundToDriver());

    const plan = try command_buffer.dispatchRays(&pipeline, &shader_binding_table, .{
        .width = 8,
        .height = 4,
    });
    try std.testing.expectEqual(@as(u64, 32), plan.total_rays);
    try std.testing.expectEqual(@as(u64, 1), shader_binding_table.dispatchCount());
    try std.testing.expect(!shader_binding_table.lastDispatchRecordedBackendCommand());
    try std.testing.expect(!shader_binding_table.lastDispatchSubmittedToDriver());
}

test "runtime device plans Metal ray tracing mapping from native capabilities" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.metal);
    report.features.ray_tracing = true;
    report.features.ray_tracing_custom_intersection = true;
    report.native_features.ray_tracing = true;
    report.limits.max_ray_tracing_recursion_depth = 2;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .metal, &backend_runtime, "test metal ray tracing adapter", report);
    const device = Device{ ._state = &device_state };

    const groups = [_]core.RayTracingShaderGroupDescriptor{
        .{ .kind = .ray_generation, .entry_point = "raygen" },
        .{ .kind = .miss, .entry_point = "miss" },
    };
    const intersections = [_]core.MetalIntersectionFunctionDescriptor{
        .{ .entry_point = "custom_intersection" },
    };
    const plan = try device.planMetalRayTracingMapping(.{
        .pipeline = .{
            .shader_groups = groups[0..],
            .max_recursion_depth = 1,
        },
        .intersections = intersections[0..],
    });
    try std.testing.expectEqual(@as(u32, 3), plan.function_table_entries);
    try std.testing.expect(plan.requires_intersection_function_table);
}

test "runtime creates Metal ray tracing execution mappings from native capabilities" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.metal);
    report.features.ray_tracing = true;
    report.features.ray_tracing_custom_intersection = true;
    report.native_features.ray_tracing = true;
    report.limits.max_ray_tracing_recursion_depth = 2;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .metal, &backend_runtime, "test metal execution mapping adapter", report);
    var device = Device{ ._state = &device_state };

    const groups = [_]core.RayTracingShaderGroupDescriptor{
        .{ .kind = .ray_generation, .entry_point = "raygen" },
        .{ .kind = .miss, .entry_point = "miss" },
    };
    const intersections = [_]core.MetalIntersectionFunctionDescriptor{
        .{ .entry_point = "custom_intersection" },
    };
    var mapping = try device.makeMetalRayTracingExecutionMapping(.{
        .pipeline = .{
            .shader_groups = groups[0..],
            .max_recursion_depth = 1,
        },
        .intersections = intersections[0..],
        .function_table_label = "rt table",
    });
    defer mapping.deinit();
    try std.testing.expectEqual(@as(usize, 1), tracker.metal_ray_tracing_execution_mappings);
    try std.testing.expectEqualStrings("rt table", mapping.label().?);
    try std.testing.expectEqual(@as(u32, 3), mapping.functionTableEntryCount());
    try std.testing.expectEqual(@as(u32, 1), mapping.intersectionFunctionCount());
    try std.testing.expect(mapping.requiresIntersectionFunctionTable());
    try std.testing.expect(!mapping.hasBackendPrivateFunctionTables());
    try std.testing.expectEqual(@as(u32, 1), mapping.backendPrivateAccelerationStructureSlots());
    try std.testing.expect(!mapping.backendPrivateMetalTablesBoundToDriver());

    var vulkan_report = core.defaultDeviceCapabilityReport(.vulkan);
    vulkan_report.native_features.ray_tracing = true;
    var vulkan_device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test vulkan mapping adapter", vulkan_report);
    var vulkan_device = Device{ ._state = &vulkan_device_state };
    try std.testing.expectError(
        core.AdvancedFeatureError.UnsupportedRayTracing,
        vulkan_device.makeMetalRayTracingExecutionMapping(.{
            .pipeline = .{
                .shader_groups = groups[0..],
            },
        }),
    );
}

test "runtime device plans ray query support from native capabilities" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.native_features.ray_tracing = true;
    report.native_features.ray_query = true;
    report.limits.max_ray_tracing_recursion_depth = 4;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test ray query adapter", report);
    const device = Device{ ._state = &device_state };

    const plan = try device.planRayQuery(.{
        .shader_stage = .fragment,
        .max_traversal_depth = 2,
    });
    try std.testing.expectEqual(core.Backend.vulkan, plan.backend);
    try std.testing.expectEqual(core.ShaderStage.fragment, plan.shader_stage);
    try std.testing.expectEqual(@as(u32, 2), plan.max_traversal_depth);

    var metal_device_state = testRuntimeState(std.testing.allocator, &tracker, .metal, &backend_runtime, "test metal ray query adapter", core.defaultDeviceCapabilityReport(.metal));
    const metal_device = Device{ ._state = &metal_device_state };
    try std.testing.expectError(core.AdvancedFeatureError.UnsupportedRayTracing, metal_device.planRayQuery(.{}));
}

test "runtime device plans ray tracing stress from native capabilities" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.native_features.acceleration_structures = true;
    report.native_features.acceleration_structure_update = true;
    report.native_features.acceleration_structure_compaction = true;
    report.native_features.ray_tracing = true;
    report.native_features.ray_query = true;
    report.native_features.ray_tracing_callable_shaders = true;
    report.limits.shader_binding_table_alignment = 64;
    report.limits.max_shader_binding_table_records = 8;
    report.limits.max_acceleration_structure_instances = 8;
    report.limits.max_ray_tracing_recursion_depth = 2;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test rt stress adapter", report);
    const device = Device{ ._state = &device_state };

    const instances = [_]core.TopLevelAccelerationStructureInstanceDescriptor{
        .{ .geometry_kind = .triangles },
    };
    const maintenance = [_]core.AccelerationStructureMaintenanceDescriptor{.{
        .acceleration_structure = .{
            .kind = .bottom_level,
            .primitive_count = 2,
            .allow_update = true,
        },
        .operation = .update,
    }};
    const plan = try device.planRayTracingStress(.{
        .iterations = 2,
        .tlas_layout = .{ .instances = instances[0..] },
        .maintenance_operations = maintenance[0..],
        .complex_sbt = .{
            .table = .{
                .stride = 64,
                .ray_generation_count = 1,
                .miss_count = 1,
                .hit_count = 1,
            },
            .hit_group_ranges = &.{.{ .first_record = 0, .record_count = 1 }},
        },
        .ray_query = .{ .max_traversal_depth = 1 },
        .dispatch = .{ .width = 4, .height = 4 },
    });
    try std.testing.expectEqual(core.Backend.vulkan, plan.backend);
    try std.testing.expectEqual(@as(u32, 2), plan.iterations);
    try std.testing.expectEqual(@as(u32, 1), plan.tlas_instances);
    try std.testing.expectEqual(@as(u32, 1), plan.maintenance_operations);
    try std.testing.expect(plan.ray_query_enabled);
    try std.testing.expectEqual(@as(u64, 16), plan.dispatch_rays_per_iteration);
    try std.testing.expectEqual(@as(u64, 32), plan.totalDispatchRays());
}

test "runtime plans driver pipeline caches from native feature reports" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.features.driver_pipeline_cache = false;
    report.native_features.driver_pipeline_cache = true;
    report.limits.max_driver_cache_identity_bytes = 128;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test vulkan adapter", report);
    const device = Device{ ._state = &device_state };

    const descriptor = core.DriverPipelineCacheDescriptor{
        .path = "build.zig",
        .kind = .vulkan_pipeline_cache,
        .identity = .{
            .backend = .vulkan,
            .device_id = "device",
            .driver_id = "driver",
            .shader_hash = "shader",
            .schema_version = "vkmtl-test",
        },
        .read_only = true,
    };

    try std.testing.expectError(core.AdvancedFeatureError.UnsupportedDriverPipelineCache, device.validateDriverPipelineCacheDescriptor(descriptor));
    const plan = try device.planDriverPipelineCache(descriptor);
    try std.testing.expect(plan.load_existing);
    try std.testing.expect(!plan.store_on_shutdown);

    const missing_plan = try device.planDriverPipelineCache(.{
        .path = "zig-out/definitely-missing-vkmtl-cache.bin",
        .kind = .vulkan_pipeline_cache,
        .identity = descriptor.identity,
    });
    try std.testing.expect(!missing_plan.load_existing);
    try std.testing.expect(missing_plan.store_on_shutdown);
}

test "runtime device exposes diagnostics and capture names" {
    var tracker = ResourceTracker{};
    tracker.retain(.sampler_state);
    tracker.recordObjectCreation(.sampler, 19, .{}, 5);
    var backend_runtime: BackendRuntime = undefined;
    var device_state = testRuntimeState(std.testing.allocator, &tracker, .metal, &backend_runtime, "test metal adapter", core.defaultDeviceCapabilityReport(.metal));
    const device = Device{ ._state = &device_state };

    const snapshot = device.runtimeDiagnostics();
    try std.testing.expectEqual(@as(usize, 1), snapshot.live_resources);
    try std.testing.expectEqual(@as(u64, 1), snapshot.object_cache.samplers.creation_attempts);

    var buffer: [64]u8 = undefined;
    const name = try device.writeCaptureName(.{
        .scope = "frame",
        .name = "encoder",
        .frame_index = 3,
    }, buffer[0..]);
    try std.testing.expectEqualStrings("frame:encoder backend=metal frame=3", name);
}

test "runtime device plans native advanced closure inventory" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var device_state = testRuntimeState(std.testing.allocator, &tracker, .metal, &backend_runtime, "test native closure adapter", core.defaultDeviceCapabilityReport(.metal));
    const device = Device{ ._state = &device_state };

    const plan = device.planNativeAdvancedClosure(.{
        .features = &.{
            .native_object_handle_pooling,
            .native_driver_pipeline_cache,
            .native_sparse_page_binding,
        },
    });
    try std.testing.expectEqual(@as(usize, 3), plan.requested_features);
    try std.testing.expectEqual(@as(usize, 3), plan.deferred_native_features);
    try std.testing.expectEqual(@as(usize, 3), plan.backend_private_runtime_features);
    try std.testing.expectEqual(@as(usize, 0), plan.period30_phase5_features);
    try std.testing.expectEqual(@as(usize, 3), plan.period31_plus_driver_features);
    try std.testing.expectEqual(@as(usize, 2), plan.public_runtime_contract_features);
    try std.testing.expect(plan.hasDeferredNativeWork());
    try std.testing.expect(plan.hasBackendPrivateRuntimeInventory());
    try std.testing.expect(plan.hasPublicRuntimeContracts());
}

test "runtime device plans backend parity semantics for selected backend" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var device_state = testRuntimeState(std.testing.allocator, &tracker, .metal, &backend_runtime, "test parity adapter", core.defaultDeviceCapabilityReport(.metal));
    const device = Device{ ._state = &device_state };

    const plan = try device.planBackendParitySemantics(.{
        .backend = .vulkan,
        .gpu_soak_iterations = 30,
    });
    try std.testing.expectEqual(core.Backend.metal, plan.backend);
    try std.testing.expect(plan.hasTypedUnsupportedCopies());
    try std.testing.expect(plan.hasBackendPrivateValidationPlan());
    try std.testing.expect(plan.requiresPeriod31PlusDriverValidation());
    try std.testing.expect(plan.hasStabilityPlan());
    try std.testing.expect(plan.hasStabilityDiagnostics());
}

test "runtime plans persistent cache manifests through device" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var device_state = testRuntimeState(std.testing.allocator, &tracker, .metal, &backend_runtime, "test metal adapter", core.defaultDeviceCapabilityReport(.metal));
    const device = Device{ ._state = &device_state };

    const manifest = core.RuntimeCacheManifestDescriptor{
        .backend = .metal,
        .source_hash = "source",
        .toolchain_id = "slang",
    };
    const plan = try device.planRuntimeCache(.{
        .cache_dir = "vkmtl-cache",
        .entry_name = "shader",
        .manifest = manifest,
        .existing_manifest = null,
    });
    defer plan.deinit(std.testing.allocator);
    try std.testing.expectEqual(core.RuntimeCacheCompatibility.missing, plan.compatibility);
    try std.testing.expect(plan.should_rebuild);
    try std.testing.expectError(core.ObjectCacheError.InvalidObjectCacheKey, device.planRuntimeCache(.{
        .cache_dir = "vkmtl-cache",
        .entry_name = "shader",
        .manifest = .{
            .backend = .vulkan,
            .source_hash = "source",
            .toolchain_id = "slang",
        },
    }));
}

test "runtime plans pipeline artifact cache compatibility through device" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test vulkan adapter", core.defaultDeviceCapabilityReport(.vulkan));
    const device = Device{ ._state = &device_state };

    const manifest = core.PipelineArtifactManifestDescriptor{
        .backend = .vulkan,
        .shader_hash = "shader",
        .entry_points_hash = "vs-fs",
        .reflection_hash = "reflection",
        .format_hash = "format",
        .toolchain_id = "slang",
    };
    const plan = try device.planPipelineArtifactCache(.{
        .artifact_dir = "zig-out/shaders/rainbow_cube",
        .manifest = manifest,
        .existing_manifest = null,
    });
    try std.testing.expectEqual(core.PipelineArtifactCompatibility.missing, plan.compatibility);
    try std.testing.expect(plan.should_rebuild);
    try std.testing.expect(plan.should_persist);

    const stale_plan = try device.planPipelineArtifactCache(.{
        .artifact_dir = "zig-out/shaders/rainbow_cube",
        .manifest = manifest,
        .existing_manifest = .{
            .backend = .vulkan,
            .shader_hash = "shader",
            .entry_points_hash = "cs",
            .reflection_hash = "reflection",
            .format_hash = "format",
            .toolchain_id = "slang",
        },
        .read_only = true,
    });
    try std.testing.expectEqual(core.PipelineArtifactCompatibility.entry_point_mismatch, stale_plan.compatibility);
    try std.testing.expect(stale_plan.should_rebuild);
    try std.testing.expect(!stale_plan.should_persist);

    try std.testing.expectError(core.ObjectCacheError.InvalidObjectCacheKey, device.planPipelineArtifactCache(.{
        .artifact_dir = "zig-out/shaders/rainbow_cube",
        .manifest = .{
            .backend = .metal,
            .shader_hash = "shader",
            .entry_points_hash = "vs-fs",
            .reflection_hash = "reflection",
            .format_hash = "format",
            .toolchain_id = "slang",
        },
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

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .metal, &backend_runtime, "test metal adapter", report);
    var device = Device{ ._state = &device_state };

    var ranges = [_]core.DescriptorIndexingRange{.{
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
    try std.testing.expectEqual(@as(u32, 8), layout.totalDescriptorCount());
    try std.testing.expectEqual(@as(u32, 8), layout.resourceDescriptorCount(.sampled_texture));
    try std.testing.expectEqual(@as(u32, 0), layout.resourceDescriptorCount(.sampler));
    try std.testing.expect(!layout.usesPartiallyBoundRanges());
    try std.testing.expect(!layout.usesUpdateAfterBindRanges());
    try std.testing.expectEqual(@as(usize, 1), tracker.advanced_bind_group_layouts);
}

test "runtime plans resource table pressure through device limits" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.features.descriptor_indexing = true;
    report.limits.max_bindless_descriptors_per_range = 64;
    report.limits.max_bindless_ranges_per_layout = 2;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test vulkan adapter", report);
    const device = Device{ ._state = &device_state };

    const ranges = [_]core.DescriptorIndexingRange{
        .{
            .binding = 0,
            .resource = .sampled_texture,
            .visibility = .{ .fragment = true },
            .descriptor_count = 32,
            .partially_bound = true,
        },
        .{
            .binding = 1,
            .resource = .sampler,
            .visibility = .{ .fragment = true },
            .descriptor_count = 4,
        },
    };
    const plan = try device.planResourceTablePressure(.{
        .layout = .{
            .model = .descriptor_indexing,
            .ranges = ranges[0..],
        },
        .expected_bound_descriptors = 12,
        .expected_updates_per_frame = 5,
        .frames_in_flight = 2,
        .allow_partially_bound = true,
    });
    try std.testing.expectEqual(@as(u32, 36), plan.total_descriptors);
    try std.testing.expectEqual(@as(u32, 24), plan.expected_unbound_descriptors);
    try std.testing.expectEqual(@as(u64, 10), plan.worst_case_updates_in_flight);
    try std.testing.expect(plan.canCreateTable());

    try std.testing.expectError(core.AdvancedFeatureError.InvalidDescriptorIndexingCount, device.planResourceTablePressure(.{
        .layout = .{
            .model = .descriptor_indexing,
            .ranges = &.{.{
                .binding = 0,
                .resource = .sampled_texture,
                .visibility = .{ .fragment = true },
                .descriptor_count = 65,
            }},
        },
    }));
}

test "runtime resource table updates clear and validate slots" {
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

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .metal, &backend_runtime, "test metal adapter", report);
    var device = Device{ ._state = &device_state };

    const ranges = [_]core.DescriptorIndexingRange{
        .{
            .binding = 0,
            .resource = .sampled_texture,
            .visibility = .{ .fragment = true },
            .descriptor_count = 2,
            .partially_bound = true,
        },
        .{
            .binding = 1,
            .resource = .sampler,
            .visibility = .{ .fragment = true },
            .descriptor_count = 1,
            .update_after_bind = true,
        },
    };

    var layout = try device.makeAdvancedBindGroupLayout(.{
        .label = "bindless table layout",
        .model = .argument_buffer,
        .ranges = &ranges,
    });
    defer layout.deinit();

    try std.testing.expectError(core.BindingError.ResourceTablePartiallyBoundUnsupported, device.makeResourceTable(.{
        .layout = &layout,
    }));
    try std.testing.expectError(core.BindingError.ResourceTableUpdateAfterBindUnsupported, device.makeResourceTable(.{
        .layout = &layout,
        .allow_partially_bound = true,
    }));

    var table = try device.makeResourceTable(.{
        .label = "bindless table",
        .layout = &layout,
        .allow_partially_bound = true,
        .allow_update_after_bind = true,
    });
    defer table.deinit();

    var texture_view = TextureView.init(.{
        .backend = .metal,
        .tracker = &tracker,
        .format_value = .rgba8_unorm,
        .usage_value = .{ .shader_read = true },
        .sample_count_value = 1,
        .width_value = 1,
        .height_value = 1,
        .impl = undefined,
    });
    var sampler = SamplerState.init(.{
        .backend = .metal,
        .tracker = &tracker,
        .impl = undefined,
    });
    var dead_sampler = SamplerState.init(.{
        .backend = .metal,
        .tracker = &tracker,
        .alive = false,
        .impl = undefined,
    });

    try std.testing.expectEqual(@as(usize, 3), table.slotCount());
    try std.testing.expectError(core.BindingError.MissingResourceTableBinding, table.validateReadyForBinding());
    try table.update(.{
        .slot = .{ .binding = 0, .array_element = 1 },
        .resource = .{ .sampled_texture = &texture_view },
    });
    try std.testing.expect(try table.isSlotBound(.{ .binding = 0, .array_element = 1 }));
    try std.testing.expectError(core.BindingError.BindingResourceKindMismatch, table.update(.{
        .slot = .{ .binding = 1 },
        .resource = .{ .sampled_texture = &texture_view },
    }));
    try std.testing.expectError(core.BindingError.InvalidResourceTableResource, table.update(.{
        .slot = .{ .binding = 1 },
        .resource = .{ .sampler = &dead_sampler },
    }));
    try table.update(.{
        .slot = .{ .binding = 1 },
        .resource = .{ .sampler = &sampler },
    });
    try table.validateReadyForBinding();
    try table.markBoundForCommands();
    var vulkan_table = table;
    vulkan_table.state().backend = .vulkan;
    try std.testing.expectError(
        core.BindingError.ResourceTableUpdateAfterBindUnsupported,
        vulkan_table.clear(.{ .binding = 1 }),
    );
    try table.clear(.{ .binding = 1 });
    try std.testing.expect(!(try table.isSlotBound(.{ .binding = 1 })));
    try std.testing.expectEqual(@as(usize, 1), tracker.resource_tables);
}

test "runtime resource table rejects update after bind without range support" {
    var tracker = ResourceTracker{};
    var backend_runtime = BackendRuntime{
        .metal = .{
            .handle = undefined,
            .extent = .{ .width = 1, .height = 1 },
        },
    };
    var report = core.defaultDeviceCapabilityReport(.metal);
    report.features.argument_buffers = true;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, .metal, &backend_runtime, "test metal adapter", report);
    var device = Device{ ._state = &device_state };

    var ranges = [_]core.DescriptorIndexingRange{.{
        .binding = 0,
        .resource = .sampler,
        .visibility = .{ .fragment = true },
        .descriptor_count = 1,
    }};
    var layout = try device.makeAdvancedBindGroupLayout(.{
        .model = .argument_buffer,
        .ranges = &ranges,
    });
    defer layout.deinit();

    var table = try device.makeResourceTable(.{
        .layout = &layout,
        .allow_update_after_bind = true,
    });
    defer table.deinit();

    var sampler = SamplerState.init(.{
        .backend = .metal,
        .tracker = &tracker,
        .impl = undefined,
    });
    try table.update(.{
        .slot = .{ .binding = 0 },
        .resource = .{ .sampler = &sampler },
    });
    try table.markBoundForCommands();
    try std.testing.expectError(core.BindingError.ResourceTableUpdateAfterBindUnsupported, table.clear(.{
        .binding = 0,
    }));
}

test "runtime indirect command buffers validate slots kinds ranges and reset" {
    var tracker = ResourceTracker{};
    var backend_runtime = BackendRuntime{ .vulkan = undefined };
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.features.indirect_command_buffers = true;
    report.limits.max_indirect_command_count = 4;

    var device_state = testRuntimeState(
        std.testing.allocator,
        &tracker,
        .vulkan,
        &backend_runtime,
        "test indirect adapter",
        report,
    );
    var device = Device{ ._state = &device_state };
    var buffer = try makeIndirectCommandBuffer(&device, .{
        .label = "draw list",
        .kind = .render,
        .max_command_count = 4,
    });
    defer buffer.deinit();

    try buffer.encodeDrawPrimitives(1, .{ .vertex_count = 3 });
    try buffer.encodeDrawPrimitives(2, .{ .vertex_count = 6 });
    try std.testing.expectEqual(@as(u32, 2), buffer.encodedCommandCount());
    try std.testing.expect(try buffer.isCommandEncoded(1));
    try buffer.validateExecution(.render, .{ .location = 1, .count = 2 });
    try std.testing.expectError(
        core.CommandEncodingError.MissingIndirectCommand,
        buffer.validateExecution(.render, .{ .location = 0, .count = 2 }),
    );
    try std.testing.expectError(
        core.CommandEncodingError.InvalidIndirectCommandKind,
        buffer.encodeDispatchThreadgroups(0, .{}),
    );
    try buffer.reset(.{ .location = 1, .count = 1 });
    try std.testing.expect(!(try buffer.isCommandEncoded(1)));
    try std.testing.expectEqual(@as(u32, 1), buffer.encodedCommandCount());
    try std.testing.expectEqual(@as(usize, 1), tracker.indirect_command_buffers);
}

test "runtime external texture wrapper validates and tracks lifetime" {
    const platform = core.ExternalInteropPlatform.native();
    const backend: core.Backend = switch (platform) {
        .macos, .ios => .metal,
        .linux, .windows => .vulkan,
        .unknown => return error.SkipZigTest,
    };
    const memory_handle_kind: core.ExternalHandleKind = switch (platform) {
        .macos, .ios => .metal_buffer,
        .linux => .opaque_fd,
        .windows => .win32_handle,
        .unknown => unreachable,
    };
    const texture_handle_kind: core.ExternalHandleKind = switch (platform) {
        .macos, .ios => .metal_texture,
        .linux => .opaque_fd,
        .windows => .win32_handle,
        .unknown => unreachable,
    };
    const platform_texture_handle_kind: core.ExternalHandleKind = switch (platform) {
        .macos, .ios => .iosurface,
        .linux => .opaque_fd,
        .windows => .win32_handle,
        .unknown => unreachable,
    };
    const semaphore_handle_kind: core.ExternalHandleKind = switch (platform) {
        .macos, .ios => .metal_shared_event,
        .linux => .opaque_fd,
        .windows => .win32_handle,
        .unknown => unreachable,
    };
    const resource_lane: core.ExternalInteropLane = if (backend == .metal) .native_only else .capability_gated;
    const supports_external_events = backend == .metal;
    const other_backend: core.Backend = if (backend == .metal) .vulkan else .metal;

    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = switch (backend) {
        .metal => .{ .metal = .{
            .handle = undefined,
            .extent = .{ .width = 1, .height = 1 },
        } },
        .vulkan => .{ .vulkan = undefined },
    };
    var report = core.defaultDeviceCapabilityReport(backend);
    report.features.external_memory = true;
    report.features.external_textures = true;
    report.features.external_semaphores = true;
    report.native_features.external_memory = true;
    report.native_features.external_textures = true;
    report.native_features.external_semaphores = true;

    var device_state = testRuntimeState(std.testing.allocator, &tracker, backend, &backend_runtime, "test external interop adapter", report);
    var device = Device{ ._state = &device_state };

    const interop_matrix = device.externalInteropCapabilityMatrixForPlatform(platform);
    try std.testing.expect(interop_matrix.supportsPortableWrapper(.texture));
    try std.testing.expect(interop_matrix.supports(.texture, texture_handle_kind));
    try std.testing.expect(interop_matrix.supports(.texture, platform_texture_handle_kind));
    try std.testing.expectEqual(
        supports_external_events,
        interop_matrix.supports(.event, semaphore_handle_kind),
    );
    const texture_diagnostic = device.diagnoseExternalInteropImportForPlatform(
        platform,
        .texture,
        .{ .kind = platform_texture_handle_kind, .value = 6 },
    );
    try std.testing.expect(texture_diagnostic.ok());
    try std.testing.expectEqual(core.ExternalInteropLane.capability_gated, texture_diagnostic.lane);

    var memory = try device.makeExternalMemory(.{
        .label = "external memory",
        .handle = .{
            .kind = memory_handle_kind,
            .value = 2,
        },
        .size = 256,
        .ownership = .transferred,
    });
    defer memory.deinit();

    var buffer = try device.makeExternalBuffer(.{
        .label = "external buffer",
        .handle = .{
            .kind = memory_handle_kind,
            .value = 3,
        },
        .length = 128,
        .usage = .{ .storage = true },
    });
    defer buffer.deinit();

    var semaphore = try device.makeExternalSemaphore(.{
        .handle = .{
            .kind = semaphore_handle_kind,
            .value = 4,
        },
        .timeline = true,
    });
    defer semaphore.deinit();

    var event: ?ExternalEvent = if (supports_external_events)
        try device.makeExternalEvent(.{
            .handle = .{
                .kind = semaphore_handle_kind,
                .value = 5,
            },
            .shared = true,
        })
    else
        null;
    defer if (event) |*external_event| external_event.deinit();
    if (!supports_external_events) {
        try std.testing.expectError(core.AdvancedFeatureError.UnsupportedExternalSemaphores, device.makeExternalEvent(.{
            .handle = .{
                .kind = semaphore_handle_kind,
                .value = 5,
            },
            .shared = true,
        }));
    }

    var texture = try device.makeExternalTexture(.{
        .label = "external texture",
        .handle = .{
            .kind = texture_handle_kind,
            .value = 1,
        },
        .format = .rgba8_unorm,
        .width = 64,
        .height = 32,
    });
    defer texture.deinit();

    try std.testing.expectEqual(backend, texture.selectedBackend());
    try std.testing.expectEqual(core.ExternalResourceOwnership.borrowed, texture.ownership());
    try std.testing.expectEqual(@as(u32, 64), texture.textureDescriptor().width);
    try std.testing.expectEqual(resource_lane, texture.importPlan().lane);
    try std.testing.expect(texture.importPlan().requiresNativeImport());
    const usage_plan = try device.planExternalTextureUsageForPlatform(platform, .{
        .texture = .{
            .label = "external texture",
            .handle = .{
                .kind = texture_handle_kind,
                .value = 1,
            },
            .format = .rgba8_unorm,
            .width = 64,
            .height = 32,
            .usage = .{
                .shader_read = true,
                .copy_source = true,
                .render_attachment = true,
            },
        },
        .sample = true,
        .copy_source = true,
        .present = true,
    });
    try std.testing.expect(usage_plan.requiresSampling());
    try std.testing.expect(usage_plan.requiresCopy());
    try std.testing.expect(usage_plan.requiresPresentation());
    try std.testing.expectEqual(backend, memory.selectedBackend());
    try std.testing.expectEqual(@as(u64, 256), memory.size());
    try std.testing.expectEqual(core.ExternalResourceOwnership.transferred, memory.ownership());
    try std.testing.expectEqual(resource_lane, memory.importPlan().lane);
    try std.testing.expectEqual(@as(u64, 128), buffer.length());
    try std.testing.expect(buffer.usage().storage);
    try std.testing.expect(semaphore.isTimeline());
    try std.testing.expectEqual(core.ExternalInteropLane.capability_gated, semaphore.importPlan().lane);
    if (event) |external_event| {
        try std.testing.expect(external_event.isShared());
        try std.testing.expectEqual(core.ExternalInteropLane.capability_gated, external_event.importPlan().lane);
    }
    const external_sync = if (event) |*external_event|
        ExternalSynchronizationDescriptor{
            .wait_semaphores = &.{&semaphore},
            .signal_events = &.{external_event},
        }
    else
        ExternalSynchronizationDescriptor{
            .wait_semaphores = &.{&semaphore},
            .signal_semaphores = &.{&semaphore},
        };
    const external_sync_plan = try external_sync.plan(backend);
    try std.testing.expect(external_sync_plan.hasWaits());
    try std.testing.expect(external_sync_plan.hasSignals());
    try std.testing.expect(external_sync_plan.requiresNativeInterop());
    try std.testing.expectEqual(@as(usize, 1), external_sync_plan.wait_semaphore_count);
    try std.testing.expectEqual(@as(usize, if (supports_external_events) 0 else 1), external_sync_plan.signal_semaphore_count);
    try std.testing.expectEqual(@as(usize, if (supports_external_events) 1 else 0), external_sync_plan.signal_event_count);
    try std.testing.expectEqual(@as(usize, 1), external_sync_plan.native_wait_count);
    try std.testing.expectEqual(@as(usize, 1), external_sync_plan.native_signal_count);
    try std.testing.expectError(RuntimeError.BackendMismatch, external_sync.plan(other_backend));
    var command_buffer = CommandBuffer.init(.{
        .backend = backend,
        .tracker = &tracker,
    });
    try command_buffer.commitWithExternalSynchronization(external_sync);
    try std.testing.expect(!command_buffer.privateState().alive);
    try std.testing.expectEqual(@as(usize, 1), tracker.external_memories);
    try std.testing.expectEqual(@as(usize, 1), tracker.external_buffers);
    try std.testing.expectEqual(@as(usize, 1), tracker.external_semaphores);
    try std.testing.expectEqual(@as(usize, if (supports_external_events) 1 else 0), tracker.external_events);
    try std.testing.expectEqual(@as(usize, 1), tracker.textures);
}

test "runtime native command insertion validates encoder and invokes callback" {
    const State = struct {
        calls: usize = 0,
        backend: ?core.Backend = null,
    };
    const callback = struct {
        fn call(context: ?*anyopaque, handles: core.NativeHandleView) void {
            const state: *State = @ptrCast(@alignCast(context.?));
            state.calls += 1;
            state.backend = handles.backend();
        }
    }.call;

    var state = State{};
    var command_buffer = CommandBuffer.init(.{
        .backend = .vulkan,
        .features_value = .{ .native_command_insertion = true },
        .native_handle_view = core.nativeHandleView(.{
            .vulkan = .{
                .instance = 1,
                .physical_device = 2,
                .device = 3,
                .surface = 4,
                .graphics_queue = 5,
                .present_queue = 6,
            },
        }),
    });
    var blit_encoder = BlitCommandEncoder.init(.{
        .backend = .vulkan,
        .command_buffer = &command_buffer,
    });

    try blit_encoder.insertNativeCommands(.{
        .encoder = .blit,
        .callback = callback,
        .context = &state,
    });
    try std.testing.expectEqual(@as(usize, 1), state.calls);
    try std.testing.expectEqual(core.Backend.vulkan, state.backend.?);

    try std.testing.expectError(core.AdvancedFeatureError.NativeCommandEncoderMismatch, blit_encoder.insertNativeCommands(.{
        .encoder = .render,
        .callback = callback,
        .context = &state,
    }));

    var gated_command_buffer = CommandBuffer.init(.{
        .backend = .vulkan,
    });
    var gated_encoder = BlitCommandEncoder.init(.{
        .backend = .vulkan,
        .command_buffer = &gated_command_buffer,
    });
    try std.testing.expectError(core.AdvancedFeatureError.UnsupportedNativeCommandInsertion, gated_encoder.insertNativeCommands(.{
        .encoder = .blit,
        .callback = callback,
        .context = &state,
    }));
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

const LifecycleCallbackProbe = struct {
    statuses: [3]core.CommandBufferLifecycleStatus = undefined,
    count: usize = 0,
};

fn recordLifecycleCallback(context: ?*anyopaque, status: core.CommandBufferLifecycleStatus) callconv(.c) void {
    const probe: *LifecycleCallbackProbe = @ptrCast(@alignCast(context orelse return));
    probe.statuses[probe.count] = status;
    probe.count += 1;
}

test "command buffer lifecycle callback reports scheduled then completed once" {
    var probe = LifecycleCallbackProbe{};
    var command_buffer = CommandBuffer.init(.{
        .backend = .metal,
        .lifecycle_callback = recordLifecycleCallback,
        .lifecycle_context = &probe,
        .impl = null,
    });
    try command_buffer.commit();
    try std.testing.expectEqual(@as(usize, 2), probe.count);
    try std.testing.expectEqual(core.CommandBufferLifecycleStatus.scheduled, probe.statuses[0]);
    try std.testing.expectEqual(core.CommandBufferLifecycleStatus.completed, probe.statuses[1]);
    try std.testing.expectEqual(core.CommandBufferLifecycleStatus.completed, command_buffer.lifecycleStatus());
}

test "window context exposes device and queue views" {
    var tracker = ResourceTracker{};
    var context_state = RuntimeState{
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
    var context = WindowContext{ ._state = &context_state };

    var device = context.device();
    const queue_view = context.queue();
    const descriptor_queue = try device.queueWithDescriptor(.{});
    const fallback_compute_queue = try device.queueWithDescriptor(.{
        .kind = .compute,
        .allow_fallback = true,
    });
    var surface_view = context.surface();
    const swapchain_view = context.swapchain();
    const surface_swapchain_view = surface_view.swapchain();

    try std.testing.expectEqual(core.Backend.vulkan, device.selectedBackend());
    try std.testing.expectEqual(core.Backend.vulkan, queue_view.selectedBackend());
    try std.testing.expectEqual(core.QueueKind.graphics, queue_view.kind());
    try std.testing.expectEqual(core.QueueKind.graphics, descriptor_queue.kind());
    try std.testing.expectEqual(core.QueueKind.graphics, fallback_compute_queue.kind());
    try std.testing.expect(queueCapabilities(device).compute);
    try std.testing.expect(syncCapabilities(device).fences);
    try std.testing.expect(syncCapabilities(device).events);
    const fallback_plan = try planQueue(device, .{
        .kind = .compute,
        .allow_fallback = true,
    });
    try std.testing.expectEqual(core.QueueKind.compute, fallback_plan.requested);
    try std.testing.expectEqual(core.QueueKind.graphics, fallback_plan.resolved);
    try std.testing.expect(fallback_plan.fallback_to_graphics);
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
    try std.testing.expect(presentModeSupport(device).fifo);
    try std.testing.expectEqual(core.PresentMode.fifo, resolvePresentMode(device, .immediate).selected);
}

test "runtime device creates multi surface collections" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var device_state = testRuntimeState(std.testing.allocator, &tracker, .metal, &backend_runtime, "test metal adapter", core.defaultDeviceCapabilityReport(.metal));
    var device = Device{ ._state = &device_state };

    var collection = device.makeSurfaceCollection();
    defer collection.deinit();

    const first = try collection.add(.{
        .label = "primary",
        .source = .{
            .provider = .external,
            .window = @ptrFromInt(1),
        },
    }, .{
        .extent = .{ .width = 640, .height = 480 },
    });
    const second = try collection.add(.{
        .label = "secondary",
        .source = .{
            .provider = .external,
            .window = @ptrFromInt(2),
        },
    }, .{
        .extent = .{ .width = 320, .height = 240 },
    });

    try std.testing.expectEqual(@as(usize, 2), collection.liveCount());
    try collection.resize(second, .{ .width = 800, .height = 600 });
    try std.testing.expectEqual(@as(u32, 640), (try collection.info(first)).presentation_state.extent.width);
    try std.testing.expectEqual(@as(u32, 800), (try collection.info(second)).presentation_state.extent.width);
    try std.testing.expectEqual(core.Backend.metal, (try collection.info(first)).backend);
}

test "runtime queue descriptor selects logical queue view when multi queue is supported" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.features.multi_queue = true;
    report.features.dedicated_compute_queue = true;
    report.features.dedicated_transfer_queue = true;
    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test vulkan adapter", report);
    var device = Device{ ._state = &device_state };

    const compute_queue = try device.queueWithDescriptor(.{
        .label = "compute queue",
        .kind = .compute,
        .require_dedicated = true,
    });
    try std.testing.expectEqual(core.QueueKind.compute, compute_queue.kind());
    try std.testing.expectEqualStrings("compute queue", compute_queue.label().?);

    const transfer_queue = try device.queueWithDescriptor(.{
        .kind = .transfer,
        .require_dedicated = true,
    });
    try std.testing.expectEqual(core.QueueKind.transfer, transfer_queue.kind());
}

test "runtime queue ownership transfers gate cross queue resource use" {
    var tracker = ResourceTracker{};
    var graphics_command_buffer = CommandBuffer.init(.{
        .backend = .vulkan,
        .queue_kind_value = .graphics,
        .features_value = .{
            .explicit_resource_barriers = true,
            .queue_ownership_transfer = true,
        },
        .impl = null,
    });
    var graphics_blit = BlitCommandEncoder.init(.{
        .backend = .vulkan,
        .command_buffer = &graphics_command_buffer,
        .impl = null,
    });
    var compute_command_buffer = CommandBuffer.init(.{
        .backend = .vulkan,
        .queue_kind_value = .compute,
        .features_value = .{
            .explicit_resource_barriers = true,
            .queue_ownership_transfer = true,
        },
        .impl = null,
    });
    var compute_encoder = ComputeCommandEncoder.init(.{
        .backend = .vulkan,
        .command_buffer = &compute_command_buffer,
        .impl = null,
    });

    const buffer_state = Buffer.State{
        .backend = .vulkan,
        .tracker = &tracker,
        .impl = undefined,

        .length_value = 64,
        .usage_value = .{ .copy_destination = true, .copy_source = true, .storage = true },
        .storage_mode_value = .shared,
        .usage_state = .{ .current = .copy_destination },
    };
    var buffer = Buffer.init(buffer_state);

    try graphics_blit.bufferOwnershipTransfer(&buffer, .{
        .source = .graphics,
        .destination = .compute,
        .before = .copy_destination,
        .after = .storage_buffer_read,
    });
    try std.testing.expectEqual(core.QueueKind.compute, buffer.ownerQueue());
    try std.testing.expectEqual(core.ResourceUsageKind.storage_buffer_read, buffer.currentUsage().?);
    try std.testing.expectError(core.CommandEncodingError.InvalidQueueOwnershipState, graphics_blit.fillBuffer(&buffer, .{
        .size = 4,
    }));
    try compute_encoder.bufferBarrier(&buffer, .{
        .before = .storage_buffer_read,
        .after = .copy_source,
        .size = 64,
    });
    try std.testing.expectEqual(core.ResourceUsageKind.copy_source, buffer.currentUsage().?);

    var gated_command_buffer = CommandBuffer.init(.{
        .backend = .vulkan,
        .queue_kind_value = .graphics,
        .features_value = .{},
        .impl = null,
    });
    var gated_blit = BlitCommandEncoder.init(.{
        .backend = .vulkan,
        .command_buffer = &gated_command_buffer,
        .impl = null,
    });
    try std.testing.expectError(core.CommandEncodingError.UnsupportedQueueOwnershipTransfer, gated_blit.bufferOwnershipTransfer(&buffer, .{
        .source = .graphics,
        .destination = .transfer,
        .before = .copy_source,
        .after = .copy_destination,
    }));
    try std.testing.expectError(core.CommandEncodingError.InvalidQueueOwnershipState, gated_blit.bufferOwnershipTransfer(&buffer, .{
        .source = .compute,
        .destination = .graphics,
        .before = .copy_source,
        .after = .copy_destination,
    }));
}

test "runtime explicit barriers update resource usage state" {
    var tracker = ResourceTracker{};
    var command_buffer = CommandBuffer.init(.{
        .backend = .vulkan,
        .features_value = core.defaultDeviceFeatures(.vulkan),
        .impl = null,
    });
    var blit = BlitCommandEncoder.init(.{
        .backend = .vulkan,
        .command_buffer = &command_buffer,
        .impl = null,
    });

    const buffer_state = Buffer.State{
        .backend = .vulkan,
        .tracker = &tracker,
        .impl = undefined,

        .length_value = 64,
        .usage_value = .{ .copy_destination = true, .vertex = true },
        .storage_mode_value = .shared,
        .usage_state = .{ .current = .copy_destination },
    };
    var buffer = Buffer.init(buffer_state);

    try blit.bufferBarrier(&buffer, .{
        .before = .copy_destination,
        .after = .vertex_buffer,
        .offset = 0,
        .size = 64,
    });
    try std.testing.expectEqual(core.ResourceUsageKind.vertex_buffer, buffer.currentUsage().?);
    try std.testing.expectEqual(@as(usize, 1), buffer.usageBarrierCount());
    try std.testing.expectError(core.CommandEncodingError.InvalidResourceBarrierState, blit.bufferBarrier(&buffer, .{
        .before = .copy_destination,
        .after = .index_buffer,
    }));

    const texture_descriptor = core.TextureDescriptor{
        .format = .rgba8_unorm,
        .width = 8,
        .height = 8,
        .usage = .{ .copy_destination = true, .shader_read = true },
    };
    var texture = Texture.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .format_value = texture_descriptor.format,
        .usage_value = texture_descriptor.usage,
        .sample_count_value = texture_descriptor.sample_count,
        .usage_state = .{ .current = .copy_destination },
        .impl = .{ .vulkan = .{
            .gc = undefined,
            .handle = .null_handle,
            .memory = .null_handle,
            .descriptor = texture_descriptor,
            .layout = .undefined,
            .width_value = texture_descriptor.width,
            .height_value = texture_descriptor.height,
            .depth_or_array_layers_value = texture_descriptor.depth_or_array_layers,
            .mip_level_count_value = texture_descriptor.mip_level_count,
        } },
    });

    try blit.textureBarrier(&texture, .{
        .before = .copy_destination,
        .after = .sampled_texture,
    });
    try std.testing.expectEqual(core.ResourceUsageKind.sampled_texture, texture.currentUsage().?);
    try std.testing.expectEqual(@as(usize, 1), texture.usageBarrierCount());

    var gated_command_buffer = CommandBuffer.init(.{
        .backend = .vulkan,
        .features_value = .{},
        .impl = null,
    });
    var gated_compute = ComputeCommandEncoder.init(.{
        .backend = .vulkan,
        .command_buffer = &gated_command_buffer,
        .impl = null,
    });
    try std.testing.expectError(core.CommandEncodingError.UnsupportedExplicitResourceBarrier, gated_compute.bufferBarrier(&buffer, .{
        .before = .vertex_buffer,
        .after = .copy_destination,
    }));
}

test "runtime generate mipmaps validates full texture range" {
    var tracker = ResourceTracker{};
    var command_buffer = CommandBuffer.init(.{
        .backend = .vulkan,
        .features_value = core.defaultDeviceFeatures(.vulkan),
        .impl = null,
    });
    var blit = BlitCommandEncoder.init(.{
        .backend = .vulkan,
        .command_buffer = &command_buffer,
        .impl = null,
    });
    const descriptor = core.TextureDescriptor{
        .format = .rgba8_unorm,
        .width = 8,
        .height = 8,
        .depth_or_array_layers = 2,
        .mip_level_count = 4,
        .usage = .{
            .copy_source = true,
            .copy_destination = true,
            .shader_read = true,
        },
    };
    var texture = Texture.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .format_value = descriptor.format,
        .usage_value = descriptor.usage,
        .sample_count_value = descriptor.sample_count,
        .impl = .{ .vulkan = .{
            .gc = undefined,
            .handle = undefined,
            .memory = undefined,
            .descriptor = descriptor,
            .layout = undefined,
            .width_value = descriptor.width,
            .height_value = descriptor.height,
            .depth_or_array_layers_value = descriptor.depth_or_array_layers,
            .mip_level_count_value = descriptor.mip_level_count,
        } },
    });

    try std.testing.expectError(core.TextureError.UnsupportedMipmapGeneration, blit.generateMipmaps(&texture, .{
        .base_mip_level = 1,
    }));
    try blit.generateMipmaps(&texture, .{});
    try std.testing.expectEqual(core.ResourceUsageKind.sampled_texture, texture.currentUsage().?);
}

test "runtime fences and events track lifecycle state" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test vulkan adapter", report);
    var device = Device{ ._state = &device_state };

    var fence = try device.makeFence(.{ .label = "binary fence" });
    defer fence.deinit();
    try std.testing.expectEqual(@as(usize, 1), tracker.fences);
    try std.testing.expectEqual(core.FenceKind.binary, fence.descriptor().kind);
    try std.testing.expect(!fence.isSignaled(1));
    try std.testing.expectError(core.CommandEncodingError.FenceWaitTimeout, fence.wait(.{}));
    try fence.signal(.{});
    try fence.wait(.{});
    try std.testing.expect(fence.isSignaled(1));
    try fence.reset();
    try std.testing.expect(!fence.isSignaled(1));

    try std.testing.expectError(core.CommandEncodingError.UnsupportedTimelineFences, device.makeFence(.{
        .kind = .timeline,
        .initial_value = 2,
    }));
    report.features.timeline_fences = true;
    device.state().capability_report = report;
    var timeline = try device.makeFence(.{
        .kind = .timeline,
        .initial_value = 2,
    });
    defer timeline.deinit();
    try std.testing.expect(timeline.isSignaled(2));
    try timeline.signal(.{ .value = 5 });
    try timeline.wait(.{ .value = 4 });
    try std.testing.expectError(core.CommandEncodingError.InvalidFenceValue, timeline.signal(.{ .value = 3 }));
    try std.testing.expectError(core.CommandEncodingError.InvalidFenceValue, timeline.reset());

    var event = try device.makeEvent(.{ .label = "event" });
    defer event.deinit();
    try std.testing.expectEqual(@as(usize, 1), tracker.events);
    try std.testing.expect(!event.isSignaled());
    try std.testing.expectError(core.CommandEncodingError.EventWaitTimeout, event.wait(.{}));
    try event.signal(.{});
    try event.wait(.{});
    try std.testing.expect(event.isSignaled());
    event.reset();
    try std.testing.expect(!event.isSignaled());
    try event.signal(.{ .signaled = false });
    try std.testing.expectError(core.CommandEncodingError.EventWaitTimeout, event.wait(.{}));
    try std.testing.expectError(core.CommandEncodingError.UnsupportedSharedEvents, device.makeEvent(.{
        .shared = true,
    }));
}

test "runtime command buffer synchronization waits before submit and signals after submit" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.features.timeline_fences = true;
    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test vulkan adapter", report);
    var device = Device{ ._state = &device_state };

    var wait_fence = try device.makeFence(.{ .label = "wait fence" });
    defer wait_fence.deinit();
    var signal_fence = try device.makeFence(.{ .label = "signal fence" });
    defer signal_fence.deinit();
    var timeline = try device.makeFence(.{
        .label = "timeline",
        .kind = .timeline,
        .initial_value = 2,
    });
    defer timeline.deinit();
    var event = try device.makeEvent(.{ .label = "signal event" });
    defer event.deinit();

    var blocked = CommandBuffer.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
    });
    const blocked_waits = [_]FenceWaitOperation{.{
        .fence = &wait_fence,
    }};
    try std.testing.expectError(core.CommandEncodingError.FenceWaitTimeout, blocked.commitWithSynchronization(.{
        .wait_fences = blocked_waits[0..],
    }));
    try std.testing.expectEqual(core.CommandBufferState.ready, blocked.state());

    try wait_fence.signal(.{});
    var command_buffer = CommandBuffer.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
    });
    const waits = [_]FenceWaitOperation{.{
        .fence = &wait_fence,
    }};
    const signals = [_]FenceSignalOperation{
        .{ .fence = &signal_fence },
        .{ .fence = &timeline, .descriptor = .{ .value = 5 } },
    };
    const event_signals = [_]EventSignalOperation{.{
        .event = &event,
    }};
    try command_buffer.commitWithSynchronization(.{
        .wait_fences = waits[0..],
        .signal_fences = signals[0..],
        .signal_events = event_signals[0..],
    });

    try std.testing.expect(!command_buffer.privateState().alive);
    try std.testing.expect(signal_fence.isSignaled(1));
    try std.testing.expect(timeline.isSignaled(5));
    try std.testing.expect(event.isSignaled());
}

test "runtime query sets support encoder writes and readback" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test vulkan adapter", core.defaultDeviceCapabilityReport(.vulkan));
    var device = Device{ ._state = &device_state };

    var command_buffer = CommandBuffer.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .queue_kind_value = .graphics,
        .features_value = device.features(),
        .impl = null,
    });
    var render_encoder = RenderCommandEncoder.init(.{
        .backend = .vulkan,
        .command_buffer = &command_buffer,
        .impl = null,
    });
    var compute_encoder = ComputeCommandEncoder.init(.{
        .backend = .vulkan,
        .command_buffer = &command_buffer,
        .impl = null,
    });
    var timestamps = try device.makeQuerySet(.{
        .query_type = .timestamp,
        .count = 2,
    });
    defer timestamps.deinit();
    try std.testing.expectEqual(core.TimestampQuerySource.logical_sequence, timestamps.resultSource());
    try std.testing.expectEqual(@as(usize, 1), tracker.query_sets);
    try compute_encoder.writeTimestamp(&timestamps, 0);
    try render_encoder.writeTimestamp(&timestamps, 1);
    try std.testing.expectError(core.QueryError.QueryNotReady, compute_encoder.writeTimestamp(&timestamps, 0));
    var timestamp_results = [_]u64{0} ** 2;
    try timestamps.readback(.{
        .first_query = 0,
        .query_count = 2,
        .destination = timestamp_results[0..],
    });
    try std.testing.expectEqual(@as(u64, 1), timestamp_results[0]);
    try std.testing.expectEqual(@as(u64, 2), timestamp_results[1]);
    try std.testing.expectError(core.QueryError.QueryTypeMismatch, render_encoder.beginOcclusionQuery(&timestamps, 0));

    try std.testing.expectError(core.QueryError.UnsupportedOcclusionQueries, device.makeQuerySet(.{
        .query_type = .occlusion,
        .count = 1,
    }));

    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.features.pipeline_statistics_queries = false;
    device.state().capability_report = report;
    try std.testing.expectError(core.QueryError.UnsupportedPipelineStatisticsQueries, device.makeQuerySet(.{
        .query_type = .pipeline_statistics,
        .count = 1,
        .pipeline_statistics = .{ .vertex_invocations = true },
    }));
}

test "query commands reject resources from another runtime" {
    var query_tracker = ResourceTracker{};
    var command_tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var device_state = testRuntimeState(
        std.testing.allocator,
        &query_tracker,
        .vulkan,
        &backend_runtime,
        "query owner adapter",
        core.defaultDeviceCapabilityReport(.vulkan),
    );
    var device = Device{ ._state = &device_state };
    var timestamps = try device.makeQuerySet(.{
        .query_type = .timestamp,
        .count = 1,
    });
    defer timestamps.deinit();

    var command_buffer = CommandBuffer.init(.{
        .backend = .vulkan,
        .tracker = &command_tracker,
    });
    var render_encoder = RenderCommandEncoder.init(.{
        .backend = .vulkan,
        .command_buffer = &command_buffer,
    });
    var compute_encoder = ComputeCommandEncoder.init(.{
        .backend = .vulkan,
        .command_buffer = &command_buffer,
    });
    var blit_encoder = BlitCommandEncoder.init(.{
        .backend = .vulkan,
        .command_buffer = &command_buffer,
    });

    try std.testing.expectError(RuntimeError.BackendMismatch, render_encoder.writeTimestamp(&timestamps, 0));
    try std.testing.expectError(RuntimeError.BackendMismatch, compute_encoder.writeTimestamp(&timestamps, 0));
    try std.testing.expectError(RuntimeError.BackendMismatch, blit_encoder.writeTimestamp(&timestamps, 0));

    var owner_command_buffer = CommandBuffer.init(.{
        .backend = .vulkan,
        .tracker = &query_tracker,
    });
    var owner_blit_encoder = BlitCommandEncoder.init(.{
        .backend = .vulkan,
        .command_buffer = &owner_command_buffer,
    });
    var foreign_destination = Buffer.init(.{
        .backend = .vulkan,
        .tracker = &command_tracker,
        .length_value = @sizeOf(u64),
        .usage_value = .{ .copy_destination = true },
        .impl = undefined,
    });
    try std.testing.expectError(RuntimeError.BackendMismatch, owner_blit_encoder.resolveQuerySet(
        &timestamps,
        &foreign_destination,
        .{ .query_count = 1 },
    ));
}

test "query resolve borrows survive until command buffer completion" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var device_state = testRuntimeState(
        std.testing.allocator,
        &tracker,
        .vulkan,
        &backend_runtime,
        "query resolve borrow adapter",
        core.defaultDeviceCapabilityReport(.vulkan),
    );
    var device = Device{ ._state = &device_state };
    var timestamps = try device.makeQuerySet(.{
        .query_type = .timestamp,
        .count = 1,
    });
    defer timestamps.deinit();

    var command_buffer = CommandBuffer.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
    });

    try command_buffer.retainQuerySetForResolve(&timestamps);
    try std.testing.expect(timestamps.hasPendingNativeWork());
    try std.testing.expectEqual(@as(usize, 1), timestamps.state().pending_command_borrows);

    // A native/logical resolve encoding error rolls back the borrow immediately.
    command_buffer.rollbackQuerySetResolveBorrow(&timestamps);
    try std.testing.expect(!timestamps.hasPendingNativeWork());
    try std.testing.expectEqual(@as(usize, 0), command_buffer.privateState().borrowed_query_sets.items.len);

    // A successfully encoded resolve remains borrowed while unsubmitted, then
    // the synchronous commit releases it only after completion.
    try command_buffer.retainQuerySetForResolve(&timestamps);
    try std.testing.expect(timestamps.hasPendingNativeWork());
    try command_buffer.commit();
    try std.testing.expect(!timestamps.hasPendingNativeWork());
    try std.testing.expectEqual(@as(usize, 0), timestamps.state().pending_command_borrows);
    try std.testing.expectEqual(@as(usize, 0), command_buffer.privateState().borrowed_query_sets.items.len);

    timestamps.reset();
}

test "runtime occlusion queries require pass binding and reset before slot reuse" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.features.occlusion_queries = true;
    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "query validation adapter", report);
    var device = Device{ ._state = &device_state };

    var visibility = try device.makeQuerySet(.{
        .query_type = .occlusion,
        .count = 1,
    });
    defer visibility.deinit();

    var command_buffer = CommandBuffer.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .queue_kind_value = .graphics,
        .features_value = device.features(),
        .impl = null,
    });
    var unbound = RenderCommandEncoder.init(.{
        .backend = .vulkan,
        .command_buffer = &command_buffer,
        .impl = null,
    });
    try std.testing.expectError(core.CommandEncodingError.InvalidRenderCommandEncoderState, unbound.beginOcclusionQuery(&visibility, 0));

    var bound = RenderCommandEncoder.init(.{
        .backend = .vulkan,
        .command_buffer = &command_buffer,
        .occlusion_query_set = &visibility,
        .impl = null,
    });
    var other_bound = RenderCommandEncoder.init(.{
        .backend = .vulkan,
        .command_buffer = &command_buffer,
        .occlusion_query_set = &visibility,
        .impl = null,
    });
    try bound.beginOcclusionQuery(&visibility, 0);
    try std.testing.expectError(core.CommandEncodingError.InvalidRenderCommandEncoderState, other_bound.endOcclusionQuery(&visibility));
    try std.testing.expectError(core.QueryError.QueryNotReady, bound.endEncoding());
    try bound.endOcclusionQuery(&visibility);
    try std.testing.expectError(core.QueryError.QueryNotReady, bound.beginOcclusionQuery(&visibility, 0));

    var values = [_]u64{0};
    try visibility.readback(.{
        .query_count = 1,
        .destination = values[0..],
    });
    try std.testing.expectEqual(@as(u64, 1), values[0]);

    visibility.reset();
    try bound.beginOcclusionQuery(&visibility, 0);
    try bound.endOcclusionQuery(&visibility);
}

test "Period 43 runtime diagnostics expose markers profiling capture and issue reports" {
    var tracker = ResourceTracker{};
    tracker.retain(.buffer);
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    report.features.debug_labels = true;
    report.features.debug_markers = true;
    report.features.timestamp_queries = true;
    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "diagnostic adapter", report);
    var device = Device{ ._state = &device_state };

    const markers = debugMarkerCapabilities(device);
    try std.testing.expectEqual(core.NativeDiagnosticSupport.native, markers.object_labels);
    try std.testing.expectEqual(core.NativeDiagnosticSupport.validation_only, markers.command_buffer_groups);
    try std.testing.expectEqual(core.NativeDiagnosticSupport.native, markers.encoder_groups);

    const profiling = profilingCapabilities(device);
    try std.testing.expectEqual(core.TimestampQuerySource.logical_sequence, profiling.timestamp_source);
    const plan = try planProfiling(device, .{});
    try std.testing.expectEqual(core.ProfilingMode.cpu_fallback, plan.mode);
    try std.testing.expect(!plan.gpu_duration_available);

    report.source = .vulkan_query;
    report.native_features.timestamp_queries = true;
    device.state().capability_report = report;
    device.state().native_gpu_timestamp_queries = true;
    const native_profiling = profilingCapabilities(device);
    try std.testing.expectEqual(core.TimestampQuerySource.native_gpu, native_profiling.timestamp_source);
    try std.testing.expect(native_profiling.native_gpu_timestamps);
    const native_plan = try planProfiling(device, .{ .require_gpu_timestamps = true });
    try std.testing.expectEqual(core.ProfilingMode.native_gpu_timestamps, native_plan.mode);
    try std.testing.expect(!native_plan.gpu_duration_available);

    const issue = try issueReport(device, .{
        .operation = "blitTexture",
        .object_kind = "texture",
        .object_label = "upload target",
        .failure = error.UnsupportedTextureBlit,
    });
    try std.testing.expectEqualStrings("diagnostic adapter", issue.adapter_name);
    try std.testing.expectEqualStrings("UnsupportedTextureBlit", issue.failure_name.?);
    try std.testing.expectEqual(core.ErrorCategory.unsupported_feature, issue.failure_category.?);
    try std.testing.expectEqual(@as(usize, 1), issue.runtime.live_resources);

    try std.testing.expectError(core.CaptureError.UnsupportedCapture, beginCaptureScope(&device, .{
        .label = "vulkan capture",
    }));
}

test "runtime heaps track aligned reservations and diagnostics" {
    var tracker = ResourceTracker{};
    var backend_runtime: BackendRuntime = undefined;
    var report = core.defaultDeviceCapabilityReport(.vulkan);
    var device_state = testRuntimeState(std.testing.allocator, &tracker, .vulkan, &backend_runtime, "test vulkan adapter", report);
    var device = Device{ ._state = &device_state };

    try std.testing.expectError(core.HeapError.UnsupportedHeaps, device.makeHeap(.{
        .size = 4096,
    }));
    report.features.heaps = true;
    device.state().capability_report = report;
    var heap = try device.makeHeap(.{
        .label = "upload heap",
        .size = 4096,
        .storage_mode = .cpu_visible,
    });
    defer heap.deinit();
    try std.testing.expectEqual(@as(usize, 1), tracker.heaps);
    try std.testing.expectEqualStrings("upload heap", heap.label().?);

    const first = try heap.reserve(.{
        .size = 128,
        .alignment = 64,
    });
    try std.testing.expectEqual(@as(u64, 0), first.offset);
    const second = try heap.reserve(.{
        .size = 128,
        .alignment = 256,
    });
    try std.testing.expectEqual(@as(u64, 256), second.offset);
    try std.testing.expectEqual(@as(u64, 384), heap.reservedBytes());
    try heap.validateAllocation(first, .{ .size = 128, .alignment = 64 });
    try std.testing.expectError(core.HeapError.HeapAllocationTooSmall, heap.validateAllocation(first, .{
        .size = 129,
        .alignment = 64,
    }));
    try std.testing.expectError(core.HeapError.HeapAllocationNotReserved, heap.validateAllocation(.{
        .offset = 512,
        .size = 64,
        .alignment = 64,
    }, .{ .size = 64, .alignment = 64 }));
    try std.testing.expectError(core.HeapError.HeapOutOfMemory, heap.reserve(.{
        .size = 4096,
    }));
    const aliasing = try heap.aliasingPlan(.{
        .first = first,
        .second = .{
            .offset = first.offset,
            .size = 64,
            .alignment = 64,
        },
        .first_use = 0,
        .first_last_use = 1,
        .second_use = 2,
        .second_last_use = 3,
    });
    try std.testing.expect(aliasing.eligible);
    try std.testing.expectEqual(core.HeapAliasingReason.eligible, aliasing.reason);

    const budget = try device.memoryBudgetReport(.{
        .budget_bytes = 4096,
        .heap_reserved_bytes = heap.reservedBytes(),
        .transient_peak_bytes = 1024,
        .warning_threshold_percent = 25,
        .critical_threshold_percent = 80,
        .native_budget_available = true,
    });
    try std.testing.expectEqual(core.MemoryBudgetSource.fallback, budget.source);
    try std.testing.expectEqual(core.MemoryPressureStatus.warning, budget.pressure);

    const resources = [_]core.TransientResourceDescriptor{
        .{
            .kind = .buffer,
            .size = 1024,
            .alignment = 256,
            .first_use = 0,
            .last_use = 1,
        },
        .{
            .kind = .buffer,
            .size = 512,
            .alignment = 128,
            .first_use = 2,
            .last_use = 3,
        },
    };
    const diagnostics = try device.transientAllocationDiagnostics(resources[0..]);
    try std.testing.expectEqual(@as(usize, 2), diagnostics.resource_count);
    try std.testing.expectEqual(@as(usize, 1), diagnostics.aliasable_pairs);
    try std.testing.expectEqual(@as(u64, 1024), diagnostics.peak_live_units);
    try std.testing.expectEqual(@as(u64, 512), diagnostics.aliasing_savings_units);
}

test "heap resource storage compatibility stays explicit" {
    try validateHeapBufferCompatibility(.{
        .size = 4096,
        .storage_mode = .cpu_visible,
    }, .{
        .length = 64,
        .storage_mode = .shared,
    });
    try std.testing.expectError(core.HeapError.HeapResourceIncompatible, validateHeapBufferCompatibility(.{
        .size = 4096,
        .storage_mode = .device_local,
    }, .{
        .length = 64,
        .storage_mode = .shared,
    }));
    try validateHeapTextureCompatibility(.{
        .size = 4096,
        .storage_mode = .device_local,
    }, .{
        .format = .rgba8_unorm,
        .width = 8,
        .usage = .{ .render_attachment = true },
        .storage_mode = .private,
    });
    try std.testing.expectError(core.HeapError.HeapResourceIncompatible, validateHeapTextureCompatibility(.{
        .size = 4096,
        .storage_mode = .cpu_visible,
    }, .{
        .format = .rgba8_unorm,
        .width = 8,
        .storage_mode = .shared,
    }));
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
    var layout = BindGroupLayout.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .allocator = allocator,
        .entries = copied_layout_entries,
    });
    tracker.retain(.bind_group_layout);
    defer layout.deinit();

    const buffer_state = Buffer.State{
        .backend = .vulkan,
        .tracker = &tracker,
        .impl = undefined,

        .length_value = 128,
    };
    var buffer = Buffer.init(buffer_state);
    var texture_view = TextureView.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .format_value = .rgba8_unorm,
        .usage_value = .{ .shader_read = true },
        .sample_count_value = 1,
        .width_value = 1,
        .height_value = 1,
        .impl = undefined,
    });
    var sampler = SamplerState.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .impl = undefined,
    });

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
    var compare_layout = BindGroupLayout.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .allocator = allocator,
        .entries = copied_compare_layout_entries,
    });
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
    var storage_layout = BindGroupLayout.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .allocator = allocator,
        .entries = copied_storage_layout_entries,
    });
    tracker.retain(.bind_group_layout);
    defer storage_layout.deinit();

    const storage_buffer_state = Buffer.State{
        .backend = .vulkan,
        .tracker = &tracker,
        .impl = undefined,

        .length_value = 128,
        .usage_value = .{ .storage = true },
    };
    var storage_buffer = Buffer.init(storage_buffer_state);
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

    const non_storage_buffer_state = Buffer.State{
        .backend = .vulkan,
        .tracker = &tracker,
        .impl = undefined,

        .length_value = 128,
    };
    var non_storage_buffer = Buffer.init(non_storage_buffer_state);
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

    const metal_buffer_state = Buffer.State{
        .backend = .metal,
        .tracker = &tracker,
        .impl = undefined,

        .length_value = 128,
    };
    var metal_buffer = Buffer.init(metal_buffer_state);
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
    var array_layout = BindGroupLayout.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .allocator = allocator,
        .entries = copied_array_layout_entries,
    });
    tracker.retain(.bind_group_layout);
    defer array_layout.deinit();
    try std.testing.expectError(core.BindingError.InvalidBindGroupResourceCount, materializeBindGroupEntries(allocator, .vulkan, .{
        .layout = &array_layout,
        .entries = &.{.{
            .binding = 0,
            .resource = .{ .sampler = &sampler },
        }},
    }));
    const sampler_array_resources = [_]BindGroupResource{
        .{ .sampler = &sampler },
        .{ .sampler = &sampler },
    };
    const materialized_array = try materializeBindGroupEntries(allocator, .vulkan, .{
        .layout = &array_layout,
        .entries = &.{.{
            .binding = 0,
            .resource = .{ .sampler = &sampler },
            .resources = sampler_array_resources[0..],
        }},
    });
    defer allocator.free(materialized_array);
    try std.testing.expectEqual(core.BindingResourceKind.sampler, materialized_array[0].resource.resourceKind());

    const dynamic_layout_entries = [_]core.BindGroupLayoutEntry{
        .{
            .binding = 0,
            .resource = .uniform_buffer,
            .visibility = .{ .vertex = true },
            .dynamic_offset = true,
        },
    };
    const copied_dynamic_layout_entries = try allocator.dupe(core.BindGroupLayoutEntry, dynamic_layout_entries[0..]);
    var dynamic_layout = BindGroupLayout.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .allocator = allocator,
        .entries = copied_dynamic_layout_entries,
    });
    tracker.retain(.bind_group_layout);
    defer dynamic_layout.deinit();
    const materialized_dynamic = try materializeBindGroupEntries(allocator, .vulkan, .{
        .layout = &dynamic_layout,
        .entries = entries[0..1],
    });
    defer allocator.free(materialized_dynamic);
    try std.testing.expectEqual(core.BindingResourceKind.uniform_buffer, materialized_dynamic[0].resource.resourceKind());
}

test "runtime bind group dynamic offsets validate against layout" {
    const layout_entries = [_]core.BindGroupLayoutEntry{
        .{
            .binding = 3,
            .resource = .uniform_buffer,
            .visibility = .{ .vertex = true },
            .dynamic_offset = true,
        },
    };
    var tracker = ResourceTracker{};
    const bind_group = BindGroup.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .allocator = std.testing.allocator,
        .layout_entries = layout_entries[0..],
        .entries = &.{},
    });

    try validateDynamicOffsetsForBindGroup(bind_group, .{
        .index = 0,
        .dynamic_offsets = &.{.{ .binding = 3, .offset = 256 }},
    });
    try std.testing.expectError(core.BindingError.MissingDynamicOffset, validateDynamicOffsetsForBindGroup(bind_group, .{
        .index = 0,
    }));
    try std.testing.expectError(core.BindingError.ExtraDynamicOffset, validateDynamicOffsetsForBindGroup(bind_group, .{
        .index = 0,
        .dynamic_offsets = &.{.{ .binding = 4, .offset = 256 }},
    }));
    try std.testing.expectError(core.BindingError.InvalidDynamicOffsetAlignment, validateDynamicOffsetsForBindGroup(bind_group, .{
        .index = 0,
        .dynamic_offsets = &.{.{ .binding = 3, .offset = 4 }},
    }));
}

test "runtime bind group dynamic offsets validate array elements" {
    const layout_entries = [_]core.BindGroupLayoutEntry{.{
        .binding = 3,
        .resource = .uniform_buffer,
        .visibility = .{ .vertex = true },
        .array_count = 2,
        .dynamic_offset = true,
    }};
    var tracker = ResourceTracker{};
    const bind_group = BindGroup.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .allocator = std.testing.allocator,
        .layout_entries = layout_entries[0..],
        .entries = &.{},
    });

    try validateDynamicOffsetsForBindGroup(bind_group, .{
        .index = 0,
        .dynamic_offsets = &.{
            .{ .binding = 3, .array_element = 0, .offset = 256 },
            .{ .binding = 3, .array_element = 1, .offset = 512 },
        },
    });
    try std.testing.expectError(core.BindingError.MissingDynamicOffset, validateDynamicOffsetsForBindGroup(bind_group, .{
        .index = 0,
        .dynamic_offsets = &.{.{ .binding = 3, .array_element = 0, .offset = 256 }},
    }));
    try std.testing.expectError(core.BindingError.ExtraDynamicOffset, validateDynamicOffsetsForBindGroup(bind_group, .{
        .index = 0,
        .dynamic_offsets = &.{
            .{ .binding = 3, .array_element = 0, .offset = 256 },
            .{ .binding = 3, .array_element = 2, .offset = 512 },
        },
    }));
}

test "runtime command encoders bind resource tables with validation" {
    var tracker = ResourceTracker{};
    var command_buffer = CommandBuffer.init(.{ .backend = .metal });
    var sampler = SamplerState.init(.{
        .backend = .metal,
        .tracker = &tracker,
        .impl = undefined,
    });
    var ranges = [_]core.DescriptorIndexingRange{.{
        .binding = 0,
        .resource = .sampler,
        .visibility = .{ .fragment = true },
        .descriptor_count = 1,
    }};
    var slots = [_]?BindGroupResource{.{ .sampler = &sampler }};
    var table = ResourceTable.init(.{
        .backend = .metal,
        .tracker = &tracker,
        .allocator = std.testing.allocator,
        .model_value = .argument_buffer,
        .ranges = ranges[0..],
        .slots = slots[0..],
    });
    var render_encoder = RenderCommandEncoder.init(.{
        .backend = .metal,
        .command_buffer = &command_buffer,
    });
    render_encoder.privateState().active_resource_table_layout_base = 1;
    render_encoder.privateState().active_resource_table_layout_count = 1;
    render_encoder.privateState().active_resource_table_layout_hashes[0] = table.layoutFingerprint();
    try render_encoder.setResourceTable(&table, .{ .index = 1 });
    try std.testing.expectEqual(@as(u64, 2), render_encoder.privateState().debug.resource_table_mask);
    try std.testing.expectEqual(@as(u64, 1), table.state().bound_count);
    try std.testing.expectError(core.BindingError.ResourceTableUpdateAfterBindUnsupported, table.clear(.{ .binding = 0 }));

    var compute_encoder = ComputeCommandEncoder.init(.{
        .backend = .metal,
        .command_buffer = &command_buffer,
    });
    try std.testing.expectError(core.BindingError.ResourceTableVisibilityMismatch, compute_encoder.setResourceTable(&table, .{ .index = 0 }));

    try std.testing.expectError(core.BindingError.ResourceTablePipelineLayoutMismatch, render_encoder.setResourceTable(&table, .{ .index = 0 }));

    var vulkan_table = table;
    vulkan_table.state().backend = .vulkan;
    try std.testing.expectError(RuntimeError.BackendMismatch, render_encoder.setResourceTable(&vulkan_table, .{ .index = 0 }));

    var empty_slots = [_]?BindGroupResource{null};
    var incomplete_table = table;
    incomplete_table.state().slots = empty_slots[0..];
    try std.testing.expectError(core.BindingError.MissingResourceTableBinding, render_encoder.setResourceTable(&incomplete_table, .{ .index = 0 }));
}

test "runtime command encoders write root constants with pipeline layout validation" {
    var tracker = ResourceTracker{};
    var command_buffer = CommandBuffer.init(.{ .backend = .metal });
    var bytes = [_]u8{ 1, 2, 3, 4 };
    var render_encoder = RenderCommandEncoder.init(.{
        .backend = .metal,
        .command_buffer = &command_buffer,
    });

    try std.testing.expectError(core.RootConstantError.MissingRootConstantRange, render_encoder.setRootConstants(.{
        .offset = 0,
        .bytes = bytes[0..],
    }));

    var render_ranges = [_]core.RootConstantRange{.{
        .visibility = .{ .vertex = true },
        .offset = 0,
        .size = 8,
    }};
    var render_pipeline = RenderPipelineState.init(.{
        .backend = .metal,
        .tracker = &tracker,
        .root_constant_ranges = render_ranges[0..],
        .impl = undefined,
    });
    try render_encoder.setRenderPipelineState(&render_pipeline);
    try render_encoder.setRootConstants(.{
        .offset = 0,
        .bytes = bytes[0..],
    });
    try std.testing.expectError(core.RootConstantError.InvalidRootConstantAlignment, render_encoder.setRootConstants(.{
        .offset = 2,
        .bytes = bytes[0..],
    }));
    try std.testing.expectError(core.RootConstantError.RootConstantWriteOutOfRange, render_encoder.setRootConstants(.{
        .offset = 8,
        .bytes = bytes[0..],
    }));

    var compute_encoder = ComputeCommandEncoder.init(.{
        .backend = .metal,
        .command_buffer = &command_buffer,
    });
    var compute_pipeline = ComputePipelineState.init(.{
        .backend = .metal,
        .tracker = &tracker,
        .root_constant_ranges = render_ranges[0..],
        .impl = undefined,
    });
    try compute_encoder.setComputePipelineState(&compute_pipeline);
    try std.testing.expectError(core.RootConstantError.RootConstantVisibilityMismatch, compute_encoder.setRootConstants(.{
        .offset = 0,
        .bytes = bytes[0..],
    }));
}

test "runtime specialization gate honors device feature support" {
    const constants = [_]core.ShaderSpecializationConstant{.{
        .id = 0,
        .name = "variant",
        .value = .{ .u32 = 1 },
    }};
    try std.testing.expectError(core.ShaderError.UnsupportedShaderSpecialization, validateRuntimeSpecialization(.{
        .module = .{ .source = .{ .slang = "shader source" } },
        .stage = .vertex,
        .specialization = .{ .constants = constants[0..] },
    }, .{}));
    try validateRuntimeSpecialization(.{
        .module = .{ .source = .{ .slang = "shader source" } },
        .stage = .vertex,
        .specialization = .{ .constants = constants[0..] },
    }, .{ .shader_specialization = true });
}

test "runtime pipeline fingerprints include shader specialization constants" {
    const color_attachments = [_]core.RenderPipelineColorAttachmentDescriptor{.{
        .format = .rgba8_unorm,
    }};
    const module = core.ShaderModuleDescriptor{
        .source = .{ .slang = "shader source" },
    };
    const constants_a = [_]core.ShaderSpecializationConstant{.{
        .id = 0,
        .name = "variant",
        .value = .{ .u32 = 1 },
    }};
    const constants_b = [_]core.ShaderSpecializationConstant{.{
        .id = 0,
        .name = "variant",
        .value = .{ .u32 = 2 },
    }};

    const descriptor_a = core.RenderPipelineDescriptor{
        .vertex = .{
            .module = module,
            .stage = .vertex,
            .specialization = .{ .constants = constants_a[0..] },
        },
        .color_attachments = color_attachments[0..],
    };
    var descriptor_b = descriptor_a;
    descriptor_b.vertex.specialization = .{ .constants = constants_b[0..] };

    var hash_a: u64 = 0;
    hashRenderPipelineDescriptor(&hash_a, descriptor_a);
    var hash_b: u64 = 0;
    hashRenderPipelineDescriptor(&hash_b, descriptor_b);
    try std.testing.expect(hash_a != hash_b);
}

test "runtime root constant layout gate validates pipeline compatibility" {
    const ranges = [_]core.RootConstantRange{.{
        .visibility = .{ .vertex = true },
        .offset = 0,
        .size = 16,
    }};
    const layout = core.RootConstantLayoutDescriptor{ .ranges = ranges[0..] };
    const limits = core.DeviceLimits{
        .max_root_constant_bytes = 64,
        .root_constant_alignment = 4,
    };

    try std.testing.expectError(core.RootConstantError.UnsupportedRootConstants, validateRuntimeRootConstantLayout(
        layout,
        .{},
        limits,
    ));
    try validateRuntimeRootConstantLayout(layout, .{ .root_constants = true }, limits);
    try validateRuntimeRootConstantLayout(null, .{}, .{});
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
        .format = .depth32_float_stencil8,
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

test "headless command buffer rejects current drawable render passes" {
    var command_buffer = CommandBuffer.init(.{
        .backend = .metal,
        .presentation_available = false,
    });
    const color_attachments = [_]RenderPassColorAttachmentDescriptor{.{}};
    try std.testing.expectError(
        RuntimeError.UnsupportedBackendForPresentation,
        command_buffer.makeRenderCommandEncoder(.{
            .color_attachments = color_attachments[0..],
        }),
    );
    try std.testing.expectError(
        RuntimeError.UnsupportedBackendForPresentation,
        command_buffer.presentDrawable(),
    );
}

test "runtime render encoder validates bind group binding" {
    var command_buffer = CommandBuffer.init(.{ .backend = .vulkan });
    const color_attachments = [_]RenderPassColorAttachmentDescriptor{.{}};
    var encoder = try command_buffer.makeRenderCommandEncoder(.{
        .color_attachments = color_attachments[0..],
    });

    var tracker = ResourceTracker{};
    var entries = [_]core.BindGroupEntry{};
    var layout_entries = [_]core.BindGroupLayoutEntry{.{
        .binding = 0,
        .resource = .sampler,
        .visibility = .{ .fragment = true },
    }};
    var bind_group = BindGroup.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .allocator = std.testing.allocator,
        .layout_entries = layout_entries[0..],
        .entries = entries[0..],
    });
    try encoder.setBindGroup(&bind_group, .{ .index = 0 });
    try std.testing.expectEqual(@as(u64, 1), encoder.privateState().debug.bind_group_mask);

    var metal_bind_group = BindGroup.init(.{
        .backend = .metal,
        .tracker = &tracker,
        .allocator = std.testing.allocator,
        .layout_entries = layout_entries[0..],
        .entries = entries[0..],
    });
    try std.testing.expectError(RuntimeError.BackendMismatch, encoder.setBindGroup(&metal_bind_group, .{ .index = 0 }));
    try std.testing.expectError(error.InvalidBindGroupIndex, encoder.setBindGroup(&bind_group, .{ .index = 16 }));

    try encoder.endEncoding();
}

test "runtime render encoder dynamic state methods validate before backend lowering" {
    var command_buffer = CommandBuffer.init(.{ .backend = .vulkan });
    const color_attachments = [_]RenderPassColorAttachmentDescriptor{.{}};
    var encoder = try command_buffer.makeRenderCommandEncoder(.{
        .color_attachments = color_attachments[0..],
    });

    try encoder.setViewport(.{
        .width = 640,
        .height = 480,
    });
    try encoder.setScissorRect(.{
        .width = 640,
        .height = 480,
    });
    try encoder.setBlendColor(.{
        .red = 1,
        .alpha = 1,
    });
    try encoder.setStencilReference(.{
        .value = 1,
    });
    try encoder.setDepthBias(.{
        .enabled = true,
        .constant = 1,
    });
    try std.testing.expectError(core.CommandEncodingError.InvalidViewport, encoder.setViewport(.{
        .width = 0,
        .height = 480,
    }));

    try encoder.endEncoding();
}

test "runtime render encoder base draw fields lower while indirect variants are gated" {
    var command_buffer = CommandBuffer.init(.{ .backend = .vulkan });
    const color_attachments = [_]RenderPassColorAttachmentDescriptor{.{}};
    var encoder = try command_buffer.makeRenderCommandEncoder(.{
        .color_attachments = color_attachments[0..],
    });

    var tracker = ResourceTracker{};
    var pipeline = RenderPipelineState.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .impl = undefined,
    });
    try encoder.setRenderPipelineState(&pipeline);

    try encoder.drawPrimitives(.{
        .vertex_count = 3,
        .base_instance = 1,
    });
    const index_buffer_state = Buffer.State{
        .backend = .vulkan,
        .tracker = &tracker,
        .impl = undefined,

        .length_value = 64,
    };
    var index_buffer = Buffer.init(index_buffer_state);
    try encoder.setIndexBuffer(&index_buffer);
    try encoder.drawIndexedPrimitives(.{
        .index_count = 3,
        .base_vertex = 1,
        .base_instance = 1,
    });

    const indirect_buffer_state = Buffer.State{
        .backend = .vulkan,
        .tracker = &tracker,
        .impl = undefined,

        .length_value = 64,
        .usage_value = .{ .indirect = true },
    };
    var indirect_buffer = Buffer.init(indirect_buffer_state);
    try encoder.drawPrimitivesIndirect(&indirect_buffer, .{});
    try encoder.drawIndexedPrimitivesIndirect(&indirect_buffer, .{});
    try encoder.drawPrimitivesIndirect(&indirect_buffer, .{
        .draw_count = 2,
        .stride = 16,
    });
    try std.testing.expectEqual(core.ResourceUsageKind.indirect_buffer, indirect_buffer.currentUsage().?);

    const draws = [_]core.DrawPrimitivesDescriptor{.{ .vertex_count = 3 }};
    try encoder.drawPrimitivesMulti(.{
        .draws = draws[0..],
    });
    const indexed_draws = [_]core.DrawIndexedPrimitivesDescriptor{.{ .index_count = 3 }};
    try encoder.drawIndexedPrimitivesMulti(.{
        .draws = indexed_draws[0..],
    });

    try encoder.endEncoding();
}

test "runtime resources keep borrowed debug labels" {
    var tracker = ResourceTracker{};
    const buffer_state = Buffer.State{
        .backend = .vulkan,
        .tracker = &tracker,
        .impl = undefined,

        .label_value = "vertices",
        .length_value = 16,
    };
    var buffer = Buffer.init(buffer_state);

    try std.testing.expectEqualStrings("vertices", buffer.label().?);
    buffer.setLabel("renamed vertices");
    try std.testing.expectEqualStrings("renamed vertices", buffer.label().?);
    buffer.setLabel(null);
    try std.testing.expect(buffer.label() == null);
}

test "runtime buffers expose storage and cpu visibility" {
    var tracker = ResourceTracker{};
    const buffer_state = Buffer.State{
        .backend = .vulkan,
        .tracker = &tracker,
        .impl = undefined,

        .length_value = 16,
        .storage_mode_value = .private,
    };
    var buffer = Buffer.init(buffer_state);

    try std.testing.expectEqual(core.ResourceStorageMode.private, buffer.storageMode());
    try std.testing.expect(!buffer.cpuVisible());
}

test "runtime private textures reject CPU upload before backend access" {
    var tracker = ResourceTracker{};
    var texture = Texture.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .format_value = .rgba8_unorm,
        .usage_value = .{ .copy_destination = true },
        .storage_mode_value = .private,
        .sample_count_value = 1,
        .impl = undefined,
    });

    try std.testing.expectError(core.TextureError.TextureNotCpuVisible, texture.replaceRegion(.{
        .size = .{ .width = 1, .height = 1 },
    }, .{
        .bytes = &.{ 0, 0, 0, 0 },
    }));
}

test "runtime texture views expose resolved ranges" {
    var tracker = ResourceTracker{};
    var view = TextureView.init(.{
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
    });

    try std.testing.expectEqual(core.TextureViewDimension.two_d_array, view.dimension());
    try std.testing.expectEqual(@as(u32, 2), view.baseMipLevel());
    try std.testing.expectEqual(@as(u32, 3), view.mipLevelCount());
    try std.testing.expectEqual(@as(u32, 1), view.baseArrayLayer());
    try std.testing.expectEqual(@as(u32, 2), view.arrayLayerCount());
    try std.testing.expectEqual(core.TextureViewDimension.two_d_array, view.descriptor().dimension);
}

test "runtime command objects validate debug group balance" {
    var command_buffer = CommandBuffer.init(.{ .backend = .vulkan });
    const invalid_utf8 = [_]u8{0xff};
    command_buffer.setLabel("frame commands");
    try std.testing.expectEqualStrings("frame commands", command_buffer.label().?);

    try command_buffer.insertDebugSignpost("frame start");
    try std.testing.expectError(core.CommandEncodingError.EmptyDebugGroupLabel, command_buffer.insertDebugSignpost(""));
    try std.testing.expectError(core.CommandEncodingError.InvalidDebugLabelEncoding, command_buffer.insertDebugSignpost(invalid_utf8[0..]));

    try command_buffer.pushDebugGroup("frame");

    const color_attachments = [_]RenderPassColorAttachmentDescriptor{.{}};
    var encoder = try command_buffer.makeRenderCommandEncoder(.{
        .label = "main render",
        .color_attachments = color_attachments[0..],
    });
    try std.testing.expectEqualStrings("main render", encoder.label().?);
    try std.testing.expectError(core.CommandEncodingError.InvalidCommandBufferState, command_buffer.pushDebugGroup("nested command scope"));
    try std.testing.expectError(core.CommandEncodingError.InvalidCommandBufferState, command_buffer.popDebugGroup());
    try std.testing.expectError(core.CommandEncodingError.InvalidCommandBufferState, command_buffer.insertDebugSignpost("inside encoder"));

    try encoder.insertDebugSignpost("draw setup");
    try std.testing.expectError(core.CommandEncodingError.EmptyDebugGroupLabel, encoder.insertDebugSignpost(""));

    try encoder.pushDebugGroup("draws");
    try std.testing.expectError(core.CommandEncodingError.UnclosedDebugGroup, encoder.endEncoding());
    try encoder.popDebugGroup();
    try encoder.endEncoding();

    try std.testing.expectError(core.CommandEncodingError.UnclosedDebugGroup, command_buffer.commit());
    try command_buffer.popDebugGroup();
    try command_buffer.commit();
}

test "runtime render pass descriptor accepts texture-backed color targets" {
    var tracker = ResourceTracker{};
    var color_view = TextureView.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .format_value = .rgba8_unorm,
        .usage_value = .{ .render_attachment = true, .shader_read = true },
        .sample_count_value = 1,
        .width_value = 64,
        .height_value = 64,
        .impl = undefined,
    });
    var second_color_view = color_view;
    const color_attachments = [_]RenderPassColorAttachmentDescriptor{.{
        .target = .{ .texture_view = &color_view },
    }};

    try (RenderPassDescriptor{
        .color_attachments = color_attachments[0..],
    }).validateRuntime(.vulkan);

    const mrt_attachments = [_]RenderPassColorAttachmentDescriptor{
        .{ .target = .{ .texture_view = &color_view } },
        .{ .target = .{ .texture_view = &second_color_view } },
    };
    try (RenderPassDescriptor{
        .color_attachments = mrt_attachments[0..],
    }).validateRuntime(.vulkan);

    var command_buffer = CommandBuffer.init(.{ .backend = .vulkan });
    var encoder = try command_buffer.makeRenderCommandEncoder(.{
        .color_attachments = mrt_attachments[0..],
    });
    try encoder.endEncoding();
}

test "runtime render pass descriptor rejects invalid texture targets" {
    var tracker = ResourceTracker{};
    var sampled_only_view = TextureView.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .format_value = .rgba8_unorm,
        .usage_value = .{ .shader_read = true },
        .sample_count_value = 1,
        .width_value = 64,
        .height_value = 64,
        .impl = undefined,
    });
    const color_attachments = [_]RenderPassColorAttachmentDescriptor{.{
        .target = .{ .texture_view = &sampled_only_view },
    }};

    try std.testing.expectError(RuntimeError.InvalidRenderPassAttachment, (RenderPassDescriptor{
        .color_attachments = color_attachments[0..],
    }).validateRuntime(.vulkan));

    const multiple_color_attachments = [_]RenderPassColorAttachmentDescriptor{ .{}, .{} };
    try std.testing.expectError(RuntimeError.InvalidRenderPassAttachment, (RenderPassDescriptor{
        .color_attachments = multiple_color_attachments[0..],
    }).validateRuntime(.vulkan));

    const transient_color_attachments = [_]RenderPassColorAttachmentDescriptor{.{
        .options = .{ .transient = true },
    }};
    try (RenderPassDescriptor{
        .color_attachments = transient_color_attachments[0..],
    }).validateRuntime(.vulkan);

    const drawable_color_attachments = [_]RenderPassColorAttachmentDescriptor{.{}};
    try std.testing.expectError(RuntimeError.UnsupportedStencilAttachment, (RenderPassDescriptor{
        .color_attachments = drawable_color_attachments[0..],
        .stencil_attachment = .{},
    }).validateRuntime(.vulkan));
}

test "runtime render pass supports combined depth stencil texture actions" {
    var tracker = ResourceTracker{};
    var color_view = TextureView.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .format_value = .rgba8_unorm,
        .usage_value = .{ .render_attachment = true },
        .sample_count_value = 1,
        .width_value = 64,
        .height_value = 64,
        .impl = undefined,
    });
    var depth_stencil_view = TextureView.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .format_value = .depth32_float_stencil8,
        .usage_value = .{ .render_attachment = true },
        .sample_count_value = 1,
        .width_value = 64,
        .height_value = 64,
        .impl = undefined,
    });
    const colors = [_]RenderPassColorAttachmentDescriptor{.{
        .target = .{ .texture_view = &color_view },
        .load_action = .load,
        .store_action = .dont_care,
    }};
    try (RenderPassDescriptor{
        .color_attachments = &colors,
        .depth_attachment = .{
            .target = .{ .texture_view = &depth_stencil_view },
            .load_action = .load,
            .store_action = .store,
        },
        .stencil_attachment = .{
            .target = .{ .texture_view = &depth_stencil_view },
            .clear_stencil = 7,
            .store_action = .store,
        },
    }).validateRuntime(.vulkan);
}

test "runtime render pass descriptor validates msaa resolve targets" {
    var tracker = ResourceTracker{};
    var msaa_view = TextureView.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .format_value = .rgba8_unorm,
        .usage_value = .{ .render_attachment = true },
        .sample_count_value = 4,
        .width_value = 64,
        .height_value = 64,
        .impl = undefined,
    });
    var resolve_view = TextureView.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .format_value = .rgba8_unorm,
        .usage_value = .{ .render_attachment = true, .shader_read = true },
        .sample_count_value = 1,
        .width_value = 64,
        .height_value = 64,
        .impl = undefined,
    });

    const color_attachments = [_]RenderPassColorAttachmentDescriptor{.{
        .target = .{ .texture_view = &msaa_view },
        .resolve_target = &resolve_view,
    }};
    try (RenderPassDescriptor{
        .color_attachments = color_attachments[0..],
    }).validateRuntime(.vulkan);

    msaa_view.state().storage_mode_value = .memoryless;
    try std.testing.expectError(RuntimeError.UnsupportedRenderPassAttachmentAction, (RenderPassDescriptor{
        .color_attachments = color_attachments[0..],
    }).validateRuntime(.vulkan));
    const memoryless_resolve = [_]RenderPassColorAttachmentDescriptor{.{
        .target = .{ .texture_view = &msaa_view },
        .resolve_target = &resolve_view,
        .store_action = .dont_care,
    }};
    try (RenderPassDescriptor{
        .color_attachments = memoryless_resolve[0..],
    }).validateRuntime(.vulkan);
    msaa_view.state().storage_mode_value = .automatic;

    const missing_resolve = [_]RenderPassColorAttachmentDescriptor{.{
        .target = .{ .texture_view = &msaa_view },
    }};
    try std.testing.expectError(RuntimeError.InvalidRenderPassAttachment, (RenderPassDescriptor{
        .color_attachments = missing_resolve[0..],
    }).validateRuntime(.vulkan));

    resolve_view.state().sample_count_value = 4;
    try std.testing.expectError(RuntimeError.InvalidRenderPassAttachment, (RenderPassDescriptor{
        .color_attachments = color_attachments[0..],
    }).validateRuntime(.vulkan));
}

test "Period 42 runtime depth and stencil resolve targets fail with typed unsupported errors" {
    var tracker = ResourceTracker{};
    var depth_source = TextureView.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .format_value = .depth32_float,
        .usage_value = .{ .render_attachment = true },
        .sample_count_value = 4,
        .width_value = 32,
        .height_value = 32,
        .impl = undefined,
    });
    var depth_destination = TextureView.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .format_value = .depth32_float,
        .usage_value = .{ .render_attachment = true },
        .sample_count_value = 1,
        .width_value = 32,
        .height_value = 32,
        .impl = undefined,
    });
    try std.testing.expectError(core.CommandEncodingError.UnsupportedTextureResolve, (RenderPassDepthAttachmentDescriptor{
        .target = .{ .texture_view = &depth_source },
        .resolve_target = &depth_destination,
    }).validateRuntime(.vulkan));

    var stencil_source = TextureView.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .format_value = .depth32_float_stencil8,
        .usage_value = .{ .render_attachment = true },
        .sample_count_value = 4,
        .width_value = 32,
        .height_value = 32,
        .impl = undefined,
    });
    var stencil_destination = TextureView.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .format_value = .depth32_float_stencil8,
        .usage_value = .{ .render_attachment = true },
        .sample_count_value = 1,
        .width_value = 32,
        .height_value = 32,
        .impl = undefined,
    });
    try std.testing.expectError(core.CommandEncodingError.UnsupportedTextureResolve, (RenderPassStencilAttachmentDescriptor{
        .target = .{ .texture_view = &stencil_source },
        .resolve_target = &stencil_destination,
    }).validateRuntime(.vulkan));
}

test "runtime command buffer refuses to present offscreen render passes" {
    var tracker = ResourceTracker{};
    var color_view = TextureView.init(.{
        .backend = .vulkan,
        .tracker = &tracker,
        .format_value = .rgba8_unorm,
        .usage_value = .{ .render_attachment = true },
        .sample_count_value = 1,
        .width_value = 32,
        .height_value = 32,
        .impl = undefined,
    });
    const color_attachments = [_]RenderPassColorAttachmentDescriptor{.{
        .target = .{ .texture_view = &color_view },
    }};

    var command_buffer = CommandBuffer.init(.{ .backend = .vulkan });
    var encoder = try command_buffer.makeRenderCommandEncoder(.{
        .color_attachments = color_attachments[0..],
    });
    try encoder.endEncoding();

    try std.testing.expectError(RuntimeError.PresentRequiresCurrentDrawable, command_buffer.presentDrawable());
}
