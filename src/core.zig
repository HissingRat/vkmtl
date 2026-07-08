const builtin = @import("builtin");
const std = @import("std");

pub const BackendPreference = enum {
    auto,
    vulkan,
    metal,
};

pub const Backend = enum {
    vulkan,
    metal,
};

pub const AdapterDeviceType = enum {
    unknown,
    integrated_gpu,
    discrete_gpu,
    virtual_gpu,
    cpu,
};

pub const AdapterPowerPreference = enum {
    default,
    low_power,
    high_performance,
};

pub const AdapterInfo = struct {
    backend: Backend,
    name: []const u8,
    vendor: []const u8 = "",
    device_type: AdapterDeviceType = .unknown,
};

pub const AdapterSelectionDescriptor = struct {
    backend: ?Backend = null,
    name: ?[]const u8 = null,
    power_preference: AdapterPowerPreference = .default,

    pub fn matches(self: AdapterSelectionDescriptor, adapter: AdapterInfo) bool {
        if (self.backend) |backend| {
            if (adapter.backend != backend) return false;
        }
        if (self.name) |name| {
            if (!std.mem.eql(u8, adapter.name, name)) return false;
        }
        return true;
    }
};

pub const AdapterList = struct {
    allocator: std.mem.Allocator,
    adapters: []AdapterInfo,

    pub fn deinit(self: *AdapterList) void {
        self.allocator.free(self.adapters);
        self.* = undefined;
    }

    pub fn items(self: AdapterList) []const AdapterInfo {
        return self.adapters;
    }

    pub fn len(self: AdapterList) usize {
        return self.adapters.len;
    }
};

pub const DeviceFeatures = struct {
    runtime_slang: bool = true,
    shader_reflection: bool = true,
    buffers: bool = true,
    textures: bool = true,
    texture_1d: bool = true,
    texture_2d: bool = true,
    texture_3d: bool = true,
    texture_arrays: bool = true,
    cube_textures: bool = true,
    multisample_textures: bool = true,
    samplers: bool = true,
    sampler_compare: bool = false,
    sampler_anisotropy: bool = false,
    sampler_border_color: bool = false,
    static_samplers: bool = false,
    heaps: bool = false,
    small_constants: bool = false,
    root_constants: bool = false,
    shader_specialization: bool = false,
    wireframe_fill_mode: bool = false,
    depth_bias: bool = false,
    conservative_rasterization: bool = false,
    blend_state: bool = false,
    independent_blend: bool = false,
    stencil_state: bool = false,
    tessellation: bool = false,
    mesh_shaders: bool = false,
    task_shaders: bool = false,
    acceleration_structures: bool = false,
    ray_tracing: bool = false,
    driver_pipeline_cache: bool = false,
    metal_binary_archive: bool = false,
    vertex_instance_step_rate: bool = false,
    draw_base_vertex: bool = false,
    draw_base_instance: bool = false,
    indirect_draw: bool = false,
    multi_draw: bool = false,
    occlusion_queries: bool = false,
    timestamp_queries: bool = false,
    pipeline_statistics_queries: bool = false,
    render_pipelines: bool = true,
    compute_pipelines: bool = true,
    compute_dispatch_indirect: bool = false,
    bind_groups: bool = true,
    descriptor_indexing: bool = false,
    argument_buffers: bool = false,
    sparse_buffers: bool = false,
    sparse_textures: bool = false,
    tiled_textures: bool = false,
    external_memory: bool = false,
    external_textures: bool = false,
    external_semaphores: bool = false,
    native_command_insertion: bool = false,
    transfer_commands: bool = true,
    storage_buffers: bool = true,
    storage_textures: bool = true,
    depth_attachments: bool = true,
    offscreen_render_targets: bool = true,
    msaa_render_targets: bool = true,
    indexed_draw: bool = true,
    multi_surface: bool = false,
    native_handles: bool = false,
    debug_labels: bool = false,
    command_buffer_pooling: bool = false,
    command_buffer_reset: bool = false,
    explicit_resource_barriers: bool = false,
    fences: bool = false,
    events: bool = false,
    timeline_fences: bool = false,
    shared_events: bool = false,
    multi_queue: bool = false,
    dedicated_compute_queue: bool = false,
    dedicated_transfer_queue: bool = false,
    queue_ownership_transfer: bool = false,
    debug_markers: bool = false,
    compute_atomics: bool = false,
    compute_threadgroup_memory: bool = false,
};

pub const DeviceLimits = struct {
    max_vertex_buffer_slots: u32 = default_max_vertex_buffer_slots,
    max_bind_group_slots: u32 = default_max_bind_group_slots,
    max_color_attachments: u32 = default_max_color_attachments,
    max_sample_count: u32 = 4,
    max_sampler_anisotropy: f32 = 1,
    min_uniform_buffer_offset_alignment: u64 = 256,
    min_storage_buffer_offset_alignment: u64 = 256,
    max_small_constant_bytes: u32 = 0,
    small_constant_alignment: u32 = 4,
    max_root_constant_bytes: u32 = 0,
    root_constant_alignment: u32 = 4,
    query_result_alignment: u64 = 8,
    max_compute_threadgroups_per_grid_x: u32 = 65_535,
    max_compute_threadgroups_per_grid_y: u32 = 65_535,
    max_compute_threadgroups_per_grid_z: u32 = 65_535,
    max_compute_threads_per_threadgroup_x: u32 = 1024,
    max_compute_threads_per_threadgroup_y: u32 = 1024,
    max_compute_threads_per_threadgroup_z: u32 = 64,
    max_compute_total_threads_per_threadgroup: u32 = 1024,
    max_compute_threadgroup_memory_bytes: u32 = 0,
    dispatch_indirect_alignment: u64 = 4,
    max_bindless_descriptors_per_range: u32 = 0,
    max_bindless_ranges_per_layout: u32 = 0,
    max_tessellation_control_points: u32 = 0,
    max_mesh_threads_per_threadgroup: u32 = 0,
    max_task_threads_per_threadgroup: u32 = 0,
    max_ray_tracing_recursion_depth: u32 = 0,
    shader_binding_table_alignment: u64 = 0,
    max_driver_cache_identity_bytes: u32 = 0,
    sparse_buffer_page_size: u64 = 0,
    sparse_texture_page_width: u32 = 0,
    sparse_texture_page_height: u32 = 0,
    sparse_texture_page_depth: u32 = 0,
    max_sparse_regions_per_commit: u32 = 0,
};

pub const FormatCapabilities = struct {
    sampled: bool = false,
    storage: bool = false,
    color_attachment: bool = false,
    depth_stencil_attachment: bool = false,
    filterable: bool = false,
    linear_filter: bool = false,
    mipmapped: bool = false,
    mipmap_generation: bool = false,
    blendable: bool = false,
    copy_source: bool = false,
    copy_destination: bool = false,

    pub fn supportsTextureUsage(self: FormatCapabilities, usage: TextureUsage) bool {
        return (!usage.shader_read or self.sampled) and
            (!usage.shader_write or self.storage) and
            (!usage.render_attachment or self.color_attachment or self.depth_stencil_attachment) and
            (!usage.copy_source or self.copy_source) and
            (!usage.copy_destination or self.copy_destination);
    }

    pub fn supportsTextureDescriptor(self: FormatCapabilities, descriptor: TextureDescriptor) bool {
        if (!self.supportsTextureUsage(descriptor.usage)) return false;
        if (descriptor.mip_level_count > 1 and !self.mipmapped) return false;
        return true;
    }
};

pub const DeviceCapabilitySource = enum {
    defaults,
    vulkan_query,
    metal_query,
};

pub const DeviceCapabilityReport = struct {
    backend: Backend,
    source: DeviceCapabilitySource = .defaults,
    features: DeviceFeatures,
    native_features: DeviceFeatures,
    limits: DeviceLimits,
};

pub const ResourceAccess = enum {
    read,
    write,
};

pub const ResourceUsageKind = enum {
    vertex_buffer,
    index_buffer,
    uniform_buffer,
    storage_buffer_read,
    storage_buffer_write,
    sampled_texture,
    indirect_buffer,
    storage_texture_read,
    storage_texture_write,
    render_attachment_read,
    render_attachment_write,
    copy_source,
    copy_destination,
    present,

    pub fn access(self: ResourceUsageKind) ResourceAccess {
        return switch (self) {
            .vertex_buffer,
            .index_buffer,
            .uniform_buffer,
            .storage_buffer_read,
            .sampled_texture,
            .indirect_buffer,
            .storage_texture_read,
            .render_attachment_read,
            .copy_source,
            .present,
            => .read,
            .storage_buffer_write,
            .storage_texture_write,
            .render_attachment_write,
            .copy_destination,
            => .write,
        };
    }
};

pub const ResourceHazard = enum {
    none,
    read_after_write,
    write_after_read,
    write_after_write,
};

pub const ResourceUsageTransition = struct {
    previous: ?ResourceUsageKind = null,
    next: ResourceUsageKind,
    hazard: ResourceHazard = .none,
    requires_barrier: bool = false,
};

pub const ResourceUsageState = struct {
    current: ?ResourceUsageKind = null,
    barrier_count: usize = 0,

    pub fn transitionTo(self: *ResourceUsageState, next: ResourceUsageKind) ResourceUsageTransition {
        const previous = self.current;
        const hazard = resourceHazard(previous, next);
        const requires_barrier = hazard != .none;
        if (requires_barrier) self.barrier_count += 1;
        self.current = next;
        return .{
            .previous = previous,
            .next = next,
            .hazard = hazard,
            .requires_barrier = requires_barrier,
        };
    }

    pub fn applyExplicitBarrier(
        self: *ResourceUsageState,
        before: ResourceUsageKind,
        after: ResourceUsageKind,
    ) CommandEncodingError!ResourceUsageTransition {
        if (before == after) return CommandEncodingError.RedundantResourceBarrier;
        if (self.current) |current| {
            if (current != before) return CommandEncodingError.InvalidResourceBarrierState;
        }
        self.current = after;
        self.barrier_count += 1;
        return .{
            .previous = before,
            .next = after,
            .hazard = resourceHazard(before, after),
            .requires_barrier = true,
        };
    }
};

pub const CommandBufferDescriptor = struct {
    label: ?[]const u8 = null,
    pooled: bool = false,
    reusable: bool = false,

    pub fn validate(self: CommandBufferDescriptor, features: DeviceFeatures) CommandEncodingError!void {
        if (self.pooled and !features.command_buffer_pooling) {
            return CommandEncodingError.UnsupportedCommandBufferPooling;
        }
        if (self.reusable and !features.command_buffer_reset) {
            return CommandEncodingError.UnsupportedCommandBufferReset;
        }
        if (self.reusable and !self.pooled) {
            return CommandEncodingError.UnsupportedCommandBufferReset;
        }
    }
};

pub const TransientResourceKind = enum {
    buffer,
    texture,
};

pub const TransientResourceDescriptor = struct {
    kind: TransientResourceKind,
    size: u64 = 0,
    texture_extent: Extent2D = .{ .width = 0, .height = 0 },
    alignment: u64 = 1,
    first_use: u64 = 0,
    last_use: u64 = 0,

    pub fn validate(self: TransientResourceDescriptor) error{InvalidResourceBarrierRange}!void {
        if (self.alignment == 0) return error.InvalidResourceBarrierRange;
        if (self.last_use < self.first_use) return error.InvalidResourceBarrierRange;
        switch (self.kind) {
            .buffer => if (self.size == 0) return error.InvalidResourceBarrierRange,
            .texture => if (self.texture_extent.isZero()) return error.InvalidResourceBarrierRange,
        }
    }

    pub fn canAlias(existing: TransientResourceDescriptor, requested: TransientResourceDescriptor) bool {
        existing.validate() catch return false;
        requested.validate() catch return false;
        if (existing.kind != requested.kind) return false;
        if (lifetimesOverlap(existing, requested)) return false;
        if (existing.alignment < requested.alignment) return false;
        return switch (existing.kind) {
            .buffer => existing.size >= requested.size,
            .texture => existing.texture_extent.width >= requested.texture_extent.width and
                existing.texture_extent.height >= requested.texture_extent.height,
        };
    }
};

pub const TransientAllocationDiagnostics = struct {
    resource_count: usize = 0,
    aliasable_pairs: usize = 0,
    requested_units: u64 = 0,

    pub fn analyze(resources: []const TransientResourceDescriptor) error{InvalidResourceBarrierRange}!TransientAllocationDiagnostics {
        var result = TransientAllocationDiagnostics{
            .resource_count = resources.len,
        };
        for (resources, 0..) |resource, i| {
            try resource.validate();
            result.requested_units = std.math.add(u64, result.requested_units, transientResourceUnits(resource)) catch {
                return error.InvalidResourceBarrierRange;
            };
            for (resources[i + 1 ..]) |other| {
                if (TransientResourceDescriptor.canAlias(resource, other)) {
                    result.aliasable_pairs += 1;
                }
            }
        }
        return result;
    }
};

fn transientResourceUnits(resource: TransientResourceDescriptor) u64 {
    return switch (resource.kind) {
        .buffer => resource.size,
        .texture => @as(u64, resource.texture_extent.width) * @as(u64, resource.texture_extent.height),
    };
}

fn lifetimesOverlap(a: TransientResourceDescriptor, b: TransientResourceDescriptor) bool {
    return a.first_use <= b.last_use and b.first_use <= a.last_use;
}

pub const BufferBarrierDescriptor = struct {
    before: ResourceUsageKind,
    after: ResourceUsageKind,
    offset: u64 = 0,
    size: ?u64 = null,

    pub fn validate(
        self: BufferBarrierDescriptor,
        buffer_length: usize,
        features: DeviceFeatures,
    ) CommandEncodingError!void {
        if (!features.explicit_resource_barriers) {
            return CommandEncodingError.UnsupportedExplicitResourceBarrier;
        }
        if (self.before == self.after) return CommandEncodingError.RedundantResourceBarrier;
        const size = self.size orelse std.math.sub(u64, buffer_length, self.offset) catch {
            return CommandEncodingError.InvalidResourceBarrierRange;
        };
        if (size == 0) return CommandEncodingError.InvalidResourceBarrierRange;
        const end = std.math.add(u64, self.offset, size) catch return CommandEncodingError.InvalidResourceBarrierRange;
        if (end > buffer_length) return CommandEncodingError.InvalidResourceBarrierRange;
    }
};

pub const TextureBarrierDescriptor = struct {
    before: ResourceUsageKind,
    after: ResourceUsageKind,
    base_mip_level: u32 = 0,
    mip_level_count: u32 = 1,
    base_array_layer: u32 = 0,
    array_layer_count: u32 = 1,

    pub fn validate(
        self: TextureBarrierDescriptor,
        texture: TextureDescriptor,
        features: DeviceFeatures,
    ) CommandEncodingError!void {
        if (!features.explicit_resource_barriers) {
            return CommandEncodingError.UnsupportedExplicitResourceBarrier;
        }
        if (self.before == self.after) return CommandEncodingError.RedundantResourceBarrier;
        texture.validate() catch return CommandEncodingError.InvalidResourceBarrierRange;
        if (self.mip_level_count == 0 or self.array_layer_count == 0) {
            return CommandEncodingError.InvalidResourceBarrierRange;
        }
        const mip_end = std.math.add(u32, self.base_mip_level, self.mip_level_count) catch {
            return CommandEncodingError.InvalidResourceBarrierRange;
        };
        if (mip_end > texture.mip_level_count) return CommandEncodingError.InvalidResourceBarrierRange;
        const layer_limit: u32 = switch (texture.dimension) {
            .three_d => 1,
            else => texture.depth_or_array_layers,
        };
        const layer_end = std.math.add(u32, self.base_array_layer, self.array_layer_count) catch {
            return CommandEncodingError.InvalidResourceBarrierRange;
        };
        if (layer_end > layer_limit) return CommandEncodingError.InvalidResourceBarrierRange;
    }
};

pub const FenceKind = enum {
    binary,
    timeline,
};

pub const FenceDescriptor = struct {
    label: ?[]const u8 = null,
    kind: FenceKind = .binary,
    initial_value: u64 = 0,

    pub fn validate(self: FenceDescriptor, features: DeviceFeatures) CommandEncodingError!void {
        if (!features.fences) return CommandEncodingError.UnsupportedFences;
        switch (self.kind) {
            .binary => if (self.initial_value > 1) return CommandEncodingError.InvalidFenceValue,
            .timeline => if (!features.timeline_fences) return CommandEncodingError.UnsupportedTimelineFences,
        }
    }
};

pub const FenceSignalDescriptor = struct {
    value: u64 = 1,

    pub fn validate(self: FenceSignalDescriptor, fence: FenceDescriptor) CommandEncodingError!void {
        switch (fence.kind) {
            .binary => if (self.value != 1) return CommandEncodingError.InvalidFenceValue,
            .timeline => if (self.value == 0) return CommandEncodingError.InvalidFenceValue,
        }
    }
};

pub const FenceWaitDescriptor = struct {
    value: u64 = 1,
    timeout_ns: ?u64 = null,

    pub fn validate(self: FenceWaitDescriptor, fence: FenceDescriptor) CommandEncodingError!void {
        switch (fence.kind) {
            .binary => if (self.value != 1) return CommandEncodingError.InvalidFenceValue,
            .timeline => if (self.value == 0) return CommandEncodingError.InvalidFenceValue,
        }
    }
};

pub const EventDescriptor = struct {
    label: ?[]const u8 = null,
    shared: bool = false,

    pub fn validate(self: EventDescriptor, features: DeviceFeatures) CommandEncodingError!void {
        if (!features.events) return CommandEncodingError.UnsupportedEvents;
        if (self.shared and !features.shared_events) return CommandEncodingError.UnsupportedSharedEvents;
    }
};

pub const EventSignalDescriptor = struct {
    signaled: bool = true,
};

pub const EventWaitDescriptor = struct {
    timeout_ns: ?u64 = null,
};

pub const QueueKind = enum {
    graphics,
    compute,
    transfer,
};

pub const QueueCapabilities = struct {
    graphics: bool = true,
    compute: bool = true,
    transfer: bool = true,
    present: bool = true,

    pub fn supports(self: QueueCapabilities, kind: QueueKind) bool {
        return switch (kind) {
            .graphics => self.graphics,
            .compute => self.compute,
            .transfer => self.transfer,
        };
    }
};

pub const QueueDescriptor = struct {
    label: ?[]const u8 = null,
    kind: QueueKind = .graphics,
    require_dedicated: bool = false,
    allow_fallback: bool = true,

    pub fn validate(
        self: QueueDescriptor,
        features: DeviceFeatures,
        capabilities: QueueCapabilities,
    ) CommandEncodingError!void {
        if (!capabilities.supports(self.kind)) return CommandEncodingError.InvalidQueueCapability;
        if (self.kind == .graphics) return;
        if (!features.multi_queue) {
            if (self.allow_fallback and !self.require_dedicated) return;
            return CommandEncodingError.UnsupportedMultiQueue;
        }
        if (!self.require_dedicated) return;
        switch (self.kind) {
            .graphics => {},
            .compute => if (!features.dedicated_compute_queue) return CommandEncodingError.UnsupportedDedicatedQueue,
            .transfer => if (!features.dedicated_transfer_queue) return CommandEncodingError.UnsupportedDedicatedQueue,
        }
    }
};

pub const TransferBatchDescriptor = struct {
    upload_bytes: u64 = 0,
    readback_bytes: u64 = 0,
    prefer_dedicated_transfer: bool = true,

    pub fn validate(self: TransferBatchDescriptor) CommandEncodingError!void {
        if (self.upload_bytes == 0 and self.readback_bytes == 0) return CommandEncodingError.InvalidCopySize;
    }
};

pub const TransferBatchPlan = struct {
    queue: QueueKind,
    upload_bytes: u64,
    readback_bytes: u64,

    pub fn fromDescriptor(descriptor: TransferBatchDescriptor, features: DeviceFeatures, capabilities: QueueCapabilities) CommandEncodingError!TransferBatchPlan {
        try descriptor.validate();
        const can_use_transfer = capabilities.transfer and features.multi_queue and
            (!descriptor.prefer_dedicated_transfer or features.dedicated_transfer_queue);
        return .{
            .queue = if (can_use_transfer) .transfer else .graphics,
            .upload_bytes = descriptor.upload_bytes,
            .readback_bytes = descriptor.readback_bytes,
        };
    }
};

pub const QueueOwnershipTransferDescriptor = struct {
    source: QueueKind,
    destination: QueueKind,
    before: ResourceUsageKind,
    after: ResourceUsageKind,

    pub fn validate(self: QueueOwnershipTransferDescriptor, features: DeviceFeatures) CommandEncodingError!void {
        if (!features.queue_ownership_transfer) return CommandEncodingError.UnsupportedQueueOwnershipTransfer;
        if (self.source == self.destination) return CommandEncodingError.RedundantQueueOwnershipTransfer;
        if (self.before == self.after) return CommandEncodingError.RedundantResourceBarrier;
    }
};

fn resourceHazard(previous: ?ResourceUsageKind, next: ResourceUsageKind) ResourceHazard {
    const prev = previous orelse return .none;
    const prev_access = prev.access();
    const next_access = next.access();

    return switch (prev_access) {
        .read => switch (next_access) {
            .read => .none,
            .write => .write_after_read,
        },
        .write => switch (next_access) {
            .read => .read_after_write,
            .write => .write_after_write,
        },
    };
}

pub const DebugGroupStack = struct {
    depth: u32 = 0,
    max_depth: u32 = 64,

    pub fn push(self: *DebugGroupStack, label: []const u8) CommandEncodingError!void {
        if (label.len == 0) return CommandEncodingError.EmptyDebugGroupLabel;
        if (self.depth >= self.max_depth) return CommandEncodingError.DebugGroupStackOverflow;
        self.depth += 1;
    }

    pub fn pop(self: *DebugGroupStack) CommandEncodingError!void {
        if (self.depth == 0) return CommandEncodingError.DebugGroupStackUnderflow;
        self.depth -= 1;
    }

    pub fn requireEmpty(self: DebugGroupStack) CommandEncodingError!void {
        if (self.depth != 0) return CommandEncodingError.UnclosedDebugGroup;
    }
};

pub const DebugSignpostDescriptor = struct {
    label: []const u8,

    pub fn validate(self: DebugSignpostDescriptor) CommandEncodingError!void {
        if (self.label.len == 0) return CommandEncodingError.EmptyDebugGroupLabel;
    }
};

pub const BackendAvailability = struct {
    vulkan: bool = true,
    metal: bool = builtin.os.tag.isDarwin(),
};

pub const BackendSelectionOptions = struct {
    preference: BackendPreference = .auto,
    adapter_selection: AdapterSelectionDescriptor = .{},
    os_tag: std.Target.Os.Tag = builtin.os.tag,
    availability: BackendAvailability = .{},
    debug_override: ?Backend = null,
};

pub const BackendSelectionError = error{
    VulkanUnavailable,
    MetalUnavailable,
    NoSupportedBackend,
    AdapterSelectionConflict,
    AdapterNotFound,
};

pub const ErrorCategory = enum {
    validation,
    unsupported_feature,
    backend,
    device_lost,
    surface_lost,
    resource_lifetime,
    shader_compilation,
    unknown,
};

pub const ObjectCacheError = error{
    EmptyObjectCacheSourceHash,
    EmptyObjectCacheOptionsHash,
    EmptyObjectCacheEntryPoint,
    EmptyObjectCacheKey,
    InvalidObjectCacheKey,
    MissingObjectCacheLayout,
};

pub const AdvancedFeatureError = error{
    UnsupportedDescriptorIndexing,
    UnsupportedArgumentBuffers,
    MissingDescriptorIndexingRange,
    EmptyDescriptorIndexingVisibility,
    InvalidDescriptorIndexingCount,
    DescriptorIndexingRangeCountExceeded,
    DuplicateDescriptorIndexingBinding,
    UnsupportedSparseBuffers,
    UnsupportedSparseTextures,
    UnsupportedTiledTextures,
    InvalidSparsePageSize,
    InvalidSparseRegion,
    SparseRegionCountExceeded,
    UnsupportedExternalMemory,
    UnsupportedExternalTextures,
    UnsupportedExternalSemaphores,
    UnsupportedNativeCommandInsertion,
    InvalidExternalHandle,
    ExternalHandleBackendMismatch,
    MissingNativeCommandCallback,
    NativeCommandEncoderMismatch,
    UnsupportedTessellation,
    InvalidPatchControlPointCount,
    MissingTessellationStage,
    UnsupportedMeshShaders,
    UnsupportedTaskShaders,
    MissingMeshStage,
    InvalidMeshThreadgroupSize,
    UnsupportedAccelerationStructures,
    UnsupportedRayTracing,
    InvalidAccelerationStructureDescriptor,
    InvalidRayTracingPipeline,
    InvalidShaderBindingTable,
    UnsupportedDriverPipelineCache,
    UnsupportedBinaryArchive,
    EmptyDriverCachePath,
    EmptyDriverCacheIdentity,
    DriverCacheBackendMismatch,
    DriverCacheIdentityTooLarge,
};

pub const ObjectCacheMode = enum {
    enabled,
    disabled,
    diagnostics_only,
};

pub const ObjectCachePolicy = struct {
    mode: ObjectCacheMode = .enabled,

    pub fn allowsReuse(self: ObjectCachePolicy) bool {
        return self.mode == .enabled;
    }

    pub fn recordsDiagnostics(self: ObjectCachePolicy) bool {
        return self.mode != .disabled;
    }
};

pub const ObjectCacheKind = enum {
    shader_module,
    bind_group_layout,
    pipeline_layout,
    render_pipeline,
    compute_pipeline,
    sampler,
};

pub const object_cache_kind_count: usize = 6;

pub const ObjectCacheStats = struct {
    hits: u64 = 0,
    misses: u64 = 0,
    creation_attempts: u64 = 0,
    equivalent_recreations: u64 = 0,
    reuse_bypassed_creations: u64 = 0,
    diagnostics_suppressed: u64 = 0,
    total_creation_time_ns: u64 = 0,

    pub fn recordHit(self: *ObjectCacheStats) void {
        self.hits += 1;
    }

    pub fn recordMiss(self: *ObjectCacheStats) void {
        self.misses += 1;
    }

    pub fn recordCreation(
        self: *ObjectCacheStats,
        equivalent: bool,
        policy: ObjectCachePolicy,
        creation_time_ns: u64,
    ) void {
        if (!policy.recordsDiagnostics()) {
            self.diagnostics_suppressed += 1;
            return;
        }
        self.recordMiss();
        self.creation_attempts += 1;
        self.total_creation_time_ns = self.total_creation_time_ns +| creation_time_ns;
        if (equivalent) self.equivalent_recreations += 1;
        if (!policy.allowsReuse()) self.reuse_bypassed_creations += 1;
    }
};

pub const ObjectCacheDiagnostics = struct {
    shader_modules: ObjectCacheStats = .{},
    bind_group_layouts: ObjectCacheStats = .{},
    pipeline_layouts: ObjectCacheStats = .{},
    render_pipelines: ObjectCacheStats = .{},
    compute_pipelines: ObjectCacheStats = .{},
    samplers: ObjectCacheStats = .{},

    pub fn stats(self: ObjectCacheDiagnostics, kind: ObjectCacheKind) ObjectCacheStats {
        return switch (kind) {
            .shader_module => self.shader_modules,
            .bind_group_layout => self.bind_group_layouts,
            .pipeline_layout => self.pipeline_layouts,
            .render_pipeline => self.render_pipelines,
            .compute_pipeline => self.compute_pipelines,
            .sampler => self.samplers,
        };
    }

    pub fn recordHit(self: *ObjectCacheDiagnostics, kind: ObjectCacheKind) void {
        self.statsPtr(kind).recordHit();
    }

    pub fn recordCreation(
        self: *ObjectCacheDiagnostics,
        kind: ObjectCacheKind,
        equivalent: bool,
        policy: ObjectCachePolicy,
        creation_time_ns: u64,
    ) void {
        self.statsPtr(kind).recordCreation(equivalent, policy, creation_time_ns);
    }

    pub fn totalCreationAttempts(self: ObjectCacheDiagnostics) u64 {
        return self.shader_modules.creation_attempts +
            self.bind_group_layouts.creation_attempts +
            self.pipeline_layouts.creation_attempts +
            self.render_pipelines.creation_attempts +
            self.compute_pipelines.creation_attempts +
            self.samplers.creation_attempts;
    }

    fn statsPtr(self: *ObjectCacheDiagnostics, kind: ObjectCacheKind) *ObjectCacheStats {
        return switch (kind) {
            .shader_module => &self.shader_modules,
            .bind_group_layout => &self.bind_group_layouts,
            .pipeline_layout => &self.pipeline_layouts,
            .render_pipeline => &self.render_pipelines,
            .compute_pipeline => &self.compute_pipelines,
            .sampler => &self.samplers,
        };
    }
};

pub const RuntimeDiagnosticsSnapshot = struct {
    live_resources: usize = 0,
    pending_retirements: usize = 0,
    submitted_work_serial: u64 = 0,
    completed_work_serial: u64 = 0,
    object_cache: ObjectCacheDiagnostics = .{},

    pub fn hasPendingGpuWork(self: RuntimeDiagnosticsSnapshot) bool {
        return self.completed_work_serial < self.submitted_work_serial;
    }

    pub fn hasLiveResources(self: RuntimeDiagnosticsSnapshot) bool {
        return self.live_resources != 0;
    }
};

pub const DriverCacheKind = enum {
    vulkan_pipeline_cache,
    metal_binary_archive,
};

pub const DriverCacheIdentityDescriptor = struct {
    backend: Backend,
    device_id: []const u8,
    driver_id: []const u8,
    shader_hash: []const u8,
    schema_version: []const u8,

    pub fn validate(self: DriverCacheIdentityDescriptor, limits: DeviceLimits) AdvancedFeatureError!void {
        if (self.device_id.len == 0 or self.driver_id.len == 0 or self.shader_hash.len == 0 or self.schema_version.len == 0) {
            return AdvancedFeatureError.EmptyDriverCacheIdentity;
        }
        const identity_size = self.device_id.len + self.driver_id.len + self.shader_hash.len + self.schema_version.len;
        if (limits.max_driver_cache_identity_bytes != 0 and identity_size > limits.max_driver_cache_identity_bytes) {
            return AdvancedFeatureError.DriverCacheIdentityTooLarge;
        }
    }
};

pub const DriverPipelineCacheDescriptor = struct {
    path: []const u8,
    kind: DriverCacheKind,
    identity: DriverCacheIdentityDescriptor,
    read_only: bool = false,

    pub fn validate(self: DriverPipelineCacheDescriptor, features: DeviceFeatures, limits: DeviceLimits) AdvancedFeatureError!void {
        if (self.path.len == 0) return AdvancedFeatureError.EmptyDriverCachePath;
        try self.identity.validate(limits);
        switch (self.kind) {
            .vulkan_pipeline_cache => {
                if (!features.driver_pipeline_cache) return AdvancedFeatureError.UnsupportedDriverPipelineCache;
                if (self.identity.backend != .vulkan) return AdvancedFeatureError.DriverCacheBackendMismatch;
            },
            .metal_binary_archive => {
                if (!features.metal_binary_archive) return AdvancedFeatureError.UnsupportedBinaryArchive;
                if (self.identity.backend != .metal) return AdvancedFeatureError.DriverCacheBackendMismatch;
            },
        }
    }
};

pub const DriverPipelineCachePlan = struct {
    path: []const u8,
    kind: DriverCacheKind,
    load_existing: bool,
    store_on_shutdown: bool,

    pub fn fromDescriptor(descriptor: DriverPipelineCacheDescriptor, cache_exists: bool, features: DeviceFeatures, limits: DeviceLimits) AdvancedFeatureError!DriverPipelineCachePlan {
        try descriptor.validate(features, limits);
        return .{
            .path = descriptor.path,
            .kind = descriptor.kind,
            .load_existing = cache_exists,
            .store_on_shutdown = !descriptor.read_only,
        };
    }
};

pub const runtime_cache_schema_version: u32 = 1;

pub const RuntimeCacheCompatibility = enum {
    compatible,
    missing,
    stale_schema,
    backend_mismatch,
    source_hash_mismatch,
    toolchain_mismatch,
};

pub const RuntimeCacheManifestDescriptor = struct {
    schema_version: u32 = runtime_cache_schema_version,
    backend: Backend,
    source_hash: []const u8,
    toolchain_id: []const u8,

    pub fn validate(self: RuntimeCacheManifestDescriptor) ObjectCacheError!void {
        if (self.source_hash.len == 0) return ObjectCacheError.EmptyObjectCacheSourceHash;
        if (self.toolchain_id.len == 0) return ObjectCacheError.EmptyObjectCacheOptionsHash;
    }

    pub fn compatibilityWith(
        self: RuntimeCacheManifestDescriptor,
        existing: ?RuntimeCacheManifestDescriptor,
    ) ObjectCacheError!RuntimeCacheCompatibility {
        try self.validate();
        const previous = existing orelse return .missing;
        try previous.validate();
        if (previous.schema_version != self.schema_version) return .stale_schema;
        if (previous.backend != self.backend) return .backend_mismatch;
        if (!std.mem.eql(u8, previous.source_hash, self.source_hash)) return .source_hash_mismatch;
        if (!std.mem.eql(u8, previous.toolchain_id, self.toolchain_id)) return .toolchain_mismatch;
        return .compatible;
    }
};

pub const RuntimeCachePlanDescriptor = struct {
    cache_dir: []const u8,
    entry_name: []const u8,
    manifest: RuntimeCacheManifestDescriptor,
    existing_manifest: ?RuntimeCacheManifestDescriptor = null,

    pub fn validate(self: RuntimeCachePlanDescriptor) ObjectCacheError!void {
        if (self.cache_dir.len == 0) return ObjectCacheError.EmptyObjectCacheKey;
        if (self.entry_name.len == 0) return ObjectCacheError.EmptyObjectCacheEntryPoint;
        try self.manifest.validate();
        if (self.existing_manifest) |existing| try existing.validate();
    }
};

pub const RuntimeCachePlan = struct {
    cache_dir: []const u8,
    entry_name: []const u8,
    manifest_path: []const u8,
    artifact_dir: []const u8,
    compatibility: RuntimeCacheCompatibility,
    should_rebuild: bool,
    should_write_manifest: bool,

    pub fn fromDescriptor(
        allocator: std.mem.Allocator,
        descriptor: RuntimeCachePlanDescriptor,
    ) (ObjectCacheError || std.mem.Allocator.Error)!RuntimeCachePlan {
        try descriptor.validate();
        const compatibility = try descriptor.manifest.compatibilityWith(descriptor.existing_manifest);
        const artifact_dir = try std.fs.path.join(allocator, &.{ descriptor.cache_dir, descriptor.entry_name });
        errdefer allocator.free(artifact_dir);
        const manifest_path = try std.fs.path.join(allocator, &.{ artifact_dir, "vkmtl-cache-manifest.json" });
        return .{
            .cache_dir = descriptor.cache_dir,
            .entry_name = descriptor.entry_name,
            .manifest_path = manifest_path,
            .artifact_dir = artifact_dir,
            .compatibility = compatibility,
            .should_rebuild = compatibility != .compatible,
            .should_write_manifest = compatibility != .compatible,
        };
    }

    pub fn deinit(self: RuntimeCachePlan, allocator: std.mem.Allocator) void {
        allocator.free(self.manifest_path);
        allocator.free(self.artifact_dir);
    }
};

pub const DebugLabelTarget = enum {
    resource,
    command_buffer,
    command_encoder,
    queue,
};

pub const DebugLabelDescriptor = struct {
    target: DebugLabelTarget,
    label: []const u8,

    pub fn validate(self: DebugLabelDescriptor) CommandEncodingError!void {
        _ = self.target;
        if (self.label.len == 0) return CommandEncodingError.EmptyDebugGroupLabel;
    }
};

pub const CaptureNameDescriptor = struct {
    scope: []const u8,
    name: []const u8,
    backend: ?Backend = null,
    frame_index: ?u64 = null,

    pub fn validate(self: CaptureNameDescriptor) CommandEncodingError!void {
        if (self.scope.len == 0 or self.name.len == 0) return CommandEncodingError.EmptyDebugGroupLabel;
    }

    pub fn formattedLength(self: CaptureNameDescriptor) CommandEncodingError!usize {
        try self.validate();
        var length = self.scope.len + 1 + self.name.len;
        if (self.backend != null) length += " backend=".len + "vulkan".len;
        if (self.frame_index != null) length += " frame=".len + 20;
        return length;
    }

    pub fn write(self: CaptureNameDescriptor, buffer: []u8) CommandEncodingError![]const u8 {
        const required = try self.formattedLength();
        if (buffer.len < required) return CommandEncodingError.CaptureNameTooLong;
        if (self.backend) |backend| {
            if (self.frame_index) |frame_index| {
                return std.fmt.bufPrint(buffer, "{s}:{s} backend={s} frame={}", .{ self.scope, self.name, @tagName(backend), frame_index }) catch return CommandEncodingError.CaptureNameTooLong;
            }
            return std.fmt.bufPrint(buffer, "{s}:{s} backend={s}", .{ self.scope, self.name, @tagName(backend) }) catch return CommandEncodingError.CaptureNameTooLong;
        }
        if (self.frame_index) |frame_index| {
            return std.fmt.bufPrint(buffer, "{s}:{s} frame={}", .{ self.scope, self.name, frame_index }) catch return CommandEncodingError.CaptureNameTooLong;
        }
        return std.fmt.bufPrint(buffer, "{s}:{s}", .{ self.scope, self.name }) catch return CommandEncodingError.CaptureNameTooLong;
    }
};

pub const StabilityRunError = error{
    InvalidDrawCount,
    InvalidStabilityRunInterval,
    InvalidStabilityResourceCount,
    InvalidCopySize,
};

pub const StabilityRunPlan = struct {
    iterations: u32,
    resize_events: u64,
    resources_created: u64,
    shader_cache_cycles: u64,
    upload_readback_cycles: u64,
    upload_bytes: u64,
    vulkan_unaligned_fill_fallback_checks: u64,
    max_live_resources: usize,

    pub fn expectsResize(self: StabilityRunPlan) bool {
        return self.resize_events != 0;
    }

    pub fn expectsUploadReadback(self: StabilityRunPlan) bool {
        return self.upload_readback_cycles != 0;
    }

    pub fn expectsVulkanFillFallbackChecks(self: StabilityRunPlan) bool {
        return self.vulkan_unaligned_fill_fallback_checks != 0;
    }
};

pub const StabilityRunDescriptor = struct {
    iterations: u32,
    resource_churn: bool = true,
    presentation_resize: bool = true,
    shader_cache_warm_cold: bool = true,
    upload_readback: bool = true,
    vulkan_unaligned_fill_fallback: bool = true,
    resize_interval: u32 = 60,
    shader_cache_interval: u32 = 30,
    upload_readback_interval: u32 = 1,
    resources_per_iteration: u32 = 4,
    upload_bytes_per_iteration: u64 = 4096,
    max_live_resources: usize = 256,

    pub fn validate(self: StabilityRunDescriptor) StabilityRunError!void {
        if (self.iterations == 0) return StabilityRunError.InvalidDrawCount;
        if (self.presentation_resize and self.resize_interval == 0) return StabilityRunError.InvalidStabilityRunInterval;
        if (self.shader_cache_warm_cold and self.shader_cache_interval == 0) return StabilityRunError.InvalidStabilityRunInterval;
        if (self.upload_readback and self.upload_readback_interval == 0) return StabilityRunError.InvalidStabilityRunInterval;
        if (self.resource_churn and (self.resources_per_iteration == 0 or self.max_live_resources == 0)) {
            return StabilityRunError.InvalidStabilityResourceCount;
        }
        if (self.upload_readback and self.upload_bytes_per_iteration == 0) return StabilityRunError.InvalidCopySize;
    }

    pub fn plan(self: StabilityRunDescriptor) StabilityRunError!StabilityRunPlan {
        try self.validate();
        const upload_cycles = stabilityScheduledCycles(self.upload_readback, self.iterations, self.upload_readback_interval);
        return .{
            .iterations = self.iterations,
            .resize_events = stabilityScheduledCycles(self.presentation_resize, self.iterations, self.resize_interval),
            .resources_created = if (self.resource_churn)
                @as(u64, self.iterations) * @as(u64, self.resources_per_iteration)
            else
                0,
            .shader_cache_cycles = stabilityScheduledCycles(self.shader_cache_warm_cold, self.iterations, self.shader_cache_interval),
            .upload_readback_cycles = upload_cycles,
            .upload_bytes = saturatingMulU64(upload_cycles, self.upload_bytes_per_iteration),
            .vulkan_unaligned_fill_fallback_checks = if (self.vulkan_unaligned_fill_fallback) upload_cycles else 0,
            .max_live_resources = if (self.resource_churn) self.max_live_resources else 0,
        };
    }
};

pub const StabilityRunDiagnostics = struct {
    iterations_completed: u32 = 0,
    resources_created: u64 = 0,
    resize_events: u64 = 0,
    cache_cycles: u64 = 0,
    upload_readback_cycles: u64 = 0,
    upload_bytes: u64 = 0,
    vulkan_unaligned_fill_fallback_checks: u64 = 0,
    max_live_resources: usize = 0,
    leak_reports: u64 = 0,
    pending_retirement_warnings: u64 = 0,
    backend_errors: u64 = 0,

    pub fn fromPlan(plan: StabilityRunPlan) StabilityRunDiagnostics {
        return .{
            .iterations_completed = plan.iterations,
            .resources_created = plan.resources_created,
            .resize_events = plan.resize_events,
            .cache_cycles = plan.shader_cache_cycles,
            .upload_readback_cycles = plan.upload_readback_cycles,
            .upload_bytes = plan.upload_bytes,
            .vulkan_unaligned_fill_fallback_checks = plan.vulkan_unaligned_fill_fallback_checks,
            .max_live_resources = plan.max_live_resources,
        };
    }

    pub fn recordRuntimeSnapshot(self: *StabilityRunDiagnostics, snapshot: RuntimeDiagnosticsSnapshot) void {
        self.max_live_resources = @max(self.max_live_resources, snapshot.live_resources);
        if (snapshot.pending_retirements != 0) self.pending_retirement_warnings += 1;
    }

    pub fn hasFailures(self: StabilityRunDiagnostics) bool {
        return self.leak_reports != 0 or self.backend_errors != 0;
    }
};

fn stabilityScheduledCycles(enabled: bool, iterations: u32, interval: u32) u64 {
    if (!enabled) return 0;
    return (@as(u64, iterations) + @as(u64, interval) - 1) / @as(u64, interval);
}

fn saturatingMulU64(a: u64, b: u64) u64 {
    return std.math.mul(u64, a, b) catch std.math.maxInt(u64);
}

pub const VulkanNativeHandles = struct {
    instance: usize,
    physical_device: usize,
    device: usize,
    surface: u64,
    graphics_queue: usize,
    present_queue: usize,
};

pub const MetalNativeHandles = struct {
    device: *anyopaque,
    command_queue: *anyopaque,
    layer: *anyopaque,
    view: *anyopaque,
};

pub const NativeHandles = union(Backend) {
    vulkan: VulkanNativeHandles,
    metal: MetalNativeHandles,
};

pub const NativeHandleLifetime = enum {
    borrowed,
};

pub const NativeHandleView = struct {
    handles: NativeHandles,
    lifetime: NativeHandleLifetime = .borrowed,
    mutable: bool = false,

    pub fn backend(self: NativeHandleView) Backend {
        return std.meta.activeTag(self.handles);
    }

    pub fn isBorrowed(self: NativeHandleView) bool {
        return self.lifetime == .borrowed;
    }

    pub fn allowsMutation(self: NativeHandleView) bool {
        return self.mutable;
    }
};

pub fn nativeHandleView(handles: NativeHandles) NativeHandleView {
    return .{ .handles = handles };
}

pub const NativeCommandEncoderKind = enum {
    render,
    compute,
    blit,
};

pub const NativeCommandInsertionPoint = enum {
    before_portable_commands,
    after_portable_commands,
    inline_boundary,
};

pub const NativeCommandCallback = *const fn (context: ?*anyopaque, handles: NativeHandleView) void;

pub const NativeCommandInsertionDescriptor = struct {
    label: ?[]const u8 = null,
    encoder: NativeCommandEncoderKind,
    point: NativeCommandInsertionPoint = .inline_boundary,
    callback: ?NativeCommandCallback = null,
    context: ?*anyopaque = null,
    inserts_resource_boundary: bool = true,

    pub fn validate(self: NativeCommandInsertionDescriptor, features: DeviceFeatures) AdvancedFeatureError!void {
        if (!features.native_command_insertion) return AdvancedFeatureError.UnsupportedNativeCommandInsertion;
        if (self.callback == null) return AdvancedFeatureError.MissingNativeCommandCallback;
    }

    pub fn validateForEncoder(
        self: NativeCommandInsertionDescriptor,
        encoder_kind: NativeCommandEncoderKind,
        features: DeviceFeatures,
    ) AdvancedFeatureError!void {
        try self.validate(features);
        if (self.encoder != encoder_kind) return AdvancedFeatureError.NativeCommandEncoderMismatch;
    }
};

pub fn classifyError(err: anyerror) ErrorCategory {
    return switch (err) {
        error.DeviceLost => .device_lost,
        error.SurfaceLost,
        error.SwapchainCreationFailed,
        error.InvalidSurfaceDimensions,
        error.NoDrawable,
        => .surface_lost,

        error.VulkanUnavailable,
        error.MetalUnavailable,
        error.NoSuitableDevice,
        error.AdapterNotFound,
        error.MissingVulkanSurfaceExtensions,
        error.BackendMismatch,
        error.CommandFailed,
        error.UnexpectedMetalStatus,
        error.MetalUnsupported,
        error.NoMetalDevice,
        error.FenceWaitTimeout,
        error.EventWaitTimeout,
        => .backend,

        error.NoSupportedBackend,
        error.UnsupportedSurfaceProvider,
        error.UnsupportedBackendForPresentation,
        error.UnsupportedSampleCount,
        error.UnsupportedTextureUploadFormat,
        error.UnsupportedTextureCopyFormat,
        error.UnsupportedTextureViewDimension,
        error.UnsupportedTextureViewFormat,
        error.UnsupportedMipmapGeneration,
        error.UnsupportedStorageTextureFormat,
        error.UnsupportedCompareSampler,
        error.UnsupportedSamplerAnisotropy,
        error.UnsupportedSamplerBorderColor,
        error.UnsupportedHeaps,
        error.UnsupportedSmallConstants,
        error.UnsupportedRootConstants,
        error.UnsupportedShaderSpecialization,
        error.UnsupportedMultipleRenderTargets,
        error.UnsupportedStencilAttachment,
        error.UnsupportedTransientAttachment,
        error.UnsupportedFillMode,
        error.UnsupportedDepthBias,
        error.UnsupportedConservativeRasterization,
        error.UnsupportedDynamicRenderState,
        error.UnsupportedBlendState,
        error.UnsupportedIndependentBlend,
        error.UnsupportedBlendFormat,
        error.UnsupportedStencilState,
        error.UnsupportedInstanceStepRate,
        error.UnsupportedBaseVertex,
        error.UnsupportedBaseInstance,
        error.UnsupportedIndirectDraw,
        error.UnsupportedMultiDraw,
        error.UnsupportedOcclusionQueries,
        error.UnsupportedTimestampQueries,
        error.UnsupportedPipelineStatisticsQueries,
        error.UnsupportedShaderReflectionSchema,
        error.UnsupportedCommandBufferPooling,
        error.UnsupportedCommandBufferReset,
        error.UnsupportedTextureToTextureCopy,
        error.UnsupportedFillBuffer,
        error.UnsupportedExplicitResourceBarrier,
        error.UnsupportedFences,
        error.UnsupportedEvents,
        error.UnsupportedTimelineFences,
        error.UnsupportedSharedEvents,
        error.UnsupportedMultiQueue,
        error.UnsupportedDedicatedQueue,
        error.UnsupportedQueueOwnershipTransfer,
        error.UnsupportedDispatchIndirect,
        error.UnsupportedComputeAtomics,
        error.UnsupportedThreadgroupMemory,
        error.UnsupportedDescriptorIndexing,
        error.UnsupportedArgumentBuffers,
        error.UnsupportedSparseBuffers,
        error.UnsupportedSparseTextures,
        error.UnsupportedTiledTextures,
        error.UnsupportedExternalMemory,
        error.UnsupportedExternalTextures,
        error.UnsupportedExternalSemaphores,
        error.UnsupportedNativeCommandInsertion,
        error.UnsupportedTessellation,
        error.UnsupportedMeshShaders,
        error.UnsupportedTaskShaders,
        error.UnsupportedAccelerationStructures,
        error.UnsupportedRayTracing,
        error.UnsupportedDriverPipelineCache,
        error.UnsupportedBinaryArchive,
        => .unsupported_feature,

        error.EmptyShaderSource,
        error.EmptyShaderArtifactPath,
        error.EmptyShaderReflectionPath,
        error.EmptyShaderEntryPoint,
        error.UnexpectedShaderStage,
        error.InvalidShaderReflection,
        error.ShaderReflectionStageMismatch,
        error.ShaderReflectionEntryPointMismatch,
        error.ShaderReflectionMissingBindGroupLayout,
        error.ShaderReflectionMissingBinding,
        error.ShaderReflectionBindingKindMismatch,
        error.ShaderReflectionBindingArrayCountMismatch,
        error.ShaderReflectionVisibilityMismatch,
        error.InvalidVertexStride,
        error.InvalidVertexAttributeOffset,
        error.DuplicateVertexBufferIndex,
        error.DuplicateVertexAttributeLocation,
        error.InvalidInstanceStepRate,
        error.InvalidDepthBias,
        error.InvalidStencilMask,
        error.InvalidColorAttachmentFormat,
        error.MissingColorAttachment,
        error.InvalidDepthStencilFormat,
        error.InvalidCommandBufferState,
        error.InvalidRenderCommandEncoderState,
        error.InvalidBlitCommandEncoderState,
        error.InvalidComputeCommandEncoderState,
        error.MissingRenderPipelineState,
        error.MissingComputePipelineState,
        error.MissingIndexBuffer,
        error.InvalidVertexBufferIndex,
        error.InvalidBindGroupIndex,
        error.InvalidViewport,
        error.InvalidScissorRect,
        error.InvalidBlendColor,
        error.InvalidStencilReference,
        error.EmptyDebugGroupLabel,
        error.CaptureNameTooLong,
        error.DebugGroupStackOverflow,
        error.DebugGroupStackUnderflow,
        error.UnclosedDebugGroup,
        error.InvalidVertexCount,
        error.InvalidIndexCount,
        error.InvalidInstanceCount,
        error.InvalidDrawCount,
        error.InvalidIndexBufferOffset,
        error.InvalidIndirectDrawStride,
        error.InvalidQueryCount,
        error.InvalidQueryRange,
        error.InvalidQueryResultAlignment,
        error.QueryTypeMismatch,
        error.QueryNotReady,
        error.MissingPipelineStatistics,
        error.InvalidStencilClearValue,
        error.InvalidThreadgroupCount,
        error.InvalidCopySize,
        error.InvalidCopyBufferRange,
        error.InvalidCopyTextureRegion,
        error.InvalidCopyTextureSlice,
        error.InvalidCopyBufferLayout,
        error.RedundantResourceBarrier,
        error.RedundantQueueOwnershipTransfer,
        error.InvalidResourceBarrierState,
        error.InvalidResourceBarrierRange,
        error.InvalidQueueCapability,
        error.InvalidQueueOwnershipState,
        error.InvalidFenceValue,
        error.InvalidEventState,
        error.InvalidDispatchIndirectOffset,
        error.InvalidIndirectBufferUsage,
        error.InvalidAtomicStorageResource,
        error.MissingAtomicOperation,
        error.InvalidThreadgroupMemorySize,
        error.InvalidThreadgroupMemoryAlignment,
        error.TextureCopySizeOverflow,
        error.MissingBindGroupLayoutEntry,
        error.EmptyShaderVisibility,
        error.DuplicateBinding,
        error.MissingBindGroupEntry,
        error.ExtraBindGroupEntry,
        error.BindingResourceKindMismatch,
        error.InvalidBufferBindingRange,
        error.InvalidStorageTextureVisibility,
        error.InvalidStorageAccess,
        error.InvalidBindingArrayCount,
        error.InvalidBindGroupResourceCount,
        error.InvalidDynamicBindingResource,
        error.UnsupportedResourceArray,
        error.UnsupportedDynamicBinding,
        error.UnsupportedStaticSampler,
        error.MissingDynamicOffset,
        error.ExtraDynamicOffset,
        error.InvalidDynamicOffsetAlignment,
        error.InvalidDynamicOffsetRange,
        error.InvalidResourceTableSlot,
        error.MissingResourceTableBinding,
        error.ResourceTablePartiallyBoundUnsupported,
        error.ResourceTableUpdateAfterBindUnsupported,
        error.InvalidResourceTableResource,
        error.ResourceTableVisibilityMismatch,
        error.EmptySmallConstantVisibility,
        error.EmptySmallConstantData,
        error.SmallConstantDataTooLarge,
        error.InvalidSmallConstantAlignment,
        error.MissingRootConstantRange,
        error.EmptyRootConstantVisibility,
        error.InvalidRootConstantRange,
        error.RootConstantRangeTooLarge,
        error.InvalidRootConstantAlignment,
        error.EmptyRootConstantWrite,
        error.RootConstantWriteOutOfRange,
        error.RootConstantVisibilityMismatch,
        error.MissingSurfaceSource,
        error.InvalidSurfaceExtent,
        error.InvalidSurfaceHandle,
        error.InvalidSurfaceFrameState,
        error.InvalidBufferLength,
        error.InitialDataTooLarge,
        error.InitialDataRequiresCpuVisibleStorage,
        error.InvalidBufferWriteRange,
        error.InvalidBufferReadRange,
        error.InvalidBufferMapRange,
        error.InvalidBufferMapMode,
        error.BufferNotCpuVisible,
        error.InvalidTextureFormat,
        error.InvalidTextureExtent,
        error.InvalidTextureViewRange,
        error.InvalidTextureRegion,
        error.InvalidBytesPerRow,
        error.InvalidBytesPerImage,
        error.UploadBytesTooSmall,
        error.TextureUploadSizeOverflow,
        error.InvalidLodRange,
        error.InvalidMaxAnisotropy,
        error.InvalidHeapSize,
        error.EmptyShaderLibraryName,
        error.EmptyShaderLibraryEntryName,
        error.EmptyShaderIncludePath,
        error.EmptyShaderSourceHash,
        error.EmptyShaderSpecializationName,
        error.MissingShaderLibraryEntry,
        error.DuplicateShaderLibraryEntry,
        error.DuplicateShaderSpecializationConstant,
        error.InvalidRenderPassAttachment,
        error.InvalidStorageBufferUsage,
        error.InvalidStorageTextureUsage,
        error.PresentRequiresCurrentDrawable,
        error.AdapterSelectionConflict,
        error.InvalidSurface,
        error.InvalidBuffer,
        error.InvalidTexture,
        error.InvalidTextureView,
        error.InvalidSampler,
        error.InvalidShader,
        error.InvalidPipeline,
        error.InvalidCommand,
        error.MissingShaderCacheDirValue,
        error.EmptyObjectCacheSourceHash,
        error.EmptyObjectCacheOptionsHash,
        error.EmptyObjectCacheEntryPoint,
        error.EmptyObjectCacheKey,
        error.InvalidObjectCacheKey,
        error.MissingObjectCacheLayout,
        error.MissingDescriptorIndexingRange,
        error.EmptyDescriptorIndexingVisibility,
        error.InvalidDescriptorIndexingCount,
        error.DescriptorIndexingRangeCountExceeded,
        error.DuplicateDescriptorIndexingBinding,
        error.InvalidSparsePageSize,
        error.InvalidSparseRegion,
        error.SparseRegionCountExceeded,
        error.InvalidExternalHandle,
        error.ExternalHandleBackendMismatch,
        error.MissingNativeCommandCallback,
        error.NativeCommandEncoderMismatch,
        error.InvalidPatchControlPointCount,
        error.MissingTessellationStage,
        error.MissingMeshStage,
        error.InvalidMeshThreadgroupSize,
        error.InvalidAccelerationStructureDescriptor,
        error.InvalidRayTracingPipeline,
        error.InvalidShaderBindingTable,
        error.EmptyDriverCachePath,
        error.EmptyDriverCacheIdentity,
        error.DriverCacheBackendMismatch,
        error.DriverCacheIdentityTooLarge,
        error.InvalidStabilityRunInterval,
        error.InvalidStabilityResourceCount,
        => .validation,

        error.SlangCompilationFailed,
        error.SlangReflectionFailed,
        error.InvalidSlangArtifact,
        => .shader_compilation,

        error.UseAfterFree => .resource_lifetime,
        else => .unknown,
    };
}

pub const ContextOptions = struct {
    backend: BackendPreference = .auto,
    adapter_selection: AdapterSelectionDescriptor = .{},
    availability: BackendAvailability = .{},
    debug_backend_override: ?Backend = null,
};

pub const Context = struct {
    backend: Backend,

    pub fn init(options: ContextOptions) BackendSelectionError!Context {
        const backend = try selectBackend(.{
            .preference = options.backend,
            .adapter_selection = options.adapter_selection,
            .availability = options.availability,
            .debug_override = options.debug_backend_override,
        });
        return .{ .backend = backend };
    }

    pub fn deinit(self: *Context) void {
        _ = self;
    }

    pub fn selectedBackend(self: Context) Backend {
        return self.backend;
    }

    pub fn createSurface(self: Context, descriptor: SurfaceDescriptor) SurfaceError!Surface {
        if (descriptor.source == null) return SurfaceError.MissingSurfaceSource;
        return .{
            .backend = self.backend,
            .descriptor = descriptor,
        };
    }
};

pub const Adapter = opaqueBackendHandle("Adapter");
pub const Device = opaqueBackendHandle("Device");
pub const Queue = opaqueBackendHandle("Queue");
pub const ShaderModule = opaqueBackendHandle("ShaderModule");
pub const RenderPipelineState = opaqueBackendHandle("RenderPipelineState");
pub const BindGroupLayout = opaqueBackendHandle("BindGroupLayout");
pub const BindGroup = opaqueBackendHandle("BindGroup");

pub const Extent2D = struct {
    width: u32,
    height: u32,

    pub fn isZero(self: Extent2D) bool {
        return self.width == 0 or self.height == 0;
    }
};

pub const SurfaceProvider = enum {
    external,
    metal_layer,
    app_kit_view,
    xlib_window,
    wayland_surface,
    win32_hwnd,
};

pub const VulkanSurfaceProvider = struct {
    context: *anyopaque,
    get_instance_proc_addr: *const fn (
        context: *anyopaque,
        instance: usize,
        procname: [*:0]const u8,
    ) callconv(.c) ?*const anyopaque,
    get_required_instance_extensions: *const fn (
        context: *anyopaque,
        count: *u32,
    ) callconv(.c) ?[*]const [*:0]const u8,
    create_surface: *const fn (
        context: *anyopaque,
        instance: usize,
        allocation_callbacks: ?*const anyopaque,
        surface: *usize,
    ) callconv(.c) i32,
};

pub const SurfaceSource = struct {
    provider: SurfaceProvider,
    window: *anyopaque,
    display: ?*anyopaque = null,
    vulkan: ?VulkanSurfaceProvider = null,
};

pub const SurfaceDescriptor = struct {
    label: ?[]const u8 = null,
    source: ?SurfaceSource = null,
};

pub const TextureFormat = enum {
    automatic,
    bgra8_unorm,
    bgra8_unorm_srgb,
    rgba8_unorm,
    rgba8_unorm_srgb,
    depth32_float,
    depth32_float_stencil8,
};

pub const TextureFormatKind = enum {
    invalid,
    color,
    depth,
    stencil,
    depth_stencil,
    compressed,
};

pub fn defaultAdapterInfo(backend: Backend) AdapterInfo {
    return .{
        .backend = backend,
        .name = switch (backend) {
            .vulkan => "Default Vulkan adapter",
            .metal => "Default Metal adapter",
        },
    };
}

pub fn enumerateAdapters(
    allocator: std.mem.Allocator,
    options: BackendSelectionOptions,
) (std.mem.Allocator.Error || BackendSelectionError)!AdapterList {
    var backends: [2]Backend = undefined;
    var backend_count: usize = 0;

    if (options.adapter_selection.backend) |adapter_backend| {
        try ensureBackendPreferenceAllowsAdapter(options.preference, adapter_backend);
        backends[0] = try requireBackend(adapter_backend, options.availability);
        backend_count = 1;
    } else {
        switch (options.preference) {
            .vulkan => {
                backends[0] = try requireBackend(.vulkan, options.availability);
                backend_count = 1;
            },
            .metal => {
                backends[0] = try requireBackend(.metal, options.availability);
                backend_count = 1;
            },
            .auto => {
                if (options.debug_override) |override| {
                    backends[0] = try requireBackend(override, options.availability);
                    backend_count = 1;
                } else {
                    const first: Backend = if (options.os_tag.isDarwin()) .metal else .vulkan;
                    const second: Backend = if (first == .metal) .vulkan else .metal;
                    if (isAvailable(first, options.availability)) {
                        backends[backend_count] = first;
                        backend_count += 1;
                    }
                    if (isAvailable(second, options.availability)) {
                        backends[backend_count] = second;
                        backend_count += 1;
                    }
                    if (backend_count == 0) return BackendSelectionError.NoSupportedBackend;
                }
            },
        }
    }

    const adapters = try allocator.alloc(AdapterInfo, backend_count);
    for (backends[0..backend_count], adapters) |backend, *adapter| {
        adapter.* = defaultAdapterInfo(backend);
    }

    return .{
        .allocator = allocator,
        .adapters = adapters,
    };
}

pub fn defaultDeviceFeatures(backend: Backend) DeviceFeatures {
    var result = DeviceFeatures{
        .native_handles = true,
        .debug_labels = true,
        .sampler_compare = true,
        .sampler_anisotropy = true,
        .sampler_border_color = true,
        .depth_bias = true,
        .blend_state = true,
        .stencil_state = true,
        .draw_base_vertex = true,
        .draw_base_instance = true,
        .indirect_draw = true,
        .compute_dispatch_indirect = true,
        .explicit_resource_barriers = true,
        .fences = true,
        .events = true,
        .occlusion_queries = true,
        .timestamp_queries = true,
    };

    if (backend == .metal) {
        result.wireframe_fill_mode = true;
        result.independent_blend = true;
        result.vertex_instance_step_rate = true;
    }

    return result;
}

pub fn defaultDeviceLimits(_: Backend) DeviceLimits {
    return .{};
}

pub fn defaultDeviceCapabilityReport(backend: Backend) DeviceCapabilityReport {
    const features = defaultDeviceFeatures(backend);
    return .{
        .backend = backend,
        .features = features,
        .native_features = features,
        .limits = defaultDeviceLimits(backend),
    };
}

pub fn defaultFormatCapabilities(format: TextureFormat) FormatCapabilities {
    return switch (format) {
        .automatic => .{},
        .bgra8_unorm,
        .bgra8_unorm_srgb,
        .rgba8_unorm_srgb,
        => .{
            .sampled = true,
            .color_attachment = true,
            .filterable = true,
            .linear_filter = true,
            .mipmapped = true,
            .mipmap_generation = true,
            .blendable = true,
            .copy_source = true,
            .copy_destination = true,
        },
        .rgba8_unorm => .{
            .sampled = true,
            .storage = true,
            .color_attachment = true,
            .filterable = true,
            .linear_filter = true,
            .mipmapped = true,
            .mipmap_generation = true,
            .blendable = true,
            .copy_source = true,
            .copy_destination = true,
        },
        .depth32_float => .{
            .depth_stencil_attachment = true,
            .mipmapped = true,
            .copy_source = true,
            .copy_destination = true,
        },
        .depth32_float_stencil8 => .{
            .depth_stencil_attachment = true,
            .copy_source = true,
            .copy_destination = true,
        },
    };
}

pub const ShaderSourceLanguage = enum {
    slang,
    spirv,
    msl,
};

pub const shader_reflection_schema_version: u32 = 1;

pub const ShaderArtifact = struct {
    path: []const u8,
    language: ShaderSourceLanguage,
};

pub const ShaderSource = union(enum) {
    slang: []const u8,
    spirv: []const u32,
    msl: []const u8,
    artifact: ShaderArtifact,
};

pub const ShaderModuleDescriptor = struct {
    label: ?[]const u8 = null,
    source: ShaderSource,
    cache_policy: ObjectCachePolicy = .{},

    pub fn validate(self: ShaderModuleDescriptor) ShaderError!void {
        switch (self.source) {
            .slang => |source| if (source.len == 0) return ShaderError.EmptyShaderSource,
            .spirv => |words| if (words.len == 0) return ShaderError.EmptyShaderSource,
            .msl => |source| if (source.len == 0) return ShaderError.EmptyShaderSource,
            .artifact => |artifact| if (artifact.path.len == 0) return ShaderError.EmptyShaderArtifactPath,
        }
    }
};

pub const ShaderStage = enum {
    vertex,
    fragment,
    compute,
    tessellation_control,
    tessellation_evaluation,
    mesh,
    task,

    pub fn isAdvancedGeometry(self: ShaderStage) bool {
        return switch (self) {
            .tessellation_control,
            .tessellation_evaluation,
            .mesh,
            .task,
            => true,
            else => false,
        };
    }
};

pub const ShaderCompileProfile = enum {
    debug,
    release,
};

pub const ShaderLibraryEntryDescriptor = struct {
    name: []const u8,
    stage: ShaderStage,
    entry_point: []const u8 = "main",

    pub fn validate(self: ShaderLibraryEntryDescriptor) ShaderError!void {
        if (self.name.len == 0) return ShaderError.EmptyShaderLibraryEntryName;
        if (self.entry_point.len == 0) return ShaderError.EmptyShaderEntryPoint;
    }
};

pub const ShaderLibraryDescriptor = struct {
    label: ?[]const u8 = null,
    name: []const u8,
    source: ShaderSource,
    entries: []const ShaderLibraryEntryDescriptor = &.{},
    include_paths: []const []const u8 = &.{},
    profile: ShaderCompileProfile = .debug,

    pub fn validate(self: ShaderLibraryDescriptor) ShaderError!void {
        try (ShaderModuleDescriptor{
            .label = self.label,
            .source = self.source,
        }).validate();
        if (self.name.len == 0) return ShaderError.EmptyShaderLibraryName;
        if (self.entries.len == 0) return ShaderError.MissingShaderLibraryEntry;
        for (self.entries, 0..) |entry, i| {
            try entry.validate();
            for (self.entries[i + 1 ..]) |other| {
                if (std.mem.eql(u8, entry.name, other.name)) return ShaderError.DuplicateShaderLibraryEntry;
                if (entry.stage == other.stage and std.mem.eql(u8, entry.entry_point, other.entry_point)) {
                    return ShaderError.DuplicateShaderLibraryEntry;
                }
            }
        }
        for (self.include_paths) |path| {
            if (path.len == 0) return ShaderError.EmptyShaderIncludePath;
        }
    }
};

pub const ShaderLibraryCacheKeyDescriptor = struct {
    library_name: []const u8,
    source_hash: []const u8,
    profile: ShaderCompileProfile = .debug,
    backend: Backend,
    specialization: ShaderSpecializationDescriptor = .{},

    pub fn validate(self: ShaderLibraryCacheKeyDescriptor) ShaderError!void {
        if (self.library_name.len == 0) return ShaderError.EmptyShaderLibraryName;
        if (self.source_hash.len == 0) return ShaderError.EmptyShaderSourceHash;
        try self.specialization.validateShape();
    }
};

pub const ShaderModuleCacheKeyDescriptor = struct {
    source_hash: []const u8,
    compile_options_hash: []const u8,
    entry_point: []const u8 = "main",
    backend: Backend,
    stage: ShaderStage,
    profile: ShaderCompileProfile = .debug,

    pub fn validate(self: ShaderModuleCacheKeyDescriptor) ObjectCacheError!void {
        if (self.source_hash.len == 0) return ObjectCacheError.EmptyObjectCacheSourceHash;
        if (self.compile_options_hash.len == 0) return ObjectCacheError.EmptyObjectCacheOptionsHash;
        if (self.entry_point.len == 0) return ObjectCacheError.EmptyObjectCacheEntryPoint;
    }
};

pub const ShaderSpecializationValueKind = enum {
    bool,
    i32,
    u32,
    f32,
};

pub const ShaderSpecializationValue = union(ShaderSpecializationValueKind) {
    bool: bool,
    i32: i32,
    u32: u32,
    f32: f32,

    pub fn kind(self: ShaderSpecializationValue) ShaderSpecializationValueKind {
        return switch (self) {
            .bool => .bool,
            .i32 => .i32,
            .u32 => .u32,
            .f32 => .f32,
        };
    }
};

pub const ShaderSpecializationConstant = struct {
    id: u32,
    name: ?[]const u8 = null,
    value: ShaderSpecializationValue,

    pub fn validate(self: ShaderSpecializationConstant) ShaderError!void {
        if (self.name) |name| {
            if (name.len == 0) return ShaderError.EmptyShaderSpecializationName;
        }
    }
};

pub const ShaderSpecializationDescriptor = struct {
    constants: []const ShaderSpecializationConstant = &.{},

    pub fn validateShape(self: ShaderSpecializationDescriptor) ShaderError!void {
        for (self.constants, 0..) |constant, i| {
            try constant.validate();
            for (self.constants[i + 1 ..]) |other| {
                if (constant.id == other.id) return ShaderError.DuplicateShaderSpecializationConstant;
                if (constant.name != null and other.name != null and std.mem.eql(u8, constant.name.?, other.name.?)) {
                    return ShaderError.DuplicateShaderSpecializationConstant;
                }
            }
        }
    }

    pub fn validate(self: ShaderSpecializationDescriptor, features: DeviceFeatures) ShaderError!void {
        if (self.constants.len != 0 and !features.shader_specialization) {
            return ShaderError.UnsupportedShaderSpecialization;
        }
        try self.validateShape();
    }

    pub fn constantForId(self: ShaderSpecializationDescriptor, id: u32) ?ShaderSpecializationConstant {
        for (self.constants) |constant| {
            if (constant.id == id) return constant;
        }
        return null;
    }
};

pub const ShaderReflectionArtifact = struct {
    path: []const u8,
};

pub const ShaderReflectionBinding = struct {
    binding: u32,
    resource: BindingResourceKind,
    visibility: ShaderVisibility,
    array_count: u32 = 1,
    bindless: bool = false,
    partially_bound: bool = false,
    update_after_bind: bool = false,
};

pub const ShaderReflectionBindGroup = struct {
    index: u32,
    bindings: []const ShaderReflectionBinding = &.{},
};

pub const ShaderReflectionVertexInput = struct {
    location: u32,
    format: VertexFormat,
    offset: u32 = 0,
};

pub const ShaderStageReflection = struct {
    schema_version: u32 = shader_reflection_schema_version,
    stage: ShaderStage,
    entry_point: []const u8,
    vertex_inputs: []const ShaderReflectionVertexInput = &.{},
    bind_groups: []const ShaderReflectionBindGroup = &.{},
};

pub const ShaderReflectionSource = union(enum) {
    data: ShaderStageReflection,
    artifact: ShaderReflectionArtifact,

    pub fn validate(self: ShaderReflectionSource) ShaderError!void {
        switch (self) {
            .data => |reflection| try validateShaderStageReflectionShape(reflection),
            .artifact => |artifact| if (artifact.path.len == 0) return ShaderError.EmptyShaderReflectionPath,
        }
    }
};

pub const ProgrammableStageDescriptor = struct {
    module: ShaderModuleDescriptor,
    stage: ShaderStage,
    entry_point: []const u8 = "main",
    reflection: ?ShaderReflectionSource = null,
    specialization: ShaderSpecializationDescriptor = .{},

    pub fn validate(self: ProgrammableStageDescriptor, expected_stage: ShaderStage) ShaderError!void {
        try self.module.validate();
        if (self.stage != expected_stage) return ShaderError.UnexpectedShaderStage;
        if (self.entry_point.len == 0) return ShaderError.EmptyShaderEntryPoint;
        if (self.reflection) |reflection| try reflection.validate();
        try self.specialization.validateShape();
    }
};

pub const VertexFormat = enum {
    float32,
    float32x2,
    float32x3,
    float32x4,
};

pub const VertexStepFunction = enum {
    per_vertex,
    per_instance,
};

pub const VertexAttributeDescriptor = struct {
    location: u32,
    format: VertexFormat,
    offset: u32 = 0,
};

pub const VertexBufferLayoutDescriptor = struct {
    stride: u32,
    buffer_index: ?u32 = null,
    step_function: VertexStepFunction = .per_vertex,
    instance_step_rate: u32 = 1,
    attributes: []const VertexAttributeDescriptor = &.{},

    pub fn validate(self: VertexBufferLayoutDescriptor) PipelineError!void {
        try self.validateAt(0);
    }

    fn validateAt(self: VertexBufferLayoutDescriptor, default_index: usize) PipelineError!void {
        if (self.resolvedBufferIndex(default_index) >= default_max_vertex_buffer_slots) return PipelineError.InvalidVertexBufferIndex;
        if (self.stride == 0 and self.attributes.len != 0) return PipelineError.InvalidVertexStride;
        if (self.instance_step_rate == 0) return PipelineError.InvalidInstanceStepRate;
        if (self.step_function == .per_vertex and self.instance_step_rate != 1) return PipelineError.InvalidInstanceStepRate;
        for (self.attributes) |attribute| {
            if (attribute.offset > self.stride or vertexFormatSize(attribute.format) > self.stride - attribute.offset) {
                return PipelineError.InvalidVertexAttributeOffset;
            }
        }
    }

    pub fn resolvedBufferIndex(self: VertexBufferLayoutDescriptor, default_index: usize) u32 {
        return self.buffer_index orelse @intCast(default_index);
    }
};

pub const VertexDescriptor = struct {
    buffers: []const VertexBufferLayoutDescriptor = &.{},

    pub fn validate(self: VertexDescriptor) PipelineError!void {
        for (self.buffers, 0..) |buffer, i| {
            try buffer.validateAt(i);
            const resolved_index = buffer.resolvedBufferIndex(i);
            for (self.buffers[i + 1 ..], i + 1..) |other, other_i| {
                if (resolved_index == other.resolvedBufferIndex(other_i)) return PipelineError.DuplicateVertexBufferIndex;
            }
            for (buffer.attributes) |attribute| {
                for (self.buffers[i + 1 ..]) |other| {
                    for (other.attributes) |other_attribute| {
                        if (attribute.location == other_attribute.location) return PipelineError.DuplicateVertexAttributeLocation;
                    }
                }
            }
            for (buffer.attributes, 0..) |attribute, attribute_i| {
                for (buffer.attributes[attribute_i + 1 ..]) |other_attribute| {
                    if (attribute.location == other_attribute.location) return PipelineError.DuplicateVertexAttributeLocation;
                }
            }
        }
    }
};

pub const PrimitiveTopology = enum {
    triangle,
    line,
    point,
};

pub const Winding = enum {
    clockwise,
    counter_clockwise,
};

pub const CullMode = enum {
    none,
    front,
    back,
};

pub const TriangleFillMode = enum {
    fill,
    lines,
};

pub const TessellationDomain = enum {
    triangle,
    quad,
    isoline,
};

pub const TessellationPartitionMode = enum {
    integer,
    fractional_even,
    fractional_odd,
};

pub const TessellationDescriptor = struct {
    control_point_count: u32,
    domain: TessellationDomain = .triangle,
    partition_mode: TessellationPartitionMode = .integer,
    has_control_stage: bool = false,
    has_evaluation_stage: bool = false,

    pub fn validate(self: TessellationDescriptor, features: DeviceFeatures, limits: DeviceLimits) AdvancedFeatureError!void {
        if (!features.tessellation) return AdvancedFeatureError.UnsupportedTessellation;
        if (!self.has_control_stage or !self.has_evaluation_stage) return AdvancedFeatureError.MissingTessellationStage;
        if (self.control_point_count == 0) return AdvancedFeatureError.InvalidPatchControlPointCount;
        if (limits.max_tessellation_control_points != 0 and self.control_point_count > limits.max_tessellation_control_points) {
            return AdvancedFeatureError.InvalidPatchControlPointCount;
        }
    }
};

pub const VulkanTessellationLowering = struct {
    patch_control_points: u32,
    domain: TessellationDomain,
    partition_mode: TessellationPartitionMode,

    pub fn fromDescriptor(descriptor: TessellationDescriptor, features: DeviceFeatures, limits: DeviceLimits) AdvancedFeatureError!VulkanTessellationLowering {
        try descriptor.validate(features, limits);
        return .{
            .patch_control_points = descriptor.control_point_count,
            .domain = descriptor.domain,
            .partition_mode = descriptor.partition_mode,
        };
    }
};

pub const MetalTessellationLowering = struct {
    patch_control_points: u32,
    domain: TessellationDomain,
    partition_mode: TessellationPartitionMode,
    requires_factor_buffer: bool = true,

    pub fn fromDescriptor(descriptor: TessellationDescriptor, features: DeviceFeatures, limits: DeviceLimits) AdvancedFeatureError!MetalTessellationLowering {
        try descriptor.validate(features, limits);
        return .{
            .patch_control_points = descriptor.control_point_count,
            .domain = descriptor.domain,
            .partition_mode = descriptor.partition_mode,
        };
    }
};

pub const TessellationLowering = union(Backend) {
    vulkan: VulkanTessellationLowering,
    metal: MetalTessellationLowering,

    pub fn fromDescriptor(
        backend: Backend,
        descriptor: TessellationDescriptor,
        features: DeviceFeatures,
        limits: DeviceLimits,
    ) AdvancedFeatureError!TessellationLowering {
        return switch (backend) {
            .vulkan => .{ .vulkan = try VulkanTessellationLowering.fromDescriptor(descriptor, features, limits) },
            .metal => .{ .metal = try MetalTessellationLowering.fromDescriptor(descriptor, features, limits) },
        };
    }

    pub fn patchControlPoints(self: TessellationLowering) u32 {
        return switch (self) {
            .vulkan => |lowering| lowering.patch_control_points,
            .metal => |lowering| lowering.patch_control_points,
        };
    }

    pub fn domain(self: TessellationLowering) TessellationDomain {
        return switch (self) {
            .vulkan => |lowering| lowering.domain,
            .metal => |lowering| lowering.domain,
        };
    }

    pub fn partitionMode(self: TessellationLowering) TessellationPartitionMode {
        return switch (self) {
            .vulkan => |lowering| lowering.partition_mode,
            .metal => |lowering| lowering.partition_mode,
        };
    }

    pub fn requiresFactorBuffer(self: TessellationLowering) bool {
        return switch (self) {
            .vulkan => false,
            .metal => |lowering| lowering.requires_factor_buffer,
        };
    }
};

pub const MeshPipelineDescriptor = struct {
    label: ?[]const u8 = null,
    mesh_entry_point: []const u8,
    task_entry_point: ?[]const u8 = null,
    mesh_threads_per_threadgroup: u32 = 1,
    task_threads_per_threadgroup: u32 = 1,

    pub fn validate(self: MeshPipelineDescriptor, features: DeviceFeatures, limits: DeviceLimits) AdvancedFeatureError!void {
        if (!features.mesh_shaders) return AdvancedFeatureError.UnsupportedMeshShaders;
        if (self.mesh_entry_point.len == 0) return AdvancedFeatureError.MissingMeshStage;
        if (self.mesh_threads_per_threadgroup == 0) return AdvancedFeatureError.InvalidMeshThreadgroupSize;
        if (limits.max_mesh_threads_per_threadgroup != 0 and self.mesh_threads_per_threadgroup > limits.max_mesh_threads_per_threadgroup) {
            return AdvancedFeatureError.InvalidMeshThreadgroupSize;
        }
        if (self.task_entry_point) |entry| {
            if (!features.task_shaders) return AdvancedFeatureError.UnsupportedTaskShaders;
            if (entry.len == 0) return AdvancedFeatureError.MissingMeshStage;
            if (self.task_threads_per_threadgroup == 0) return AdvancedFeatureError.InvalidMeshThreadgroupSize;
            if (limits.max_task_threads_per_threadgroup != 0 and self.task_threads_per_threadgroup > limits.max_task_threads_per_threadgroup) {
                return AdvancedFeatureError.InvalidMeshThreadgroupSize;
            }
        }
    }
};

pub const VulkanMeshPipelineLowering = struct {
    mesh_entry_point: []const u8,
    task_entry_point: ?[]const u8 = null,
    mesh_threads_per_threadgroup: u32,
    task_threads_per_threadgroup: u32 = 0,

    pub fn fromDescriptor(descriptor: MeshPipelineDescriptor, features: DeviceFeatures, limits: DeviceLimits) AdvancedFeatureError!VulkanMeshPipelineLowering {
        try descriptor.validate(features, limits);
        return .{
            .mesh_entry_point = descriptor.mesh_entry_point,
            .task_entry_point = descriptor.task_entry_point,
            .mesh_threads_per_threadgroup = descriptor.mesh_threads_per_threadgroup,
            .task_threads_per_threadgroup = if (descriptor.task_entry_point != null) descriptor.task_threads_per_threadgroup else 0,
        };
    }
};

pub const MetalMeshPipelineLowering = struct {
    mesh_entry_point: []const u8,
    object_entry_point: ?[]const u8 = null,
    mesh_threads_per_threadgroup: u32,
    object_threads_per_threadgroup: u32 = 0,

    pub fn fromDescriptor(descriptor: MeshPipelineDescriptor, features: DeviceFeatures, limits: DeviceLimits) AdvancedFeatureError!MetalMeshPipelineLowering {
        try descriptor.validate(features, limits);
        return .{
            .mesh_entry_point = descriptor.mesh_entry_point,
            .object_entry_point = descriptor.task_entry_point,
            .mesh_threads_per_threadgroup = descriptor.mesh_threads_per_threadgroup,
            .object_threads_per_threadgroup = if (descriptor.task_entry_point != null) descriptor.task_threads_per_threadgroup else 0,
        };
    }
};

pub const AccelerationStructureKind = enum {
    bottom_level,
    top_level,
};

pub const AccelerationStructureDescriptor = struct {
    label: ?[]const u8 = null,
    kind: AccelerationStructureKind,
    primitive_count: u32,
    allow_update: bool = false,

    pub fn validate(self: AccelerationStructureDescriptor, features: DeviceFeatures) AdvancedFeatureError!void {
        if (!features.acceleration_structures) return AdvancedFeatureError.UnsupportedAccelerationStructures;
        if (self.primitive_count == 0) return AdvancedFeatureError.InvalidAccelerationStructureDescriptor;
    }
};

pub const AccelerationStructureBuildSizes = struct {
    result_size: u64,
    scratch_size: u64,
    update_scratch_size: u64 = 0,
};

pub const AccelerationStructureInstanceDescriptor = struct {
    instance_count: u32,
    allow_update: bool = false,

    pub fn validate(self: AccelerationStructureInstanceDescriptor, features: DeviceFeatures) AdvancedFeatureError!void {
        if (!features.acceleration_structures) return AdvancedFeatureError.UnsupportedAccelerationStructures;
        if (self.instance_count == 0) return AdvancedFeatureError.InvalidAccelerationStructureDescriptor;
    }
};

pub fn estimateAccelerationStructureBuildSizes(descriptor: AccelerationStructureDescriptor) AccelerationStructureBuildSizes {
    const primitive_count = @as(u64, @max(descriptor.primitive_count, 1));
    const base_size: u64 = switch (descriptor.kind) {
        .bottom_level => 1024,
        .top_level => 512,
    };
    const primitive_size: u64 = switch (descriptor.kind) {
        .bottom_level => 128,
        .top_level => 64,
    };
    const result_size = base_size + primitive_count * primitive_size;
    return .{
        .result_size = result_size,
        .scratch_size = result_size * 2,
        .update_scratch_size = if (descriptor.allow_update) result_size else 0,
    };
}

pub const RayTracingShaderGroupKind = enum {
    ray_generation,
    miss,
    hit,
    callable,
};

pub const RayTracingShaderGroupDescriptor = struct {
    kind: RayTracingShaderGroupKind,
    entry_point: []const u8,

    pub fn validate(self: RayTracingShaderGroupDescriptor) AdvancedFeatureError!void {
        if (self.entry_point.len == 0) return AdvancedFeatureError.InvalidRayTracingPipeline;
    }
};

pub const RayTracingPipelineDescriptor = struct {
    label: ?[]const u8 = null,
    shader_groups: []const RayTracingShaderGroupDescriptor = &.{},
    max_recursion_depth: u32 = 1,

    pub fn validate(self: RayTracingPipelineDescriptor, features: DeviceFeatures, limits: DeviceLimits) AdvancedFeatureError!void {
        if (!features.ray_tracing) return AdvancedFeatureError.UnsupportedRayTracing;
        if (self.shader_groups.len == 0 or self.max_recursion_depth == 0) return AdvancedFeatureError.InvalidRayTracingPipeline;
        if (limits.max_ray_tracing_recursion_depth != 0 and self.max_recursion_depth > limits.max_ray_tracing_recursion_depth) {
            return AdvancedFeatureError.InvalidRayTracingPipeline;
        }
        var has_ray_generation = false;
        for (self.shader_groups) |group| {
            try group.validate();
            if (group.kind == .ray_generation) has_ray_generation = true;
        }
        if (!has_ray_generation) return AdvancedFeatureError.InvalidRayTracingPipeline;
    }
};

pub const VulkanRayTracingPipelineLowering = struct {
    max_recursion_depth: u32,
    ray_generation_groups: u32 = 0,
    miss_groups: u32 = 0,
    hit_groups: u32 = 0,
    callable_groups: u32 = 0,

    pub fn fromDescriptor(descriptor: RayTracingPipelineDescriptor, features: DeviceFeatures, limits: DeviceLimits) AdvancedFeatureError!VulkanRayTracingPipelineLowering {
        try descriptor.validate(features, limits);
        var lowering = VulkanRayTracingPipelineLowering{ .max_recursion_depth = descriptor.max_recursion_depth };
        for (descriptor.shader_groups) |group| switch (group.kind) {
            .ray_generation => lowering.ray_generation_groups += 1,
            .miss => lowering.miss_groups += 1,
            .hit => lowering.hit_groups += 1,
            .callable => lowering.callable_groups += 1,
        };
        return lowering;
    }
};

pub const MetalIntersectionFunctionDescriptor = struct {
    entry_point: []const u8,

    pub fn validate(self: MetalIntersectionFunctionDescriptor, features: DeviceFeatures) AdvancedFeatureError!void {
        if (!features.ray_tracing) return AdvancedFeatureError.UnsupportedRayTracing;
        if (self.entry_point.len == 0) return AdvancedFeatureError.InvalidRayTracingPipeline;
    }
};

pub const MetalRayTracingLowering = struct {
    max_recursion_depth: u32,
    function_table_entries: u32,
    intersection_function_count: u32 = 0,

    pub fn fromDescriptor(
        descriptor: RayTracingPipelineDescriptor,
        intersections: []const MetalIntersectionFunctionDescriptor,
        features: DeviceFeatures,
        limits: DeviceLimits,
    ) AdvancedFeatureError!MetalRayTracingLowering {
        try descriptor.validate(features, limits);
        for (intersections) |intersection| try intersection.validate(features);
        return .{
            .max_recursion_depth = descriptor.max_recursion_depth,
            .function_table_entries = @intCast(descriptor.shader_groups.len + intersections.len),
            .intersection_function_count = @intCast(intersections.len),
        };
    }
};

pub const ShaderBindingTableDescriptor = struct {
    stride: u64,
    ray_generation_count: u32 = 1,
    miss_count: u32 = 0,
    hit_count: u32 = 0,
    callable_count: u32 = 0,

    pub fn validate(self: ShaderBindingTableDescriptor, features: DeviceFeatures, limits: DeviceLimits) AdvancedFeatureError!void {
        if (!features.ray_tracing) return AdvancedFeatureError.UnsupportedRayTracing;
        if (self.stride == 0) return AdvancedFeatureError.InvalidShaderBindingTable;
        if (limits.shader_binding_table_alignment != 0 and !isAlignedU64(self.stride, limits.shader_binding_table_alignment)) {
            return AdvancedFeatureError.InvalidShaderBindingTable;
        }
        if (self.ray_generation_count == 0) return AdvancedFeatureError.InvalidShaderBindingTable;
    }
};

pub const ShaderBindingTableLayout = struct {
    ray_generation_offset: u64 = 0,
    miss_offset: u64 = 0,
    hit_offset: u64 = 0,
    callable_offset: u64 = 0,
    total_size: u64 = 0,

    pub fn fromDescriptor(descriptor: ShaderBindingTableDescriptor, features: DeviceFeatures, limits: DeviceLimits) AdvancedFeatureError!ShaderBindingTableLayout {
        try descriptor.validate(features, limits);
        const raygen_size = @as(u64, descriptor.ray_generation_count) * descriptor.stride;
        const miss_offset = raygen_size;
        const miss_size = @as(u64, descriptor.miss_count) * descriptor.stride;
        const hit_offset = miss_offset + miss_size;
        const hit_size = @as(u64, descriptor.hit_count) * descriptor.stride;
        const callable_offset = hit_offset + hit_size;
        const callable_size = @as(u64, descriptor.callable_count) * descriptor.stride;
        return .{
            .ray_generation_offset = 0,
            .miss_offset = miss_offset,
            .hit_offset = hit_offset,
            .callable_offset = callable_offset,
            .total_size = callable_offset + callable_size,
        };
    }
};

pub const DepthBiasDescriptor = struct {
    enabled: bool = false,
    constant: f32 = 0,
    slope: f32 = 0,
    clamp: f32 = 0,

    pub fn validate(self: DepthBiasDescriptor) error{InvalidDepthBias}!void {
        if (!std.math.isFinite(self.constant) or
            !std.math.isFinite(self.slope) or
            !std.math.isFinite(self.clamp))
        {
            return error.InvalidDepthBias;
        }
    }
};

pub const ColorWriteMask = struct {
    red: bool = true,
    green: bool = true,
    blue: bool = true,
    alpha: bool = true,
};

pub const BlendFactor = enum {
    zero,
    one,
    source_color,
    one_minus_source_color,
    source_alpha,
    one_minus_source_alpha,
    destination_color,
    one_minus_destination_color,
    destination_alpha,
    one_minus_destination_alpha,
    blend_color,
    one_minus_blend_color,
    blend_alpha,
    one_minus_blend_alpha,
};

pub const BlendOperation = enum {
    add,
    subtract,
    reverse_subtract,
    min,
    max,
};

pub const RenderPipelineBlendDescriptor = struct {
    source_rgb_blend_factor: BlendFactor = .one,
    destination_rgb_blend_factor: BlendFactor = .zero,
    rgb_blend_operation: BlendOperation = .add,
    source_alpha_blend_factor: BlendFactor = .one,
    destination_alpha_blend_factor: BlendFactor = .zero,
    alpha_blend_operation: BlendOperation = .add,

    pub fn eql(a: RenderPipelineBlendDescriptor, b: RenderPipelineBlendDescriptor) bool {
        return a.source_rgb_blend_factor == b.source_rgb_blend_factor and
            a.destination_rgb_blend_factor == b.destination_rgb_blend_factor and
            a.rgb_blend_operation == b.rgb_blend_operation and
            a.source_alpha_blend_factor == b.source_alpha_blend_factor and
            a.destination_alpha_blend_factor == b.destination_alpha_blend_factor and
            a.alpha_blend_operation == b.alpha_blend_operation;
    }
};

pub const CompareFunction = enum {
    never,
    less,
    equal,
    less_equal,
    greater,
    not_equal,
    greater_equal,
    always,
};

pub const StencilOperation = enum {
    keep,
    zero,
    replace,
    increment_clamp,
    decrement_clamp,
    invert,
    increment_wrap,
    decrement_wrap,
};

pub const StencilFaceDescriptor = struct {
    stencil_fail_operation: StencilOperation = .keep,
    depth_fail_operation: StencilOperation = .keep,
    depth_stencil_pass_operation: StencilOperation = .keep,
    stencil_compare_function: CompareFunction = .always,
};

pub const StencilDescriptor = struct {
    enabled: bool = false,
    front: StencilFaceDescriptor = .{},
    back: StencilFaceDescriptor = .{},
    read_mask: u32 = 0xff,
    write_mask: u32 = 0xff,

    pub fn validate(self: StencilDescriptor) PipelineError!void {
        if (self.read_mask > 0xff or self.write_mask > 0xff) return PipelineError.InvalidStencilMask;
    }
};

pub const DepthStencilDescriptor = struct {
    format: TextureFormat = .automatic,
    depth_test_enabled: bool = true,
    depth_compare_function: CompareFunction = .always,
    depth_write_enabled: bool = false,
    stencil: StencilDescriptor = .{},

    pub fn validate(self: DepthStencilDescriptor) PipelineError!void {
        try self.stencil.validate();
        const requires_depth = self.depth_test_enabled or self.depth_write_enabled;
        const requires_stencil = self.stencil.enabled;
        if (requires_depth and !isDepthFormat(self.format)) return PipelineError.InvalidDepthStencilFormat;
        if (requires_stencil and !isStencilFormat(self.format)) return PipelineError.InvalidDepthStencilFormat;
        if (!requires_depth and !requires_stencil) return PipelineError.InvalidDepthStencilFormat;
    }
};

pub const RenderPipelineColorAttachmentDescriptor = struct {
    format: TextureFormat = .automatic,
    write_mask: ColorWriteMask = .{},
    blend: ?RenderPipelineBlendDescriptor = null,

    pub fn validate(self: RenderPipelineColorAttachmentDescriptor) PipelineError!void {
        if (self.format == .automatic) return PipelineError.InvalidColorAttachmentFormat;
        if (!isColorFormat(self.format)) return PipelineError.InvalidColorAttachmentFormat;
        if (self.blend != null and !defaultFormatCapabilities(self.format).blendable) {
            return PipelineError.UnsupportedBlendFormat;
        }
    }
};

pub const RenderPipelineDescriptor = struct {
    label: ?[]const u8 = null,
    vertex: ProgrammableStageDescriptor,
    fragment: ?ProgrammableStageDescriptor = null,
    vertex_descriptor: VertexDescriptor = .{},
    bind_group_layouts: []const BindGroupLayoutDescriptor = &.{},
    primitive_topology: PrimitiveTopology = .triangle,
    front_facing_winding: Winding = .counter_clockwise,
    cull_mode: CullMode = .none,
    fill_mode: TriangleFillMode = .fill,
    depth_bias: DepthBiasDescriptor = .{},
    conservative_rasterization: bool = false,
    sample_count: u32 = 1,
    color_attachments: []const RenderPipelineColorAttachmentDescriptor = &.{},
    depth_stencil: ?DepthStencilDescriptor = null,
    root_constant_layout: ?RootConstantLayoutDescriptor = null,
    cache_policy: ObjectCachePolicy = .{},

    pub fn validate(self: RenderPipelineDescriptor) (ShaderError || PipelineError || BindingError)!void {
        try self.vertex.validate(.vertex);
        if (self.fragment) |fragment| try fragment.validate(.fragment);
        try self.vertex_descriptor.validate();
        for (self.bind_group_layouts) |layout| {
            try layout.validate();
        }
        try validateProgrammableStageReflection(self.vertex, .vertex, self.bind_group_layouts);
        if (self.fragment) |fragment| try validateProgrammableStageReflection(fragment, .fragment, self.bind_group_layouts);
        if (self.color_attachments.len == 0) return PipelineError.MissingColorAttachment;
        if (self.color_attachments.len > default_max_color_attachments) return PipelineError.UnsupportedMultipleRenderTargets;
        try self.depth_bias.validate();
        try validateSampleCount(self.sample_count);
        for (self.color_attachments) |attachment| {
            try attachment.validate();
        }
        if (self.depth_stencil) |depth_stencil| try depth_stencil.validate();
    }
};

pub const RenderPipelineCacheKeyDescriptor = struct {
    pipeline: RenderPipelineDescriptor,
    vertex_shader: ShaderModuleCacheKeyDescriptor,
    fragment_shader: ?ShaderModuleCacheKeyDescriptor = null,
    pipeline_layout: ?PipelineLayoutCacheKeyDescriptor = null,

    pub fn validate(
        self: RenderPipelineCacheKeyDescriptor,
        features: DeviceFeatures,
        limits: DeviceLimits,
    ) (ShaderError || PipelineError || BindingError || ObjectCacheError || SmallConstantError || RootConstantError)!void {
        try self.pipeline.validate();
        try self.vertex_shader.validate();
        if (self.vertex_shader.stage != .vertex) return ObjectCacheError.InvalidObjectCacheKey;

        if ((self.pipeline.fragment == null) != (self.fragment_shader == null)) {
            return ObjectCacheError.InvalidObjectCacheKey;
        }
        if (self.fragment_shader) |fragment_shader| {
            try fragment_shader.validate();
            if (fragment_shader.stage != .fragment) return ObjectCacheError.InvalidObjectCacheKey;
        }
        if (self.pipeline_layout) |layout| {
            try layout.validate(features, limits);
        }
    }
};

pub const ComputePipelineDescriptor = struct {
    label: ?[]const u8 = null,
    compute: ProgrammableStageDescriptor,
    bind_group_layouts: []const BindGroupLayoutDescriptor = &.{},
    root_constant_layout: ?RootConstantLayoutDescriptor = null,
    cache_policy: ObjectCachePolicy = .{},

    pub fn validate(self: ComputePipelineDescriptor) (ShaderError || BindingError)!void {
        try self.compute.validate(.compute);
        for (self.bind_group_layouts) |layout| {
            try layout.validate();
        }
        try validateProgrammableStageReflection(self.compute, .compute, self.bind_group_layouts);
    }
};

pub const ComputePipelineCacheKeyDescriptor = struct {
    shader: ShaderLibraryCacheKeyDescriptor,
    entry_point: []const u8,
    bind_group_layouts: []const BindGroupLayoutDescriptor = &.{},
    pipeline_layout: ?PipelineLayoutCacheKeyDescriptor = null,

    pub fn validate(self: ComputePipelineCacheKeyDescriptor) (ShaderError || BindingError || SmallConstantError || RootConstantError)!void {
        try self.validateForDevice(.{}, .{});
    }

    pub fn validateForDevice(
        self: ComputePipelineCacheKeyDescriptor,
        features: DeviceFeatures,
        limits: DeviceLimits,
    ) (ShaderError || BindingError || SmallConstantError || RootConstantError)!void {
        try self.shader.validate();
        if (self.entry_point.len == 0) return ShaderError.EmptyShaderEntryPoint;
        for (self.bind_group_layouts) |layout| {
            try layout.validate();
        }
        if (self.pipeline_layout) |layout| {
            try layout.validate(features, limits);
        }
    }
};

pub const ShaderError = error{
    EmptyShaderSource,
    EmptyShaderArtifactPath,
    EmptyShaderEntryPoint,
    EmptyShaderLibraryName,
    EmptyShaderLibraryEntryName,
    EmptyShaderIncludePath,
    EmptyShaderSourceHash,
    MissingShaderLibraryEntry,
    DuplicateShaderLibraryEntry,
    EmptyShaderReflectionPath,
    UnsupportedShaderReflectionSchema,
    InvalidShaderReflection,
    ShaderReflectionReadFailed,
    ShaderReflectionStageMismatch,
    ShaderReflectionEntryPointMismatch,
    ShaderReflectionMissingBindGroupLayout,
    ShaderReflectionMissingBinding,
    ShaderReflectionBindingKindMismatch,
    ShaderReflectionBindingArrayCountMismatch,
    ShaderReflectionVisibilityMismatch,
    UnexpectedShaderStage,
    UnsupportedShaderSpecialization,
    EmptyShaderSpecializationName,
    DuplicateShaderSpecializationConstant,
};

pub const PipelineError = error{
    MissingColorAttachment,
    InvalidColorAttachmentFormat,
    InvalidDepthStencilFormat,
    InvalidSampleCount,
    UnsupportedSampleCount,
    InvalidVertexStride,
    InvalidVertexAttributeOffset,
    InvalidVertexBufferIndex,
    DuplicateVertexBufferIndex,
    DuplicateVertexAttributeLocation,
    InvalidInstanceStepRate,
    InvalidDepthBias,
    UnsupportedFillMode,
    UnsupportedDepthBias,
    UnsupportedConservativeRasterization,
    UnsupportedBlendState,
    UnsupportedIndependentBlend,
    UnsupportedBlendFormat,
    UnsupportedMultipleRenderTargets,
    InvalidStencilMask,
    UnsupportedStencilState,
    UnsupportedInstanceStepRate,
};

pub fn validateProgrammableStageReflection(
    stage_descriptor: ProgrammableStageDescriptor,
    expected_stage: ShaderStage,
    bind_group_layouts: []const BindGroupLayoutDescriptor,
) ShaderError!void {
    const source = stage_descriptor.reflection orelse return;
    switch (source) {
        .data => |reflection| try validateShaderStageReflection(stage_descriptor, expected_stage, reflection, bind_group_layouts),
        .artifact => {},
    }
}

pub fn validateShaderStageReflection(
    stage_descriptor: ProgrammableStageDescriptor,
    expected_stage: ShaderStage,
    reflection: ShaderStageReflection,
    bind_group_layouts: []const BindGroupLayoutDescriptor,
) ShaderError!void {
    try validateShaderStageReflectionShape(reflection);
    if (reflection.stage != expected_stage or reflection.stage != stage_descriptor.stage) {
        return ShaderError.ShaderReflectionStageMismatch;
    }
    if (!std.mem.eql(u8, reflection.entry_point, stage_descriptor.entry_point)) {
        return ShaderError.ShaderReflectionEntryPointMismatch;
    }

    for (reflection.bind_groups) |bind_group| {
        const layout_index: usize = @intCast(bind_group.index);
        if (layout_index >= bind_group_layouts.len) {
            return ShaderError.ShaderReflectionMissingBindGroupLayout;
        }
        for (bind_group.bindings) |binding| {
            try validateShaderReflectionBinding(bind_group_layouts[layout_index], binding);
        }
    }
}

pub fn validateShaderReflectionBinding(
    layout: BindGroupLayoutDescriptor,
    reflection: ShaderReflectionBinding,
) ShaderError!void {
    if (reflection.visibility.isEmpty()) return ShaderError.InvalidShaderReflection;

    const layout_entry = layout.entryForBinding(reflection.binding) orelse {
        return ShaderError.ShaderReflectionMissingBinding;
    };
    if (layout_entry.resource != reflection.resource) {
        return ShaderError.ShaderReflectionBindingKindMismatch;
    }
    if (layout_entry.array_count != reflection.array_count) {
        return ShaderError.ShaderReflectionBindingArrayCountMismatch;
    }
    if (!visibilityContains(layout_entry.visibility, reflection.visibility)) {
        return ShaderError.ShaderReflectionVisibilityMismatch;
    }
}

fn validateShaderStageReflectionShape(reflection: ShaderStageReflection) ShaderError!void {
    if (reflection.schema_version != shader_reflection_schema_version) return ShaderError.UnsupportedShaderReflectionSchema;
    if (reflection.entry_point.len == 0) return ShaderError.InvalidShaderReflection;
    for (reflection.bind_groups) |bind_group| {
        for (bind_group.bindings) |binding| {
            if (binding.visibility.isEmpty()) return ShaderError.InvalidShaderReflection;
            if (binding.array_count == 0) return ShaderError.InvalidShaderReflection;
        }
    }
}

pub fn descriptorIndexingRangeCountForReflection(reflection: ShaderStageReflection) usize {
    var count: usize = 0;
    for (reflection.bind_groups) |bind_group| {
        for (bind_group.bindings) |binding| {
            if (binding.bindless or binding.array_count != 1) count += 1;
        }
    }
    return count;
}

pub fn deriveDescriptorIndexingLayoutFromReflection(
    reflection: ShaderStageReflection,
    model: AdvancedBindingModel,
    ranges: []DescriptorIndexingRange,
) ShaderError!DescriptorIndexingLayoutDescriptor {
    try validateShaderStageReflectionShape(reflection);
    const required_count = descriptorIndexingRangeCountForReflection(reflection);
    if (ranges.len < required_count) return ShaderError.InvalidShaderReflection;

    var out_index: usize = 0;
    for (reflection.bind_groups) |bind_group| {
        _ = bind_group.index;
        for (bind_group.bindings) |binding| {
            if (!binding.bindless and binding.array_count == 1) continue;
            ranges[out_index] = .{
                .binding = binding.binding,
                .resource = binding.resource,
                .visibility = binding.visibility,
                .descriptor_count = binding.array_count,
                .partially_bound = binding.partially_bound,
                .update_after_bind = binding.update_after_bind,
            };
            out_index += 1;
        }
    }

    return .{
        .model = model,
        .ranges = ranges[0..required_count],
    };
}

fn visibilityContains(container: ShaderVisibility, required: ShaderVisibility) bool {
    return (!required.vertex or container.vertex) and
        (!required.fragment or container.fragment) and
        (!required.compute or container.compute);
}

pub const LoadAction = enum {
    dont_care,
    load,
    clear,
};

pub const StoreAction = enum {
    dont_care,
    store,
};

pub const RenderPassAttachmentOptions = struct {
    transient: bool = false,
};

pub const RenderPassColorAttachmentTarget = enum {
    current_drawable,
    texture_view,
};

pub const RenderPassColorAttachmentDescriptor = struct {
    target: RenderPassColorAttachmentTarget = .current_drawable,
    resolve_target: ?RenderPassColorAttachmentTarget = null,
    load_action: LoadAction = .clear,
    store_action: StoreAction = .store,
    clear_color: ClearColorLike = .{},
    options: RenderPassAttachmentOptions = .{},
};

pub const RenderPassDepthAttachmentTarget = enum {
    current_drawable,
    texture_view,
};

pub const RenderPassDepthAttachmentDescriptor = struct {
    target: RenderPassDepthAttachmentTarget = .current_drawable,
    load_action: LoadAction = .clear,
    store_action: StoreAction = .dont_care,
    clear_depth: f32 = 1.0,
    options: RenderPassAttachmentOptions = .{},

    pub fn validate(self: RenderPassDepthAttachmentDescriptor) CommandEncodingError!void {
        if (!std.math.isFinite(self.clear_depth) or self.clear_depth < 0 or self.clear_depth > 1) {
            return CommandEncodingError.InvalidDepthClearValue;
        }
    }
};

pub const RenderPassStencilAttachmentTarget = enum {
    current_drawable,
    texture_view,
};

pub const RenderPassStencilAttachmentDescriptor = struct {
    target: RenderPassStencilAttachmentTarget = .current_drawable,
    load_action: LoadAction = .clear,
    store_action: StoreAction = .dont_care,
    clear_stencil: u32 = 0,
    options: RenderPassAttachmentOptions = .{},

    pub fn validate(self: RenderPassStencilAttachmentDescriptor) CommandEncodingError!void {
        if (self.clear_stencil > 0xff) return CommandEncodingError.InvalidStencilClearValue;
    }
};

pub const RenderPassDescriptor = struct {
    label: ?[]const u8 = null,
    color_attachments: []const RenderPassColorAttachmentDescriptor = &.{},
    depth_attachment: ?RenderPassDepthAttachmentDescriptor = null,
    stencil_attachment: ?RenderPassStencilAttachmentDescriptor = null,

    pub fn validate(self: RenderPassDescriptor) CommandEncodingError!void {
        if (self.color_attachments.len == 0) return CommandEncodingError.MissingColorAttachment;
        if (self.color_attachments.len > default_max_color_attachments) return CommandEncodingError.UnsupportedMultipleRenderTargets;
        if (self.depth_attachment) |depth_attachment| try depth_attachment.validate();
        if (self.stencil_attachment) |stencil_attachment| try stencil_attachment.validate();
    }
};

pub const IndexType = enum {
    uint16,
    uint32,
};

pub const VertexBufferBinding = struct {
    index: u32,
    offset: u64 = 0,

    pub fn validate(self: VertexBufferBinding) CommandEncodingError!void {
        if (self.index >= max_vertex_buffer_slots) return CommandEncodingError.InvalidVertexBufferIndex;
    }
};

pub const BindGroupBinding = struct {
    index: u32,
    dynamic_offsets: []const DynamicOffset = &.{},

    pub fn validate(self: BindGroupBinding) CommandEncodingError!void {
        if (self.index >= max_bind_group_slots) return CommandEncodingError.InvalidBindGroupIndex;
    }
};

pub const ResourceTableBinding = struct {
    index: u32,

    pub fn validate(self: ResourceTableBinding) CommandEncodingError!void {
        if (self.index >= max_bind_group_slots) return CommandEncodingError.InvalidBindGroupIndex;
    }
};

pub const Viewport = struct {
    x: f32 = 0,
    y: f32 = 0,
    width: f32,
    height: f32,
    min_depth: f32 = 0,
    max_depth: f32 = 1,

    pub fn validate(self: Viewport) CommandEncodingError!void {
        if (!std.math.isFinite(self.x) or
            !std.math.isFinite(self.y) or
            !std.math.isFinite(self.width) or
            !std.math.isFinite(self.height) or
            !std.math.isFinite(self.min_depth) or
            !std.math.isFinite(self.max_depth) or
            self.width <= 0 or
            self.height <= 0 or
            self.min_depth < 0 or
            self.max_depth > 1 or
            self.min_depth > self.max_depth)
        {
            return CommandEncodingError.InvalidViewport;
        }
    }
};

pub const ScissorRect = struct {
    x: u32 = 0,
    y: u32 = 0,
    width: u32,
    height: u32,

    pub fn validate(self: ScissorRect) CommandEncodingError!void {
        if (self.width == 0 or self.height == 0) return CommandEncodingError.InvalidScissorRect;
    }
};

pub const BlendColor = struct {
    red: f32 = 0,
    green: f32 = 0,
    blue: f32 = 0,
    alpha: f32 = 0,

    pub fn validate(self: BlendColor) CommandEncodingError!void {
        if (!std.math.isFinite(self.red) or
            !std.math.isFinite(self.green) or
            !std.math.isFinite(self.blue) or
            !std.math.isFinite(self.alpha))
        {
            return CommandEncodingError.InvalidBlendColor;
        }
    }
};

pub const StencilReference = struct {
    value: u32 = 0,

    pub fn validate(self: StencilReference) CommandEncodingError!void {
        if (self.value > 0xff) return CommandEncodingError.InvalidStencilReference;
    }
};

pub const DrawPrimitivesDescriptor = struct {
    primitive_type: PrimitiveTopology = .triangle,
    vertex_start: u32 = 0,
    vertex_count: u32 = 0,
    instance_count: u32 = 1,
    base_instance: u32 = 0,

    pub fn validate(self: DrawPrimitivesDescriptor) CommandEncodingError!void {
        if (self.vertex_count == 0) return CommandEncodingError.InvalidVertexCount;
        if (self.instance_count == 0) return CommandEncodingError.InvalidInstanceCount;
    }
};

pub const DrawIndexedPrimitivesDescriptor = struct {
    primitive_type: PrimitiveTopology = .triangle,
    index_type: IndexType = .uint16,
    index_count: u32 = 0,
    index_buffer_offset: u64 = 0,
    instance_count: u32 = 1,
    base_vertex: i32 = 0,
    base_instance: u32 = 0,

    pub fn validate(self: DrawIndexedPrimitivesDescriptor) CommandEncodingError!void {
        if (self.index_count == 0) return CommandEncodingError.InvalidIndexCount;
        if (self.instance_count == 0) return CommandEncodingError.InvalidInstanceCount;
        if (self.index_buffer_offset % indexTypeSize(self.index_type) != 0) {
            return CommandEncodingError.InvalidIndexBufferOffset;
        }
    }
};

pub const DrawPrimitivesIndirectDescriptor = struct {
    primitive_type: PrimitiveTopology = .triangle,
    buffer_offset: u64 = 0,
    draw_count: u32 = 1,
    stride: u32 = 0,

    pub fn validate(self: DrawPrimitivesIndirectDescriptor) CommandEncodingError!void {
        try validateIndirectDrawShape(self.draw_count, self.stride);
    }
};

pub const DrawIndexedPrimitivesIndirectDescriptor = struct {
    primitive_type: PrimitiveTopology = .triangle,
    index_type: IndexType = .uint16,
    buffer_offset: u64 = 0,
    draw_count: u32 = 1,
    stride: u32 = 0,

    pub fn validate(self: DrawIndexedPrimitivesIndirectDescriptor) CommandEncodingError!void {
        try validateIndirectDrawShape(self.draw_count, self.stride);
    }
};

pub const MultiDrawPrimitivesDescriptor = struct {
    draws: []const DrawPrimitivesDescriptor = &.{},

    pub fn validate(self: MultiDrawPrimitivesDescriptor) CommandEncodingError!void {
        if (self.draws.len == 0) return CommandEncodingError.InvalidDrawCount;
        for (self.draws) |draw| try draw.validate();
    }
};

pub const MultiDrawIndexedPrimitivesDescriptor = struct {
    draws: []const DrawIndexedPrimitivesDescriptor = &.{},

    pub fn validate(self: MultiDrawIndexedPrimitivesDescriptor) CommandEncodingError!void {
        if (self.draws.len == 0) return CommandEncodingError.InvalidDrawCount;
        for (self.draws) |draw| try draw.validate();
    }
};

fn validateIndirectDrawShape(draw_count: u32, stride: u32) CommandEncodingError!void {
    if (draw_count == 0) return CommandEncodingError.InvalidDrawCount;
    if (stride != 0 and stride % 4 != 0) return CommandEncodingError.InvalidIndirectDrawStride;
}

pub const QueryType = enum {
    occlusion,
    timestamp,
    pipeline_statistics,
};

pub const PipelineStatisticFlags = struct {
    vertex_invocations: bool = false,
    fragment_invocations: bool = false,
    compute_invocations: bool = false,

    pub fn isEmpty(self: PipelineStatisticFlags) bool {
        return !self.vertex_invocations and !self.fragment_invocations and !self.compute_invocations;
    }
};

pub const QuerySetDescriptor = struct {
    label: ?[]const u8 = null,
    query_type: QueryType,
    count: u32,
    pipeline_statistics: PipelineStatisticFlags = .{},

    pub fn validate(self: QuerySetDescriptor, features: DeviceFeatures) QueryError!void {
        if (self.count == 0) return QueryError.InvalidQueryCount;
        switch (self.query_type) {
            .occlusion => if (!features.occlusion_queries) return QueryError.UnsupportedOcclusionQueries,
            .timestamp => if (!features.timestamp_queries) return QueryError.UnsupportedTimestampQueries,
            .pipeline_statistics => {
                if (!features.pipeline_statistics_queries) return QueryError.UnsupportedPipelineStatisticsQueries;
                if (self.pipeline_statistics.isEmpty()) return QueryError.MissingPipelineStatistics;
            },
        }
    }
};

pub const ProfilerMarkerDescriptor = struct {
    label: []const u8,
    write_timestamp_begin: bool = false,
    write_timestamp_end: bool = false,

    pub fn validate(self: ProfilerMarkerDescriptor, features: DeviceFeatures) (QueryError || CommandEncodingError)!void {
        if (self.label.len == 0) return CommandEncodingError.EmptyDebugGroupLabel;
        if ((self.write_timestamp_begin or self.write_timestamp_end) and !features.timestamp_queries) {
            return QueryError.UnsupportedTimestampQueries;
        }
    }
};

pub const QueryResolveDescriptor = struct {
    first_query: u32 = 0,
    query_count: u32 = 0,
    destination_offset: u64 = 0,

    pub fn validate(
        self: QueryResolveDescriptor,
        set: QuerySetDescriptor,
        limits: DeviceLimits,
    ) QueryError!void {
        try validateQueryRange(self.first_query, self.query_count, set.count);
        if (!isAlignedU64(self.destination_offset, limits.query_result_alignment)) {
            return QueryError.InvalidQueryResultAlignment;
        }
    }
};

pub const QueryReadbackDescriptor = struct {
    first_query: u32 = 0,
    query_count: u32 = 0,
    destination: []u64 = &.{},

    pub fn validate(self: QueryReadbackDescriptor, set: QuerySetDescriptor) QueryError!void {
        try validateQueryRange(self.first_query, self.query_count, set.count);
        if (self.destination.len < self.query_count) return QueryError.InvalidQueryRange;
    }
};

fn validateQueryRange(first_query: u32, query_count: u32, set_count: u32) QueryError!void {
    if (query_count == 0) return QueryError.InvalidQueryCount;
    const end = std.math.add(u32, first_query, query_count) catch return QueryError.InvalidQueryRange;
    if (end > set_count) return QueryError.InvalidQueryRange;
}

pub const QueryError = error{
    InvalidQueryCount,
    InvalidQueryRange,
    InvalidQueryResultAlignment,
    QueryTypeMismatch,
    QueryNotReady,
    MissingPipelineStatistics,
    UnsupportedOcclusionQueries,
    UnsupportedTimestampQueries,
    UnsupportedPipelineStatisticsQueries,
};

pub const DispatchThreadgroupsDescriptor = struct {
    threadgroup_count_x: u32 = 0,
    threadgroup_count_y: u32 = 1,
    threadgroup_count_z: u32 = 1,
    threads_per_threadgroup_x: u32 = 1,
    threads_per_threadgroup_y: u32 = 1,
    threads_per_threadgroup_z: u32 = 1,

    pub fn validate(self: DispatchThreadgroupsDescriptor) CommandEncodingError!void {
        if (self.threadgroup_count_x == 0 or
            self.threadgroup_count_y == 0 or
            self.threadgroup_count_z == 0 or
            self.threads_per_threadgroup_x == 0 or
            self.threads_per_threadgroup_y == 0 or
            self.threads_per_threadgroup_z == 0)
        {
            return CommandEncodingError.InvalidThreadgroupCount;
        }
    }

    pub fn validateForLimits(
        self: DispatchThreadgroupsDescriptor,
        limits: DeviceLimits,
    ) CommandEncodingError!void {
        try self.validate();
        if (self.threadgroup_count_x > limits.max_compute_threadgroups_per_grid_x or
            self.threadgroup_count_y > limits.max_compute_threadgroups_per_grid_y or
            self.threadgroup_count_z > limits.max_compute_threadgroups_per_grid_z)
        {
            return CommandEncodingError.InvalidThreadgroupCount;
        }
        if (self.threads_per_threadgroup_x > limits.max_compute_threads_per_threadgroup_x or
            self.threads_per_threadgroup_y > limits.max_compute_threads_per_threadgroup_y or
            self.threads_per_threadgroup_z > limits.max_compute_threads_per_threadgroup_z)
        {
            return CommandEncodingError.InvalidThreadgroupCount;
        }
        const total = checkedMul(usize, self.threads_per_threadgroup_x, self.threads_per_threadgroup_y) catch {
            return CommandEncodingError.InvalidThreadgroupCount;
        };
        const total_xyz = checkedMul(usize, total, self.threads_per_threadgroup_z) catch {
            return CommandEncodingError.InvalidThreadgroupCount;
        };
        if (total_xyz > limits.max_compute_total_threads_per_threadgroup) {
            return CommandEncodingError.InvalidThreadgroupCount;
        }
    }
};

pub const DispatchThreadsDescriptor = struct {
    thread_count_x: u32 = 0,
    thread_count_y: u32 = 1,
    thread_count_z: u32 = 1,
    threads_per_threadgroup_x: u32 = 1,
    threads_per_threadgroup_y: u32 = 1,
    threads_per_threadgroup_z: u32 = 1,

    pub fn resolve(self: DispatchThreadsDescriptor, limits: DeviceLimits) CommandEncodingError!DispatchThreadgroupsDescriptor {
        if (self.thread_count_x == 0 or
            self.thread_count_y == 0 or
            self.thread_count_z == 0 or
            self.threads_per_threadgroup_x == 0 or
            self.threads_per_threadgroup_y == 0 or
            self.threads_per_threadgroup_z == 0)
        {
            return CommandEncodingError.InvalidThreadgroupCount;
        }

        const resolved = DispatchThreadgroupsDescriptor{
            .threadgroup_count_x = try ceilDivU32(self.thread_count_x, self.threads_per_threadgroup_x),
            .threadgroup_count_y = try ceilDivU32(self.thread_count_y, self.threads_per_threadgroup_y),
            .threadgroup_count_z = try ceilDivU32(self.thread_count_z, self.threads_per_threadgroup_z),
            .threads_per_threadgroup_x = self.threads_per_threadgroup_x,
            .threads_per_threadgroup_y = self.threads_per_threadgroup_y,
            .threads_per_threadgroup_z = self.threads_per_threadgroup_z,
        };
        try resolved.validateForLimits(limits);
        return resolved;
    }
};

pub const DispatchThreadgroupsIndirectDescriptor = struct {
    offset: u64 = 0,
    threads_per_threadgroup_x: u32 = 1,
    threads_per_threadgroup_y: u32 = 1,
    threads_per_threadgroup_z: u32 = 1,

    pub fn validate(
        self: DispatchThreadgroupsIndirectDescriptor,
        buffer_length: usize,
        features: DeviceFeatures,
        limits: DeviceLimits,
    ) CommandEncodingError!void {
        if (!features.compute_dispatch_indirect) return CommandEncodingError.UnsupportedDispatchIndirect;
        if (!isAlignedU64(self.offset, limits.dispatch_indirect_alignment)) {
            return CommandEncodingError.InvalidDispatchIndirectOffset;
        }
        const end = std.math.add(u64, self.offset, 12) catch {
            return CommandEncodingError.InvalidDispatchIndirectOffset;
        };
        if (end > buffer_length) return CommandEncodingError.InvalidDispatchIndirectOffset;
        try (DispatchThreadgroupsDescriptor{
            .threadgroup_count_x = 1,
            .threadgroup_count_y = 1,
            .threadgroup_count_z = 1,
            .threads_per_threadgroup_x = self.threads_per_threadgroup_x,
            .threads_per_threadgroup_y = self.threads_per_threadgroup_y,
            .threads_per_threadgroup_z = self.threads_per_threadgroup_z,
        }).validateForLimits(limits);
    }
};

pub const ComputeAtomicOperations = struct {
    add: bool = false,
    min: bool = false,
    max: bool = false,
    bitwise_and: bool = false,
    bitwise_or: bool = false,
    bitwise_xor: bool = false,
    exchange: bool = false,
    compare_exchange: bool = false,

    pub fn isEmpty(self: ComputeAtomicOperations) bool {
        return !self.add and
            !self.min and
            !self.max and
            !self.bitwise_and and
            !self.bitwise_or and
            !self.bitwise_xor and
            !self.exchange and
            !self.compare_exchange;
    }
};

pub const ComputeAtomicDescriptor = struct {
    storage: BindingResourceKind = .storage_buffer,
    operations: ComputeAtomicOperations = .{},

    pub fn validate(self: ComputeAtomicDescriptor, features: DeviceFeatures) CommandEncodingError!void {
        if (!features.compute_atomics) return CommandEncodingError.UnsupportedComputeAtomics;
        if (self.storage != .storage_buffer and self.storage != .storage_texture) {
            return CommandEncodingError.InvalidAtomicStorageResource;
        }
        if (self.operations.isEmpty()) return CommandEncodingError.MissingAtomicOperation;
    }
};

pub const ThreadgroupMemoryDescriptor = struct {
    bytes: u32 = 0,
    alignment: u32 = 16,

    pub fn validate(self: ThreadgroupMemoryDescriptor, features: DeviceFeatures, limits: DeviceLimits) CommandEncodingError!void {
        if (!features.compute_threadgroup_memory) return CommandEncodingError.UnsupportedThreadgroupMemory;
        if (self.bytes == 0 or self.bytes > limits.max_compute_threadgroup_memory_bytes) {
            return CommandEncodingError.InvalidThreadgroupMemorySize;
        }
        if (self.alignment == 0 or !isAlignedU32(self.bytes, self.alignment)) {
            return CommandEncodingError.InvalidThreadgroupMemoryAlignment;
        }
    }
};

pub const CopyBufferToBufferDescriptor = struct {
    source_offset: u64 = 0,
    destination_offset: u64 = 0,
    size: u64,

    pub fn validate(
        self: CopyBufferToBufferDescriptor,
        source_length: usize,
        destination_length: usize,
    ) CommandEncodingError!void {
        if (self.size == 0) return CommandEncodingError.InvalidCopySize;
        const source_end = std.math.add(u64, self.source_offset, self.size) catch return CommandEncodingError.InvalidCopyBufferRange;
        const destination_end = std.math.add(u64, self.destination_offset, self.size) catch return CommandEncodingError.InvalidCopyBufferRange;
        if (source_end > source_length or destination_end > destination_length) {
            return CommandEncodingError.InvalidCopyBufferRange;
        }
    }
};

pub const FillBufferDescriptor = struct {
    offset: u64 = 0,
    size: u64,
    value: u8 = 0,

    pub fn validate(self: FillBufferDescriptor, buffer_length: usize) CommandEncodingError!void {
        if (self.size == 0) return CommandEncodingError.InvalidFillBufferRange;
        const end = std.math.add(u64, self.offset, self.size) catch return CommandEncodingError.InvalidFillBufferRange;
        if (end > buffer_length) return CommandEncodingError.InvalidFillBufferRange;
    }
};

pub const CommandBufferState = enum {
    ready,
    render_encoding,
    blit_encoding,
    compute_encoding,
    committed,
};

pub const RenderCommandEncoderState = enum {
    encoding,
    ended,
};

pub const CommandBufferDebugState = struct {
    state: CommandBufferState = .ready,
    presented: bool = false,
    reusable: bool = false,
    signpost_count: u32 = 0,

    pub fn init(
        descriptor: CommandBufferDescriptor,
        features: DeviceFeatures,
    ) CommandEncodingError!CommandBufferDebugState {
        try descriptor.validate(features);
        return .{
            .reusable = descriptor.reusable,
        };
    }

    pub fn status(self: CommandBufferDebugState) CommandBufferState {
        return self.state;
    }

    pub fn reset(self: *CommandBufferDebugState) CommandEncodingError!void {
        if (!self.reusable) return CommandEncodingError.UnsupportedCommandBufferReset;
        if (self.state != .committed) return CommandEncodingError.InvalidCommandBufferState;
        self.state = .ready;
        self.presented = false;
        self.signpost_count = 0;
    }

    pub fn makeRenderCommandEncoder(
        self: *CommandBufferDebugState,
        descriptor: RenderPassDescriptor,
    ) CommandEncodingError!RenderCommandEncoderDebugState {
        if (self.state != .ready) return CommandEncodingError.InvalidCommandBufferState;
        try descriptor.validate();
        self.state = .render_encoding;
        return .{};
    }

    pub fn makeBlitCommandEncoder(self: *CommandBufferDebugState) CommandEncodingError!BlitCommandEncoderDebugState {
        if (self.state != .ready) return CommandEncodingError.InvalidCommandBufferState;
        self.state = .blit_encoding;
        return .{};
    }

    pub fn makeComputeCommandEncoder(self: *CommandBufferDebugState) CommandEncodingError!ComputeCommandEncoderDebugState {
        if (self.state != .ready) return CommandEncodingError.InvalidCommandBufferState;
        self.state = .compute_encoding;
        return .{};
    }

    pub fn insertDebugSignpost(
        self: *CommandBufferDebugState,
        descriptor: DebugSignpostDescriptor,
    ) CommandEncodingError!void {
        if (self.state != .ready) return CommandEncodingError.InvalidCommandBufferState;
        try descriptor.validate();
        self.signpost_count += 1;
    }

    pub fn finishRenderEncoding(self: *CommandBufferDebugState) CommandEncodingError!void {
        if (self.state != .render_encoding) return CommandEncodingError.InvalidCommandBufferState;
        self.state = .ready;
    }

    pub fn finishBlitEncoding(self: *CommandBufferDebugState) CommandEncodingError!void {
        if (self.state != .blit_encoding) return CommandEncodingError.InvalidCommandBufferState;
        self.state = .ready;
    }

    pub fn finishComputeEncoding(self: *CommandBufferDebugState) CommandEncodingError!void {
        if (self.state != .compute_encoding) return CommandEncodingError.InvalidCommandBufferState;
        self.state = .ready;
    }

    pub fn presentDrawable(self: *CommandBufferDebugState) CommandEncodingError!void {
        if (self.state != .ready) return CommandEncodingError.InvalidCommandBufferState;
        if (self.presented) return CommandEncodingError.InvalidCommandBufferState;
        self.presented = true;
    }

    pub fn commit(self: *CommandBufferDebugState) CommandEncodingError!void {
        if (self.state != .ready) return CommandEncodingError.InvalidCommandBufferState;
        self.state = .committed;
    }
};

pub const RenderCommandEncoderDebugState = struct {
    state: RenderCommandEncoderState = .encoding,
    pipeline_set: bool = false,
    vertex_buffer_mask: u64 = 0,
    bind_group_mask: u64 = 0,
    resource_table_mask: u64 = 0,
    index_buffer_set: bool = false,
    signpost_count: u32 = 0,

    pub fn setRenderPipelineState(self: *RenderCommandEncoderDebugState) CommandEncodingError!void {
        try self.requireEncoding();
        self.pipeline_set = true;
    }

    pub fn setVertexBuffer(
        self: *RenderCommandEncoderDebugState,
        binding: VertexBufferBinding,
    ) CommandEncodingError!void {
        try self.requireEncoding();
        try binding.validate();
        self.vertex_buffer_mask |= @as(u64, 1) << @intCast(binding.index);
    }

    pub fn setIndexBuffer(self: *RenderCommandEncoderDebugState) CommandEncodingError!void {
        try self.requireEncoding();
        self.index_buffer_set = true;
    }

    pub fn setBindGroup(
        self: *RenderCommandEncoderDebugState,
        binding: BindGroupBinding,
    ) CommandEncodingError!void {
        try self.requireEncoding();
        try binding.validate();
        self.bind_group_mask |= @as(u64, 1) << @intCast(binding.index);
    }

    pub fn setRootConstants(self: *RenderCommandEncoderDebugState) CommandEncodingError!void {
        try self.requireEncoding();
    }

    pub fn setResourceTable(
        self: *RenderCommandEncoderDebugState,
        binding: ResourceTableBinding,
    ) CommandEncodingError!void {
        try self.requireEncoding();
        try binding.validate();
        self.resource_table_mask |= @as(u64, 1) << @intCast(binding.index);
    }

    pub fn setViewport(
        self: *RenderCommandEncoderDebugState,
        viewport: Viewport,
    ) CommandEncodingError!void {
        try self.requireEncoding();
        try viewport.validate();
    }

    pub fn setScissorRect(
        self: *RenderCommandEncoderDebugState,
        rect: ScissorRect,
    ) CommandEncodingError!void {
        try self.requireEncoding();
        try rect.validate();
    }

    pub fn setBlendColor(
        self: *RenderCommandEncoderDebugState,
        color: BlendColor,
    ) CommandEncodingError!void {
        try self.requireEncoding();
        try color.validate();
    }

    pub fn setStencilReference(
        self: *RenderCommandEncoderDebugState,
        reference: StencilReference,
    ) CommandEncodingError!void {
        try self.requireEncoding();
        try reference.validate();
    }

    pub fn setDepthBias(
        self: *RenderCommandEncoderDebugState,
        descriptor: DepthBiasDescriptor,
    ) CommandEncodingError!void {
        try self.requireEncoding();
        try descriptor.validate();
    }

    pub fn insertDebugSignpost(
        self: *RenderCommandEncoderDebugState,
        descriptor: DebugSignpostDescriptor,
    ) CommandEncodingError!void {
        try self.requireEncoding();
        try descriptor.validate();
        self.signpost_count += 1;
    }

    pub fn drawPrimitives(
        self: *RenderCommandEncoderDebugState,
        descriptor: DrawPrimitivesDescriptor,
    ) CommandEncodingError!void {
        try self.requirePipeline();
        try descriptor.validate();
    }

    pub fn drawIndexedPrimitives(
        self: *RenderCommandEncoderDebugState,
        descriptor: DrawIndexedPrimitivesDescriptor,
    ) CommandEncodingError!void {
        try self.requirePipeline();
        if (!self.index_buffer_set) return CommandEncodingError.MissingIndexBuffer;
        try descriptor.validate();
    }

    pub fn drawPrimitivesIndirect(
        self: *RenderCommandEncoderDebugState,
        descriptor: DrawPrimitivesIndirectDescriptor,
    ) CommandEncodingError!void {
        try self.requirePipeline();
        try descriptor.validate();
    }

    pub fn drawIndexedPrimitivesIndirect(
        self: *RenderCommandEncoderDebugState,
        descriptor: DrawIndexedPrimitivesIndirectDescriptor,
    ) CommandEncodingError!void {
        try self.requirePipeline();
        if (!self.index_buffer_set) return CommandEncodingError.MissingIndexBuffer;
        try descriptor.validate();
    }

    pub fn drawPrimitivesMulti(
        self: *RenderCommandEncoderDebugState,
        descriptor: MultiDrawPrimitivesDescriptor,
    ) CommandEncodingError!void {
        try self.requirePipeline();
        try descriptor.validate();
    }

    pub fn drawIndexedPrimitivesMulti(
        self: *RenderCommandEncoderDebugState,
        descriptor: MultiDrawIndexedPrimitivesDescriptor,
    ) CommandEncodingError!void {
        try self.requirePipeline();
        if (!self.index_buffer_set) return CommandEncodingError.MissingIndexBuffer;
        try descriptor.validate();
    }

    pub fn endEncoding(
        self: *RenderCommandEncoderDebugState,
        command_buffer: *CommandBufferDebugState,
    ) CommandEncodingError!void {
        try self.requireEncoding();
        try command_buffer.finishRenderEncoding();
        self.state = .ended;
    }

    fn requireEncoding(self: RenderCommandEncoderDebugState) CommandEncodingError!void {
        if (self.state != .encoding) return CommandEncodingError.InvalidRenderCommandEncoderState;
    }

    fn requirePipeline(self: RenderCommandEncoderDebugState) CommandEncodingError!void {
        try self.requireEncoding();
        if (!self.pipeline_set) return CommandEncodingError.MissingRenderPipelineState;
    }
};

pub const BlitCommandEncoderState = enum {
    encoding,
    ended,
};

pub const BlitCommandEncoderDebugState = struct {
    state: BlitCommandEncoderState = .encoding,
    signpost_count: u32 = 0,

    pub fn copyBufferToBuffer(
        self: *BlitCommandEncoderDebugState,
        descriptor: CopyBufferToBufferDescriptor,
        source_length: usize,
        destination_length: usize,
    ) CommandEncodingError!void {
        try self.requireEncoding();
        try descriptor.validate(source_length, destination_length);
    }

    pub fn copyBufferToTexture(
        self: *BlitCommandEncoderDebugState,
        descriptor: CopyBufferToTextureDescriptor,
        source_length: usize,
        destination: TextureDescriptor,
    ) CommandEncodingError!ResolvedBufferTextureCopy {
        try self.requireEncoding();
        return try descriptor.resolve(source_length, destination);
    }

    pub fn copyTextureToBuffer(
        self: *BlitCommandEncoderDebugState,
        descriptor: CopyTextureToBufferDescriptor,
        source: TextureDescriptor,
        destination_length: usize,
    ) CommandEncodingError!ResolvedBufferTextureCopy {
        try self.requireEncoding();
        return try descriptor.resolve(source, destination_length);
    }

    pub fn copyTextureToTexture(
        self: *BlitCommandEncoderDebugState,
        descriptor: CopyTextureToTextureDescriptor,
        source: TextureDescriptor,
        destination: TextureDescriptor,
    ) CommandEncodingError!ResolvedTextureTextureCopy {
        try self.requireEncoding();
        return try descriptor.resolve(source, destination);
    }

    pub fn fillBuffer(
        self: *BlitCommandEncoderDebugState,
        descriptor: FillBufferDescriptor,
        buffer_length: usize,
    ) CommandEncodingError!void {
        try self.requireEncoding();
        try descriptor.validate(buffer_length);
    }

    pub fn insertDebugSignpost(
        self: *BlitCommandEncoderDebugState,
        descriptor: DebugSignpostDescriptor,
    ) CommandEncodingError!void {
        try self.requireEncoding();
        try descriptor.validate();
        self.signpost_count += 1;
    }

    pub fn endEncoding(
        self: *BlitCommandEncoderDebugState,
        command_buffer: *CommandBufferDebugState,
    ) CommandEncodingError!void {
        try self.requireEncoding();
        try command_buffer.finishBlitEncoding();
        self.state = .ended;
    }

    fn requireEncoding(self: BlitCommandEncoderDebugState) CommandEncodingError!void {
        if (self.state != .encoding) return CommandEncodingError.InvalidBlitCommandEncoderState;
    }
};

pub const ComputeCommandEncoderState = enum {
    encoding,
    ended,
};

pub const ComputeCommandEncoderDebugState = struct {
    state: ComputeCommandEncoderState = .encoding,
    pipeline_set: bool = false,
    bind_group_mask: u64 = 0,
    resource_table_mask: u64 = 0,
    signpost_count: u32 = 0,

    pub fn setComputePipelineState(self: *ComputeCommandEncoderDebugState) CommandEncodingError!void {
        try self.requireEncoding();
        self.pipeline_set = true;
    }

    pub fn setBindGroup(
        self: *ComputeCommandEncoderDebugState,
        binding: BindGroupBinding,
    ) CommandEncodingError!void {
        try self.requireEncoding();
        try binding.validate();
        self.bind_group_mask |= @as(u64, 1) << @intCast(binding.index);
    }

    pub fn setRootConstants(self: *ComputeCommandEncoderDebugState) CommandEncodingError!void {
        try self.requireEncoding();
    }

    pub fn setResourceTable(
        self: *ComputeCommandEncoderDebugState,
        binding: ResourceTableBinding,
    ) CommandEncodingError!void {
        try self.requireEncoding();
        try binding.validate();
        self.resource_table_mask |= @as(u64, 1) << @intCast(binding.index);
    }

    pub fn dispatchThreadgroups(
        self: *ComputeCommandEncoderDebugState,
        descriptor: DispatchThreadgroupsDescriptor,
    ) CommandEncodingError!void {
        try self.requirePipeline();
        try descriptor.validate();
    }

    pub fn dispatchThreads(
        self: *ComputeCommandEncoderDebugState,
        descriptor: DispatchThreadsDescriptor,
        limits: DeviceLimits,
    ) CommandEncodingError!DispatchThreadgroupsDescriptor {
        try self.requirePipeline();
        return try descriptor.resolve(limits);
    }

    pub fn dispatchThreadgroupsIndirect(
        self: *ComputeCommandEncoderDebugState,
        descriptor: DispatchThreadgroupsIndirectDescriptor,
        buffer_length: usize,
        features: DeviceFeatures,
        limits: DeviceLimits,
    ) CommandEncodingError!void {
        try self.requirePipeline();
        try descriptor.validate(buffer_length, features, limits);
    }

    pub fn insertDebugSignpost(
        self: *ComputeCommandEncoderDebugState,
        descriptor: DebugSignpostDescriptor,
    ) CommandEncodingError!void {
        try self.requireEncoding();
        try descriptor.validate();
        self.signpost_count += 1;
    }

    pub fn endEncoding(
        self: *ComputeCommandEncoderDebugState,
        command_buffer: *CommandBufferDebugState,
    ) CommandEncodingError!void {
        try self.requireEncoding();
        try command_buffer.finishComputeEncoding();
        self.state = .ended;
    }

    fn requireEncoding(self: ComputeCommandEncoderDebugState) CommandEncodingError!void {
        if (self.state != .encoding) return CommandEncodingError.InvalidComputeCommandEncoderState;
    }

    fn requirePipeline(self: ComputeCommandEncoderDebugState) CommandEncodingError!void {
        try self.requireEncoding();
        if (!self.pipeline_set) return CommandEncodingError.MissingComputePipelineState;
    }
};

pub const CommandEncodingError = error{
    MissingColorAttachment,
    InvalidCommandBufferState,
    InvalidRenderCommandEncoderState,
    InvalidBlitCommandEncoderState,
    InvalidComputeCommandEncoderState,
    MissingRenderPipelineState,
    MissingComputePipelineState,
    MissingIndexBuffer,
    InvalidVertexBufferIndex,
    InvalidBindGroupIndex,
    InvalidViewport,
    InvalidScissorRect,
    InvalidBlendColor,
    InvalidStencilReference,
    InvalidDepthBias,
    EmptyDebugGroupLabel,
    CaptureNameTooLong,
    DebugGroupStackOverflow,
    DebugGroupStackUnderflow,
    UnclosedDebugGroup,
    InvalidDepthClearValue,
    InvalidStencilClearValue,
    DepthStateRenderPassMismatch,
    SampleCountRenderPassMismatch,
    InvalidVertexCount,
    InvalidIndexCount,
    InvalidInstanceCount,
    InvalidDrawCount,
    InvalidIndexBufferOffset,
    InvalidIndirectDrawStride,
    UnsupportedBaseVertex,
    UnsupportedBaseInstance,
    UnsupportedMultipleRenderTargets,
    UnsupportedIndirectDraw,
    UnsupportedMultiDraw,
    UnsupportedCommandBufferPooling,
    UnsupportedCommandBufferReset,
    UnsupportedTextureToTextureCopy,
    UnsupportedFillBuffer,
    UnsupportedExplicitResourceBarrier,
    UnsupportedFences,
    UnsupportedEvents,
    UnsupportedTimelineFences,
    UnsupportedSharedEvents,
    UnsupportedMultiQueue,
    UnsupportedDedicatedQueue,
    UnsupportedQueueOwnershipTransfer,
    UnsupportedDispatchIndirect,
    UnsupportedComputeAtomics,
    UnsupportedThreadgroupMemory,
    RedundantResourceBarrier,
    RedundantQueueOwnershipTransfer,
    InvalidResourceBarrierState,
    InvalidResourceBarrierRange,
    InvalidQueueCapability,
    InvalidQueueOwnershipState,
    InvalidFenceValue,
    InvalidEventState,
    FenceWaitTimeout,
    EventWaitTimeout,
    InvalidDispatchIndirectOffset,
    InvalidIndirectBufferUsage,
    InvalidAtomicStorageResource,
    MissingAtomicOperation,
    InvalidThreadgroupMemorySize,
    InvalidThreadgroupMemoryAlignment,
    InvalidCopySize,
    InvalidCopyBufferRange,
    InvalidCopyTextureRegion,
    InvalidCopyTextureSlice,
    InvalidCopyBufferLayout,
    InvalidCopyBufferUsage,
    InvalidCopyTextureUsage,
    InvalidFillBufferRange,
    InvalidThreadgroupCount,
    UnsupportedTextureCopyFormat,
    TextureCopySizeOverflow,
};

pub const TextureDimension = enum {
    one_d,
    two_d,
    three_d,
};

pub const TextureShape = enum {
    one_d,
    one_d_array,
    two_d,
    two_d_array,
    three_d,
    cube_compatible,
    cube_array_compatible,
    multisampled,
};

pub const TextureViewDimension = enum {
    automatic,
    one_d,
    one_d_array,
    two_d,
    two_d_array,
    three_d,
};

pub const TextureUsage = struct {
    copy_source: bool = false,
    copy_destination: bool = false,
    shader_read: bool = false,
    shader_write: bool = false,
    render_attachment: bool = false,

    pub fn isEmpty(self: TextureUsage) bool {
        return !self.copy_source and
            !self.copy_destination and
            !self.shader_read and
            !self.shader_write and
            !self.render_attachment;
    }
};

pub const TextureDescriptor = struct {
    label: ?[]const u8 = null,
    dimension: TextureDimension = .two_d,
    format: TextureFormat = .automatic,
    width: u32 = 0,
    height: u32 = 1,
    depth_or_array_layers: u32 = 1,
    mip_level_count: u32 = 1,
    sample_count: u32 = 1,
    usage: TextureUsage = .{},
    storage_mode: ResourceStorageMode = .automatic,

    pub fn validate(self: TextureDescriptor) TextureError!void {
        if (self.format == .automatic) return TextureError.InvalidTextureFormat;
        if (self.width == 0 or self.height == 0 or self.depth_or_array_layers == 0) {
            return TextureError.InvalidTextureExtent;
        }
        if (self.mip_level_count == 0) return TextureError.InvalidMipLevelCount;
        if (self.mip_level_count > self.maxMipLevelCount()) return TextureError.InvalidMipLevelCount;
        try validateSampleCount(self.sample_count);
        if (self.sample_count != 1) {
            if (self.dimension != .two_d) return TextureError.UnsupportedSampleCount;
            if (self.mip_level_count != 1) return TextureError.UnsupportedSampleCount;
            if (self.depth_or_array_layers != 1) return TextureError.UnsupportedSampleCount;
            if (!self.usage.render_attachment) return TextureError.UnsupportedSampleCount;
            if (self.usage.shader_read or
                self.usage.shader_write or
                self.usage.copy_source or
                self.usage.copy_destination)
            {
                return TextureError.UnsupportedSampleCount;
            }
            if (self.storage_mode == .shared or self.storage_mode == .managed) {
                return TextureError.UnsupportedSampleCount;
            }
        }

        switch (self.dimension) {
            .one_d => if (self.height != 1) return TextureError.InvalidTextureExtent,
            .two_d => {},
            .three_d => {},
        }
    }

    pub fn isArray(self: TextureDescriptor) bool {
        return self.dimension != .three_d and self.depth_or_array_layers > 1;
    }

    pub fn isMultisampled(self: TextureDescriptor) bool {
        return self.sample_count > 1;
    }

    pub fn isCubeCompatible(self: TextureDescriptor) bool {
        return self.dimension == .two_d and
            self.width == self.height and
            self.depth_or_array_layers >= 6 and
            self.depth_or_array_layers % 6 == 0;
    }

    pub fn cubeCount(self: TextureDescriptor) u32 {
        if (!self.isCubeCompatible()) return 0;
        return self.depth_or_array_layers / 6;
    }

    pub fn shape(self: TextureDescriptor) TextureShape {
        if (self.isMultisampled()) return .multisampled;
        return switch (self.dimension) {
            .one_d => if (self.isArray()) .one_d_array else .one_d,
            .two_d => if (self.isCubeCompatible())
                if (self.cubeCount() == 1) .cube_compatible else .cube_array_compatible
            else if (self.isArray()) .two_d_array else .two_d,
            .three_d => .three_d,
        };
    }

    pub fn maxMipLevelCount(self: TextureDescriptor) u32 {
        return switch (self.dimension) {
            .one_d => maxMipLevelCountForExtent(self.width, 1, 1),
            .two_d => maxMipLevelCountForExtent(self.width, self.height, 1),
            .three_d => maxMipLevelCountForExtent(self.width, self.height, self.depth_or_array_layers),
        };
    }

    pub fn mipExtent(self: TextureDescriptor, level: u32) TextureError!Size3D {
        try self.validate();
        if (level >= self.mip_level_count) return TextureError.InvalidMipLevelCount;
        return switch (self.dimension) {
            .one_d => .{ .width = mipDimension(self.width, level) },
            .two_d => .{
                .width = mipDimension(self.width, level),
                .height = mipDimension(self.height, level),
            },
            .three_d => .{
                .width = mipDimension(self.width, level),
                .height = mipDimension(self.height, level),
                .depth = mipDimension(self.depth_or_array_layers, level),
            },
        };
    }
};

pub const ExternalHandleKind = enum {
    opaque_fd,
    win32_handle,
    vulkan_memory,
    iosurface,
    metal_buffer,
    metal_texture,
    metal_shared_event,
    vulkan_image,
    vulkan_semaphore,

    pub fn isVulkanSpecific(self: ExternalHandleKind) bool {
        return switch (self) {
            .vulkan_memory,
            .vulkan_image,
            .vulkan_semaphore,
            => true,
            else => false,
        };
    }

    pub fn isMetalSpecific(self: ExternalHandleKind) bool {
        return switch (self) {
            .iosurface,
            .metal_buffer,
            .metal_texture,
            .metal_shared_event,
            => true,
            else => false,
        };
    }
};

pub const ExternalResourceOwnership = enum {
    borrowed,
    transferred,
};

pub const ExternalHandleDescriptor = struct {
    kind: ExternalHandleKind,
    value: usize,
    backend: ?Backend = null,

    pub fn validateForBackend(self: ExternalHandleDescriptor, selected_backend: Backend) AdvancedFeatureError!void {
        if (self.value == 0) return AdvancedFeatureError.InvalidExternalHandle;
        if (self.backend) |backend| {
            if (backend != selected_backend) return AdvancedFeatureError.ExternalHandleBackendMismatch;
        }
        switch (self.kind) {
            .iosurface, .metal_buffer, .metal_texture, .metal_shared_event => if (selected_backend != .metal) return AdvancedFeatureError.ExternalHandleBackendMismatch,
            .vulkan_memory, .vulkan_image, .vulkan_semaphore => if (selected_backend != .vulkan) return AdvancedFeatureError.ExternalHandleBackendMismatch,
            .opaque_fd, .win32_handle => {},
        }
    }
};

pub const ExternalMemoryDescriptor = struct {
    label: ?[]const u8 = null,
    handle: ExternalHandleDescriptor,
    size: u64,
    dedicated: bool = false,
    ownership: ExternalResourceOwnership = .borrowed,

    pub fn validate(
        self: ExternalMemoryDescriptor,
        selected_backend: Backend,
        features: DeviceFeatures,
    ) AdvancedFeatureError!void {
        if (!features.external_memory) return AdvancedFeatureError.UnsupportedExternalMemory;
        if (self.size == 0) return AdvancedFeatureError.InvalidExternalHandle;
        try self.handle.validateForBackend(selected_backend);
        if (selected_backend == .metal and self.handle.kind.isVulkanSpecific()) {
            return AdvancedFeatureError.ExternalHandleBackendMismatch;
        }
    }
};

pub const ExternalBufferDescriptor = struct {
    label: ?[]const u8 = null,
    handle: ExternalHandleDescriptor,
    length: u64,
    usage: BufferUsage = .{ .storage = true },
    ownership: ExternalResourceOwnership = .borrowed,

    pub fn validate(
        self: ExternalBufferDescriptor,
        selected_backend: Backend,
        features: DeviceFeatures,
    ) AdvancedFeatureError!void {
        if (!features.external_memory) return AdvancedFeatureError.UnsupportedExternalMemory;
        if (self.length == 0) return AdvancedFeatureError.InvalidExternalHandle;
        try self.handle.validateForBackend(selected_backend);
    }
};

pub const ExternalTextureDescriptor = struct {
    label: ?[]const u8 = null,
    handle: ExternalHandleDescriptor,
    format: TextureFormat,
    width: u32,
    height: u32,
    depth_or_array_layers: u32 = 1,
    usage: TextureUsage = .{ .shader_read = true },
    ownership: ExternalResourceOwnership = .borrowed,

    pub fn validate(
        self: ExternalTextureDescriptor,
        selected_backend: Backend,
        features: DeviceFeatures,
    ) (AdvancedFeatureError || TextureError)!void {
        if (!features.external_textures) return AdvancedFeatureError.UnsupportedExternalTextures;
        try self.handle.validateForBackend(selected_backend);
        try (TextureDescriptor{
            .format = self.format,
            .width = self.width,
            .height = self.height,
            .depth_or_array_layers = self.depth_or_array_layers,
            .usage = self.usage,
        }).validate();
    }

    pub fn textureDescriptor(self: ExternalTextureDescriptor) TextureDescriptor {
        return .{
            .label = self.label,
            .format = self.format,
            .width = self.width,
            .height = self.height,
            .depth_or_array_layers = self.depth_or_array_layers,
            .usage = self.usage,
        };
    }
};

pub const ExternalSemaphoreDescriptor = struct {
    handle: ExternalHandleDescriptor,
    timeline: bool = false,
    ownership: ExternalResourceOwnership = .borrowed,

    pub fn validate(
        self: ExternalSemaphoreDescriptor,
        selected_backend: Backend,
        features: DeviceFeatures,
    ) AdvancedFeatureError!void {
        if (!features.external_semaphores) return AdvancedFeatureError.UnsupportedExternalSemaphores;
        try self.handle.validateForBackend(selected_backend);
    }
};

pub const ExternalEventDescriptor = struct {
    handle: ExternalHandleDescriptor,
    shared: bool = true,
    ownership: ExternalResourceOwnership = .borrowed,

    pub fn validate(
        self: ExternalEventDescriptor,
        selected_backend: Backend,
        features: DeviceFeatures,
    ) AdvancedFeatureError!void {
        if (!features.external_semaphores) return AdvancedFeatureError.UnsupportedExternalSemaphores;
        try self.handle.validateForBackend(selected_backend);
    }
};

pub const TextureViewDescriptor = struct {
    label: ?[]const u8 = null,
    format: TextureFormat = .automatic,
    dimension: TextureViewDimension = .automatic,
    base_mip_level: u32 = 0,
    mip_level_count: u32 = 0,
    base_array_layer: u32 = 0,
    array_layer_count: u32 = 0,

    pub fn resolveForTexture(
        self: TextureViewDescriptor,
        texture: TextureDescriptor,
    ) TextureError!ResolvedTextureViewDescriptor {
        try texture.validate();

        const format = if (self.format == .automatic) texture.format else self.format;
        if (format != texture.format) return TextureError.UnsupportedTextureViewFormat;

        if (self.base_mip_level >= texture.mip_level_count) {
            return TextureError.InvalidTextureViewRange;
        }
        const mip_level_count = if (self.mip_level_count == 0)
            texture.mip_level_count - self.base_mip_level
        else
            self.mip_level_count;
        if (mip_level_count == 0 or self.base_mip_level + mip_level_count > texture.mip_level_count) {
            return TextureError.InvalidTextureViewRange;
        }

        const dimension = if (self.dimension == .automatic)
            defaultViewDimension(texture)
        else
            self.dimension;

        const layer_limit: u32 = switch (texture.dimension) {
            .one_d, .two_d => texture.depth_or_array_layers,
            .three_d => 1,
        };
        if (self.base_array_layer >= layer_limit) {
            return TextureError.InvalidTextureViewRange;
        }
        const array_layer_count = if (self.array_layer_count == 0)
            layer_limit - self.base_array_layer
        else
            self.array_layer_count;
        if (array_layer_count == 0 or self.base_array_layer + array_layer_count > layer_limit) {
            return TextureError.InvalidTextureViewRange;
        }

        try validateViewDimension(texture.dimension, dimension, array_layer_count);

        return .{
            .format = format,
            .dimension = dimension,
            .base_mip_level = self.base_mip_level,
            .mip_level_count = mip_level_count,
            .base_array_layer = self.base_array_layer,
            .array_layer_count = array_layer_count,
        };
    }
};

pub const ResolvedTextureViewDescriptor = struct {
    format: TextureFormat,
    dimension: TextureViewDimension,
    base_mip_level: u32,
    mip_level_count: u32,
    base_array_layer: u32,
    array_layer_count: u32,
};

pub const Origin3D = struct {
    x: u32 = 0,
    y: u32 = 0,
    z: u32 = 0,
};

pub const Size3D = struct {
    width: u32,
    height: u32 = 1,
    depth: u32 = 1,

    pub fn isZero(self: Size3D) bool {
        return self.width == 0 or self.height == 0 or self.depth == 0;
    }
};

pub const Region3D = struct {
    origin: Origin3D = .{},
    size: Size3D,
};

pub const TextureRegion = Region3D;

pub const SparseResidency = enum {
    resident,
    evicted,
};

pub const SparseBufferDescriptor = struct {
    label: ?[]const u8 = null,
    size: u64,
    page_size: u64 = 0,
    usage: BufferUsage = .{ .storage = true },

    pub fn resolvedPageSize(self: SparseBufferDescriptor, limits: DeviceLimits) u64 {
        return if (self.page_size != 0) self.page_size else limits.sparse_buffer_page_size;
    }

    pub fn pageCount(self: SparseBufferDescriptor, limits: DeviceLimits) AdvancedFeatureError!u64 {
        const resolved_page_size = self.resolvedPageSize(limits);
        if (resolved_page_size == 0) return AdvancedFeatureError.InvalidSparsePageSize;
        if (self.size == 0 or !isAlignedU64(self.size, resolved_page_size)) return AdvancedFeatureError.InvalidSparseRegion;
        return self.size / resolved_page_size;
    }

    pub fn validate(self: SparseBufferDescriptor, features: DeviceFeatures, limits: DeviceLimits) AdvancedFeatureError!void {
        if (!features.sparse_buffers) return AdvancedFeatureError.UnsupportedSparseBuffers;
        _ = try self.pageCount(limits);
    }
};

pub const SparseBufferLoweringMode = enum {
    vulkan_sparse_binding,
    metal_sparse_binding,
};

pub const SparseBufferLowering = struct {
    backend: Backend,
    mode: SparseBufferLoweringMode,
    size: u64,
    page_size: u64,
    page_count: u64,
    usage: BufferUsage,
    requires_residency_commit: bool = true,

    pub fn fromDescriptor(
        backend: Backend,
        descriptor: SparseBufferDescriptor,
        native_features: DeviceFeatures,
        limits: DeviceLimits,
    ) AdvancedFeatureError!SparseBufferLowering {
        try descriptor.validate(native_features, limits);
        const page_size = descriptor.resolvedPageSize(limits);
        return .{
            .backend = backend,
            .mode = switch (backend) {
                .vulkan => .vulkan_sparse_binding,
                .metal => .metal_sparse_binding,
            },
            .size = descriptor.size,
            .page_size = page_size,
            .page_count = try descriptor.pageCount(limits),
            .usage = descriptor.usage,
        };
    }
};

pub const SparseBufferMappingDescriptor = struct {
    offset: u64 = 0,
    size: u64 = 0,
    page_size: u64 = 0,
    residency: SparseResidency = .resident,

    pub fn validate(self: SparseBufferMappingDescriptor, features: DeviceFeatures, limits: DeviceLimits) AdvancedFeatureError!void {
        if (!features.sparse_buffers) return AdvancedFeatureError.UnsupportedSparseBuffers;
        const page_size = if (self.page_size != 0) self.page_size else limits.sparse_buffer_page_size;
        if (page_size == 0) return AdvancedFeatureError.InvalidSparsePageSize;
        if (self.size == 0) return AdvancedFeatureError.InvalidSparseRegion;
        if (!isAlignedU64(self.offset, page_size) or !isAlignedU64(self.size, page_size)) {
            return AdvancedFeatureError.InvalidSparseRegion;
        }
    }
};

pub const SparseTextureKind = enum {
    sparse_texture,
    tiled_texture,
};

pub const SparseTextureDescriptor = struct {
    label: ?[]const u8 = null,
    kind: SparseTextureKind = .sparse_texture,
    texture: TextureDescriptor,
    page_extent: Size3D,

    pub fn pageGrid(self: SparseTextureDescriptor) AdvancedFeatureError!Size3D {
        if (self.page_extent.isZero()) return AdvancedFeatureError.InvalidSparsePageSize;
        self.texture.validate() catch return AdvancedFeatureError.InvalidSparseRegion;
        return .{
            .width = sparseCeilDivU32(self.texture.width, self.page_extent.width),
            .height = sparseCeilDivU32(self.texture.height, self.page_extent.height),
            .depth = sparseCeilDivU32(self.texture.depth_or_array_layers, self.page_extent.depth),
        };
    }

    pub fn validate(self: SparseTextureDescriptor, features: DeviceFeatures, limits: DeviceLimits) (AdvancedFeatureError || TextureError)!void {
        switch (self.kind) {
            .sparse_texture => if (!features.sparse_textures) return AdvancedFeatureError.UnsupportedSparseTextures,
            .tiled_texture => if (!features.tiled_textures) return AdvancedFeatureError.UnsupportedTiledTextures,
        }
        try self.texture.validate();
        if (self.page_extent.isZero()) return AdvancedFeatureError.InvalidSparsePageSize;
        if (limits.sparse_texture_page_width != 0 and self.page_extent.width != limits.sparse_texture_page_width) {
            return AdvancedFeatureError.InvalidSparsePageSize;
        }
        if (limits.sparse_texture_page_height != 0 and self.page_extent.height != limits.sparse_texture_page_height) {
            return AdvancedFeatureError.InvalidSparsePageSize;
        }
        if (limits.sparse_texture_page_depth != 0 and self.page_extent.depth != limits.sparse_texture_page_depth) {
            return AdvancedFeatureError.InvalidSparsePageSize;
        }
    }
};

pub const SparseTextureLoweringMode = enum {
    vulkan_sparse_image,
    metal_sparse_texture,
    metal_tiled_texture,
};

pub const SparseTextureLowering = struct {
    backend: Backend,
    mode: SparseTextureLoweringMode,
    kind: SparseTextureKind,
    format: TextureFormat,
    extent: Size3D,
    page_extent: Size3D,
    page_grid: Size3D,
    mip_level_count: u32,
    requires_residency_commit: bool = true,

    pub fn fromDescriptor(
        backend: Backend,
        descriptor: SparseTextureDescriptor,
        native_features: DeviceFeatures,
        limits: DeviceLimits,
    ) (AdvancedFeatureError || TextureError)!SparseTextureLowering {
        try descriptor.validate(native_features, limits);
        return .{
            .backend = backend,
            .mode = switch (backend) {
                .vulkan => .vulkan_sparse_image,
                .metal => switch (descriptor.kind) {
                    .sparse_texture => .metal_sparse_texture,
                    .tiled_texture => .metal_tiled_texture,
                },
            },
            .kind = descriptor.kind,
            .format = descriptor.texture.format,
            .extent = .{
                .width = descriptor.texture.width,
                .height = descriptor.texture.height,
                .depth = descriptor.texture.depth_or_array_layers,
            },
            .page_extent = descriptor.page_extent,
            .page_grid = try descriptor.pageGrid(),
            .mip_level_count = descriptor.texture.mip_level_count,
        };
    }
};

pub const SparseMipTailDescriptor = struct {
    first_mip_level: u32,
    offset: u64 = 0,
    size: u64,
    stride: u64 = 0,
    is_packed: bool = true,

    pub fn validate(self: SparseMipTailDescriptor, texture: TextureDescriptor, page_size: u64) AdvancedFeatureError!void {
        if (page_size == 0) return AdvancedFeatureError.InvalidSparsePageSize;
        if (self.size == 0) return AdvancedFeatureError.InvalidSparseRegion;
        if (self.first_mip_level >= texture.maxMipLevelCount()) return AdvancedFeatureError.InvalidSparseRegion;
        if (!isAlignedU64(self.offset, page_size) or !isAlignedU64(self.size, page_size)) {
            return AdvancedFeatureError.InvalidSparseRegion;
        }
        if (!self.is_packed and self.stride == 0) return AdvancedFeatureError.InvalidSparseRegion;
        if (self.stride != 0 and !isAlignedU64(self.stride, page_size)) return AdvancedFeatureError.InvalidSparseRegion;
    }
};

pub const SparseTextureMappingDescriptor = struct {
    kind: SparseTextureKind = .sparse_texture,
    region: Region3D,
    mip_level: u32 = 0,
    array_layer: u32 = 0,
    page_extent: Size3D,
    residency: SparseResidency = .resident,

    pub fn validate(self: SparseTextureMappingDescriptor, features: DeviceFeatures, limits: DeviceLimits) AdvancedFeatureError!void {
        switch (self.kind) {
            .sparse_texture => if (!features.sparse_textures) return AdvancedFeatureError.UnsupportedSparseTextures,
            .tiled_texture => if (!features.tiled_textures) return AdvancedFeatureError.UnsupportedTiledTextures,
        }
        if (self.region.size.isZero() or self.page_extent.isZero()) return AdvancedFeatureError.InvalidSparseRegion;
        if (limits.sparse_texture_page_width != 0 and self.page_extent.width != limits.sparse_texture_page_width) {
            return AdvancedFeatureError.InvalidSparsePageSize;
        }
        if (limits.sparse_texture_page_height != 0 and self.page_extent.height != limits.sparse_texture_page_height) {
            return AdvancedFeatureError.InvalidSparsePageSize;
        }
        if (limits.sparse_texture_page_depth != 0 and self.page_extent.depth != limits.sparse_texture_page_depth) {
            return AdvancedFeatureError.InvalidSparsePageSize;
        }
        if (!isAlignedU32(self.region.origin.x, self.page_extent.width) or
            !isAlignedU32(self.region.origin.y, self.page_extent.height) or
            !isAlignedU32(self.region.origin.z, self.page_extent.depth) or
            !isAlignedU32(self.region.size.width, self.page_extent.width) or
            !isAlignedU32(self.region.size.height, self.page_extent.height) or
            !isAlignedU32(self.region.size.depth, self.page_extent.depth))
        {
            return AdvancedFeatureError.InvalidSparseRegion;
        }
    }

    pub fn pageCount(self: SparseTextureMappingDescriptor) AdvancedFeatureError!u64 {
        try self.validate(.{ .sparse_textures = true, .tiled_textures = true }, .{});
        const width_pages = sparseCeilDivU32(self.region.size.width, self.page_extent.width);
        const height_pages = sparseCeilDivU32(self.region.size.height, self.page_extent.height);
        const depth_pages = sparseCeilDivU32(self.region.size.depth, self.page_extent.depth);
        return @as(u64, width_pages) * @as(u64, height_pages) * @as(u64, depth_pages);
    }
};

pub const SparseMappingCommitPlan = struct {
    total_regions: usize = 0,
    buffer_commits: usize = 0,
    buffer_evictions: usize = 0,
    texture_commits: usize = 0,
    texture_evictions: usize = 0,
    buffer_bytes: u64 = 0,
    texture_pages: u64 = 0,

    pub fn hasEvictions(self: SparseMappingCommitPlan) bool {
        return self.buffer_evictions != 0 or self.texture_evictions != 0;
    }
};

pub const SparseMappingCommitDescriptor = struct {
    buffers: []const SparseBufferMappingDescriptor = &.{},
    textures: []const SparseTextureMappingDescriptor = &.{},

    pub fn validate(self: SparseMappingCommitDescriptor, features: DeviceFeatures, limits: DeviceLimits) AdvancedFeatureError!void {
        const count = self.buffers.len + self.textures.len;
        if (count == 0) return AdvancedFeatureError.InvalidSparseRegion;
        if (limits.max_sparse_regions_per_commit != 0 and count > limits.max_sparse_regions_per_commit) {
            return AdvancedFeatureError.SparseRegionCountExceeded;
        }
        for (self.buffers) |buffer| try buffer.validate(features, limits);
        for (self.textures) |texture| try texture.validate(features, limits);
    }

    pub fn plan(self: SparseMappingCommitDescriptor, features: DeviceFeatures, limits: DeviceLimits) AdvancedFeatureError!SparseMappingCommitPlan {
        try self.validate(features, limits);
        var result = SparseMappingCommitPlan{
            .total_regions = self.buffers.len + self.textures.len,
        };
        for (self.buffers) |buffer| {
            switch (buffer.residency) {
                .resident => result.buffer_commits += 1,
                .evicted => result.buffer_evictions += 1,
            }
            result.buffer_bytes = result.buffer_bytes +| buffer.size;
        }
        for (self.textures) |texture| {
            switch (texture.residency) {
                .resident => result.texture_commits += 1,
                .evicted => result.texture_evictions += 1,
            }
            result.texture_pages = result.texture_pages +| (texture.pageCount() catch return AdvancedFeatureError.InvalidSparseRegion);
        }
        return result;
    }
};

pub const SparseResidencyDiagnostics = struct {
    buffer_regions: usize = 0,
    texture_regions: usize = 0,
    resident_buffer_bytes: u64 = 0,
    resident_texture_pages: u64 = 0,
};

pub const SparseResidencyMap = struct {
    allocator: std.mem.Allocator,
    buffers: std.ArrayListUnmanaged(SparseBufferMappingDescriptor) = .empty,
    textures: std.ArrayListUnmanaged(SparseTextureMappingDescriptor) = .empty,

    pub fn init(allocator: std.mem.Allocator) SparseResidencyMap {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *SparseResidencyMap) void {
        self.buffers.deinit(self.allocator);
        self.textures.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn diagnostics(self: SparseResidencyMap) SparseResidencyDiagnostics {
        var resident_buffer_bytes: u64 = 0;
        var resident_texture_pages: u64 = 0;
        for (self.buffers.items) |buffer| {
            resident_buffer_bytes = resident_buffer_bytes +| buffer.size;
        }
        for (self.textures.items) |texture| {
            resident_texture_pages = resident_texture_pages +| (texture.pageCount() catch 0);
        }
        return .{
            .buffer_regions = self.buffers.items.len,
            .texture_regions = self.textures.items.len,
            .resident_buffer_bytes = resident_buffer_bytes,
            .resident_texture_pages = resident_texture_pages,
        };
    }

    pub fn apply(self: *SparseResidencyMap, descriptor: SparseMappingCommitDescriptor) AdvancedFeatureError!void {
        for (descriptor.buffers) |mapping| try self.applyBuffer(mapping);
        for (descriptor.textures) |mapping| try self.applyTexture(mapping);
    }

    fn applyBuffer(self: *SparseResidencyMap, mapping: SparseBufferMappingDescriptor) AdvancedFeatureError!void {
        switch (mapping.residency) {
            .resident => {
                for (self.buffers.items) |existing| {
                    if (bufferRangesOverlap(existing, mapping)) return AdvancedFeatureError.InvalidSparseRegion;
                }
                self.buffers.append(self.allocator, mapping) catch return AdvancedFeatureError.InvalidSparseRegion;
            },
            .evicted => {
                const index = self.findBuffer(mapping) orelse return AdvancedFeatureError.InvalidSparseRegion;
                _ = self.buffers.swapRemove(index);
            },
        }
    }

    fn applyTexture(self: *SparseResidencyMap, mapping: SparseTextureMappingDescriptor) AdvancedFeatureError!void {
        switch (mapping.residency) {
            .resident => {
                for (self.textures.items) |existing| {
                    if (textureRegionsOverlap(existing, mapping)) return AdvancedFeatureError.InvalidSparseRegion;
                }
                self.textures.append(self.allocator, mapping) catch return AdvancedFeatureError.InvalidSparseRegion;
            },
            .evicted => {
                const index = self.findTexture(mapping) orelse return AdvancedFeatureError.InvalidSparseRegion;
                _ = self.textures.swapRemove(index);
            },
        }
    }

    fn findBuffer(self: SparseResidencyMap, mapping: SparseBufferMappingDescriptor) ?usize {
        for (self.buffers.items, 0..) |existing, i| {
            if (existing.offset == mapping.offset and existing.size == mapping.size) return i;
        }
        return null;
    }

    fn findTexture(self: SparseResidencyMap, mapping: SparseTextureMappingDescriptor) ?usize {
        for (self.textures.items, 0..) |existing, i| {
            if (existing.kind == mapping.kind and
                existing.mip_level == mapping.mip_level and
                existing.array_layer == mapping.array_layer and
                regionsEqual(existing.region, mapping.region))
            {
                return i;
            }
        }
        return null;
    }
};

fn bufferRangesOverlap(a: SparseBufferMappingDescriptor, b: SparseBufferMappingDescriptor) bool {
    const a_end = a.offset + a.size;
    const b_end = b.offset + b.size;
    return a.offset < b_end and b.offset < a_end;
}

fn textureRegionsOverlap(a: SparseTextureMappingDescriptor, b: SparseTextureMappingDescriptor) bool {
    if (a.kind != b.kind or a.mip_level != b.mip_level or a.array_layer != b.array_layer) return false;
    return regionsOverlap(a.region, b.region);
}

fn regionsEqual(a: Region3D, b: Region3D) bool {
    return a.origin.x == b.origin.x and
        a.origin.y == b.origin.y and
        a.origin.z == b.origin.z and
        a.size.width == b.size.width and
        a.size.height == b.size.height and
        a.size.depth == b.size.depth;
}

fn regionsOverlap(a: Region3D, b: Region3D) bool {
    return rangesOverlapU32(a.origin.x, a.size.width, b.origin.x, b.size.width) and
        rangesOverlapU32(a.origin.y, a.size.height, b.origin.y, b.size.height) and
        rangesOverlapU32(a.origin.z, a.size.depth, b.origin.z, b.size.depth);
}

fn rangesOverlapU32(a_origin: u32, a_size: u32, b_origin: u32, b_size: u32) bool {
    const a_end = a_origin + a_size;
    const b_end = b_origin + b_size;
    return a_origin < b_end and b_origin < a_end;
}

pub const TextureReplaceRegionDescriptor = struct {
    bytes: []const u8,
    mip_level: u32 = 0,
    slice: u32 = 0,
    bytes_per_row: usize = 0,
    bytes_per_image: usize = 0,

    pub fn resolveForTexture(
        self: TextureReplaceRegionDescriptor,
        texture: TextureDescriptor,
        region: Region3D,
    ) TextureError!ResolvedTextureReplaceRegion {
        try texture.validate();
        if (!isColorFormat(texture.format)) return TextureError.UnsupportedTextureUploadFormat;
        if (texture.sample_count != 1) return TextureError.UnsupportedTextureUploadFormat;
        if (region.size.isZero()) return TextureError.InvalidTextureRegion;
        if (self.bytes.len == 0) return TextureError.UploadBytesTooSmall;
        if (self.mip_level >= texture.mip_level_count) return TextureError.InvalidTextureRegion;

        const mip_width = mipDimension(texture.width, self.mip_level);
        const mip_height = mipDimension(texture.height, self.mip_level);
        const mip_depth = mipDimension(texture.depth_or_array_layers, self.mip_level);

        switch (texture.dimension) {
            .one_d => {
                if (region.origin.y != 0 or region.origin.z != 0 or
                    region.size.height != 1 or region.size.depth != 1)
                {
                    return TextureError.InvalidTextureRegion;
                }
                try validateRange(region.origin.x, region.size.width, mip_width);
                if (self.slice >= texture.depth_or_array_layers) return TextureError.InvalidTextureSlice;
            },
            .two_d => {
                if (region.origin.z != 0 or region.size.depth != 1) {
                    return TextureError.InvalidTextureRegion;
                }
                try validateRange(region.origin.x, region.size.width, mip_width);
                try validateRange(region.origin.y, region.size.height, mip_height);
                if (self.slice >= texture.depth_or_array_layers) return TextureError.InvalidTextureSlice;
            },
            .three_d => {
                if (self.slice != 0) return TextureError.InvalidTextureSlice;
                try validateRange(region.origin.x, region.size.width, mip_width);
                try validateRange(region.origin.y, region.size.height, mip_height);
                try validateRange(region.origin.z, region.size.depth, mip_depth);
            },
        }

        const bytes_per_pixel = textureFormatBytesPerPixel(texture.format);
        const tight_row_bytes = checkedMul(usize, region.size.width, bytes_per_pixel) catch {
            return TextureError.TextureUploadSizeOverflow;
        };
        const bytes_per_row = if (self.bytes_per_row == 0) tight_row_bytes else self.bytes_per_row;
        if (bytes_per_row < tight_row_bytes or bytes_per_row % bytes_per_pixel != 0) {
            return TextureError.InvalidBytesPerRow;
        }

        const tight_image_bytes = checkedMul(usize, bytes_per_row, region.size.height) catch {
            return TextureError.TextureUploadSizeOverflow;
        };
        const bytes_per_image = if (self.bytes_per_image == 0) tight_image_bytes else self.bytes_per_image;
        if (bytes_per_image < tight_image_bytes or bytes_per_image % bytes_per_row != 0) {
            return TextureError.InvalidBytesPerImage;
        }

        const required_bytes = requiredUploadBytes(
            region.size.width,
            region.size.height,
            region.size.depth,
            bytes_per_pixel,
            bytes_per_row,
            bytes_per_image,
        ) catch return TextureError.TextureUploadSizeOverflow;
        if (self.bytes.len < required_bytes) return TextureError.UploadBytesTooSmall;

        return .{
            .region = region,
            .mip_level = self.mip_level,
            .slice = self.slice,
            .bytes = self.bytes,
            .bytes_per_row = bytes_per_row,
            .bytes_per_image = bytes_per_image,
            .bytes_per_pixel = bytes_per_pixel,
            .required_bytes = required_bytes,
        };
    }
};

pub const ResolvedTextureReplaceRegion = struct {
    region: Region3D,
    mip_level: u32,
    slice: u32,
    bytes: []const u8,
    bytes_per_row: usize,
    bytes_per_image: usize,
    bytes_per_pixel: usize,
    required_bytes: usize,
};

pub const TextureUpload2DDescriptor = struct {
    bytes: []const u8,
    mip_level: u32 = 0,
    slice: u32 = 0,
    bytes_per_row: usize = 0,

    pub fn asReplaceRegionDescriptor(self: TextureUpload2DDescriptor) TextureReplaceRegionDescriptor {
        return .{
            .bytes = self.bytes,
            .mip_level = self.mip_level,
            .slice = self.slice,
            .bytes_per_row = self.bytes_per_row,
        };
    }
};

pub const GenerateMipmapsDescriptor = struct {
    base_mip_level: u32 = 0,
    mip_level_count: u32 = 0,
    base_array_layer: u32 = 0,
    array_layer_count: u32 = 0,

    pub fn resolveForTexture(
        self: GenerateMipmapsDescriptor,
        texture: TextureDescriptor,
    ) TextureError!ResolvedGenerateMipmapsDescriptor {
        try texture.validate();
        const caps = defaultFormatCapabilities(texture.format);
        if (!caps.mipmap_generation) return TextureError.UnsupportedMipmapGeneration;
        if (texture.sample_count != 1) return TextureError.UnsupportedMipmapGeneration;
        if (!texture.usage.copy_source or !texture.usage.copy_destination) return TextureError.UnsupportedMipmapGeneration;
        if (texture.mip_level_count < 2) return TextureError.InvalidMipLevelCount;

        if (self.base_mip_level >= texture.mip_level_count - 1) return TextureError.InvalidMipLevelCount;
        const mip_level_count = if (self.mip_level_count == 0)
            texture.mip_level_count - self.base_mip_level
        else
            self.mip_level_count;
        if (mip_level_count < 2 or self.base_mip_level + mip_level_count > texture.mip_level_count) {
            return TextureError.InvalidMipLevelCount;
        }

        const layer_limit: u32 = switch (texture.dimension) {
            .one_d, .two_d => texture.depth_or_array_layers,
            .three_d => 1,
        };
        if (self.base_array_layer >= layer_limit) return TextureError.InvalidTextureViewRange;
        const array_layer_count = if (self.array_layer_count == 0)
            layer_limit - self.base_array_layer
        else
            self.array_layer_count;
        if (array_layer_count == 0 or self.base_array_layer + array_layer_count > layer_limit) {
            return TextureError.InvalidTextureViewRange;
        }

        return .{
            .base_mip_level = self.base_mip_level,
            .mip_level_count = mip_level_count,
            .base_array_layer = self.base_array_layer,
            .array_layer_count = array_layer_count,
        };
    }
};

pub const ResolvedGenerateMipmapsDescriptor = struct {
    base_mip_level: u32,
    mip_level_count: u32,
    base_array_layer: u32,
    array_layer_count: u32,
};

pub const BufferTextureCopyLayout = struct {
    buffer_offset: u64 = 0,
    bytes_per_row: usize = 0,
    bytes_per_image: usize = 0,
};

pub const CopyBufferToTextureDescriptor = struct {
    source: BufferTextureCopyLayout = .{},
    destination_region: Region3D,
    destination_mip_level: u32 = 0,
    destination_slice: u32 = 0,

    pub fn resolve(
        self: CopyBufferToTextureDescriptor,
        source_length: usize,
        destination: TextureDescriptor,
    ) CommandEncodingError!ResolvedBufferTextureCopy {
        return try resolveBufferTextureCopy(
            source_length,
            destination,
            self.destination_region,
            self.destination_mip_level,
            self.destination_slice,
            self.source,
        );
    }
};

pub const CopyTextureToBufferDescriptor = struct {
    source_region: Region3D,
    source_mip_level: u32 = 0,
    source_slice: u32 = 0,
    destination: BufferTextureCopyLayout = .{},

    pub fn resolve(
        self: CopyTextureToBufferDescriptor,
        source: TextureDescriptor,
        destination_length: usize,
    ) CommandEncodingError!ResolvedBufferTextureCopy {
        return try resolveBufferTextureCopy(
            destination_length,
            source,
            self.source_region,
            self.source_mip_level,
            self.source_slice,
            self.destination,
        );
    }
};

pub const CopyTextureToTextureDescriptor = struct {
    source_region: Region3D,
    source_mip_level: u32 = 0,
    source_slice: u32 = 0,
    slice_count: u32 = 1,
    destination_origin: Origin3D = .{},
    destination_mip_level: u32 = 0,
    destination_slice: u32 = 0,

    pub fn resolve(
        self: CopyTextureToTextureDescriptor,
        source: TextureDescriptor,
        destination: TextureDescriptor,
    ) CommandEncodingError!ResolvedTextureTextureCopy {
        return try resolveTextureTextureCopy(self, source, destination);
    }
};

pub const ResolvedBufferTextureCopy = struct {
    buffer_offset: u64,
    bytes_per_row: usize,
    bytes_per_image: usize,
    bytes_per_pixel: usize,
    required_bytes: usize,
    region: Region3D,
    mip_level: u32,
    slice: u32,
};

pub const ResolvedTextureTextureCopy = struct {
    source_region: Region3D,
    source_mip_level: u32,
    source_slice: u32,
    slice_count: u32,
    destination_origin: Origin3D,
    destination_mip_level: u32,
    destination_slice: u32,
};

pub const TextureError = error{
    InvalidTextureExtent,
    InvalidTextureFormat,
    InvalidMipLevelCount,
    InvalidSampleCount,
    UnsupportedSampleCount,
    InvalidTextureViewRange,
    UnsupportedTextureViewDimension,
    UnsupportedTextureViewFormat,
    InvalidTextureRegion,
    InvalidTextureSlice,
    InvalidBytesPerRow,
    InvalidBytesPerImage,
    UploadBytesTooSmall,
    TextureUploadSizeOverflow,
    UnsupportedTextureUploadFormat,
    UnsupportedMipmapGeneration,
};

pub const SamplerMinMagFilter = enum {
    nearest,
    linear,
};

pub const SamplerMipFilter = enum {
    not_mipmapped,
    nearest,
    linear,
};

pub const SamplerAddressMode = enum {
    clamp_to_edge,
    clamp_to_border,
    repeat,
    mirror_repeat,
};

pub const SamplerBorderColor = enum {
    transparent_black,
    opaque_black,
    opaque_white,
};

pub const SamplerDescriptor = struct {
    label: ?[]const u8 = null,
    min_filter: SamplerMinMagFilter = .nearest,
    mag_filter: SamplerMinMagFilter = .nearest,
    mip_filter: SamplerMipFilter = .not_mipmapped,
    address_mode_u: SamplerAddressMode = .clamp_to_edge,
    address_mode_v: SamplerAddressMode = .clamp_to_edge,
    address_mode_w: SamplerAddressMode = .clamp_to_edge,
    lod_min_clamp: f32 = 0,
    lod_max_clamp: f32 = 32,
    compare_function: ?CompareFunction = null,
    max_anisotropy: f32 = 1,
    border_color: ?SamplerBorderColor = null,
    cache_policy: ObjectCachePolicy = .{},

    pub fn validate(self: SamplerDescriptor) SamplerError!void {
        if (self.lod_min_clamp > self.lod_max_clamp) return SamplerError.InvalidLodRange;
        if (self.max_anisotropy < 1) return SamplerError.InvalidMaxAnisotropy;
    }

    pub fn validateForDevice(
        self: SamplerDescriptor,
        features: DeviceFeatures,
        limits: DeviceLimits,
    ) SamplerError!void {
        try self.validate();
        if (self.compare_function != null and !features.sampler_compare) {
            return SamplerError.UnsupportedCompareSampler;
        }
        if (self.max_anisotropy > 1) {
            if (!features.sampler_anisotropy) return SamplerError.UnsupportedSamplerAnisotropy;
            if (self.max_anisotropy > limits.max_sampler_anisotropy) return SamplerError.InvalidMaxAnisotropy;
        }
        if ((self.border_color != null or
            self.address_mode_u == .clamp_to_border or
            self.address_mode_v == .clamp_to_border or
            self.address_mode_w == .clamp_to_border) and !features.sampler_border_color)
        {
            return SamplerError.UnsupportedSamplerBorderColor;
        }
    }
};

pub const SamplerCacheKeyDescriptor = struct {
    descriptor: SamplerDescriptor = .{},
    policy: ObjectCachePolicy = .{},

    pub fn validate(self: SamplerCacheKeyDescriptor) SamplerError!void {
        try self.descriptor.validate();
    }

    pub fn validateForDevice(
        self: SamplerCacheKeyDescriptor,
        features: DeviceFeatures,
        limits: DeviceLimits,
    ) SamplerError!void {
        try self.descriptor.validateForDevice(features, limits);
    }
};

pub const SamplerError = error{
    InvalidLodRange,
    InvalidMaxAnisotropy,
    UnsupportedCompareSampler,
    UnsupportedSamplerAnisotropy,
    UnsupportedSamplerBorderColor,
};

pub const HeapStorageMode = enum {
    automatic,
    device_local,
    cpu_visible,
};

pub const HeapDescriptor = struct {
    label: ?[]const u8 = null,
    size: u64 = 0,
    storage_mode: HeapStorageMode = .automatic,

    pub fn validate(self: HeapDescriptor, features: DeviceFeatures) HeapError!void {
        if (!features.heaps) return HeapError.UnsupportedHeaps;
        if (self.size == 0) return HeapError.InvalidHeapSize;
    }
};

pub const HeapAllocationDescriptor = struct {
    size: u64 = 0,
    alignment: u64 = 1,

    pub fn validate(self: HeapAllocationDescriptor, heap: HeapDescriptor) HeapError!void {
        if (self.size == 0) return HeapError.InvalidHeapSize;
        if (self.alignment == 0) return HeapError.InvalidHeapAlignment;
        if (self.size > heap.size) return HeapError.HeapOutOfMemory;
    }
};

pub const HeapAllocationInfo = struct {
    offset: u64,
    size: u64,
    alignment: u64,
};

pub const HeapError = error{
    InvalidHeapSize,
    InvalidHeapAlignment,
    UnsupportedHeaps,
    HeapOutOfMemory,
};

pub const ShaderVisibility = struct {
    vertex: bool = false,
    fragment: bool = false,
    compute: bool = false,

    pub fn isEmpty(self: ShaderVisibility) bool {
        return !self.vertex and !self.fragment and !self.compute;
    }
};

pub const BindingLocation = struct {
    group: u32,
    binding: u32,
};

pub const BindingResourceKind = enum {
    uniform_buffer,
    storage_buffer,
    storage_texture,
    sampled_texture,
    sampler,
    compare_sampler,

    pub fn isBuffer(self: BindingResourceKind) bool {
        return switch (self) {
            .uniform_buffer, .storage_buffer => true,
            .storage_texture, .sampled_texture, .sampler, .compare_sampler => false,
        };
    }

    pub fn isTexture(self: BindingResourceKind) bool {
        return switch (self) {
            .storage_texture, .sampled_texture => true,
            .uniform_buffer, .storage_buffer, .sampler, .compare_sampler => false,
        };
    }

    pub fn isSampler(self: BindingResourceKind) bool {
        return self == .sampler or self == .compare_sampler;
    }

    pub fn isWritable(self: BindingResourceKind) bool {
        return switch (self) {
            .storage_buffer, .storage_texture => true,
            .uniform_buffer, .sampled_texture, .sampler, .compare_sampler => false,
        };
    }
};

pub const StorageAccess = enum {
    read,
    write,
    read_write,

    pub fn requiresRead(self: StorageAccess) bool {
        return self == .read or self == .read_write;
    }

    pub fn requiresWrite(self: StorageAccess) bool {
        return self == .write or self == .read_write;
    }
};

pub const BindGroupLayoutEntry = struct {
    binding: u32,
    resource: BindingResourceKind,
    visibility: ShaderVisibility,
    array_count: u32 = 1,
    dynamic_offset: bool = false,
    storage_access: ?StorageAccess = null,

    pub fn validate(self: BindGroupLayoutEntry) BindingError!void {
        if (self.visibility.isEmpty()) return BindingError.EmptyShaderVisibility;
        if (self.array_count == 0) return BindingError.InvalidBindingArrayCount;
        if (self.dynamic_offset and !self.resource.isBuffer()) return BindingError.InvalidDynamicBindingResource;
        if (self.storage_access != null and self.resource != .storage_buffer and self.resource != .storage_texture) {
            return BindingError.InvalidStorageAccess;
        }
        if (self.resource == .storage_texture and (self.visibility.vertex or self.visibility.fragment or !self.visibility.compute)) {
            return BindingError.InvalidStorageTextureVisibility;
        }
    }

    pub fn resolvedStorageAccess(self: BindGroupLayoutEntry) ?StorageAccess {
        return switch (self.resource) {
            .storage_buffer => self.storage_access orelse .read_write,
            .storage_texture => self.storage_access orelse .write,
            .uniform_buffer, .sampled_texture, .sampler, .compare_sampler => null,
        };
    }
};

pub const BindGroupLayoutDescriptor = struct {
    label: ?[]const u8 = null,
    entries: []const BindGroupLayoutEntry = &.{},
    cache_policy: ObjectCachePolicy = .{},

    pub fn validate(self: BindGroupLayoutDescriptor) BindingError!void {
        if (self.entries.len == 0) return BindingError.MissingBindGroupLayoutEntry;

        for (self.entries, 0..) |entry, i| {
            try entry.validate();
            for (self.entries[i + 1 ..]) |other| {
                if (entry.binding == other.binding) return BindingError.DuplicateBinding;
            }
        }
    }

    pub fn entryForBinding(self: BindGroupLayoutDescriptor, binding: u32) ?BindGroupLayoutEntry {
        for (self.entries) |entry| {
            if (entry.binding == binding) return entry;
        }
        return null;
    }

    pub fn containsBinding(self: BindGroupLayoutDescriptor, binding: u32) bool {
        return self.entryForBinding(binding) != null;
    }

    pub fn locationForBinding(self: BindGroupLayoutDescriptor, group: u32, binding: u32) ?BindingLocation {
        if (!self.containsBinding(binding)) return null;
        return .{ .group = group, .binding = binding };
    }

    pub fn resourceCount(self: BindGroupLayoutDescriptor, kind: BindingResourceKind) usize {
        var count: usize = 0;
        for (self.entries) |entry| {
            if (entry.resource == kind) count += 1;
        }
        return count;
    }
};

pub const AdvancedBindingModel = enum {
    descriptor_indexing,
    argument_buffer,
};

pub const DescriptorIndexingRange = struct {
    binding: u32,
    resource: BindingResourceKind,
    visibility: ShaderVisibility,
    descriptor_count: u32 = 1,
    partially_bound: bool = false,
    update_after_bind: bool = false,

    pub fn validate(self: DescriptorIndexingRange, limits: DeviceLimits) AdvancedFeatureError!void {
        if (self.visibility.isEmpty()) return AdvancedFeatureError.EmptyDescriptorIndexingVisibility;
        if (self.descriptor_count == 0) return AdvancedFeatureError.InvalidDescriptorIndexingCount;
        if (limits.max_bindless_descriptors_per_range != 0 and self.descriptor_count > limits.max_bindless_descriptors_per_range) {
            return AdvancedFeatureError.InvalidDescriptorIndexingCount;
        }
    }
};

pub const DescriptorIndexingLayoutDescriptor = struct {
    label: ?[]const u8 = null,
    model: AdvancedBindingModel = .descriptor_indexing,
    ranges: []const DescriptorIndexingRange = &.{},

    pub fn validate(
        self: DescriptorIndexingLayoutDescriptor,
        features: DeviceFeatures,
        limits: DeviceLimits,
    ) AdvancedFeatureError!void {
        switch (self.model) {
            .descriptor_indexing => if (!features.descriptor_indexing) return AdvancedFeatureError.UnsupportedDescriptorIndexing,
            .argument_buffer => if (!features.argument_buffers) return AdvancedFeatureError.UnsupportedArgumentBuffers,
        }
        if (self.ranges.len == 0) return AdvancedFeatureError.MissingDescriptorIndexingRange;
        if (limits.max_bindless_ranges_per_layout != 0 and self.ranges.len > limits.max_bindless_ranges_per_layout) {
            return AdvancedFeatureError.DescriptorIndexingRangeCountExceeded;
        }
        for (self.ranges, 0..) |range, i| {
            try range.validate(limits);
            for (self.ranges[i + 1 ..]) |other| {
                if (range.binding == other.binding) return AdvancedFeatureError.DuplicateDescriptorIndexingBinding;
            }
        }
    }
};

pub const ResourceTableSlot = struct {
    binding: u32,
    array_element: u32 = 0,

    pub fn validate(self: ResourceTableSlot, layout: DescriptorIndexingLayoutDescriptor) BindingError!DescriptorIndexingRange {
        for (layout.ranges) |range| {
            if (range.binding != self.binding) continue;
            if (self.array_element >= range.descriptor_count) return BindingError.InvalidResourceTableSlot;
            return range;
        }
        return BindingError.InvalidResourceTableSlot;
    }
};

pub const BindGroupLayoutCacheKeyDescriptor = struct {
    entries: []const BindGroupLayoutEntry = &.{},

    pub fn validate(self: BindGroupLayoutCacheKeyDescriptor) BindingError!void {
        try self.asLayoutDescriptor().validate();
    }

    pub fn asLayoutDescriptor(self: BindGroupLayoutCacheKeyDescriptor) BindGroupLayoutDescriptor {
        return .{ .entries = self.entries };
    }
};

pub const PipelineLayoutCacheKeyDescriptor = struct {
    bind_group_layouts: []const BindGroupLayoutCacheKeyDescriptor = &.{},
    small_constants: []const SmallConstantDescriptor = &.{},
    root_constant_layout: ?RootConstantLayoutDescriptor = null,

    pub fn validate(
        self: PipelineLayoutCacheKeyDescriptor,
        features: DeviceFeatures,
        limits: DeviceLimits,
    ) (BindingError || SmallConstantError || RootConstantError)!void {
        for (self.bind_group_layouts) |layout| {
            try layout.validate();
        }
        for (self.small_constants) |constant| {
            try constant.validate(features, limits);
        }
        if (self.root_constant_layout) |layout| {
            try layout.validate(features, limits);
        }
    }
};

pub const BufferBindingDescriptor = struct {
    offset: u64 = 0,
    size: ?u64 = null,

    pub fn validate(self: BufferBindingDescriptor) BindingError!void {
        if (self.size) |size| {
            if (size == 0) return BindingError.InvalidBufferBindingRange;
        }
    }
};

pub const TextureViewBindingDescriptor = struct {};

pub const SamplerBindingDescriptor = struct {};

pub const StaticSamplerDescriptor = struct {
    binding: u32,
    visibility: ShaderVisibility,
    sampler: SamplerDescriptor = .{},

    pub fn validate(self: StaticSamplerDescriptor, features: DeviceFeatures) (BindingError || SamplerError)!void {
        if (!features.static_samplers) return BindingError.UnsupportedStaticSampler;
        if (self.visibility.isEmpty()) return BindingError.EmptyShaderVisibility;
        try self.sampler.validate();
    }
};

pub const BindGroupResource = union(BindingResourceKind) {
    uniform_buffer: BufferBindingDescriptor,
    storage_buffer: BufferBindingDescriptor,
    storage_texture: TextureViewBindingDescriptor,
    sampled_texture: TextureViewBindingDescriptor,
    sampler: SamplerBindingDescriptor,
    compare_sampler: SamplerBindingDescriptor,

    pub fn resourceKind(self: BindGroupResource) BindingResourceKind {
        return switch (self) {
            .uniform_buffer => .uniform_buffer,
            .storage_buffer => .storage_buffer,
            .storage_texture => .storage_texture,
            .sampled_texture => .sampled_texture,
            .sampler => .sampler,
            .compare_sampler => .compare_sampler,
        };
    }

    pub fn validate(self: BindGroupResource) BindingError!void {
        switch (self) {
            .uniform_buffer, .storage_buffer => |buffer| try buffer.validate(),
            .storage_texture, .sampled_texture, .sampler, .compare_sampler => {},
        }
    }
};

pub const BindGroupEntry = struct {
    binding: u32,
    resource: BindGroupResource,
};

pub const BindGroupDescriptor = struct {
    label: ?[]const u8 = null,
    layout: BindGroupLayoutDescriptor,
    entries: []const BindGroupEntry = &.{},

    pub fn validate(self: BindGroupDescriptor) BindingError!void {
        try self.layout.validate();

        for (self.entries, 0..) |entry, i| {
            for (self.entries[i + 1 ..]) |other| {
                if (entry.binding == other.binding) return BindingError.DuplicateBinding;
            }

            const layout_entry = self.layout.entryForBinding(entry.binding) orelse {
                return BindingError.ExtraBindGroupEntry;
            };
            if (layout_entry.resource != entry.resource.resourceKind()) {
                return BindingError.BindingResourceKindMismatch;
            }
            try entry.resource.validate();
        }

        for (self.layout.entries) |layout_entry| {
            if (self.entryForBinding(layout_entry.binding) == null) {
                return BindingError.MissingBindGroupEntry;
            }
        }
    }

    pub fn entryForBinding(self: BindGroupDescriptor, binding: u32) ?BindGroupEntry {
        for (self.entries) |entry| {
            if (entry.binding == binding) return entry;
        }
        return null;
    }
};

pub const DynamicOffset = struct {
    binding: u32,
    array_element: u32 = 0,
    offset: u64 = 0,
};

pub const DynamicOffsetList = struct {
    offsets: []const DynamicOffset = &.{},

    pub fn validate(
        self: DynamicOffsetList,
        layout: BindGroupLayoutDescriptor,
        limits: DeviceLimits,
    ) BindingError!void {
        try layout.validate();

        for (self.offsets, 0..) |offset, i| {
            for (self.offsets[i + 1 ..]) |other| {
                if (offset.binding == other.binding and offset.array_element == other.array_element) {
                    return BindingError.DuplicateBinding;
                }
            }

            const layout_entry = layout.entryForBinding(offset.binding) orelse {
                return BindingError.ExtraDynamicOffset;
            };
            if (!layout_entry.dynamic_offset) return BindingError.ExtraDynamicOffset;
            if (!layout_entry.resource.isBuffer()) return BindingError.InvalidDynamicBindingResource;
            if (offset.array_element >= layout_entry.array_count) return BindingError.ExtraDynamicOffset;

            const alignment = dynamicOffsetAlignment(layout_entry.resource, limits);
            if (!isAlignedU64(offset.offset, alignment)) return BindingError.InvalidDynamicOffsetAlignment;
        }

        for (layout.entries) |layout_entry| {
            if (!layout_entry.dynamic_offset) continue;
            for (0..layout_entry.array_count) |array_index| {
                const array_element: u32 = @intCast(array_index);
                if (self.offsetForBindingElement(layout_entry.binding, array_element) == null) {
                    return BindingError.MissingDynamicOffset;
                }
            }
        }
    }

    pub fn offsetForBinding(self: DynamicOffsetList, binding: u32) ?u64 {
        return self.offsetForBindingElement(binding, 0);
    }

    pub fn offsetForBindingElement(self: DynamicOffsetList, binding: u32, array_element: u32) ?u64 {
        for (self.offsets) |offset| {
            if (offset.binding == binding and offset.array_element == array_element) return offset.offset;
        }
        return null;
    }
};

fn dynamicOffsetAlignment(kind: BindingResourceKind, limits: DeviceLimits) u64 {
    return switch (kind) {
        .uniform_buffer => limits.min_uniform_buffer_offset_alignment,
        .storage_buffer => limits.min_storage_buffer_offset_alignment,
        .storage_texture, .sampled_texture, .sampler, .compare_sampler => 1,
    };
}

pub const SmallConstantDescriptor = struct {
    label: ?[]const u8 = null,
    visibility: ShaderVisibility,
    offset: u32 = 0,
    bytes: []const u8 = &.{},

    pub fn validate(
        self: SmallConstantDescriptor,
        features: DeviceFeatures,
        limits: DeviceLimits,
    ) SmallConstantError!void {
        if (!features.small_constants) return SmallConstantError.UnsupportedSmallConstants;
        if (self.visibility.isEmpty()) return SmallConstantError.EmptySmallConstantVisibility;
        if (self.bytes.len == 0) return SmallConstantError.EmptySmallConstantData;
        if (self.bytes.len > std.math.maxInt(u32)) return SmallConstantError.SmallConstantDataTooLarge;

        const byte_count: u32 = @intCast(self.bytes.len);
        const end = std.math.add(u32, self.offset, byte_count) catch {
            return SmallConstantError.SmallConstantDataTooLarge;
        };
        if (end > limits.max_small_constant_bytes) return SmallConstantError.SmallConstantDataTooLarge;

        const alignment = limits.small_constant_alignment;
        if (!isAlignedU32(self.offset, alignment) or !isAlignedU32(byte_count, alignment)) {
            return SmallConstantError.InvalidSmallConstantAlignment;
        }
    }
};

pub const SmallConstantError = error{
    UnsupportedSmallConstants,
    EmptySmallConstantVisibility,
    EmptySmallConstantData,
    SmallConstantDataTooLarge,
    InvalidSmallConstantAlignment,
};

pub const RootConstantRange = struct {
    visibility: ShaderVisibility,
    offset: u32 = 0,
    size: u32 = 0,

    pub fn validate(
        self: RootConstantRange,
        features: DeviceFeatures,
        limits: DeviceLimits,
    ) RootConstantError!void {
        if (!features.root_constants) return RootConstantError.UnsupportedRootConstants;
        if (self.visibility.isEmpty()) return RootConstantError.EmptyRootConstantVisibility;
        if (self.size == 0) return RootConstantError.InvalidRootConstantRange;
        const end = std.math.add(u32, self.offset, self.size) catch {
            return RootConstantError.RootConstantRangeTooLarge;
        };
        if (end > limits.max_root_constant_bytes) return RootConstantError.RootConstantRangeTooLarge;

        const alignment = limits.root_constant_alignment;
        if (!isAlignedU32(self.offset, alignment) or !isAlignedU32(self.size, alignment)) {
            return RootConstantError.InvalidRootConstantAlignment;
        }
    }

    pub fn containsWrite(self: RootConstantRange, write: RootConstantWriteDescriptor) bool {
        if (write.bytes.len == 0 or write.bytes.len > std.math.maxInt(u32)) return false;
        const write_size: u32 = @intCast(write.bytes.len);
        const range_end = std.math.add(u32, self.offset, self.size) catch return false;
        const write_end = std.math.add(u32, write.offset, write_size) catch return false;
        return write.offset >= self.offset and write_end <= range_end;
    }
};

pub const RootConstantLayoutDescriptor = struct {
    label: ?[]const u8 = null,
    ranges: []const RootConstantRange = &.{},

    pub fn validate(
        self: RootConstantLayoutDescriptor,
        features: DeviceFeatures,
        limits: DeviceLimits,
    ) RootConstantError!void {
        if (!features.root_constants) return RootConstantError.UnsupportedRootConstants;
        if (self.ranges.len == 0) return RootConstantError.MissingRootConstantRange;
        for (self.ranges) |range| {
            try range.validate(features, limits);
        }
    }

    pub fn rangeContainingWrite(self: RootConstantLayoutDescriptor, write: RootConstantWriteDescriptor) ?RootConstantRange {
        for (self.ranges) |range| {
            if (range.containsWrite(write)) return range;
        }
        return null;
    }
};

pub const RootConstantWriteDescriptor = struct {
    offset: u32 = 0,
    bytes: []const u8 = &.{},

    pub fn validate(
        self: RootConstantWriteDescriptor,
        layout: RootConstantLayoutDescriptor,
        features: DeviceFeatures,
        limits: DeviceLimits,
    ) RootConstantError!void {
        try layout.validate(features, limits);
        if (self.bytes.len == 0) return RootConstantError.EmptyRootConstantWrite;
        if (self.bytes.len > std.math.maxInt(u32)) return RootConstantError.RootConstantRangeTooLarge;

        const byte_count: u32 = @intCast(self.bytes.len);
        const alignment = limits.root_constant_alignment;
        if (!isAlignedU32(self.offset, alignment) or !isAlignedU32(byte_count, alignment)) {
            return RootConstantError.InvalidRootConstantAlignment;
        }
        if (layout.rangeContainingWrite(self) == null) return RootConstantError.RootConstantWriteOutOfRange;
    }
};

pub const RootConstantError = error{
    UnsupportedRootConstants,
    MissingRootConstantRange,
    EmptyRootConstantVisibility,
    InvalidRootConstantRange,
    RootConstantRangeTooLarge,
    InvalidRootConstantAlignment,
    EmptyRootConstantWrite,
    RootConstantWriteOutOfRange,
    RootConstantVisibilityMismatch,
};

pub const BindingError = error{
    MissingBindGroupLayoutEntry,
    EmptyShaderVisibility,
    DuplicateBinding,
    MissingBindGroupEntry,
    ExtraBindGroupEntry,
    BindingResourceKindMismatch,
    InvalidBufferBindingRange,
    InvalidStorageTextureVisibility,
    InvalidStorageAccess,
    InvalidBindingArrayCount,
    InvalidBindGroupResourceCount,
    InvalidDynamicBindingResource,
    UnsupportedResourceArray,
    UnsupportedDynamicBinding,
    UnsupportedStaticSampler,
    MissingDynamicOffset,
    ExtraDynamicOffset,
    InvalidDynamicOffsetAlignment,
    InvalidDynamicOffsetRange,
    InvalidResourceTableSlot,
    MissingResourceTableBinding,
    ResourceTablePartiallyBoundUnsupported,
    ResourceTableUpdateAfterBindUnsupported,
    InvalidResourceTableResource,
    ResourceTableVisibilityMismatch,
};

fn isAlignedU32(value: u32, alignment: u32) bool {
    return alignment == 0 or value % alignment == 0;
}

fn sparseCeilDivU32(numerator: u32, denominator: u32) u32 {
    if (denominator == 0) return 0;
    if (numerator == 0) return 0;
    return 1 + (numerator - 1) / denominator;
}

fn isAlignedU64(value: u64, alignment: u64) bool {
    return alignment == 0 or value % alignment == 0;
}

fn defaultViewDimension(texture: TextureDescriptor) TextureViewDimension {
    return switch (texture.dimension) {
        .one_d => if (texture.depth_or_array_layers == 1) .one_d else .one_d_array,
        .two_d => if (texture.depth_or_array_layers == 1) .two_d else .two_d_array,
        .three_d => .three_d,
    };
}

fn validateViewDimension(
    texture_dimension: TextureDimension,
    view_dimension: TextureViewDimension,
    array_layer_count: u32,
) TextureError!void {
    switch (texture_dimension) {
        .one_d => switch (view_dimension) {
            .one_d => if (array_layer_count != 1) return TextureError.UnsupportedTextureViewDimension,
            .one_d_array => {},
            else => return TextureError.UnsupportedTextureViewDimension,
        },
        .two_d => switch (view_dimension) {
            .two_d => if (array_layer_count != 1) return TextureError.UnsupportedTextureViewDimension,
            .two_d_array => {},
            else => return TextureError.UnsupportedTextureViewDimension,
        },
        .three_d => switch (view_dimension) {
            .three_d => if (array_layer_count != 1) return TextureError.UnsupportedTextureViewDimension,
            else => return TextureError.UnsupportedTextureViewDimension,
        },
    }
}

fn vertexFormatSize(format: VertexFormat) u32 {
    return switch (format) {
        .float32 => 4,
        .float32x2 => 8,
        .float32x3 => 12,
        .float32x4 => 16,
    };
}

fn indexTypeSize(index_type: IndexType) u64 {
    return switch (index_type) {
        .uint16 => 2,
        .uint32 => 4,
    };
}

fn validateSampleCount(sample_count: u32) error{ InvalidSampleCount, UnsupportedSampleCount }!void {
    if (sample_count == 0) return error.InvalidSampleCount;
    switch (sample_count) {
        1, 2, 4, 8 => {},
        else => return error.UnsupportedSampleCount,
    }
}

pub const default_max_vertex_buffer_slots: u32 = 31;
pub const default_max_bind_group_slots: u32 = 16;
pub const default_max_color_attachments: u32 = 4;
const max_vertex_buffer_slots: u32 = default_max_vertex_buffer_slots;
const max_bind_group_slots: u32 = default_max_bind_group_slots;

fn validateRange(origin: u32, size: u32, limit: u32) TextureError!void {
    const end = std.math.add(u32, origin, size) catch return TextureError.InvalidTextureRegion;
    if (end > limit) return TextureError.InvalidTextureRegion;
}

pub fn mipDimension(base: u32, level: u32) u32 {
    var value = base;
    var i: u32 = 0;
    while (i < level and value > 1) : (i += 1) {
        value /= 2;
    }
    return value;
}

pub fn maxMipLevelCountForExtent(width: u32, height: u32, depth: u32) u32 {
    var largest = @max(width, @max(height, depth));
    var count: u32 = 1;
    while (largest > 1) : (count += 1) {
        largest /= 2;
    }
    return count;
}

pub fn textureFormatBytesPerPixel(format: TextureFormat) usize {
    return switch (format) {
        .automatic => unreachable,
        .bgra8_unorm,
        .bgra8_unorm_srgb,
        .rgba8_unorm,
        .rgba8_unorm_srgb,
        => 4,
        .depth32_float,
        .depth32_float_stencil8,
        => unreachable,
    };
}

pub fn textureFormatKind(format: TextureFormat) TextureFormatKind {
    return switch (format) {
        .automatic => .invalid,
        .bgra8_unorm,
        .bgra8_unorm_srgb,
        .rgba8_unorm,
        .rgba8_unorm_srgb,
        => .color,
        .depth32_float => .depth,
        .depth32_float_stencil8 => .depth_stencil,
    };
}

pub fn isColorFormat(format: TextureFormat) bool {
    return textureFormatKind(format) == .color;
}

pub fn isDepthFormat(format: TextureFormat) bool {
    const kind = textureFormatKind(format);
    return kind == .depth or kind == .depth_stencil;
}

pub fn isStencilFormat(format: TextureFormat) bool {
    const kind = textureFormatKind(format);
    return kind == .stencil or kind == .depth_stencil;
}

pub fn isDepthStencilFormat(format: TextureFormat) bool {
    return textureFormatKind(format) == .depth_stencil;
}

pub fn isCompressedFormat(format: TextureFormat) bool {
    return textureFormatKind(format) == .compressed;
}

pub fn isSrgbFormat(format: TextureFormat) bool {
    return switch (format) {
        .bgra8_unorm_srgb,
        .rgba8_unorm_srgb,
        => true,
        .automatic,
        .bgra8_unorm,
        .rgba8_unorm,
        .depth32_float,
        .depth32_float_stencil8,
        => false,
    };
}

pub fn textureFormatsCopyCompatible(source: TextureFormat, destination: TextureFormat) bool {
    if (source == destination) return true;
    return textureFormatCopyClass(source) != .none and
        textureFormatCopyClass(source) == textureFormatCopyClass(destination);
}

const TextureCopyClass = enum {
    none,
    rgba8,
    bgra8,
};

fn textureFormatCopyClass(format: TextureFormat) TextureCopyClass {
    return switch (format) {
        .rgba8_unorm,
        .rgba8_unorm_srgb,
        => .rgba8,
        .bgra8_unorm,
        .bgra8_unorm_srgb,
        => .bgra8,
        .automatic,
        .depth32_float,
        .depth32_float_stencil8,
        => .none,
    };
}

fn checkedMul(comptime T: type, a: anytype, b: anytype) error{Overflow}!T {
    return try std.math.mul(T, @as(T, @intCast(a)), @as(T, @intCast(b)));
}

fn checkedAdd(comptime T: type, a: T, b: T) error{Overflow}!T {
    return try std.math.add(T, a, b);
}

fn ceilDivU32(numerator: u32, denominator: u32) CommandEncodingError!u32 {
    if (denominator == 0) return CommandEncodingError.InvalidThreadgroupCount;
    const adjusted = std.math.add(u32, numerator, denominator - 1) catch {
        return CommandEncodingError.InvalidThreadgroupCount;
    };
    return adjusted / denominator;
}

fn requiredUploadBytes(
    width: u32,
    height: u32,
    depth: u32,
    bytes_per_pixel: usize,
    bytes_per_row: usize,
    bytes_per_image: usize,
) error{Overflow}!usize {
    const image_offset = try checkedMul(usize, depth - 1, bytes_per_image);
    const row_offset = try checkedMul(usize, height - 1, bytes_per_row);
    const row_bytes = try checkedMul(usize, width, bytes_per_pixel);
    return try checkedAdd(usize, try checkedAdd(usize, image_offset, row_offset), row_bytes);
}

fn validateTextureCopyRegion(
    texture: TextureDescriptor,
    region: Region3D,
    mip_level: u32,
    slice: u32,
) CommandEncodingError!void {
    if (region.size.isZero()) return CommandEncodingError.InvalidCopyTextureRegion;
    if (mip_level >= texture.mip_level_count) return CommandEncodingError.InvalidCopyTextureRegion;

    const mip_width = mipDimension(texture.width, mip_level);
    const mip_height = mipDimension(texture.height, mip_level);
    const mip_depth = mipDimension(texture.depth_or_array_layers, mip_level);

    switch (texture.dimension) {
        .one_d => {
            if (region.origin.y != 0 or region.origin.z != 0 or
                region.size.height != 1 or region.size.depth != 1)
            {
                return CommandEncodingError.InvalidCopyTextureRegion;
            }
            validateRange(region.origin.x, region.size.width, mip_width) catch return CommandEncodingError.InvalidCopyTextureRegion;
            if (slice >= texture.depth_or_array_layers) return CommandEncodingError.InvalidCopyTextureSlice;
        },
        .two_d => {
            if (region.origin.z != 0 or region.size.depth != 1) {
                return CommandEncodingError.InvalidCopyTextureRegion;
            }
            validateRange(region.origin.x, region.size.width, mip_width) catch return CommandEncodingError.InvalidCopyTextureRegion;
            validateRange(region.origin.y, region.size.height, mip_height) catch return CommandEncodingError.InvalidCopyTextureRegion;
            if (slice >= texture.depth_or_array_layers) return CommandEncodingError.InvalidCopyTextureSlice;
        },
        .three_d => {
            if (slice != 0) return CommandEncodingError.InvalidCopyTextureSlice;
            validateRange(region.origin.x, region.size.width, mip_width) catch return CommandEncodingError.InvalidCopyTextureRegion;
            validateRange(region.origin.y, region.size.height, mip_height) catch return CommandEncodingError.InvalidCopyTextureRegion;
            validateRange(region.origin.z, region.size.depth, mip_depth) catch return CommandEncodingError.InvalidCopyTextureRegion;
        },
    }
}

fn resolveTextureTextureCopy(
    descriptor: CopyTextureToTextureDescriptor,
    source: TextureDescriptor,
    destination: TextureDescriptor,
) CommandEncodingError!ResolvedTextureTextureCopy {
    source.validate() catch return CommandEncodingError.InvalidCopyTextureRegion;
    destination.validate() catch return CommandEncodingError.InvalidCopyTextureRegion;
    if (!textureFormatsCopyCompatible(source.format, destination.format)) return CommandEncodingError.UnsupportedTextureCopyFormat;
    if (!isColorFormat(source.format)) return CommandEncodingError.UnsupportedTextureCopyFormat;
    if (source.sample_count != 1 or destination.sample_count != 1) {
        return CommandEncodingError.UnsupportedTextureCopyFormat;
    }
    if (source.dimension != destination.dimension) return CommandEncodingError.UnsupportedTextureCopyFormat;
    if (descriptor.slice_count == 0) return CommandEncodingError.InvalidCopyTextureSlice;

    try validateTextureCopyRegion(
        source,
        descriptor.source_region,
        descriptor.source_mip_level,
        descriptor.source_slice,
    );

    const destination_region = Region3D{
        .origin = descriptor.destination_origin,
        .size = descriptor.source_region.size,
    };
    try validateTextureCopyRegion(
        destination,
        destination_region,
        descriptor.destination_mip_level,
        descriptor.destination_slice,
    );
    try validateTextureCopySliceCount(source, descriptor.source_slice, descriptor.slice_count);
    try validateTextureCopySliceCount(destination, descriptor.destination_slice, descriptor.slice_count);

    return .{
        .source_region = descriptor.source_region,
        .source_mip_level = descriptor.source_mip_level,
        .source_slice = descriptor.source_slice,
        .slice_count = descriptor.slice_count,
        .destination_origin = descriptor.destination_origin,
        .destination_mip_level = descriptor.destination_mip_level,
        .destination_slice = descriptor.destination_slice,
    };
}

fn validateTextureCopySliceCount(
    texture: TextureDescriptor,
    first_slice: u32,
    slice_count: u32,
) CommandEncodingError!void {
    if (texture.dimension == .three_d) {
        if (first_slice != 0 or slice_count != 1) return CommandEncodingError.InvalidCopyTextureSlice;
        return;
    }
    const end = std.math.add(u32, first_slice, slice_count) catch return CommandEncodingError.InvalidCopyTextureSlice;
    if (end > texture.depth_or_array_layers) return CommandEncodingError.InvalidCopyTextureSlice;
}

fn resolveBufferTextureCopy(
    buffer_length: usize,
    texture: TextureDescriptor,
    region: Region3D,
    mip_level: u32,
    slice: u32,
    layout: BufferTextureCopyLayout,
) CommandEncodingError!ResolvedBufferTextureCopy {
    texture.validate() catch return CommandEncodingError.InvalidCopyTextureRegion;
    if (!isColorFormat(texture.format)) return CommandEncodingError.UnsupportedTextureCopyFormat;
    if (texture.sample_count != 1) return CommandEncodingError.UnsupportedTextureCopyFormat;
    try validateTextureCopyRegion(texture, region, mip_level, slice);

    const bytes_per_pixel = textureFormatBytesPerPixel(texture.format);
    const tight_row_bytes = checkedMul(usize, region.size.width, bytes_per_pixel) catch {
        return CommandEncodingError.TextureCopySizeOverflow;
    };
    const bytes_per_row = if (layout.bytes_per_row == 0) tight_row_bytes else layout.bytes_per_row;
    if (bytes_per_row < tight_row_bytes or bytes_per_row % bytes_per_pixel != 0) {
        return CommandEncodingError.InvalidCopyBufferLayout;
    }

    const tight_image_bytes = checkedMul(usize, bytes_per_row, region.size.height) catch {
        return CommandEncodingError.TextureCopySizeOverflow;
    };
    const bytes_per_image = if (layout.bytes_per_image == 0) tight_image_bytes else layout.bytes_per_image;
    if (bytes_per_image < tight_image_bytes or bytes_per_image % bytes_per_row != 0) {
        return CommandEncodingError.InvalidCopyBufferLayout;
    }

    const required_bytes = requiredUploadBytes(
        region.size.width,
        region.size.height,
        region.size.depth,
        bytes_per_pixel,
        bytes_per_row,
        bytes_per_image,
    ) catch return CommandEncodingError.TextureCopySizeOverflow;
    const required_end = std.math.add(u64, layout.buffer_offset, required_bytes) catch {
        return CommandEncodingError.TextureCopySizeOverflow;
    };
    if (required_end > buffer_length) return CommandEncodingError.InvalidCopyBufferRange;

    return .{
        .buffer_offset = layout.buffer_offset,
        .bytes_per_row = bytes_per_row,
        .bytes_per_image = bytes_per_image,
        .bytes_per_pixel = bytes_per_pixel,
        .required_bytes = required_bytes,
        .region = region,
        .mip_level = mip_level,
        .slice = slice,
    };
}

pub const PresentMode = enum {
    fifo,
    mailbox,
    immediate,

    pub fn requestsVsync(self: PresentMode) bool {
        return self != .immediate;
    }
};

pub const SurfaceResizePolicy = enum {
    recreate,
    suspend_when_zero,
};

pub const SurfaceState = enum {
    unconfigured,
    configured,
    suspended,
    lost,
};

pub const PresentationDescriptor = struct {
    extent: Extent2D,
    format: TextureFormat = .automatic,
    present_mode: PresentMode = .fifo,
    resize_policy: SurfaceResizePolicy = .suspend_when_zero,

    pub fn withResolvedPresentMode(self: PresentationDescriptor, support: PresentModeSupport) PresentationDescriptor {
        var descriptor = self;
        descriptor.present_mode = support.resolve(self.present_mode);
        return descriptor;
    }
};

pub const PresentModeResolution = struct {
    requested: PresentMode,
    selected: PresentMode,
    support: PresentModeSupport,

    pub fn fellBack(self: PresentModeResolution) bool {
        return self.requested != self.selected;
    }

    pub fn requestsVsync(self: PresentModeResolution) bool {
        return self.selected.requestsVsync();
    }
};

pub const PresentModeSupport = struct {
    fifo: bool = true,
    mailbox: bool = false,
    immediate: bool = false,

    pub fn supports(self: PresentModeSupport, mode: PresentMode) bool {
        return switch (mode) {
            .fifo => self.fifo,
            .mailbox => self.mailbox,
            .immediate => self.immediate,
        };
    }

    pub fn resolve(self: PresentModeSupport, requested: PresentMode) PresentMode {
        if (self.supports(requested)) return requested;
        if (self.fifo) return .fifo;
        if (self.mailbox) return .mailbox;
        if (self.immediate) return .immediate;
        return .fifo;
    }

    pub fn resolveWithDiagnostics(self: PresentModeSupport, requested: PresentMode) PresentModeResolution {
        return .{
            .requested = requested,
            .selected = self.resolve(requested),
            .support = self,
        };
    }
};

pub fn defaultPresentModeSupport(backend: Backend) PresentModeSupport {
    _ = backend;
    return .{ .fifo = true };
}

pub const FramePacingDiagnostics = struct {
    configured: bool = false,
    extent: Extent2D = .{ .width = 0, .height = 0 },
    format: TextureFormat = .automatic,
    present_mode: PresentMode = .fifo,
    requests_vsync: bool = true,
    frame_in_flight: bool = false,
    generation: u64 = 0,
    submitted_frame_serial: u64 = 0,
    completed_frame_serial: u64 = 0,

    pub fn pendingFrameCount(self: FramePacingDiagnostics) u64 {
        return self.submitted_frame_serial - self.completed_frame_serial;
    }
};

pub const PresentationResourceState = struct {
    configured: bool = false,
    extent: Extent2D = .{ .width = 0, .height = 0 },
    format: TextureFormat = .automatic,
    present_mode: PresentMode = .fifo,
    frame_in_flight: bool = false,
    generation: u64 = 0,
    submitted_frame_serial: u64 = 0,
    completed_frame_serial: u64 = 0,

    pub fn configure(self: *PresentationResourceState, descriptor: PresentationDescriptor) void {
        self.configured = true;
        self.extent = descriptor.extent;
        self.format = descriptor.format;
        self.present_mode = descriptor.present_mode;
        self.frame_in_flight = false;
        self.generation +%= 1;
    }

    pub fn suspendPresentation(self: *PresentationResourceState, descriptor: PresentationDescriptor) void {
        self.configured = false;
        self.extent = descriptor.extent;
        self.format = descriptor.format;
        self.present_mode = descriptor.present_mode;
        self.frame_in_flight = false;
        self.generation +%= 1;
    }

    pub fn beginFrame(self: *PresentationResourceState) SurfaceError!u64 {
        if (!self.configured) return SurfaceError.InvalidSurfaceExtent;
        if (self.frame_in_flight) return SurfaceError.InvalidSurfaceFrameState;
        self.submitted_frame_serial += 1;
        self.frame_in_flight = true;
        return self.submitted_frame_serial;
    }

    pub fn completeFrame(self: *PresentationResourceState, serial: u64) SurfaceError!void {
        if (!self.frame_in_flight or serial != self.submitted_frame_serial) {
            return SurfaceError.InvalidSurfaceFrameState;
        }
        self.completed_frame_serial = serial;
        self.frame_in_flight = false;
    }

    pub fn diagnostics(self: PresentationResourceState) FramePacingDiagnostics {
        return .{
            .configured = self.configured,
            .extent = self.extent,
            .format = self.format,
            .present_mode = self.present_mode,
            .requests_vsync = self.present_mode.requestsVsync(),
            .frame_in_flight = self.frame_in_flight,
            .generation = self.generation,
            .submitted_frame_serial = self.submitted_frame_serial,
            .completed_frame_serial = self.completed_frame_serial,
        };
    }
};

pub const ClearColorLike = struct {
    red: f32 = 0,
    green: f32 = 0,
    blue: f32 = 0,
    alpha: f32 = 1,
};

pub const BufferUsage = struct {
    copy_source: bool = false,
    copy_destination: bool = false,
    vertex: bool = false,
    index: bool = false,
    uniform: bool = false,
    storage: bool = false,
    indirect: bool = false,

    pub fn isEmpty(self: BufferUsage) bool {
        return !self.copy_source and
            !self.copy_destination and
            !self.vertex and
            !self.index and
            !self.uniform and
            !self.storage and
            !self.indirect;
    }
};

pub const ResourceStorageMode = enum {
    automatic,
    shared,
    managed,
    private,

    pub fn cpuVisible(self: ResourceStorageMode) bool {
        return self != .private;
    }
};

pub const BufferDescriptor = struct {
    label: ?[]const u8 = null,
    length: usize = 0,
    bytes: ?[]const u8 = null,
    usage: BufferUsage = .{},
    storage_mode: ResourceStorageMode = .automatic,

    pub fn resolvedLength(self: BufferDescriptor) BufferError!usize {
        const length = if (self.length != 0) self.length else if (self.bytes) |bytes| bytes.len else 0;
        if (length == 0) return BufferError.InvalidBufferLength;
        if (self.bytes) |bytes| {
            if (bytes.len > length) return BufferError.InitialDataTooLarge;
            if (self.storage_mode == .private) return BufferError.InitialDataRequiresCpuVisibleStorage;
        }
        return length;
    }

    pub fn cpuVisible(self: BufferDescriptor) bool {
        return self.storage_mode.cpuVisible();
    }
};

pub const BufferWriteDescriptor = struct {
    offset: usize = 0,
    bytes: []const u8,

    pub fn validate(self: BufferWriteDescriptor, buffer_length: usize) BufferError!void {
        if (self.bytes.len == 0) return BufferError.InvalidBufferWriteRange;
        const end = std.math.add(usize, self.offset, self.bytes.len) catch {
            return BufferError.InvalidBufferWriteRange;
        };
        if (end > buffer_length) return BufferError.InvalidBufferWriteRange;
    }
};

pub const BufferReadDescriptor = struct {
    offset: usize = 0,
    destination: []u8,

    pub fn validate(self: BufferReadDescriptor, buffer_length: usize) BufferError!void {
        if (self.destination.len == 0) return BufferError.InvalidBufferReadRange;
        const end = std.math.add(usize, self.offset, self.destination.len) catch {
            return BufferError.InvalidBufferReadRange;
        };
        if (end > buffer_length) return BufferError.InvalidBufferReadRange;
    }
};

pub const BufferMapMode = struct {
    read: bool = true,
    write: bool = false,

    pub fn isEmpty(self: BufferMapMode) bool {
        return !self.read and !self.write;
    }
};

pub const BufferMapDescriptor = struct {
    offset: usize = 0,
    length: usize,
    mode: BufferMapMode = .{},

    pub fn validate(self: BufferMapDescriptor, buffer_length: usize) BufferError!void {
        if (self.length == 0) return BufferError.InvalidBufferMapRange;
        if (self.mode.isEmpty()) return BufferError.InvalidBufferMapMode;
        const end = std.math.add(usize, self.offset, self.length) catch {
            return BufferError.InvalidBufferMapRange;
        };
        if (end > buffer_length) return BufferError.InvalidBufferMapRange;
    }
};

pub const BufferError = error{
    InvalidBufferLength,
    InitialDataTooLarge,
    InitialDataRequiresCpuVisibleStorage,
    InvalidBufferWriteRange,
    InvalidBufferReadRange,
    InvalidBufferMapRange,
    InvalidBufferMapMode,
    BufferNotCpuVisible,
};

pub const SurfaceError = error{
    MissingSurfaceSource,
    InvalidSurfaceExtent,
    InvalidSurfaceHandle,
    InvalidSurfaceFrameState,
    SurfaceLost,
};

pub const Surface = struct {
    backend: Backend,
    descriptor: SurfaceDescriptor,
    state: SurfaceState = .unconfigured,
    presentation: ?PresentationDescriptor = null,
    presentation_state: PresentationResourceState = .{},

    pub fn selectedBackend(self: Surface) Backend {
        return self.backend;
    }

    pub fn provider(self: Surface) SurfaceProvider {
        return self.descriptor.source.?.provider;
    }

    pub fn configure(self: *Surface, descriptor: PresentationDescriptor) SurfaceError!void {
        if (self.state == .lost) return SurfaceError.SurfaceLost;
        if (descriptor.extent.isZero()) {
            if (descriptor.resize_policy == .suspend_when_zero) {
                self.state = .suspended;
                self.presentation = descriptor;
                self.presentation_state.suspendPresentation(descriptor);
                return;
            }
            return SurfaceError.InvalidSurfaceExtent;
        }

        self.state = .configured;
        self.presentation = descriptor;
        self.presentation_state.configure(descriptor);
    }

    pub fn resize(self: *Surface, extent: Extent2D) SurfaceError!void {
        if (self.state == .lost) return SurfaceError.SurfaceLost;
        var descriptor = self.presentation orelse return SurfaceError.InvalidSurfaceExtent;
        descriptor.extent = extent;
        try self.configure(descriptor);
    }

    pub fn markLost(self: *Surface) void {
        self.state = .lost;
        self.presentation_state.configured = false;
        self.presentation_state.frame_in_flight = false;
        self.presentation_state.generation +%= 1;
    }

    pub fn beginFrame(self: *Surface) SurfaceError!u64 {
        if (self.state == .lost) return SurfaceError.SurfaceLost;
        if (self.state != .configured) return SurfaceError.InvalidSurfaceExtent;
        return self.presentation_state.beginFrame();
    }

    pub fn completeFrame(self: *Surface, serial: u64) SurfaceError!void {
        if (self.state == .lost) return SurfaceError.SurfaceLost;
        try self.presentation_state.completeFrame(serial);
    }

    pub fn framePacingDiagnostics(self: Surface) FramePacingDiagnostics {
        return self.presentation_state.diagnostics();
    }
};

pub const SurfaceHandle = struct {
    index: u32,
    generation: u32,
};

pub const SurfaceInfo = struct {
    handle: SurfaceHandle,
    backend: Backend,
    label: ?[]const u8 = null,
    provider: SurfaceProvider,
    state: SurfaceState,
    presentation: ?PresentationDescriptor = null,
    presentation_state: PresentationResourceState = .{},
};

pub const SurfaceCollection = struct {
    allocator: std.mem.Allocator,
    backend: Backend,
    entries: std.ArrayListUnmanaged(Entry) = .empty,

    const Entry = struct {
        generation: u32 = 1,
        alive: bool = true,
        surface: Surface,
    };

    pub fn init(allocator: std.mem.Allocator, backend: Backend) SurfaceCollection {
        return .{
            .allocator = allocator,
            .backend = backend,
        };
    }

    pub fn deinit(self: *SurfaceCollection) void {
        self.entries.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn add(self: *SurfaceCollection, descriptor: SurfaceDescriptor, presentation: PresentationDescriptor) !SurfaceHandle {
        if (descriptor.source == null) return SurfaceError.MissingSurfaceSource;

        var surface = Surface{
            .backend = self.backend,
            .descriptor = descriptor,
        };
        try surface.configure(presentation);

        for (self.entries.items, 0..) |*entry, i| {
            if (!entry.alive) {
                entry.generation +%= 1;
                if (entry.generation == 0) entry.generation = 1;
                entry.alive = true;
                entry.surface = surface;
                return .{
                    .index = @intCast(i),
                    .generation = entry.generation,
                };
            }
        }

        try self.entries.append(self.allocator, .{ .surface = surface });
        return .{
            .index = @intCast(self.entries.items.len - 1),
            .generation = 1,
        };
    }

    pub fn remove(self: *SurfaceCollection, handle: SurfaceHandle) SurfaceError!void {
        const entry = try self.entryPtr(handle);
        entry.alive = false;
        entry.surface.state = .unconfigured;
        entry.surface.presentation = null;
        entry.surface.presentation_state = .{};
    }

    pub fn get(self: *SurfaceCollection, handle: SurfaceHandle) SurfaceError!*Surface {
        return &(try self.entryPtr(handle)).surface;
    }

    pub fn info(self: *SurfaceCollection, handle: SurfaceHandle) SurfaceError!SurfaceInfo {
        const surface = try self.get(handle);
        return .{
            .handle = handle,
            .backend = surface.backend,
            .label = surface.descriptor.label,
            .provider = surface.provider(),
            .state = surface.state,
            .presentation = surface.presentation,
            .presentation_state = surface.presentation_state,
        };
    }

    pub fn contains(self: SurfaceCollection, handle: SurfaceHandle) bool {
        if (handle.index >= self.entries.items.len) return false;
        const entry = self.entries.items[handle.index];
        return entry.alive and entry.generation == handle.generation;
    }

    pub fn resize(self: *SurfaceCollection, handle: SurfaceHandle, extent: Extent2D) SurfaceError!void {
        try (try self.get(handle)).resize(extent);
    }

    pub fn markLost(self: *SurfaceCollection, handle: SurfaceHandle) SurfaceError!void {
        (try self.get(handle)).markLost();
    }

    pub fn beginFrame(self: *SurfaceCollection, handle: SurfaceHandle) SurfaceError!u64 {
        return try (try self.get(handle)).beginFrame();
    }

    pub fn completeFrame(self: *SurfaceCollection, handle: SurfaceHandle, serial: u64) SurfaceError!void {
        try (try self.get(handle)).completeFrame(serial);
    }

    pub fn framePacingDiagnostics(self: *SurfaceCollection, handle: SurfaceHandle) SurfaceError!FramePacingDiagnostics {
        return (try self.get(handle)).framePacingDiagnostics();
    }

    pub fn liveCount(self: SurfaceCollection) usize {
        var count: usize = 0;
        for (self.entries.items) |entry| {
            if (entry.alive) count += 1;
        }
        return count;
    }

    fn entryPtr(self: *SurfaceCollection, handle: SurfaceHandle) SurfaceError!*Entry {
        if (handle.index >= self.entries.items.len) return SurfaceError.InvalidSurfaceHandle;
        const entry = &self.entries.items[handle.index];
        if (!entry.alive or entry.generation != handle.generation) {
            return SurfaceError.InvalidSurfaceHandle;
        }
        return entry;
    }
};

pub fn selectBackend(options: BackendSelectionOptions) BackendSelectionError!Backend {
    if (options.adapter_selection.backend) |adapter_backend| {
        try ensureBackendPreferenceAllowsAdapter(options.preference, adapter_backend);
        return requireBackend(adapter_backend, options.availability);
    }

    const requested = switch (options.preference) {
        .vulkan => return requireBackend(.vulkan, options.availability),
        .metal => return requireBackend(.metal, options.availability),
        .auto => options.debug_override,
    };

    if (requested) |backend| {
        return requireBackend(backend, options.availability);
    }

    const first: Backend = if (options.os_tag.isDarwin()) .metal else .vulkan;
    const second: Backend = if (first == .metal) .vulkan else .metal;

    if (isAvailable(first, options.availability)) return first;
    if (isAvailable(second, options.availability)) return second;
    return BackendSelectionError.NoSupportedBackend;
}

fn ensureBackendPreferenceAllowsAdapter(preference: BackendPreference, adapter_backend: Backend) BackendSelectionError!void {
    switch (preference) {
        .auto => {},
        .vulkan => if (adapter_backend != .vulkan) return BackendSelectionError.AdapterSelectionConflict,
        .metal => if (adapter_backend != .metal) return BackendSelectionError.AdapterSelectionConflict,
    }
}

fn requireBackend(backend: Backend, availability: BackendAvailability) BackendSelectionError!Backend {
    if (isAvailable(backend, availability)) return backend;
    return switch (backend) {
        .vulkan => BackendSelectionError.VulkanUnavailable,
        .metal => BackendSelectionError.MetalUnavailable,
    };
}

fn isAvailable(backend: Backend, availability: BackendAvailability) bool {
    return switch (backend) {
        .vulkan => availability.vulkan,
        .metal => availability.metal,
    };
}

fn opaqueBackendHandle(comptime name: []const u8) type {
    return struct {
        backend: Backend,

        const Self = @This();

        pub fn selectedBackend(self: Self) Backend {
            return self.backend;
        }

        pub fn typeName() []const u8 {
            return name;
        }
    };
}

test "auto selects Metal first on Apple platforms" {
    try std.testing.expectEqual(Backend.metal, try selectBackend(.{
        .os_tag = .macos,
        .availability = .{ .vulkan = true, .metal = true },
    }));
}

test "auto selects Vulkan first on non-Apple platforms" {
    try std.testing.expectEqual(Backend.vulkan, try selectBackend(.{
        .os_tag = .linux,
        .availability = .{ .vulkan = true, .metal = true },
    }));
}

test "auto falls back when preferred backend is unavailable" {
    try std.testing.expectEqual(Backend.vulkan, try selectBackend(.{
        .os_tag = .macos,
        .availability = .{ .vulkan = true, .metal = false },
    }));
    try std.testing.expectEqual(Backend.metal, try selectBackend(.{
        .os_tag = .linux,
        .availability = .{ .vulkan = false, .metal = true },
    }));
}

test "explicit preference does not fall back" {
    try std.testing.expectError(BackendSelectionError.MetalUnavailable, selectBackend(.{
        .preference = .metal,
        .availability = .{ .vulkan = true, .metal = false },
    }));
    try std.testing.expectError(BackendSelectionError.VulkanUnavailable, selectBackend(.{
        .preference = .vulkan,
        .availability = .{ .vulkan = false, .metal = true },
    }));
}

test "adapter selection can force backend or report conflicts" {
    try std.testing.expectEqual(Backend.vulkan, try selectBackend(.{
        .preference = .auto,
        .os_tag = .macos,
        .availability = .{ .vulkan = true, .metal = true },
        .adapter_selection = .{ .backend = .vulkan },
    }));
    try std.testing.expectError(BackendSelectionError.AdapterSelectionConflict, selectBackend(.{
        .preference = .metal,
        .availability = .{ .vulkan = true, .metal = true },
        .adapter_selection = .{ .backend = .vulkan },
    }));
}

test "adapter selection matches backend and name" {
    const adapter = AdapterInfo{
        .backend = .metal,
        .name = "Apple GPU",
        .vendor = "Apple",
    };

    try std.testing.expect((AdapterSelectionDescriptor{
        .backend = .metal,
        .name = "Apple GPU",
    }).matches(adapter));
    try std.testing.expect(!(AdapterSelectionDescriptor{
        .backend = .vulkan,
        .name = "Apple GPU",
    }).matches(adapter));
    try std.testing.expect(!(AdapterSelectionDescriptor{
        .backend = .metal,
        .name = "Other GPU",
    }).matches(adapter));
}

test "debug override only affects auto selection" {
    try std.testing.expectEqual(Backend.vulkan, try selectBackend(.{
        .preference = .auto,
        .os_tag = .macos,
        .availability = .{ .vulkan = true, .metal = true },
        .debug_override = .vulkan,
    }));
    try std.testing.expectEqual(Backend.metal, try selectBackend(.{
        .preference = .metal,
        .os_tag = .linux,
        .availability = .{ .vulkan = true, .metal = true },
        .debug_override = .vulkan,
    }));
}

test "resource usage state records portable hazards" {
    var state = ResourceUsageState{};

    var transition = state.transitionTo(.copy_destination);
    try std.testing.expectEqual(ResourceHazard.none, transition.hazard);
    try std.testing.expect(!transition.requires_barrier);

    transition = state.transitionTo(.vertex_buffer);
    try std.testing.expectEqual(ResourceHazard.read_after_write, transition.hazard);
    try std.testing.expect(transition.requires_barrier);

    transition = state.transitionTo(.index_buffer);
    try std.testing.expectEqual(ResourceHazard.none, transition.hazard);
    try std.testing.expect(!transition.requires_barrier);

    transition = state.transitionTo(.copy_destination);
    try std.testing.expectEqual(ResourceHazard.write_after_read, transition.hazard);
    try std.testing.expect(transition.requires_barrier);
    try std.testing.expectEqual(@as(usize, 2), state.barrier_count);

    const existing = TransientResourceDescriptor{
        .kind = .buffer,
        .size = 4096,
        .alignment = 256,
        .first_use = 0,
        .last_use = 2,
    };
    const requested = TransientResourceDescriptor{
        .kind = .buffer,
        .size = 1024,
        .alignment = 128,
        .first_use = 3,
        .last_use = 4,
    };
    try existing.validate();
    try requested.validate();
    try std.testing.expect(TransientResourceDescriptor.canAlias(existing, requested));
    const transient_diagnostics = try TransientAllocationDiagnostics.analyze(&.{ existing, requested });
    try std.testing.expectEqual(@as(usize, 2), transient_diagnostics.resource_count);
    try std.testing.expectEqual(@as(usize, 1), transient_diagnostics.aliasable_pairs);
    try std.testing.expectEqual(@as(u64, 5120), transient_diagnostics.requested_units);
    try std.testing.expect(!TransientResourceDescriptor.canAlias(existing, .{
        .kind = .buffer,
        .size = 1024,
        .alignment = 128,
        .first_use = 1,
        .last_use = 4,
    }));
    try std.testing.expect(!TransientResourceDescriptor.canAlias(existing, .{
        .kind = .texture,
        .texture_extent = .{ .width = 64, .height = 64 },
        .first_use = 3,
        .last_use = 4,
    }));

    try (BufferBarrierDescriptor{
        .before = .copy_destination,
        .after = .vertex_buffer,
        .offset = 4,
        .size = 4,
    }).validate(16, .{ .explicit_resource_barriers = true });
    try std.testing.expectError(CommandEncodingError.UnsupportedExplicitResourceBarrier, (BufferBarrierDescriptor{
        .before = .copy_destination,
        .after = .vertex_buffer,
    }).validate(16, .{}));
    try std.testing.expectError(CommandEncodingError.RedundantResourceBarrier, (BufferBarrierDescriptor{
        .before = .copy_destination,
        .after = .copy_destination,
    }).validate(16, .{ .explicit_resource_barriers = true }));
    try std.testing.expectError(CommandEncodingError.InvalidResourceBarrierRange, (BufferBarrierDescriptor{
        .before = .copy_destination,
        .after = .vertex_buffer,
        .offset = 12,
        .size = 8,
    }).validate(16, .{ .explicit_resource_barriers = true }));

    try (TextureBarrierDescriptor{
        .before = .copy_destination,
        .after = .sampled_texture,
        .base_mip_level = 1,
        .mip_level_count = 1,
        .base_array_layer = 0,
        .array_layer_count = 1,
    }).validate(.{
        .format = .rgba8_unorm,
        .width = 4,
        .height = 4,
        .mip_level_count = 2,
        .usage = .{ .copy_destination = true, .shader_read = true },
    }, .{ .explicit_resource_barriers = true });
    try std.testing.expectError(CommandEncodingError.InvalidResourceBarrierRange, (TextureBarrierDescriptor{
        .before = .copy_destination,
        .after = .sampled_texture,
        .base_mip_level = 2,
    }).validate(.{
        .format = .rgba8_unorm,
        .width = 4,
        .height = 4,
        .mip_level_count = 2,
        .usage = .{ .copy_destination = true, .shader_read = true },
    }, .{ .explicit_resource_barriers = true }));

    var explicit_state = ResourceUsageState{};
    _ = try explicit_state.applyExplicitBarrier(.copy_destination, .sampled_texture);
    try std.testing.expectEqual(ResourceUsageKind.sampled_texture, explicit_state.current.?);
    try std.testing.expectEqual(@as(usize, 1), explicit_state.barrier_count);
    try std.testing.expectError(
        CommandEncodingError.InvalidResourceBarrierState,
        explicit_state.applyExplicitBarrier(.copy_destination, .vertex_buffer),
    );
}

test "fence and event descriptors validate feature gates" {
    try std.testing.expectError(CommandEncodingError.UnsupportedFences, (FenceDescriptor{}).validate(.{}));
    const fence_features = DeviceFeatures{ .fences = true };
    const binary_fence = FenceDescriptor{};
    try binary_fence.validate(fence_features);
    try std.testing.expectError(CommandEncodingError.InvalidFenceValue, (FenceDescriptor{
        .initial_value = 2,
    }).validate(fence_features));
    try (FenceSignalDescriptor{}).validate(binary_fence);
    try std.testing.expectError(CommandEncodingError.InvalidFenceValue, (FenceSignalDescriptor{
        .value = 2,
    }).validate(binary_fence));

    const timeline_fence = FenceDescriptor{
        .kind = .timeline,
        .initial_value = 4,
    };
    try std.testing.expectError(CommandEncodingError.UnsupportedTimelineFences, timeline_fence.validate(fence_features));
    try timeline_fence.validate(.{ .fences = true, .timeline_fences = true });
    try std.testing.expectError(CommandEncodingError.InvalidFenceValue, (FenceWaitDescriptor{
        .value = 0,
    }).validate(timeline_fence));

    try std.testing.expectError(CommandEncodingError.UnsupportedEvents, (EventDescriptor{}).validate(.{}));
    try (EventDescriptor{}).validate(.{ .events = true });
    try std.testing.expectError(CommandEncodingError.UnsupportedSharedEvents, (EventDescriptor{
        .shared = true,
    }).validate(.{ .events = true }));
    try (EventDescriptor{
        .shared = true,
    }).validate(.{ .events = true, .shared_events = true });
}

test "queue descriptors validate capabilities and gates" {
    const caps = QueueCapabilities{};
    try (QueueDescriptor{}).validate(.{}, caps);
    try (QueueDescriptor{
        .kind = .compute,
    }).validate(.{}, caps);
    try std.testing.expectError(CommandEncodingError.UnsupportedMultiQueue, (QueueDescriptor{
        .kind = .compute,
        .allow_fallback = false,
    }).validate(.{}, caps));
    try std.testing.expectError(CommandEncodingError.UnsupportedDedicatedQueue, (QueueDescriptor{
        .kind = .compute,
        .require_dedicated = true,
    }).validate(.{ .multi_queue = true }, caps));
    try (QueueDescriptor{
        .kind = .transfer,
        .require_dedicated = true,
    }).validate(.{
        .multi_queue = true,
        .dedicated_transfer_queue = true,
    }, caps);
    try std.testing.expectError(CommandEncodingError.InvalidQueueCapability, (QueueDescriptor{
        .kind = .transfer,
    }).validate(.{}, .{ .transfer = false }));

    const transfer_plan = try TransferBatchPlan.fromDescriptor(.{
        .upload_bytes = 4096,
        .readback_bytes = 2048,
        .prefer_dedicated_transfer = true,
    }, .{ .multi_queue = true, .dedicated_transfer_queue = true }, .{ .transfer = true });
    try std.testing.expectEqual(QueueKind.transfer, transfer_plan.queue);
    const graphics_plan = try TransferBatchPlan.fromDescriptor(.{
        .upload_bytes = 4096,
    }, .{}, .{ .transfer = true });
    try std.testing.expectEqual(QueueKind.graphics, graphics_plan.queue);
    try std.testing.expectError(CommandEncodingError.InvalidCopySize, (TransferBatchDescriptor{}).validate());

    try std.testing.expectError(CommandEncodingError.UnsupportedQueueOwnershipTransfer, (QueueOwnershipTransferDescriptor{
        .source = .graphics,
        .destination = .transfer,
        .before = .copy_destination,
        .after = .copy_source,
    }).validate(.{}));
    try std.testing.expectError(CommandEncodingError.RedundantQueueOwnershipTransfer, (QueueOwnershipTransferDescriptor{
        .source = .graphics,
        .destination = .graphics,
        .before = .copy_destination,
        .after = .copy_source,
    }).validate(.{ .queue_ownership_transfer = true }));
}

test "debug group stack validates labels and nesting" {
    var stack = DebugGroupStack{ .max_depth = 1 };

    try (DebugSignpostDescriptor{ .label = "frame marker" }).validate();
    try (DebugLabelDescriptor{
        .target = .resource,
        .label = "albedo texture",
    }).validate();
    try std.testing.expectError(CommandEncodingError.EmptyDebugGroupLabel, (DebugLabelDescriptor{
        .target = .command_buffer,
        .label = "",
    }).validate());
    try std.testing.expectError(CommandEncodingError.EmptyDebugGroupLabel, (DebugSignpostDescriptor{ .label = "" }).validate());

    try std.testing.expectError(CommandEncodingError.EmptyDebugGroupLabel, stack.push(""));
    try stack.push("frame");
    try std.testing.expectEqual(@as(u32, 1), stack.depth);
    try std.testing.expectError(CommandEncodingError.DebugGroupStackOverflow, stack.push("too deep"));

    try stack.pop();
    try std.testing.expectEqual(@as(u32, 0), stack.depth);
    try std.testing.expectError(CommandEncodingError.DebugGroupStackUnderflow, stack.pop());

    try stack.push("frame");
    try std.testing.expectError(CommandEncodingError.UnclosedDebugGroup, stack.requireEmpty());
    try stack.pop();
    try stack.requireEmpty();
}

test "capture names format backend and frame context" {
    var buffer: [96]u8 = undefined;
    const name = try (CaptureNameDescriptor{
        .scope = "frame",
        .name = "main-pass",
        .backend = .metal,
        .frame_index = 17,
    }).write(buffer[0..]);
    try std.testing.expectEqualStrings("frame:main-pass backend=metal frame=17", name);

    try std.testing.expectError(CommandEncodingError.EmptyDebugGroupLabel, (CaptureNameDescriptor{
        .scope = "",
        .name = "main-pass",
    }).write(buffer[0..]));
    try std.testing.expectError(CommandEncodingError.CaptureNameTooLong, (CaptureNameDescriptor{
        .scope = "frame",
        .name = "main-pass",
        .backend = .vulkan,
    }).write(buffer[0..8]));
}

test "error classifier groups public error categories" {
    try std.testing.expectEqual(ErrorCategory.validation, classifyError(error.InvalidBufferLength));
    try std.testing.expectEqual(ErrorCategory.unsupported_feature, classifyError(error.UnsupportedSampleCount));
    try std.testing.expectEqual(ErrorCategory.backend, classifyError(error.VulkanUnavailable));
    try std.testing.expectEqual(ErrorCategory.surface_lost, classifyError(error.SurfaceLost));
    try std.testing.expectEqual(ErrorCategory.device_lost, classifyError(error.DeviceLost));
    try std.testing.expectEqual(ErrorCategory.shader_compilation, classifyError(error.SlangCompilationFailed));
}

test "native handle union carries backend-specific handles explicitly" {
    const handles = NativeHandles{
        .vulkan = .{
            .instance = 1,
            .physical_device = 2,
            .device = 3,
            .surface = 4,
            .graphics_queue = 5,
            .present_queue = 6,
        },
    };

    try std.testing.expectEqual(Backend.vulkan, std.meta.activeTag(handles));
    try std.testing.expectEqual(@as(usize, 3), handles.vulkan.device);

    const view = nativeHandleView(handles);
    try std.testing.expectEqual(Backend.vulkan, view.backend());
    try std.testing.expect(view.isBorrowed());
    try std.testing.expect(!view.allowsMutation());
}

test "adapter enumeration follows auto backend order" {
    var adapters = try enumerateAdapters(std.testing.allocator, .{
        .preference = .auto,
        .os_tag = .macos,
        .availability = .{ .vulkan = true, .metal = true },
    });
    defer adapters.deinit();

    try std.testing.expectEqual(@as(usize, 2), adapters.len());
    try std.testing.expectEqual(Backend.metal, adapters.items()[0].backend);
    try std.testing.expectEqual(Backend.vulkan, adapters.items()[1].backend);
}

test "adapter enumeration respects explicit preference and debug override" {
    var explicit = try enumerateAdapters(std.testing.allocator, .{
        .preference = .vulkan,
        .availability = .{ .vulkan = true, .metal = true },
    });
    defer explicit.deinit();

    try std.testing.expectEqual(@as(usize, 1), explicit.len());
    try std.testing.expectEqual(Backend.vulkan, explicit.items()[0].backend);

    var override = try enumerateAdapters(std.testing.allocator, .{
        .preference = .auto,
        .availability = .{ .vulkan = true, .metal = true },
        .debug_override = .metal,
    });
    defer override.deinit();

    try std.testing.expectEqual(@as(usize, 1), override.len());
    try std.testing.expectEqual(Backend.metal, override.items()[0].backend);
}

test "adapter enumeration reports unavailable explicit backend" {
    try std.testing.expectError(BackendSelectionError.MetalUnavailable, enumerateAdapters(std.testing.allocator, .{
        .preference = .metal,
        .availability = .{ .vulkan = true, .metal = false },
    }));
}

test "context exposes selected backend" {
    var context = try Context.init(.{
        .backend = .vulkan,
        .availability = .{ .vulkan = true, .metal = false },
    });
    defer context.deinit();

    try std.testing.expectEqual(Backend.vulkan, context.selectedBackend());
}

test "context creates backend-tagged surfaces from neutral descriptors" {
    var context = try Context.init(.{
        .backend = .metal,
        .availability = .{ .vulkan = false, .metal = true },
    });
    defer context.deinit();

    var fake_window: u8 = 0;
    var surface = try context.createSurface(.{
        .label = "test surface",
        .source = .{
            .provider = .external,
            .window = &fake_window,
        },
    });

    try std.testing.expectEqual(Backend.metal, surface.selectedBackend());
    try std.testing.expectEqual(SurfaceProvider.external, surface.provider());
    try std.testing.expectEqual(SurfaceState.unconfigured, surface.state);
}

test "surface creation requires a source" {
    const context = try Context.init(.{
        .backend = .vulkan,
        .availability = .{ .vulkan = true, .metal = false },
    });

    try std.testing.expectError(SurfaceError.MissingSurfaceSource, context.createSurface(.{}));
}

test "surface presentation handles configured and suspended extents" {
    const context = try Context.init(.{
        .backend = .vulkan,
        .availability = .{ .vulkan = true, .metal = false },
    });

    var fake_window: u8 = 0;
    var surface = try context.createSurface(.{
        .source = .{
            .provider = .external,
            .window = &fake_window,
        },
    });

    try surface.configure(.{
        .extent = .{ .width = 640, .height = 480 },
        .format = .bgra8_unorm_srgb,
        .present_mode = .fifo,
    });
    try std.testing.expectEqual(SurfaceState.configured, surface.state);

    try surface.resize(.{ .width = 0, .height = 480 });
    try std.testing.expectEqual(SurfaceState.suspended, surface.state);
    try surface.resize(.{ .width = 1280, .height = 720 });
    try std.testing.expectEqual(SurfaceState.configured, surface.state);

    try std.testing.expectError(SurfaceError.InvalidSurfaceExtent, surface.configure(.{
        .extent = .{ .width = 0, .height = 480 },
        .resize_policy = .recreate,
    }));
}

test "present mode support resolves backend fallbacks and vsync intent" {
    const fifo_only = PresentModeSupport{};
    try std.testing.expectEqual(PresentMode.fifo, fifo_only.resolve(.mailbox));
    try std.testing.expectEqual(PresentMode.fifo, fifo_only.resolve(.immediate));

    const low_latency = PresentModeSupport{
        .fifo = true,
        .mailbox = true,
        .immediate = true,
    };
    try std.testing.expectEqual(PresentMode.mailbox, low_latency.resolve(.mailbox));
    try std.testing.expectEqual(PresentMode.immediate, low_latency.resolve(.immediate));
    try std.testing.expect(PresentMode.fifo.requestsVsync());
    try std.testing.expect(PresentMode.mailbox.requestsVsync());
    try std.testing.expect(!PresentMode.immediate.requestsVsync());

    const descriptor = PresentationDescriptor{
        .extent = .{ .width = 640, .height = 480 },
        .present_mode = .mailbox,
    };
    try std.testing.expectEqual(PresentMode.fifo, descriptor.withResolvedPresentMode(fifo_only).present_mode);
    const resolution = fifo_only.resolveWithDiagnostics(.immediate);
    try std.testing.expectEqual(PresentMode.immediate, resolution.requested);
    try std.testing.expectEqual(PresentMode.fifo, resolution.selected);
    try std.testing.expect(resolution.fellBack());
    try std.testing.expect(resolution.requestsVsync());
    try std.testing.expectEqual(PresentMode.fifo, defaultPresentModeSupport(.metal).resolve(.immediate));
}

test "surface collection manages multiple neutral surfaces" {
    var collection = SurfaceCollection.init(std.testing.allocator, .metal);
    defer collection.deinit();

    var window_a: u8 = 0;
    var window_b: u8 = 0;
    const handle_a = try collection.add(.{
        .label = "surface-a",
        .source = .{
            .provider = .external,
            .window = &window_a,
        },
    }, .{
        .extent = .{ .width = 640, .height = 480 },
    });
    const handle_b = try collection.add(.{
        .source = .{
            .provider = .external,
            .window = &window_b,
        },
    }, .{
        .extent = .{ .width = 320, .height = 240 },
    });

    try std.testing.expectEqual(@as(usize, 2), collection.liveCount());
    try std.testing.expect(collection.contains(handle_a));
    try std.testing.expectEqual(Backend.metal, (try collection.get(handle_a)).selectedBackend());
    const info_a = try collection.info(handle_a);
    try std.testing.expectEqual(Backend.metal, info_a.backend);
    try std.testing.expectEqual(SurfaceProvider.external, info_a.provider);
    try std.testing.expectEqualStrings("surface-a", info_a.label.?);
    try std.testing.expectEqual(SurfaceState.configured, info_a.state);
    try collection.resize(handle_b, .{ .width = 800, .height = 600 });
    try std.testing.expectEqual(@as(u32, 800), (try collection.get(handle_b)).presentation.?.extent.width);

    try collection.remove(handle_a);
    try std.testing.expect(!collection.contains(handle_a));
    try std.testing.expectEqual(@as(usize, 1), collection.liveCount());
    try std.testing.expectError(SurfaceError.InvalidSurfaceHandle, collection.get(handle_a));
    try std.testing.expectError(SurfaceError.InvalidSurfaceHandle, collection.remove(handle_a));

    const handle_c = try collection.add(.{
        .source = .{
            .provider = .external,
            .window = &window_a,
        },
    }, .{
        .extent = .{ .width = 1024, .height = 768 },
    });
    try std.testing.expectEqual(handle_a.index, handle_c.index);
    try std.testing.expect(handle_a.generation != handle_c.generation);
    try std.testing.expect(collection.contains(handle_c));
    try std.testing.expectError(SurfaceError.InvalidSurfaceHandle, collection.info(handle_a));
}

test "surface collection isolates presentation resource state per surface" {
    var collection = SurfaceCollection.init(std.testing.allocator, .vulkan);
    defer collection.deinit();

    var window_a: u8 = 0;
    var window_b: u8 = 0;
    const handle_a = try collection.add(.{
        .source = .{
            .provider = .external,
            .window = &window_a,
        },
    }, .{
        .extent = .{ .width = 640, .height = 480 },
        .format = .rgba8_unorm,
        .present_mode = .fifo,
    });
    const handle_b = try collection.add(.{
        .source = .{
            .provider = .external,
            .window = &window_b,
        },
    }, .{
        .extent = .{ .width = 320, .height = 240 },
        .format = .bgra8_unorm_srgb,
        .present_mode = .mailbox,
    });

    const initial_a = (try collection.info(handle_a)).presentation_state;
    const initial_b = (try collection.info(handle_b)).presentation_state;
    try std.testing.expect(initial_a.configured);
    try std.testing.expect(initial_b.configured);
    try std.testing.expectEqual(@as(u32, 640), initial_a.extent.width);
    try std.testing.expectEqual(@as(u32, 320), initial_b.extent.width);
    try std.testing.expectEqual(PresentMode.mailbox, initial_b.present_mode);

    try collection.resize(handle_a, .{ .width = 1024, .height = 768 });
    const resized_a = (try collection.info(handle_a)).presentation_state;
    const unchanged_b = (try collection.info(handle_b)).presentation_state;
    try std.testing.expectEqual(@as(u32, 1024), resized_a.extent.width);
    try std.testing.expect(resized_a.generation > initial_a.generation);
    try std.testing.expectEqual(@as(u32, 320), unchanged_b.extent.width);
    try std.testing.expectEqual(initial_b.generation, unchanged_b.generation);

    try collection.resize(handle_b, .{ .width = 0, .height = 0 });
    const suspended_b = (try collection.info(handle_b)).presentation_state;
    try std.testing.expect(!suspended_b.configured);
    try std.testing.expectEqual(SurfaceState.suspended, (try collection.info(handle_b)).state);
    try std.testing.expectEqual(@as(u32, 1024), (try collection.info(handle_a)).presentation_state.extent.width);

    try collection.markLost(handle_b);
    try std.testing.expectEqual(SurfaceState.lost, (try collection.info(handle_b)).state);
    try std.testing.expectError(SurfaceError.SurfaceLost, collection.resize(handle_b, .{ .width = 400, .height = 300 }));
    try std.testing.expectError(SurfaceError.SurfaceLost, (try collection.get(handle_b)).configure(.{
        .extent = .{ .width = 400, .height = 300 },
    }));
    try collection.remove(handle_b);
    try std.testing.expectError(SurfaceError.InvalidSurfaceHandle, collection.info(handle_b));
}

test "surface collection tracks independent frame pacing counters" {
    var collection = SurfaceCollection.init(std.testing.allocator, .metal);
    defer collection.deinit();

    var window_a: u8 = 0;
    var window_b: u8 = 0;
    const handle_a = try collection.add(.{
        .source = .{
            .provider = .external,
            .window = &window_a,
        },
    }, .{
        .extent = .{ .width = 640, .height = 480 },
    });
    const handle_b = try collection.add(.{
        .source = .{
            .provider = .external,
            .window = &window_b,
        },
    }, .{
        .extent = .{ .width = 320, .height = 240 },
    });

    const frame_a_1 = try collection.beginFrame(handle_a);
    try std.testing.expectEqual(@as(u64, 1), frame_a_1);
    try std.testing.expectError(SurfaceError.InvalidSurfaceFrameState, collection.beginFrame(handle_a));

    const frame_b_1 = try collection.beginFrame(handle_b);
    try std.testing.expectEqual(@as(u64, 1), frame_b_1);
    try collection.completeFrame(handle_b, frame_b_1);
    const diagnostics_b = try collection.framePacingDiagnostics(handle_b);
    try std.testing.expectEqual(@as(u64, 1), diagnostics_b.completed_frame_serial);
    try std.testing.expectEqual(@as(u64, 0), diagnostics_b.pendingFrameCount());
    try std.testing.expect(diagnostics_b.requests_vsync);
    try std.testing.expectEqual(@as(u64, 0), (try collection.info(handle_a)).presentation_state.completed_frame_serial);

    try std.testing.expectError(SurfaceError.InvalidSurfaceFrameState, collection.completeFrame(handle_a, frame_a_1 + 1));
    try collection.completeFrame(handle_a, frame_a_1);
    const frame_a_2 = try collection.beginFrame(handle_a);
    try std.testing.expectEqual(@as(u64, 2), frame_a_2);

    try collection.markLost(handle_a);
    try std.testing.expectError(SurfaceError.SurfaceLost, collection.beginFrame(handle_a));
    try std.testing.expect(!((try collection.info(handle_a)).presentation_state.frame_in_flight));
}

test "buffer descriptor resolves length from explicit length or bytes" {
    const bytes = [_]u8{ 1, 2, 3, 4 };

    try std.testing.expectEqual(@as(usize, 16), try (BufferDescriptor{
        .length = 16,
    }).resolvedLength());

    try std.testing.expectEqual(@as(usize, 4), try (BufferDescriptor{
        .bytes = bytes[0..],
    }).resolvedLength());
}

test "buffer descriptor validates initial data" {
    const bytes = [_]u8{ 1, 2, 3, 4 };

    try std.testing.expectError(BufferError.InvalidBufferLength, (BufferDescriptor{}).resolvedLength());
    try std.testing.expectError(BufferError.InitialDataTooLarge, (BufferDescriptor{
        .length = 2,
        .bytes = bytes[0..],
    }).resolvedLength());
    try std.testing.expectError(BufferError.InitialDataRequiresCpuVisibleStorage, (BufferDescriptor{
        .bytes = bytes[0..],
        .storage_mode = .private,
    }).resolvedLength());
    try std.testing.expect((BufferDescriptor{}).cpuVisible());
    try std.testing.expect(!(BufferDescriptor{
        .storage_mode = .private,
    }).cpuVisible());
}

test "buffer write descriptor validates ranges" {
    const bytes = [_]u8{ 1, 2, 3, 4 };

    try (BufferWriteDescriptor{
        .offset = 4,
        .bytes = bytes[0..],
    }).validate(8);

    try std.testing.expectError(BufferError.InvalidBufferWriteRange, (BufferWriteDescriptor{
        .offset = 5,
        .bytes = bytes[0..],
    }).validate(8));
    try std.testing.expectError(BufferError.InvalidBufferWriteRange, (BufferWriteDescriptor{
        .bytes = bytes[0..0],
    }).validate(8));
}

test "buffer read descriptor validates ranges" {
    var bytes = [_]u8{0} ** 4;

    try (BufferReadDescriptor{
        .offset = 4,
        .destination = bytes[0..],
    }).validate(8);

    try std.testing.expectError(BufferError.InvalidBufferReadRange, (BufferReadDescriptor{
        .offset = 5,
        .destination = bytes[0..],
    }).validate(8));
    try std.testing.expectError(BufferError.InvalidBufferReadRange, (BufferReadDescriptor{
        .destination = bytes[0..0],
    }).validate(8));
}

test "buffer map descriptor validates ranges and modes" {
    try (BufferMapDescriptor{
        .offset = 4,
        .length = 4,
        .mode = .{ .read = true, .write = true },
    }).validate(8);

    try std.testing.expectError(BufferError.InvalidBufferMapRange, (BufferMapDescriptor{
        .offset = 5,
        .length = 4,
    }).validate(8));
    try std.testing.expectError(BufferError.InvalidBufferMapRange, (BufferMapDescriptor{
        .length = 0,
    }).validate(8));
    try std.testing.expectError(BufferError.InvalidBufferMapMode, (BufferMapDescriptor{
        .length = 4,
        .mode = .{ .read = false, .write = false },
    }).validate(8));
}

test "buffer usage can detect empty usage" {
    try std.testing.expect((BufferUsage{}).isEmpty());
    try std.testing.expect(!(BufferUsage{ .vertex = true }).isEmpty());
}

test "shader module descriptor validates source inputs" {
    try (ShaderModuleDescriptor{
        .source = .{ .slang = "[shader(\"vertex\")] float4 main() : SV_Position { return 0; }" },
    }).validate();

    const spirv_words = [_]u32{ 0x07230203, 0, 0, 0 };
    try (ShaderModuleDescriptor{
        .source = .{ .spirv = spirv_words[0..] },
    }).validate();

    try std.testing.expectError(ShaderError.EmptyShaderSource, (ShaderModuleDescriptor{
        .source = .{ .slang = "" },
    }).validate());
    try std.testing.expectError(ShaderError.EmptyShaderArtifactPath, (ShaderModuleDescriptor{
        .source = .{ .artifact = .{
            .path = "",
            .language = .spirv,
        } },
    }).validate());
}

test "shader library descriptor validates entries and cache keys" {
    const entries = [_]ShaderLibraryEntryDescriptor{
        .{ .name = "vertex", .stage = .vertex, .entry_point = "vs_main" },
        .{ .name = "fragment", .stage = .fragment, .entry_point = "fs_main" },
    };
    const includes = [_][]const u8{"shaders/include"};
    try (ShaderLibraryDescriptor{
        .name = "basic",
        .source = .{ .slang = "shader source" },
        .entries = entries[0..],
        .include_paths = includes[0..],
        .profile = .release,
    }).validate();

    try std.testing.expectError(ShaderError.MissingShaderLibraryEntry, (ShaderLibraryDescriptor{
        .name = "empty",
        .source = .{ .slang = "shader source" },
    }).validate());

    const duplicate_entries = [_]ShaderLibraryEntryDescriptor{
        .{ .name = "main", .stage = .vertex, .entry_point = "vs_main" },
        .{ .name = "main", .stage = .fragment, .entry_point = "fs_main" },
    };
    try std.testing.expectError(ShaderError.DuplicateShaderLibraryEntry, (ShaderLibraryDescriptor{
        .name = "dupes",
        .source = .{ .slang = "shader source" },
        .entries = duplicate_entries[0..],
    }).validate());

    try (ShaderLibraryCacheKeyDescriptor{
        .library_name = "basic",
        .source_hash = "abc",
        .backend = .metal,
    }).validate();
    try (ShaderModuleCacheKeyDescriptor{
        .source_hash = "abc",
        .compile_options_hash = "debug-options",
        .entry_point = "vs_main",
        .backend = .metal,
        .stage = .vertex,
    }).validate();
    try std.testing.expectError(ObjectCacheError.EmptyObjectCacheOptionsHash, (ShaderModuleCacheKeyDescriptor{
        .source_hash = "abc",
        .compile_options_hash = "",
        .backend = .metal,
        .stage = .fragment,
    }).validate());

    const specialization_constants = [_]ShaderSpecializationConstant{
        .{ .id = 0, .name = "use_lighting", .value = .{ .bool = true } },
        .{ .id = 1, .name = "sample_count", .value = .{ .u32 = 4 } },
    };
    const specialization = ShaderSpecializationDescriptor{
        .constants = specialization_constants[0..],
    };
    try specialization.validate(.{ .shader_specialization = true });
    try std.testing.expectEqual(ShaderSpecializationValueKind.u32, specialization.constantForId(1).?.value.kind());
    try (ShaderLibraryCacheKeyDescriptor{
        .library_name = "basic",
        .source_hash = "abc",
        .backend = .vulkan,
        .specialization = specialization,
    }).validate();

    try std.testing.expectError(ShaderError.UnsupportedShaderSpecialization, specialization.validate(.{}));
    try std.testing.expectError(ShaderError.EmptyShaderSpecializationName, (ShaderSpecializationDescriptor{
        .constants = &.{.{ .id = 0, .name = "", .value = .{ .i32 = -1 } }},
    }).validateShape());
    try std.testing.expectError(ShaderError.DuplicateShaderSpecializationConstant, (ShaderSpecializationDescriptor{
        .constants = &.{
            .{ .id = 0, .name = "a", .value = .{ .f32 = 1 } },
            .{ .id = 0, .name = "b", .value = .{ .f32 = 2 } },
        },
    }).validateShape());
    try std.testing.expectError(ShaderError.DuplicateShaderSpecializationConstant, (ShaderSpecializationDescriptor{
        .constants = &.{
            .{ .id = 0, .name = "same", .value = .{ .bool = true } },
            .{ .id = 1, .name = "same", .value = .{ .bool = false } },
        },
    }).validateShape());
    try std.testing.expectError(ShaderError.EmptyShaderSourceHash, (ShaderLibraryCacheKeyDescriptor{
        .library_name = "basic",
        .source_hash = "",
        .backend = .metal,
    }).validate());

    const compute_layout_entries = [_]BindGroupLayoutEntry{
        .{
            .binding = 0,
            .resource = .storage_buffer,
            .visibility = .{ .compute = true },
        },
    };
    const compute_layouts = [_]BindGroupLayoutDescriptor{
        .{ .entries = compute_layout_entries[0..] },
    };
    const compute_layout_keys = [_]BindGroupLayoutCacheKeyDescriptor{
        .{ .entries = compute_layout_entries[0..] },
    };
    try (ComputePipelineCacheKeyDescriptor{
        .shader = .{
            .library_name = "compute",
            .source_hash = "abc",
            .backend = .vulkan,
            .profile = .release,
            .specialization = specialization,
        },
        .entry_point = "cs_main",
        .bind_group_layouts = compute_layouts[0..],
        .pipeline_layout = .{ .bind_group_layouts = compute_layout_keys[0..] },
    }).validate();
    try std.testing.expectError(ShaderError.EmptyShaderEntryPoint, (ComputePipelineCacheKeyDescriptor{
        .shader = .{
            .library_name = "compute",
            .source_hash = "abc",
            .backend = .vulkan,
        },
        .entry_point = "",
    }).validate());
}

test "object cache diagnostics record creation policy" {
    var diagnostics = ObjectCacheDiagnostics{};
    diagnostics.recordCreation(.sampler, false, .{}, 12);
    diagnostics.recordCreation(.sampler, true, .{ .mode = .diagnostics_only }, 8);
    diagnostics.recordCreation(.sampler, true, .{ .mode = .disabled }, 4);
    diagnostics.recordHit(.sampler);

    const sampler_stats = diagnostics.stats(.sampler);
    try std.testing.expectEqual(@as(u64, 1), sampler_stats.hits);
    try std.testing.expectEqual(@as(u64, 2), sampler_stats.misses);
    try std.testing.expectEqual(@as(u64, 2), sampler_stats.creation_attempts);
    try std.testing.expectEqual(@as(u64, 1), sampler_stats.equivalent_recreations);
    try std.testing.expectEqual(@as(u64, 1), sampler_stats.reuse_bypassed_creations);
    try std.testing.expectEqual(@as(u64, 1), sampler_stats.diagnostics_suppressed);
    try std.testing.expectEqual(@as(u64, 20), sampler_stats.total_creation_time_ns);
    try std.testing.expectEqual(@as(u64, 2), diagnostics.totalCreationAttempts());
}

test "driver pipeline cache descriptors validate identity and backend gates" {
    const vulkan_identity = DriverCacheIdentityDescriptor{
        .backend = .vulkan,
        .device_id = "device",
        .driver_id = "driver",
        .shader_hash = "shader",
        .schema_version = "v1",
    };
    const vulkan_cache = DriverPipelineCacheDescriptor{
        .path = "vkmtl-cache/pipeline/vulkan.bin",
        .kind = .vulkan_pipeline_cache,
        .identity = vulkan_identity,
    };
    try std.testing.expectError(AdvancedFeatureError.UnsupportedDriverPipelineCache, vulkan_cache.validate(.{}, .{}));
    try vulkan_cache.validate(.{ .driver_pipeline_cache = true }, .{ .max_driver_cache_identity_bytes = 64 });

    try std.testing.expectError(AdvancedFeatureError.DriverCacheBackendMismatch, (DriverPipelineCacheDescriptor{
        .path = "vkmtl-cache/pipeline/wrong.bin",
        .kind = .metal_binary_archive,
        .identity = vulkan_identity,
    }).validate(.{ .metal_binary_archive = true }, .{}));
    try std.testing.expectError(AdvancedFeatureError.EmptyDriverCacheIdentity, (DriverPipelineCacheDescriptor{
        .path = "vkmtl-cache/pipeline/empty.bin",
        .kind = .vulkan_pipeline_cache,
        .identity = .{
            .backend = .vulkan,
            .device_id = "",
            .driver_id = "driver",
            .shader_hash = "shader",
            .schema_version = "v1",
        },
    }).validate(.{ .driver_pipeline_cache = true }, .{}));

    const plan = try DriverPipelineCachePlan.fromDescriptor(vulkan_cache, true, .{ .driver_pipeline_cache = true }, .{});
    try std.testing.expect(plan.load_existing);
    try std.testing.expect(plan.store_on_shutdown);

    const stability_plan = try (StabilityRunDescriptor{ .iterations = 120 }).plan();
    try std.testing.expectEqual(@as(u64, 2), stability_plan.resize_events);
    try std.testing.expectEqual(@as(u64, 480), stability_plan.resources_created);
    try std.testing.expectEqual(@as(u64, 4), stability_plan.shader_cache_cycles);
    try std.testing.expectEqual(@as(u64, 120), stability_plan.upload_readback_cycles);
    try std.testing.expectEqual(@as(u64, 120), stability_plan.vulkan_unaligned_fill_fallback_checks);
    try std.testing.expect(stability_plan.expectsResize());
    try std.testing.expect(stability_plan.expectsUploadReadback());
    try std.testing.expect(stability_plan.expectsVulkanFillFallbackChecks());

    try std.testing.expectError(error.InvalidDrawCount, (StabilityRunDescriptor{ .iterations = 0 }).validate());
    try std.testing.expectError(error.InvalidStabilityRunInterval, (StabilityRunDescriptor{
        .iterations = 1,
        .resize_interval = 0,
    }).validate());
    try std.testing.expectError(error.InvalidStabilityResourceCount, (StabilityRunDescriptor{
        .iterations = 1,
        .resources_per_iteration = 0,
    }).validate());
    try std.testing.expectError(error.InvalidCopySize, (StabilityRunDescriptor{
        .iterations = 1,
        .upload_bytes_per_iteration = 0,
    }).validate());

    var stability = StabilityRunDiagnostics.fromPlan(stability_plan);
    try std.testing.expectEqual(@as(u32, 120), stability.iterations_completed);
    try std.testing.expectEqual(@as(u64, 480), stability.resources_created);
    try std.testing.expect(!stability.hasFailures());
    stability.recordRuntimeSnapshot(.{
        .live_resources = 12,
        .pending_retirements = 1,
    });
    try std.testing.expectEqual(@as(usize, 256), stability.max_live_resources);
    try std.testing.expectEqual(@as(u64, 1), stability.pending_retirement_warnings);
}

test "runtime cache manifests plan compatibility and stale entries" {
    const manifest = RuntimeCacheManifestDescriptor{
        .backend = .metal,
        .source_hash = "source-a",
        .toolchain_id = "slang-v2026.12.2",
    };
    try std.testing.expectEqual(RuntimeCacheCompatibility.missing, try manifest.compatibilityWith(null));
    try std.testing.expectEqual(RuntimeCacheCompatibility.compatible, try manifest.compatibilityWith(manifest));
    try std.testing.expectEqual(RuntimeCacheCompatibility.source_hash_mismatch, try manifest.compatibilityWith(.{
        .backend = .metal,
        .source_hash = "source-b",
        .toolchain_id = "slang-v2026.12.2",
    }));
    try std.testing.expectEqual(RuntimeCacheCompatibility.backend_mismatch, try manifest.compatibilityWith(.{
        .backend = .vulkan,
        .source_hash = "source-a",
        .toolchain_id = "slang-v2026.12.2",
    }));
    try std.testing.expectEqual(RuntimeCacheCompatibility.stale_schema, try manifest.compatibilityWith(.{
        .schema_version = runtime_cache_schema_version + 1,
        .backend = .metal,
        .source_hash = "source-a",
        .toolchain_id = "slang-v2026.12.2",
    }));

    const plan = try RuntimeCachePlan.fromDescriptor(std.testing.allocator, .{
        .cache_dir = "vkmtl-cache",
        .entry_name = "glow",
        .manifest = manifest,
        .existing_manifest = manifest,
    });
    defer plan.deinit(std.testing.allocator);
    try std.testing.expectEqual(RuntimeCacheCompatibility.compatible, plan.compatibility);
    try std.testing.expect(!plan.should_rebuild);
    try std.testing.expect(std.mem.endsWith(u8, plan.manifest_path, "vkmtl-cache-manifest.json"));
}

test "render pipeline descriptor validates shader stages and color targets" {
    const vertex_module = ShaderModuleDescriptor{
        .source = .{ .slang = "[shader(\"vertex\")] float4 vs_main() : SV_Position { return 0; }" },
    };
    const fragment_module = ShaderModuleDescriptor{
        .source = .{ .slang = "[shader(\"fragment\")] float4 fs_main() : SV_Target0 { return 1; }" },
    };
    const attributes = [_]VertexAttributeDescriptor{
        .{ .location = 0, .format = .float32x2, .offset = 0 },
    };
    const vertex_buffers = [_]VertexBufferLayoutDescriptor{
        .{ .stride = 8, .attributes = attributes[0..] },
    };
    const color_attachments = [_]RenderPipelineColorAttachmentDescriptor{
        .{ .format = .bgra8_unorm_srgb },
    };
    try std.testing.expectError(AdvancedFeatureError.UnsupportedTessellation, (TessellationDescriptor{
        .control_point_count = 3,
        .has_control_stage = true,
        .has_evaluation_stage = true,
    }).validate(.{}, .{}));
    try std.testing.expectError(AdvancedFeatureError.MissingTessellationStage, (TessellationDescriptor{
        .control_point_count = 3,
        .has_control_stage = true,
    }).validate(.{ .tessellation = true }, .{ .max_tessellation_control_points = 32 }));
    try std.testing.expectError(AdvancedFeatureError.InvalidPatchControlPointCount, (TessellationDescriptor{
        .control_point_count = 64,
        .has_control_stage = true,
        .has_evaluation_stage = true,
    }).validate(.{ .tessellation = true }, .{ .max_tessellation_control_points = 32 }));
    try (TessellationDescriptor{
        .control_point_count = 3,
        .has_control_stage = true,
        .has_evaluation_stage = true,
    }).validate(.{ .tessellation = true }, .{ .max_tessellation_control_points = 32 });
    try std.testing.expectError(AdvancedFeatureError.UnsupportedMeshShaders, (MeshPipelineDescriptor{
        .mesh_entry_point = "ms_main",
    }).validate(.{}, .{}));
    try std.testing.expectError(AdvancedFeatureError.MissingMeshStage, (MeshPipelineDescriptor{
        .mesh_entry_point = "",
    }).validate(.{ .mesh_shaders = true }, .{}));
    try std.testing.expectError(AdvancedFeatureError.InvalidMeshThreadgroupSize, (MeshPipelineDescriptor{
        .mesh_entry_point = "ms_main",
        .mesh_threads_per_threadgroup = 128,
    }).validate(.{ .mesh_shaders = true }, .{ .max_mesh_threads_per_threadgroup = 64 }));
    try std.testing.expectError(AdvancedFeatureError.UnsupportedTaskShaders, (MeshPipelineDescriptor{
        .mesh_entry_point = "ms_main",
        .task_entry_point = "ts_main",
    }).validate(.{ .mesh_shaders = true }, .{}));
    try (MeshPipelineDescriptor{
        .mesh_entry_point = "ms_main",
        .task_entry_point = "ts_main",
        .mesh_threads_per_threadgroup = 32,
        .task_threads_per_threadgroup = 16,
    }).validate(.{ .mesh_shaders = true, .task_shaders = true }, .{
        .max_mesh_threads_per_threadgroup = 64,
        .max_task_threads_per_threadgroup = 32,
    });
    try std.testing.expectError(AdvancedFeatureError.UnsupportedAccelerationStructures, (AccelerationStructureDescriptor{
        .kind = .bottom_level,
        .primitive_count = 1,
    }).validate(.{}));
    try std.testing.expectError(AdvancedFeatureError.InvalidAccelerationStructureDescriptor, (AccelerationStructureDescriptor{
        .kind = .bottom_level,
        .primitive_count = 0,
    }).validate(.{ .acceleration_structures = true }));
    const ray_groups = [_]RayTracingShaderGroupDescriptor{
        .{ .kind = .ray_generation, .entry_point = "raygen_main" },
        .{ .kind = .miss, .entry_point = "miss_main" },
        .{ .kind = .hit, .entry_point = "hit_main" },
    };
    try std.testing.expectError(AdvancedFeatureError.UnsupportedRayTracing, (RayTracingPipelineDescriptor{
        .shader_groups = ray_groups[0..],
    }).validate(.{}, .{}));
    try std.testing.expectError(AdvancedFeatureError.InvalidRayTracingPipeline, (RayTracingPipelineDescriptor{
        .shader_groups = ray_groups[0..],
        .max_recursion_depth = 3,
    }).validate(.{ .ray_tracing = true }, .{ .max_ray_tracing_recursion_depth = 2 }));
    try (RayTracingPipelineDescriptor{
        .shader_groups = ray_groups[0..],
        .max_recursion_depth = 2,
    }).validate(.{ .ray_tracing = true }, .{ .max_ray_tracing_recursion_depth = 2 });
    try std.testing.expectError(AdvancedFeatureError.InvalidShaderBindingTable, (ShaderBindingTableDescriptor{
        .stride = 12,
    }).validate(.{ .ray_tracing = true }, .{ .shader_binding_table_alignment = 16 }));
    try (ShaderBindingTableDescriptor{
        .stride = 32,
    }).validate(.{ .ray_tracing = true }, .{ .shader_binding_table_alignment = 16 });

    const bind_group_entries = [_]BindGroupLayoutEntry{
        .{
            .binding = 0,
            .resource = .uniform_buffer,
            .visibility = .{ .vertex = true },
        },
    };
    const bind_group_layouts = [_]BindGroupLayoutDescriptor{
        .{ .entries = bind_group_entries[0..] },
    };

    const render_pipeline = RenderPipelineDescriptor{
        .vertex = .{
            .module = vertex_module,
            .stage = .vertex,
            .entry_point = "vs_main",
        },
        .fragment = .{
            .module = fragment_module,
            .stage = .fragment,
            .entry_point = "fs_main",
        },
        .vertex_descriptor = .{ .buffers = vertex_buffers[0..] },
        .bind_group_layouts = bind_group_layouts[0..],
        .color_attachments = color_attachments[0..],
    };
    try render_pipeline.validate();
    try (RenderPipelineCacheKeyDescriptor{
        .pipeline = render_pipeline,
        .vertex_shader = .{
            .source_hash = "vs-source",
            .compile_options_hash = "debug",
            .entry_point = "vs_main",
            .backend = .metal,
            .stage = .vertex,
        },
        .fragment_shader = .{
            .source_hash = "fs-source",
            .compile_options_hash = "debug",
            .entry_point = "fs_main",
            .backend = .metal,
            .stage = .fragment,
        },
    }).validate(.{}, .{});
    try std.testing.expectError(ObjectCacheError.InvalidObjectCacheKey, (RenderPipelineCacheKeyDescriptor{
        .pipeline = render_pipeline,
        .vertex_shader = .{
            .source_hash = "vs-source",
            .compile_options_hash = "debug",
            .entry_point = "vs_main",
            .backend = .metal,
            .stage = .fragment,
        },
        .fragment_shader = .{
            .source_hash = "fs-source",
            .compile_options_hash = "debug",
            .entry_point = "fs_main",
            .backend = .metal,
            .stage = .fragment,
        },
    }).validate(.{}, .{}));

    try (RenderPipelineDescriptor{
        .vertex = .{
            .module = vertex_module,
            .stage = .vertex,
            .entry_point = "vs_main",
        },
        .fragment = .{
            .module = fragment_module,
            .stage = .fragment,
            .entry_point = "fs_main",
        },
        .sample_count = 4,
        .color_attachments = color_attachments[0..],
    }).validate();

    try std.testing.expectError(PipelineError.UnsupportedSampleCount, (RenderPipelineDescriptor{
        .vertex = .{
            .module = vertex_module,
            .stage = .vertex,
            .entry_point = "vs_main",
        },
        .sample_count = 3,
        .color_attachments = color_attachments[0..],
    }).validate());

    try std.testing.expectError(PipelineError.InvalidDepthBias, (RenderPipelineDescriptor{
        .vertex = .{
            .module = vertex_module,
            .stage = .vertex,
            .entry_point = "vs_main",
        },
        .depth_bias = .{ .enabled = true, .constant = std.math.nan(f32) },
        .color_attachments = color_attachments[0..],
    }).validate());

    const blend_attachments = [_]RenderPipelineColorAttachmentDescriptor{.{
        .format = .rgba8_unorm,
        .blend = .{
            .source_rgb_blend_factor = .source_alpha,
            .destination_rgb_blend_factor = .one_minus_source_alpha,
            .source_alpha_blend_factor = .one,
            .destination_alpha_blend_factor = .one_minus_source_alpha,
        },
    }};
    try (RenderPipelineDescriptor{
        .vertex = .{
            .module = vertex_module,
            .stage = .vertex,
            .entry_point = "vs_main",
        },
        .color_attachments = blend_attachments[0..],
    }).validate();

    const unblendable_attachments = [_]RenderPipelineColorAttachmentDescriptor{.{
        .format = .depth32_float,
        .blend = .{},
    }};
    try std.testing.expectError(PipelineError.InvalidColorAttachmentFormat, (RenderPipelineDescriptor{
        .vertex = .{
            .module = vertex_module,
            .stage = .vertex,
            .entry_point = "vs_main",
        },
        .color_attachments = unblendable_attachments[0..],
    }).validate());
}

test "render pipeline descriptor validates reflection against bind group layouts" {
    const vertex_module = ShaderModuleDescriptor{
        .source = .{ .slang = "[shader(\"vertex\")] float4 vs_main() : SV_Position { return 0; }" },
    };
    const fragment_module = ShaderModuleDescriptor{
        .source = .{ .slang = "[shader(\"fragment\")] float4 fs_main() : SV_Target0 { return 1; }" },
    };
    const color_attachments = [_]RenderPipelineColorAttachmentDescriptor{
        .{ .format = .bgra8_unorm_srgb },
    };
    const reflected_bindings = [_]ShaderReflectionBinding{
        .{
            .binding = 0,
            .resource = .sampled_texture,
            .visibility = .{ .fragment = true },
        },
        .{
            .binding = 1,
            .resource = .sampler,
            .visibility = .{ .fragment = true },
        },
    };
    const reflected_groups = [_]ShaderReflectionBindGroup{
        .{ .index = 0, .bindings = reflected_bindings[0..] },
    };
    const layout_entries = [_]BindGroupLayoutEntry{
        .{
            .binding = 0,
            .resource = .sampled_texture,
            .visibility = .{ .fragment = true },
        },
        .{
            .binding = 1,
            .resource = .sampler,
            .visibility = .{ .fragment = true },
        },
    };
    const bind_group_layouts = [_]BindGroupLayoutDescriptor{
        .{ .entries = layout_entries[0..] },
    };

    try (RenderPipelineDescriptor{
        .vertex = .{
            .module = vertex_module,
            .stage = .vertex,
            .entry_point = "vs_main",
        },
        .fragment = .{
            .module = fragment_module,
            .stage = .fragment,
            .entry_point = "fs_main",
            .reflection = .{ .data = .{
                .stage = .fragment,
                .entry_point = "fs_main",
                .bind_groups = reflected_groups[0..],
            } },
        },
        .bind_group_layouts = bind_group_layouts[0..],
        .color_attachments = color_attachments[0..],
    }).validate();

    try std.testing.expectError(ShaderError.UnsupportedShaderReflectionSchema, (RenderPipelineDescriptor{
        .vertex = .{
            .module = vertex_module,
            .stage = .vertex,
            .entry_point = "vs_main",
        },
        .fragment = .{
            .module = fragment_module,
            .stage = .fragment,
            .entry_point = "fs_main",
            .reflection = .{ .data = .{
                .schema_version = 999,
                .stage = .fragment,
                .entry_point = "fs_main",
                .bind_groups = reflected_groups[0..],
            } },
        },
        .bind_group_layouts = bind_group_layouts[0..],
        .color_attachments = color_attachments[0..],
    }).validate());

    try std.testing.expectError(ShaderError.ShaderReflectionBindingKindMismatch, (RenderPipelineDescriptor{
        .vertex = .{
            .module = vertex_module,
            .stage = .vertex,
            .entry_point = "vs_main",
        },
        .fragment = .{
            .module = fragment_module,
            .stage = .fragment,
            .entry_point = "fs_main",
            .reflection = .{ .data = .{
                .stage = .fragment,
                .entry_point = "fs_main",
                .bind_groups = reflected_groups[0..],
            } },
        },
        .bind_group_layouts = &.{.{ .entries = &.{ .{
            .binding = 0,
            .resource = .uniform_buffer,
            .visibility = .{ .fragment = true },
        }, .{
            .binding = 1,
            .resource = .sampler,
            .visibility = .{ .fragment = true },
        } } }},
        .color_attachments = color_attachments[0..],
    }).validate());

    const reflected_array_bindings = [_]ShaderReflectionBinding{
        .{
            .binding = 0,
            .resource = .sampled_texture,
            .visibility = .{ .fragment = true },
            .array_count = 2,
        },
        .{
            .binding = 1,
            .resource = .sampler,
            .visibility = .{ .fragment = true },
        },
    };
    const reflected_array_groups = [_]ShaderReflectionBindGroup{
        .{ .index = 0, .bindings = reflected_array_bindings[0..] },
    };
    try std.testing.expectError(ShaderError.ShaderReflectionBindingArrayCountMismatch, (RenderPipelineDescriptor{
        .vertex = .{
            .module = vertex_module,
            .stage = .vertex,
            .entry_point = "vs_main",
        },
        .fragment = .{
            .module = fragment_module,
            .stage = .fragment,
            .entry_point = "fs_main",
            .reflection = .{ .data = .{
                .stage = .fragment,
                .entry_point = "fs_main",
                .bind_groups = reflected_array_groups[0..],
            } },
        },
        .bind_group_layouts = bind_group_layouts[0..],
        .color_attachments = color_attachments[0..],
    }).validate());

    try std.testing.expectError(ShaderError.ShaderReflectionVisibilityMismatch, (RenderPipelineDescriptor{
        .vertex = .{
            .module = vertex_module,
            .stage = .vertex,
            .entry_point = "vs_main",
        },
        .fragment = .{
            .module = fragment_module,
            .stage = .fragment,
            .entry_point = "fs_main",
            .reflection = .{ .data = .{
                .stage = .fragment,
                .entry_point = "fs_main",
                .bind_groups = reflected_groups[0..],
            } },
        },
        .bind_group_layouts = &.{.{ .entries = &.{ .{
            .binding = 0,
            .resource = .sampled_texture,
            .visibility = .{ .vertex = true },
        }, .{
            .binding = 1,
            .resource = .sampler,
            .visibility = .{ .fragment = true },
        } } }},
        .color_attachments = color_attachments[0..],
    }).validate());
}

test "reflection derives descriptor indexing layout for bindless resources" {
    const reflected_bindings = [_]ShaderReflectionBinding{
        .{
            .binding = 0,
            .resource = .sampled_texture,
            .visibility = .{ .fragment = true },
            .array_count = 64,
            .bindless = true,
            .partially_bound = true,
        },
        .{
            .binding = 1,
            .resource = .sampler,
            .visibility = .{ .fragment = true },
        },
    };
    const reflected_groups = [_]ShaderReflectionBindGroup{
        .{ .index = 0, .bindings = reflected_bindings[0..] },
    };
    const reflection = ShaderStageReflection{
        .stage = .fragment,
        .entry_point = "fs_main",
        .bind_groups = reflected_groups[0..],
    };

    var ranges: [2]DescriptorIndexingRange = undefined;
    const layout = try deriveDescriptorIndexingLayoutFromReflection(reflection, .argument_buffer, ranges[0..]);

    try std.testing.expectEqual(@as(usize, 1), layout.ranges.len);
    try std.testing.expectEqual(AdvancedBindingModel.argument_buffer, layout.model);
    try std.testing.expectEqual(@as(u32, 0), layout.ranges[0].binding);
    try std.testing.expectEqual(@as(u32, 64), layout.ranges[0].descriptor_count);
    try std.testing.expect(layout.ranges[0].partially_bound);
}

test "descriptor indexing layout validates bindless edge cases" {
    const features = DeviceFeatures{
        .descriptor_indexing = true,
        .argument_buffers = true,
    };
    const limits = DeviceLimits{
        .max_bindless_descriptors_per_range = 8,
        .max_bindless_ranges_per_layout = 2,
    };

    const empty_visibility_ranges = [_]DescriptorIndexingRange{.{
        .binding = 0,
        .resource = .sampled_texture,
        .visibility = .{},
        .descriptor_count = 4,
    }};
    try std.testing.expectError(AdvancedFeatureError.EmptyDescriptorIndexingVisibility, (DescriptorIndexingLayoutDescriptor{
        .ranges = empty_visibility_ranges[0..],
    }).validate(features, limits));

    const zero_count_ranges = [_]DescriptorIndexingRange{.{
        .binding = 0,
        .resource = .sampled_texture,
        .visibility = .{ .fragment = true },
        .descriptor_count = 0,
    }};
    try std.testing.expectError(AdvancedFeatureError.InvalidDescriptorIndexingCount, (DescriptorIndexingLayoutDescriptor{
        .ranges = zero_count_ranges[0..],
    }).validate(features, limits));

    const duplicate_binding_ranges = [_]DescriptorIndexingRange{
        .{
            .binding = 1,
            .resource = .sampled_texture,
            .visibility = .{ .fragment = true },
            .descriptor_count = 4,
        },
        .{
            .binding = 1,
            .resource = .sampler,
            .visibility = .{ .fragment = true },
            .descriptor_count = 1,
        },
    };
    try std.testing.expectError(AdvancedFeatureError.DuplicateDescriptorIndexingBinding, (DescriptorIndexingLayoutDescriptor{
        .ranges = duplicate_binding_ranges[0..],
    }).validate(features, limits));

    const too_many_ranges = [_]DescriptorIndexingRange{
        .{ .binding = 0, .resource = .sampled_texture, .visibility = .{ .fragment = true }, .descriptor_count = 1 },
        .{ .binding = 1, .resource = .sampled_texture, .visibility = .{ .fragment = true }, .descriptor_count = 1 },
        .{ .binding = 2, .resource = .sampled_texture, .visibility = .{ .fragment = true }, .descriptor_count = 1 },
    };
    try std.testing.expectError(AdvancedFeatureError.DescriptorIndexingRangeCountExceeded, (DescriptorIndexingLayoutDescriptor{
        .ranges = too_many_ranges[0..],
    }).validate(features, limits));

    try std.testing.expectError(AdvancedFeatureError.MissingDescriptorIndexingRange, (DescriptorIndexingLayoutDescriptor{}).validate(features, limits));
}

test "resource table slots validate against descriptor ranges" {
    const ranges = [_]DescriptorIndexingRange{.{
        .binding = 7,
        .resource = .sampled_texture,
        .visibility = .{ .fragment = true },
        .descriptor_count = 2,
    }};
    const layout = DescriptorIndexingLayoutDescriptor{
        .model = .argument_buffer,
        .ranges = ranges[0..],
    };

    const resolved = try (ResourceTableSlot{
        .binding = 7,
        .array_element = 1,
    }).validate(layout);
    try std.testing.expectEqual(BindingResourceKind.sampled_texture, resolved.resource);

    try std.testing.expectError(BindingError.InvalidResourceTableSlot, (ResourceTableSlot{
        .binding = 7,
        .array_element = 2,
    }).validate(layout));
    try std.testing.expectError(BindingError.InvalidResourceTableSlot, (ResourceTableSlot{
        .binding = 8,
    }).validate(layout));
}

test "reflection bindless derivation validates array metadata and capacity" {
    const invalid_bindings = [_]ShaderReflectionBinding{.{
        .binding = 0,
        .resource = .sampled_texture,
        .visibility = .{ .fragment = true },
        .array_count = 0,
        .bindless = true,
    }};
    const invalid_groups = [_]ShaderReflectionBindGroup{.{
        .index = 0,
        .bindings = invalid_bindings[0..],
    }};
    const invalid_reflection = ShaderStageReflection{
        .stage = .fragment,
        .entry_point = "fs_main",
        .bind_groups = invalid_groups[0..],
    };
    var invalid_ranges: [1]DescriptorIndexingRange = undefined;
    try std.testing.expectError(ShaderError.InvalidShaderReflection, deriveDescriptorIndexingLayoutFromReflection(
        invalid_reflection,
        .descriptor_indexing,
        invalid_ranges[0..],
    ));

    const reflected_bindings = [_]ShaderReflectionBinding{
        .{
            .binding = 0,
            .resource = .sampled_texture,
            .visibility = .{ .fragment = true },
            .array_count = 4,
            .bindless = true,
        },
        .{
            .binding = 1,
            .resource = .sampler,
            .visibility = .{ .fragment = true },
            .array_count = 4,
            .bindless = true,
        },
    };
    const reflected_groups = [_]ShaderReflectionBindGroup{.{
        .index = 0,
        .bindings = reflected_bindings[0..],
    }};
    const reflection = ShaderStageReflection{
        .stage = .fragment,
        .entry_point = "fs_main",
        .bind_groups = reflected_groups[0..],
    };
    try std.testing.expectEqual(@as(usize, 2), descriptorIndexingRangeCountForReflection(reflection));

    var too_few_ranges: [1]DescriptorIndexingRange = undefined;
    try std.testing.expectError(ShaderError.InvalidShaderReflection, deriveDescriptorIndexingLayoutFromReflection(
        reflection,
        .descriptor_indexing,
        too_few_ranges[0..],
    ));
}

test "render pipeline descriptor validates depth state" {
    const module = ShaderModuleDescriptor{
        .source = .{ .slang = "[shader(\"vertex\")] float4 main() : SV_Position { return 0; }" },
    };
    const color_attachments = [_]RenderPipelineColorAttachmentDescriptor{
        .{ .format = .bgra8_unorm_srgb },
    };

    try (RenderPipelineDescriptor{
        .vertex = .{
            .module = module,
            .stage = .vertex,
        },
        .color_attachments = color_attachments[0..],
        .depth_stencil = .{
            .format = .depth32_float,
            .depth_compare_function = .less_equal,
            .depth_write_enabled = true,
        },
    }).validate();

    try std.testing.expectError(PipelineError.InvalidDepthStencilFormat, (RenderPipelineDescriptor{
        .vertex = .{
            .module = module,
            .stage = .vertex,
        },
        .color_attachments = color_attachments[0..],
        .depth_stencil = .{ .format = .rgba8_unorm },
    }).validate());

    try std.testing.expectError(PipelineError.InvalidStencilMask, (RenderPipelineDescriptor{
        .vertex = .{
            .module = module,
            .stage = .vertex,
        },
        .color_attachments = color_attachments[0..],
        .depth_stencil = .{
            .format = .depth32_float,
            .stencil = .{ .read_mask = 0x100 },
        },
    }).validate());

    try std.testing.expectError(PipelineError.InvalidDepthStencilFormat, (RenderPipelineDescriptor{
        .vertex = .{
            .module = module,
            .stage = .vertex,
        },
        .color_attachments = color_attachments[0..],
        .depth_stencil = .{
            .format = .depth32_float,
            .stencil = .{
                .enabled = true,
                .front = .{ .stencil_compare_function = .less_equal },
                .back = .{ .stencil_compare_function = .greater_equal },
            },
        },
    }).validate());

    try (RenderPipelineDescriptor{
        .vertex = .{
            .module = module,
            .stage = .vertex,
        },
        .color_attachments = color_attachments[0..],
        .depth_stencil = .{
            .format = .depth32_float_stencil8,
            .stencil = .{
                .enabled = true,
                .front = .{ .stencil_compare_function = .less_equal },
                .back = .{ .stencil_compare_function = .greater_equal },
            },
        },
    }).validate();
}

test "render pipeline descriptor rejects invalid shapes" {
    const module = ShaderModuleDescriptor{
        .source = .{ .slang = "[shader(\"vertex\")] float4 main() : SV_Position { return 0; }" },
    };
    const color_attachments = [_]RenderPipelineColorAttachmentDescriptor{
        .{ .format = .rgba8_unorm },
    };

    try std.testing.expectError(ShaderError.UnexpectedShaderStage, (RenderPipelineDescriptor{
        .vertex = .{
            .module = module,
            .stage = .fragment,
        },
        .color_attachments = color_attachments[0..],
    }).validate());

    try std.testing.expectError(PipelineError.MissingColorAttachment, (RenderPipelineDescriptor{
        .vertex = .{
            .module = module,
            .stage = .vertex,
        },
    }).validate());

    const bad_attributes = [_]VertexAttributeDescriptor{
        .{ .location = 0, .format = .float32x4, .offset = 4 },
    };
    const bad_vertex_buffers = [_]VertexBufferLayoutDescriptor{
        .{ .stride = 8, .attributes = bad_attributes[0..] },
    };
    try std.testing.expectError(PipelineError.InvalidVertexAttributeOffset, (RenderPipelineDescriptor{
        .vertex = .{
            .module = module,
            .stage = .vertex,
        },
        .vertex_descriptor = .{ .buffers = bad_vertex_buffers[0..] },
        .color_attachments = color_attachments[0..],
    }).validate());

    const duplicate_location_attributes = [_]VertexAttributeDescriptor{
        .{ .location = 0, .format = .float32x2, .offset = 0 },
        .{ .location = 0, .format = .float32x2, .offset = 8 },
    };
    const duplicate_location_buffers = [_]VertexBufferLayoutDescriptor{
        .{ .stride = 16, .attributes = duplicate_location_attributes[0..] },
    };
    try std.testing.expectError(PipelineError.DuplicateVertexAttributeLocation, (RenderPipelineDescriptor{
        .vertex = .{
            .module = module,
            .stage = .vertex,
        },
        .vertex_descriptor = .{ .buffers = duplicate_location_buffers[0..] },
        .color_attachments = color_attachments[0..],
    }).validate());

    const duplicate_index_buffers = [_]VertexBufferLayoutDescriptor{
        .{ .buffer_index = 2, .stride = 8 },
        .{ .buffer_index = 2, .stride = 8 },
    };
    try std.testing.expectError(PipelineError.DuplicateVertexBufferIndex, (RenderPipelineDescriptor{
        .vertex = .{
            .module = module,
            .stage = .vertex,
        },
        .vertex_descriptor = .{ .buffers = duplicate_index_buffers[0..] },
        .color_attachments = color_attachments[0..],
    }).validate());

    const invalid_step_rate_buffers = [_]VertexBufferLayoutDescriptor{
        .{ .stride = 8, .step_function = .per_instance, .instance_step_rate = 0 },
    };
    try std.testing.expectError(PipelineError.InvalidInstanceStepRate, (RenderPipelineDescriptor{
        .vertex = .{
            .module = module,
            .stage = .vertex,
        },
        .vertex_descriptor = .{ .buffers = invalid_step_rate_buffers[0..] },
        .color_attachments = color_attachments[0..],
    }).validate());

    const invalid_per_vertex_step_rate_buffers = [_]VertexBufferLayoutDescriptor{
        .{ .stride = 8, .step_function = .per_vertex, .instance_step_rate = 2 },
    };
    try std.testing.expectError(PipelineError.InvalidInstanceStepRate, (RenderPipelineDescriptor{
        .vertex = .{
            .module = module,
            .stage = .vertex,
        },
        .vertex_descriptor = .{ .buffers = invalid_per_vertex_step_rate_buffers[0..] },
        .color_attachments = color_attachments[0..],
    }).validate());
}

test "compute pipeline descriptor validates shader stage and layouts" {
    const module = ShaderModuleDescriptor{
        .source = .{ .slang = "[shader(\"compute\")] [numthreads(1, 1, 1)] void cs_main() {}" },
    };
    const bind_group_entries = [_]BindGroupLayoutEntry{
        .{
            .binding = 0,
            .resource = .storage_buffer,
            .visibility = .{ .compute = true },
        },
    };
    const bind_group_layouts = [_]BindGroupLayoutDescriptor{
        .{ .entries = bind_group_entries[0..] },
    };

    try (ComputePipelineDescriptor{
        .compute = .{
            .module = module,
            .stage = .compute,
            .entry_point = "cs_main",
        },
        .bind_group_layouts = bind_group_layouts[0..],
    }).validate();

    try std.testing.expectError(ShaderError.UnexpectedShaderStage, (ComputePipelineDescriptor{
        .compute = .{
            .module = module,
            .stage = .vertex,
            .entry_point = "cs_main",
        },
    }).validate());
}

test "compute pipeline descriptor validates storage texture reflection" {
    const module = ShaderModuleDescriptor{
        .source = .{ .slang = "[shader(\"compute\")] [numthreads(1, 1, 1)] void cs_main() {}" },
    };
    const reflected_bindings = [_]ShaderReflectionBinding{
        .{
            .binding = 0,
            .resource = .storage_texture,
            .visibility = .{ .compute = true },
        },
        .{
            .binding = 1,
            .resource = .storage_buffer,
            .visibility = .{ .compute = true },
        },
    };
    const reflected_groups = [_]ShaderReflectionBindGroup{
        .{ .index = 0, .bindings = reflected_bindings[0..] },
    };
    const bind_group_layouts = [_]BindGroupLayoutDescriptor{
        .{ .entries = &.{ .{
            .binding = 0,
            .resource = .storage_texture,
            .visibility = .{ .compute = true },
        }, .{
            .binding = 1,
            .resource = .storage_buffer,
            .visibility = .{ .compute = true },
        } } },
    };

    try (ComputePipelineDescriptor{
        .compute = .{
            .module = module,
            .stage = .compute,
            .entry_point = "cs_main",
            .reflection = .{ .data = .{
                .stage = .compute,
                .entry_point = "cs_main",
                .bind_groups = reflected_groups[0..],
            } },
        },
        .bind_group_layouts = bind_group_layouts[0..],
    }).validate();

    try std.testing.expectError(ShaderError.ShaderReflectionMissingBindGroupLayout, (ComputePipelineDescriptor{
        .compute = .{
            .module = module,
            .stage = .compute,
            .entry_point = "cs_main",
            .reflection = .{ .data = .{
                .stage = .compute,
                .entry_point = "cs_main",
                .bind_groups = &.{.{ .index = 1, .bindings = reflected_bindings[0..] }},
            } },
        },
        .bind_group_layouts = bind_group_layouts[0..],
    }).validate());
}

test "render pass descriptor requires at least one color attachment" {
    const color_attachments = [_]RenderPassColorAttachmentDescriptor{
        .{
            .load_action = .clear,
            .store_action = .store,
            .clear_color = .{ .red = 0.1, .green = 0.2, .blue = 0.3, .alpha = 1.0 },
        },
    };

    try (RenderPassDescriptor{
        .color_attachments = color_attachments[0..],
    }).validate();
    try std.testing.expectError(CommandEncodingError.MissingColorAttachment, (RenderPassDescriptor{}).validate());
}

test "render pass descriptor validates depth attachment" {
    const color_attachments = [_]RenderPassColorAttachmentDescriptor{.{}};

    try (RenderPassDescriptor{
        .color_attachments = color_attachments[0..],
        .depth_attachment = .{
            .load_action = .clear,
            .store_action = .dont_care,
            .clear_depth = 1.0,
        },
    }).validate();

    try std.testing.expectError(CommandEncodingError.InvalidDepthClearValue, (RenderPassDescriptor{
        .color_attachments = color_attachments[0..],
        .depth_attachment = .{ .clear_depth = 1.5 },
    }).validate());

    try (RenderPassDescriptor{
        .color_attachments = color_attachments[0..],
        .stencil_attachment = .{
            .load_action = .clear,
            .store_action = .store,
            .clear_stencil = 0xff,
            .options = .{ .transient = true },
        },
    }).validate();

    try std.testing.expectError(CommandEncodingError.InvalidStencilClearValue, (RenderPassDescriptor{
        .color_attachments = color_attachments[0..],
        .stencil_attachment = .{ .clear_stencil = 0x100 },
    }).validate());
}

test "draw descriptors validate counts and index alignment" {
    try (Viewport{
        .width = 640,
        .height = 480,
    }).validate();
    try std.testing.expectError(CommandEncodingError.InvalidViewport, (Viewport{
        .width = 0,
        .height = 480,
    }).validate());
    try (ScissorRect{
        .width = 640,
        .height = 480,
    }).validate();
    try std.testing.expectError(CommandEncodingError.InvalidScissorRect, (ScissorRect{
        .width = 0,
        .height = 480,
    }).validate());
    try (BlendColor{
        .red = 1,
        .alpha = 1,
    }).validate();
    try std.testing.expectError(CommandEncodingError.InvalidBlendColor, (BlendColor{
        .red = std.math.inf(f32),
    }).validate());
    try (StencilReference{ .value = 0xff }).validate();
    try std.testing.expectError(CommandEncodingError.InvalidStencilReference, (StencilReference{
        .value = 0x100,
    }).validate());

    try (DrawPrimitivesDescriptor{
        .vertex_count = 3,
    }).validate();
    try std.testing.expectError(CommandEncodingError.InvalidVertexCount, (DrawPrimitivesDescriptor{}).validate());
    try std.testing.expectError(CommandEncodingError.InvalidInstanceCount, (DrawPrimitivesDescriptor{
        .vertex_count = 3,
        .instance_count = 0,
    }).validate());

    try (DrawIndexedPrimitivesDescriptor{
        .index_type = .uint32,
        .index_count = 6,
        .index_buffer_offset = 4,
    }).validate();
    try std.testing.expectError(CommandEncodingError.InvalidIndexBufferOffset, (DrawIndexedPrimitivesDescriptor{
        .index_type = .uint32,
        .index_count = 6,
        .index_buffer_offset = 2,
    }).validate());

    try (DrawPrimitivesDescriptor{
        .vertex_count = 3,
        .base_instance = 2,
    }).validate();
    try (DrawIndexedPrimitivesDescriptor{
        .index_count = 6,
        .base_vertex = -3,
        .base_instance = 2,
    }).validate();
    try (DrawPrimitivesIndirectDescriptor{
        .draw_count = 2,
        .stride = 16,
    }).validate();
    try std.testing.expectError(CommandEncodingError.InvalidDrawCount, (DrawPrimitivesIndirectDescriptor{
        .draw_count = 0,
    }).validate());
    try std.testing.expectError(CommandEncodingError.InvalidIndirectDrawStride, (DrawIndexedPrimitivesIndirectDescriptor{
        .stride = 6,
    }).validate());

    const draws = [_]DrawPrimitivesDescriptor{
        .{ .vertex_count = 3 },
        .{ .vertex_count = 6, .instance_count = 2 },
    };
    try (MultiDrawPrimitivesDescriptor{ .draws = draws[0..] }).validate();
    try std.testing.expectError(CommandEncodingError.InvalidDrawCount, (MultiDrawIndexedPrimitivesDescriptor{}).validate());
}

test "copy descriptors validate ranges and texture layouts" {
    try (CopyBufferToBufferDescriptor{
        .size = 8,
        .source_offset = 4,
        .destination_offset = 2,
    }).validate(16, 16);
    try std.testing.expectError(CommandEncodingError.InvalidCopySize, (CopyBufferToBufferDescriptor{
        .size = 0,
    }).validate(16, 16));
    try std.testing.expectError(CommandEncodingError.InvalidCopyBufferRange, (CopyBufferToBufferDescriptor{
        .size = 8,
        .source_offset = 12,
    }).validate(16, 16));

    const texture = TextureDescriptor{
        .format = .rgba8_unorm,
        .width = 4,
        .height = 4,
        .usage = .{ .copy_destination = true },
    };
    const resolved = try (CopyBufferToTextureDescriptor{
        .destination_region = .{ .size = .{ .width = 4, .height = 2 } },
    }).resolve(32, texture);
    try std.testing.expectEqual(@as(usize, 16), resolved.bytes_per_row);
    try std.testing.expectEqual(@as(usize, 32), resolved.required_bytes);

    try std.testing.expectError(CommandEncodingError.InvalidCopyBufferLayout, (CopyBufferToTextureDescriptor{
        .source = .{ .bytes_per_row = 15 },
        .destination_region = .{ .size = .{ .width = 4, .height = 2 } },
    }).resolve(64, texture));
    try std.testing.expectError(CommandEncodingError.InvalidCopyBufferRange, (CopyTextureToBufferDescriptor{
        .source_region = .{ .size = .{ .width = 4, .height = 4 } },
    }).resolve(texture, 8));

    try (FillBufferDescriptor{
        .offset = 4,
        .size = 4,
        .value = 0xff,
    }).validate(16);
    try std.testing.expectError(CommandEncodingError.InvalidFillBufferRange, (FillBufferDescriptor{
        .offset = 12,
        .size = 8,
    }).validate(16));

    const source_texture = TextureDescriptor{
        .format = .rgba8_unorm,
        .width = 4,
        .height = 4,
        .depth_or_array_layers = 3,
        .mip_level_count = 2,
        .usage = .{ .copy_source = true },
    };
    const destination_texture = TextureDescriptor{
        .format = .rgba8_unorm,
        .width = 4,
        .height = 4,
        .depth_or_array_layers = 3,
        .mip_level_count = 2,
        .usage = .{ .copy_destination = true },
    };
    const resolved_texture_copy = try (CopyTextureToTextureDescriptor{
        .source_region = .{ .size = .{ .width = 1, .height = 1 } },
        .source_mip_level = 1,
        .source_slice = 1,
        .slice_count = 2,
        .destination_origin = .{ .x = 1, .y = 1 },
        .destination_mip_level = 1,
        .destination_slice = 1,
    }).resolve(source_texture, destination_texture);
    try std.testing.expectEqual(@as(u32, 1), resolved_texture_copy.destination_origin.x);
    try std.testing.expectEqual(@as(u32, 2), resolved_texture_copy.slice_count);
    try std.testing.expectError(CommandEncodingError.InvalidCopyTextureRegion, (CopyTextureToTextureDescriptor{
        .source_region = .{ .origin = .{ .x = 3 }, .size = .{ .width = 2, .height = 1 } },
    }).resolve(source_texture, destination_texture));
    try std.testing.expectError(CommandEncodingError.InvalidCopyTextureSlice, (CopyTextureToTextureDescriptor{
        .source_region = .{ .size = .{ .width = 1, .height = 1 } },
        .source_slice = 2,
        .slice_count = 2,
    }).resolve(source_texture, destination_texture));
    _ = try (CopyTextureToTextureDescriptor{
        .source_region = .{ .size = .{ .width = 1, .height = 1 } },
    }).resolve(source_texture, .{
        .format = .rgba8_unorm_srgb,
        .width = 4,
        .height = 4,
        .depth_or_array_layers = 3,
        .mip_level_count = 2,
        .usage = .{ .copy_destination = true },
    });
    try std.testing.expectError(CommandEncodingError.UnsupportedTextureCopyFormat, (CopyTextureToTextureDescriptor{
        .source_region = .{ .size = .{ .width = 1, .height = 1 } },
    }).resolve(source_texture, .{
        .format = .bgra8_unorm,
        .width = 4,
        .height = 4,
        .usage = .{ .copy_destination = true },
    }));
}

test "query descriptors validate feature gates and ranges" {
    const occlusion_set = QuerySetDescriptor{
        .query_type = .occlusion,
        .count = 4,
    };
    try occlusion_set.validate(.{ .occlusion_queries = true });
    try std.testing.expectError(QueryError.UnsupportedOcclusionQueries, occlusion_set.validate(.{}));
    try std.testing.expectError(QueryError.InvalidQueryCount, (QuerySetDescriptor{
        .query_type = .timestamp,
        .count = 0,
    }).validate(.{ .timestamp_queries = true }));

    const statistics_set = QuerySetDescriptor{
        .query_type = .pipeline_statistics,
        .count = 2,
        .pipeline_statistics = .{ .vertex_invocations = true },
    };
    try statistics_set.validate(.{ .pipeline_statistics_queries = true });
    try std.testing.expectError(QueryError.MissingPipelineStatistics, (QuerySetDescriptor{
        .query_type = .pipeline_statistics,
        .count = 2,
    }).validate(.{ .pipeline_statistics_queries = true }));

    try (QueryResolveDescriptor{
        .first_query = 1,
        .query_count = 2,
        .destination_offset = 16,
    }).validate(occlusion_set, .{ .query_result_alignment = 8 });
    try std.testing.expectError(QueryError.InvalidQueryRange, (QueryResolveDescriptor{
        .first_query = 3,
        .query_count = 2,
    }).validate(occlusion_set, .{ .query_result_alignment = 8 }));
    try std.testing.expectError(QueryError.InvalidQueryResultAlignment, (QueryResolveDescriptor{
        .first_query = 0,
        .query_count = 1,
        .destination_offset = 4,
    }).validate(occlusion_set, .{ .query_result_alignment = 8 }));

    var results = [_]u64{0} ** 2;
    try (QueryReadbackDescriptor{
        .first_query = 0,
        .query_count = 2,
        .destination = results[0..],
    }).validate(occlusion_set);
    try std.testing.expectError(QueryError.InvalidQueryRange, (QueryReadbackDescriptor{
        .first_query = 0,
        .query_count = 3,
        .destination = results[0..],
    }).validate(occlusion_set));
    try std.testing.expectError(CommandEncodingError.EmptyDebugGroupLabel, (ProfilerMarkerDescriptor{
        .label = "",
    }).validate(.{}));
    try std.testing.expectError(QueryError.UnsupportedTimestampQueries, (ProfilerMarkerDescriptor{
        .label = "gpu span",
        .write_timestamp_begin = true,
        .write_timestamp_end = true,
    }).validate(.{}));
    try (ProfilerMarkerDescriptor{
        .label = "gpu span",
        .write_timestamp_begin = true,
        .write_timestamp_end = true,
    }).validate(.{ .timestamp_queries = true });
}

test "compute dispatch descriptors validate limits and resolve thread counts" {
    const limits = DeviceLimits{
        .max_compute_threadgroups_per_grid_x = 8,
        .max_compute_threadgroups_per_grid_y = 8,
        .max_compute_threadgroups_per_grid_z = 8,
        .max_compute_threads_per_threadgroup_x = 16,
        .max_compute_threads_per_threadgroup_y = 16,
        .max_compute_threads_per_threadgroup_z = 4,
        .max_compute_total_threads_per_threadgroup = 64,
    };

    try (DispatchThreadgroupsDescriptor{
        .threadgroup_count_x = 4,
        .threads_per_threadgroup_x = 8,
    }).validateForLimits(limits);
    try std.testing.expectError(CommandEncodingError.InvalidThreadgroupCount, (DispatchThreadgroupsDescriptor{
        .threadgroup_count_x = 9,
    }).validateForLimits(limits));
    try std.testing.expectError(CommandEncodingError.InvalidThreadgroupCount, (DispatchThreadgroupsDescriptor{
        .threadgroup_count_x = 1,
        .threads_per_threadgroup_x = 16,
        .threads_per_threadgroup_y = 16,
        .threads_per_threadgroup_z = 1,
    }).validateForLimits(limits));

    const resolved = try (DispatchThreadsDescriptor{
        .thread_count_x = 33,
        .threads_per_threadgroup_x = 8,
    }).resolve(limits);
    try std.testing.expectEqual(@as(u32, 5), resolved.threadgroup_count_x);
    try std.testing.expectEqual(@as(u32, 8), resolved.threads_per_threadgroup_x);
    try std.testing.expectError(CommandEncodingError.InvalidThreadgroupCount, (DispatchThreadsDescriptor{
        .thread_count_x = 0,
    }).resolve(limits));

    try std.testing.expectError(CommandEncodingError.UnsupportedDispatchIndirect, (DispatchThreadgroupsIndirectDescriptor{}).validate(16, .{}, limits));
    try (DispatchThreadgroupsIndirectDescriptor{ .offset = 4 }).validate(16, .{ .compute_dispatch_indirect = true }, limits);
    try std.testing.expectError(CommandEncodingError.InvalidDispatchIndirectOffset, (DispatchThreadgroupsIndirectDescriptor{
        .offset = 2,
    }).validate(16, .{ .compute_dispatch_indirect = true }, limits));
    try std.testing.expectError(CommandEncodingError.InvalidDispatchIndirectOffset, (DispatchThreadgroupsIndirectDescriptor{
        .offset = 8,
    }).validate(16, .{ .compute_dispatch_indirect = true }, limits));
}

test "compute atomic and threadgroup memory descriptors validate gates" {
    try std.testing.expectError(CommandEncodingError.UnsupportedComputeAtomics, (ComputeAtomicDescriptor{
        .operations = .{ .add = true },
    }).validate(.{}));
    try (ComputeAtomicDescriptor{
        .storage = .storage_buffer,
        .operations = .{ .add = true, .compare_exchange = true },
    }).validate(.{ .compute_atomics = true });
    try std.testing.expectError(CommandEncodingError.InvalidAtomicStorageResource, (ComputeAtomicDescriptor{
        .storage = .uniform_buffer,
        .operations = .{ .add = true },
    }).validate(.{ .compute_atomics = true }));
    try std.testing.expectError(CommandEncodingError.MissingAtomicOperation, (ComputeAtomicDescriptor{}).validate(.{ .compute_atomics = true }));

    const limits = DeviceLimits{ .max_compute_threadgroup_memory_bytes = 1024 };
    try std.testing.expectError(CommandEncodingError.UnsupportedThreadgroupMemory, (ThreadgroupMemoryDescriptor{
        .bytes = 256,
    }).validate(.{}, limits));
    try (ThreadgroupMemoryDescriptor{ .bytes = 256, .alignment = 16 }).validate(.{ .compute_threadgroup_memory = true }, limits);
    try std.testing.expectError(CommandEncodingError.InvalidThreadgroupMemorySize, (ThreadgroupMemoryDescriptor{
        .bytes = 2048,
    }).validate(.{ .compute_threadgroup_memory = true }, limits));
    try std.testing.expectError(CommandEncodingError.InvalidThreadgroupMemoryAlignment, (ThreadgroupMemoryDescriptor{
        .bytes = 258,
        .alignment = 16,
    }).validate(.{ .compute_threadgroup_memory = true }, limits));
}

test "command debug state validates render pass ordering" {
    const color_attachments = [_]RenderPassColorAttachmentDescriptor{.{}};
    var command_buffer = CommandBufferDebugState{};
    try command_buffer.insertDebugSignpost(.{ .label = "before pass" });
    var encoder = try command_buffer.makeRenderCommandEncoder(.{
        .color_attachments = color_attachments[0..],
    });

    try std.testing.expectError(CommandEncodingError.InvalidCommandBufferState, command_buffer.insertDebugSignpost(.{ .label = "inside pass" }));
    try std.testing.expectError(CommandEncodingError.InvalidCommandBufferState, command_buffer.commit());
    try std.testing.expectError(CommandEncodingError.MissingRenderPipelineState, encoder.drawPrimitives(.{
        .vertex_count = 3,
    }));

    try encoder.insertDebugSignpost(.{ .label = "draw setup" });
    try encoder.setRenderPipelineState();
    try encoder.setVertexBuffer(.{ .index = 0 });
    try encoder.setResourceTable(.{ .index = 1 });
    try std.testing.expectEqual(@as(u64, 2), encoder.resource_table_mask);
    try std.testing.expectError(CommandEncodingError.InvalidBindGroupIndex, encoder.setResourceTable(.{
        .index = max_bind_group_slots,
    }));
    try encoder.drawPrimitives(.{ .vertex_count = 3 });
    try encoder.endEncoding(&command_buffer);
    try std.testing.expectError(CommandEncodingError.InvalidRenderCommandEncoderState, encoder.insertDebugSignpost(.{ .label = "ended" }));
    try std.testing.expectError(CommandEncodingError.InvalidRenderCommandEncoderState, encoder.drawPrimitives(.{
        .vertex_count = 3,
    }));

    try command_buffer.presentDrawable();
    try command_buffer.commit();
    try std.testing.expectError(CommandEncodingError.InvalidCommandBufferState, command_buffer.presentDrawable());
}

test "command buffer descriptor validates pooling and reset gates" {
    try (CommandBufferDescriptor{}).validate(.{});
    try std.testing.expectError(CommandEncodingError.UnsupportedCommandBufferPooling, (CommandBufferDescriptor{
        .pooled = true,
    }).validate(.{}));
    try std.testing.expectError(CommandEncodingError.UnsupportedCommandBufferReset, (CommandBufferDescriptor{
        .pooled = true,
        .reusable = true,
    }).validate(.{ .command_buffer_pooling = true }));

    var debug = try CommandBufferDebugState.init(.{
        .pooled = true,
        .reusable = true,
    }, .{
        .command_buffer_pooling = true,
        .command_buffer_reset = true,
    });
    try debug.commit();
    try debug.reset();
    try std.testing.expectEqual(CommandBufferState.ready, debug.status());
}

test "command debug state validates blit pass ordering" {
    var command_buffer = CommandBufferDebugState{};
    var encoder = try command_buffer.makeBlitCommandEncoder();

    try std.testing.expectError(CommandEncodingError.InvalidCommandBufferState, command_buffer.commit());
    try encoder.copyBufferToBuffer(.{ .size = 4 }, 8, 8);
    try encoder.fillBuffer(.{ .size = 4 }, 8);
    try encoder.insertDebugSignpost(.{ .label = "copy setup" });
    _ = try encoder.copyTextureToTexture(.{
        .source_region = .{ .size = .{ .width = 1, .height = 1 } },
    }, .{
        .format = .rgba8_unorm,
        .width = 1,
        .height = 1,
        .usage = .{ .copy_source = true },
    }, .{
        .format = .rgba8_unorm,
        .width = 1,
        .height = 1,
        .usage = .{ .copy_destination = true },
    });
    try encoder.endEncoding(&command_buffer);
    try std.testing.expectError(CommandEncodingError.InvalidBlitCommandEncoderState, encoder.copyBufferToBuffer(.{ .size = 4 }, 8, 8));
    try std.testing.expectError(CommandEncodingError.InvalidBlitCommandEncoderState, encoder.fillBuffer(.{ .size = 4 }, 8));
    try std.testing.expectError(CommandEncodingError.InvalidBlitCommandEncoderState, encoder.insertDebugSignpost(.{ .label = "ended" }));
    try command_buffer.commit();
}

test "command debug state validates compute pass ordering" {
    var command_buffer = CommandBufferDebugState{};
    var encoder = try command_buffer.makeComputeCommandEncoder();

    try std.testing.expectError(CommandEncodingError.InvalidCommandBufferState, command_buffer.commit());
    try std.testing.expectError(CommandEncodingError.MissingComputePipelineState, encoder.dispatchThreadgroups(.{
        .threadgroup_count_x = 1,
    }));
    try encoder.setComputePipelineState();
    try encoder.setBindGroup(.{ .index = 0 });
    try encoder.setResourceTable(.{ .index = 1 });
    try std.testing.expectEqual(@as(u64, 2), encoder.resource_table_mask);
    try encoder.insertDebugSignpost(.{ .label = "dispatch setup" });
    _ = try encoder.dispatchThreads(.{
        .thread_count_x = 7,
        .threads_per_threadgroup_x = 4,
    }, defaultDeviceLimits(.metal));
    try encoder.dispatchThreadgroupsIndirect(.{}, 16, .{ .compute_dispatch_indirect = true }, defaultDeviceLimits(.metal));
    try encoder.dispatchThreadgroups(.{
        .threadgroup_count_x = 1,
        .threads_per_threadgroup_x = 4,
    });
    try encoder.endEncoding(&command_buffer);
    try std.testing.expectError(CommandEncodingError.InvalidComputeCommandEncoderState, encoder.insertDebugSignpost(.{ .label = "ended" }));
    try std.testing.expectError(CommandEncodingError.InvalidComputeCommandEncoderState, encoder.dispatchThreadgroupsIndirect(.{}, 16, .{ .compute_dispatch_indirect = true }, defaultDeviceLimits(.metal)));
    try std.testing.expectError(CommandEncodingError.InvalidComputeCommandEncoderState, encoder.dispatchThreadgroups(.{
        .threadgroup_count_x = 1,
    }));
    try command_buffer.commit();
}

test "command debug state validates indexed draw requirements" {
    const color_attachments = [_]RenderPassColorAttachmentDescriptor{.{}};
    var command_buffer = CommandBufferDebugState{};
    var encoder = try command_buffer.makeRenderCommandEncoder(.{
        .color_attachments = color_attachments[0..],
    });

    try encoder.setRenderPipelineState();
    try std.testing.expectError(CommandEncodingError.MissingIndexBuffer, encoder.drawIndexedPrimitives(.{
        .index_count = 6,
    }));
    try encoder.setIndexBuffer();
    try encoder.drawIndexedPrimitives(.{ .index_count = 6 });
    try encoder.endEncoding(&command_buffer);
}

test "command debug state tracks bind groups" {
    const color_attachments = [_]RenderPassColorAttachmentDescriptor{.{}};
    var command_buffer = CommandBufferDebugState{};
    var encoder = try command_buffer.makeRenderCommandEncoder(.{
        .color_attachments = color_attachments[0..],
    });

    try encoder.setBindGroup(.{ .index = 0 });
    try std.testing.expectEqual(@as(u64, 1), encoder.bind_group_mask);
    try std.testing.expectError(CommandEncodingError.InvalidBindGroupIndex, encoder.setBindGroup(.{
        .index = max_bind_group_slots,
    }));

    try encoder.endEncoding(&command_buffer);
    try std.testing.expectError(CommandEncodingError.InvalidRenderCommandEncoderState, encoder.setBindGroup(.{
        .index = 0,
    }));
}

test "texture descriptor validates basic 2d textures" {
    try (TextureDescriptor{
        .format = .rgba8_unorm,
        .width = 256,
        .height = 128,
        .usage = .{ .shader_read = true },
    }).validate();

    try (TextureDescriptor{
        .format = .depth32_float,
        .width = 256,
        .height = 128,
        .usage = .{ .render_attachment = true },
    }).validate();
}

test "texture descriptor rejects missing extent and automatic format" {
    try std.testing.expectError(TextureError.InvalidTextureFormat, (TextureDescriptor{}).validate());
    try std.testing.expectError(TextureError.InvalidTextureExtent, (TextureDescriptor{
        .format = .rgba8_unorm,
        .height = 128,
    }).validate());
}

test "texture descriptor validates dimension shape and sample count" {
    try (TextureDescriptor{
        .format = .rgba8_unorm,
        .width = 256,
        .height = 128,
        .sample_count = 4,
        .usage = .{ .render_attachment = true },
        .storage_mode = .private,
    }).validate();

    try std.testing.expectError(TextureError.InvalidTextureExtent, (TextureDescriptor{
        .dimension = .one_d,
        .format = .rgba8_unorm,
        .width = 256,
        .height = 2,
    }).validate());
    try std.testing.expectError(TextureError.UnsupportedSampleCount, (TextureDescriptor{
        .format = .rgba8_unorm,
        .width = 256,
        .height = 128,
        .sample_count = 4,
    }).validate());
    try std.testing.expectError(TextureError.UnsupportedSampleCount, (TextureDescriptor{
        .format = .rgba8_unorm,
        .width = 256,
        .height = 128,
        .mip_level_count = 2,
        .sample_count = 4,
        .usage = .{ .render_attachment = true },
        .storage_mode = .private,
    }).validate());
}

test "texture descriptor validates and resolves mip ranges" {
    const texture = TextureDescriptor{
        .format = .rgba8_unorm,
        .width = 8,
        .height = 4,
        .mip_level_count = 4,
    };

    try std.testing.expectEqual(@as(u32, 4), texture.maxMipLevelCount());
    try std.testing.expectEqual(@as(u32, 4), maxMipLevelCountForExtent(8, 4, 1));
    try std.testing.expectEqual(@as(u32, 2), mipDimension(8, 2));

    const mip = try texture.mipExtent(2);
    try std.testing.expectEqual(@as(u32, 2), mip.width);
    try std.testing.expectEqual(@as(u32, 1), mip.height);

    try std.testing.expectError(TextureError.InvalidMipLevelCount, (TextureDescriptor{
        .format = .rgba8_unorm,
        .width = 8,
        .height = 4,
        .mip_level_count = 5,
    }).validate());
}

test "external texture descriptors validate backend and feature gates" {
    const vulkan_memory = ExternalMemoryDescriptor{
        .handle = .{
            .kind = .vulkan_memory,
            .value = 1,
            .backend = .vulkan,
        },
        .size = 4096,
    };
    try std.testing.expect(ExternalHandleKind.vulkan_memory.isVulkanSpecific());
    try std.testing.expect(!ExternalHandleKind.opaque_fd.isVulkanSpecific());
    try std.testing.expectError(AdvancedFeatureError.UnsupportedExternalMemory, vulkan_memory.validate(.vulkan, .{}));
    try vulkan_memory.validate(.vulkan, .{ .external_memory = true });
    try std.testing.expectError(AdvancedFeatureError.ExternalHandleBackendMismatch, vulkan_memory.validate(.metal, .{ .external_memory = true }));
    try std.testing.expectError(AdvancedFeatureError.InvalidExternalHandle, (ExternalMemoryDescriptor{
        .handle = .{ .kind = .opaque_fd, .value = 1 },
        .size = 0,
    }).validate(.vulkan, .{ .external_memory = true }));

    const vulkan_image = ExternalTextureDescriptor{
        .handle = .{ .kind = .vulkan_image, .value = 2 },
        .format = .rgba8_unorm,
        .width = 32,
        .height = 32,
    };
    try vulkan_image.validate(.vulkan, .{ .external_textures = true });
    try std.testing.expectError(AdvancedFeatureError.ExternalHandleBackendMismatch, vulkan_image.validate(.metal, .{ .external_textures = true }));

    const metal_handle = ExternalHandleDescriptor{
        .kind = .iosurface,
        .value = 1,
        .backend = .metal,
    };
    try std.testing.expect(ExternalHandleKind.metal_buffer.isMetalSpecific());
    try std.testing.expect(!ExternalHandleKind.vulkan_memory.isMetalSpecific());

    const external_buffer = ExternalBufferDescriptor{
        .handle = .{ .kind = .metal_buffer, .value = 3 },
        .length = 256,
        .ownership = .borrowed,
    };
    try std.testing.expectEqual(ExternalResourceOwnership.borrowed, external_buffer.ownership);
    try std.testing.expectError(AdvancedFeatureError.UnsupportedExternalMemory, external_buffer.validate(.metal, .{}));
    try external_buffer.validate(.metal, .{ .external_memory = true });
    try std.testing.expectError(AdvancedFeatureError.ExternalHandleBackendMismatch, external_buffer.validate(.vulkan, .{ .external_memory = true }));

    try (ExternalEventDescriptor{
        .handle = .{ .kind = .metal_shared_event, .value = 4 },
        .shared = true,
    }).validate(.metal, .{ .external_semaphores = true });
    try std.testing.expectError(AdvancedFeatureError.ExternalHandleBackendMismatch, (ExternalEventDescriptor{
        .handle = .{ .kind = .metal_shared_event, .value = 4 },
    }).validate(.vulkan, .{ .external_semaphores = true }));

    const external_texture = ExternalTextureDescriptor{
        .handle = metal_handle,
        .format = .rgba8_unorm,
        .width = 64,
        .height = 64,
    };

    try std.testing.expectError(AdvancedFeatureError.UnsupportedExternalTextures, external_texture.validate(.metal, .{}));
    try external_texture.validate(.metal, .{ .external_textures = true });
    try std.testing.expectError(AdvancedFeatureError.ExternalHandleBackendMismatch, external_texture.validate(.vulkan, .{ .external_textures = true }));
    try std.testing.expectError(AdvancedFeatureError.InvalidExternalHandle, (ExternalTextureDescriptor{
        .handle = .{ .kind = .opaque_fd, .value = 0 },
        .format = .rgba8_unorm,
        .width = 64,
        .height = 64,
    }).validate(.vulkan, .{ .external_textures = true }));

    try std.testing.expectError(AdvancedFeatureError.UnsupportedExternalSemaphores, (ExternalSemaphoreDescriptor{
        .handle = .{ .kind = .vulkan_semaphore, .value = 1 },
    }).validate(.vulkan, .{}));
    try (ExternalSemaphoreDescriptor{
        .handle = .{ .kind = .vulkan_semaphore, .value = 1 },
        .timeline = true,
    }).validate(.vulkan, .{ .external_semaphores = true });
}

test "native command insertion descriptors are explicit and gated" {
    const callback = struct {
        fn call(context: ?*anyopaque, handles: NativeHandleView) void {
            _ = context;
            _ = handles;
        }
    }.call;

    try std.testing.expectError(AdvancedFeatureError.UnsupportedNativeCommandInsertion, (NativeCommandInsertionDescriptor{
        .encoder = .render,
        .callback = callback,
    }).validate(.{}));

    try std.testing.expectError(AdvancedFeatureError.MissingNativeCommandCallback, (NativeCommandInsertionDescriptor{
        .encoder = .compute,
    }).validate(.{ .native_command_insertion = true }));

    try (NativeCommandInsertionDescriptor{
        .label = "native render hook",
        .encoder = .render,
        .point = .after_portable_commands,
        .callback = callback,
        .inserts_resource_boundary = true,
    }).validateForEncoder(.render, .{ .native_command_insertion = true });

    try std.testing.expectError(AdvancedFeatureError.NativeCommandEncoderMismatch, (NativeCommandInsertionDescriptor{
        .label = "native render hook",
        .encoder = .render,
        .callback = callback,
    }).validateForEncoder(.compute, .{ .native_command_insertion = true }));
}

test "sparse resource descriptors validate feature gates and alignment" {
    try std.testing.expectError(AdvancedFeatureError.UnsupportedSparseBuffers, (SparseBufferDescriptor{
        .size = 4096,
    }).validate(.{}, .{}));
    try (SparseBufferDescriptor{
        .size = 8192,
    }).validate(.{ .sparse_buffers = true }, .{ .sparse_buffer_page_size = 4096 });
    const sparse_buffer_lowering = try SparseBufferLowering.fromDescriptor(.vulkan, .{
        .size = 8192,
    }, .{ .sparse_buffers = true }, .{ .sparse_buffer_page_size = 4096 });
    try std.testing.expectEqual(Backend.vulkan, sparse_buffer_lowering.backend);
    try std.testing.expectEqual(SparseBufferLoweringMode.vulkan_sparse_binding, sparse_buffer_lowering.mode);
    try std.testing.expectEqual(@as(u64, 4096), sparse_buffer_lowering.page_size);
    try std.testing.expectEqual(@as(u64, 2), sparse_buffer_lowering.page_count);
    try std.testing.expect(sparse_buffer_lowering.requires_residency_commit);
    try std.testing.expectError(AdvancedFeatureError.InvalidSparseRegion, (SparseBufferDescriptor{
        .size = 1024,
    }).validate(.{ .sparse_buffers = true }, .{ .sparse_buffer_page_size = 4096 }));

    const buffer_mapping = SparseBufferMappingDescriptor{
        .offset = 4096,
        .size = 4096,
    };
    try std.testing.expectError(AdvancedFeatureError.UnsupportedSparseBuffers, buffer_mapping.validate(.{}, .{}));
    try buffer_mapping.validate(.{ .sparse_buffers = true }, .{ .sparse_buffer_page_size = 4096 });
    try std.testing.expectError(AdvancedFeatureError.InvalidSparseRegion, (SparseBufferMappingDescriptor{
        .offset = 1,
        .size = 4096,
    }).validate(.{ .sparse_buffers = true }, .{ .sparse_buffer_page_size = 4096 }));

    const texture_mapping = SparseTextureMappingDescriptor{
        .region = .{ .size = .{ .width = 64, .height = 64, .depth = 1 } },
        .page_extent = .{ .width = 64, .height = 64, .depth = 1 },
    };
    try std.testing.expectError(AdvancedFeatureError.UnsupportedSparseTextures, (SparseTextureDescriptor{
        .texture = .{
            .format = .rgba8_unorm,
            .width = 128,
            .height = 128,
            .usage = .{ .shader_read = true },
        },
        .page_extent = .{ .width = 64, .height = 64, .depth = 1 },
    }).validate(.{}, .{}));
    try (SparseTextureDescriptor{
        .texture = .{
            .format = .rgba8_unorm,
            .width = 130,
            .height = 129,
            .usage = .{ .shader_read = true },
        },
        .page_extent = .{ .width = 64, .height = 64, .depth = 1 },
    }).validate(.{ .sparse_textures = true }, .{
        .sparse_texture_page_width = 64,
        .sparse_texture_page_height = 64,
        .sparse_texture_page_depth = 1,
    });
    const sparse_texture_lowering = try SparseTextureLowering.fromDescriptor(.vulkan, .{
        .texture = .{
            .format = .rgba8_unorm,
            .width = 130,
            .height = 129,
            .usage = .{ .shader_read = true },
        },
        .page_extent = .{ .width = 64, .height = 64, .depth = 1 },
    }, .{ .sparse_textures = true }, .{
        .sparse_texture_page_width = 64,
        .sparse_texture_page_height = 64,
        .sparse_texture_page_depth = 1,
    });
    try std.testing.expectEqual(SparseTextureLoweringMode.vulkan_sparse_image, sparse_texture_lowering.mode);
    try std.testing.expectEqual(@as(u32, 3), sparse_texture_lowering.page_grid.width);
    try std.testing.expectEqual(@as(u32, 3), sparse_texture_lowering.page_grid.height);
    try std.testing.expectEqual(@as(u32, 1), sparse_texture_lowering.page_grid.depth);
    try std.testing.expect(sparse_texture_lowering.requires_residency_commit);
    try std.testing.expectError(AdvancedFeatureError.InvalidSparsePageSize, (SparseTextureDescriptor{
        .kind = .tiled_texture,
        .texture = .{
            .format = .rgba8_unorm,
            .width = 128,
            .height = 128,
            .usage = .{ .shader_read = true },
        },
        .page_extent = .{ .width = 32, .height = 64, .depth = 1 },
    }).validate(.{ .tiled_textures = true }, .{
        .sparse_texture_page_width = 64,
        .sparse_texture_page_height = 64,
        .sparse_texture_page_depth = 1,
    }));
    try std.testing.expectError(AdvancedFeatureError.UnsupportedSparseTextures, texture_mapping.validate(.{}, .{}));
    try texture_mapping.validate(.{ .sparse_textures = true }, .{
        .sparse_texture_page_width = 64,
        .sparse_texture_page_height = 64,
        .sparse_texture_page_depth = 1,
    });
    try std.testing.expectError(AdvancedFeatureError.SparseRegionCountExceeded, (SparseMappingCommitDescriptor{
        .buffers = &.{buffer_mapping},
        .textures = &.{texture_mapping},
    }).validate(.{ .sparse_buffers = true, .sparse_textures = true }, .{
        .sparse_buffer_page_size = 4096,
        .sparse_texture_page_width = 64,
        .sparse_texture_page_height = 64,
        .sparse_texture_page_depth = 1,
        .max_sparse_regions_per_commit = 1,
    }));
}

test "sparse residency map tracks commits and rejects overlaps" {
    var map = SparseResidencyMap.init(std.testing.allocator);
    defer map.deinit();

    const buffer_region = SparseBufferMappingDescriptor{
        .offset = 0,
        .size = 4096,
        .page_size = 4096,
    };
    try map.apply(.{ .buffers = &.{buffer_region} });
    try std.testing.expectEqual(@as(usize, 1), map.diagnostics().buffer_regions);
    try std.testing.expectEqual(@as(u64, 4096), map.diagnostics().resident_buffer_bytes);
    try std.testing.expectError(AdvancedFeatureError.InvalidSparseRegion, map.apply(.{
        .buffers = &.{.{
            .offset = 2048,
            .size = 4096,
            .page_size = 4096,
        }},
    }));
    try map.apply(.{ .buffers = &.{.{
        .offset = 0,
        .size = 4096,
        .page_size = 4096,
        .residency = .evicted,
    }} });
    try std.testing.expectEqual(@as(usize, 0), map.diagnostics().buffer_regions);

    const texture_region = SparseTextureMappingDescriptor{
        .region = .{ .size = .{ .width = 64, .height = 64, .depth = 1 } },
        .page_extent = .{ .width = 64, .height = 64, .depth = 1 },
    };
    try map.apply(.{ .textures = &.{texture_region} });
    try std.testing.expectEqual(@as(usize, 1), map.diagnostics().texture_regions);
    try std.testing.expectEqual(@as(u64, 1), map.diagnostics().resident_texture_pages);
    const commit_plan = try (SparseMappingCommitDescriptor{
        .buffers = &.{buffer_region},
        .textures = &.{texture_region},
    }).plan(.{ .sparse_buffers = true, .sparse_textures = true }, .{
        .sparse_buffer_page_size = 4096,
        .sparse_texture_page_width = 64,
        .sparse_texture_page_height = 64,
        .sparse_texture_page_depth = 1,
        .max_sparse_regions_per_commit = 4,
    });
    try std.testing.expectEqual(@as(usize, 2), commit_plan.total_regions);
    try std.testing.expectEqual(@as(usize, 1), commit_plan.buffer_commits);
    try std.testing.expectEqual(@as(usize, 1), commit_plan.texture_commits);
    try std.testing.expectEqual(@as(u64, 4096), commit_plan.buffer_bytes);
    try std.testing.expectEqual(@as(u64, 1), commit_plan.texture_pages);
    try std.testing.expect(!commit_plan.hasEvictions());
    try std.testing.expectError(AdvancedFeatureError.InvalidSparseRegion, map.apply(.{
        .textures = &.{.{
            .region = .{
                .origin = .{ .x = 32, .y = 0, .z = 0 },
                .size = .{ .width = 64, .height = 64, .depth = 1 },
            },
            .page_extent = .{ .width = 64, .height = 64, .depth = 1 },
        }},
    }));
    try map.apply(.{ .textures = &.{.{
        .region = .{ .size = .{ .width = 64, .height = 64, .depth = 1 } },
        .page_extent = .{ .width = 64, .height = 64, .depth = 1 },
        .residency = .evicted,
    }} });
    try std.testing.expectEqual(@as(usize, 0), map.diagnostics().texture_regions);
    const eviction_plan = try (SparseMappingCommitDescriptor{
        .buffers = &.{.{
            .offset = 0,
            .size = 4096,
            .page_size = 4096,
            .residency = .evicted,
        }},
    }).plan(.{ .sparse_buffers = true }, .{ .sparse_buffer_page_size = 4096 });
    try std.testing.expect(eviction_plan.hasEvictions());

    try std.testing.expectError(AdvancedFeatureError.InvalidSparseRegion, map.apply(.{ .buffers = &.{.{
        .offset = 0,
        .size = 4096,
        .page_size = 4096,
        .residency = .evicted,
    }} }));
    try std.testing.expectError(AdvancedFeatureError.InvalidSparseRegion, (SparseMappingCommitDescriptor{}).validate(.{
        .sparse_buffers = true,
        .sparse_textures = true,
    }, .{
        .sparse_buffer_page_size = 4096,
        .sparse_texture_page_width = 64,
        .sparse_texture_page_height = 64,
        .sparse_texture_page_depth = 1,
    }));

    try map.apply(.{ .textures = &.{
        .{
            .mip_level = 0,
            .region = .{ .size = .{ .width = 64, .height = 64, .depth = 1 } },
            .page_extent = .{ .width = 64, .height = 64, .depth = 1 },
        },
        .{
            .mip_level = 1,
            .region = .{ .size = .{ .width = 64, .height = 64, .depth = 1 } },
            .page_extent = .{ .width = 64, .height = 64, .depth = 1 },
        },
    } });
    try std.testing.expectEqual(@as(usize, 2), map.diagnostics().texture_regions);
}

test "sparse mip tail descriptor validates page alignment" {
    const texture = TextureDescriptor{
        .format = .rgba8_unorm,
        .width = 256,
        .height = 256,
        .mip_level_count = 9,
        .usage = .{ .shader_read = true },
    };
    try (SparseMipTailDescriptor{
        .first_mip_level = 6,
        .offset = 4096,
        .size = 8192,
    }).validate(texture, 4096);
    try std.testing.expectError(AdvancedFeatureError.InvalidSparseRegion, (SparseMipTailDescriptor{
        .first_mip_level = 99,
        .offset = 4096,
        .size = 8192,
    }).validate(texture, 4096));
    try std.testing.expectError(AdvancedFeatureError.InvalidSparseRegion, (SparseMipTailDescriptor{
        .first_mip_level = 6,
        .offset = 1,
        .size = 8192,
    }).validate(texture, 4096));
    try std.testing.expectError(AdvancedFeatureError.InvalidSparseRegion, (SparseMipTailDescriptor{
        .first_mip_level = 6,
        .size = 8192,
        .is_packed = false,
    }).validate(texture, 4096));
}

test "Vulkan tessellation lowering preserves patch metadata" {
    const lowering = try VulkanTessellationLowering.fromDescriptor(.{
        .control_point_count = 4,
        .domain = .quad,
        .partition_mode = .fractional_even,
        .has_control_stage = true,
        .has_evaluation_stage = true,
    }, .{ .tessellation = true }, .{ .max_tessellation_control_points = 32 });
    try std.testing.expectEqual(@as(u32, 4), lowering.patch_control_points);
    try std.testing.expectEqual(TessellationDomain.quad, lowering.domain);
    try std.testing.expectEqual(TessellationPartitionMode.fractional_even, lowering.partition_mode);
}

test "Metal tessellation lowering records factor buffer requirement" {
    const lowering = try MetalTessellationLowering.fromDescriptor(.{
        .control_point_count = 3,
        .domain = .triangle,
        .partition_mode = .integer,
        .has_control_stage = true,
        .has_evaluation_stage = true,
    }, .{ .tessellation = true }, .{ .max_tessellation_control_points = 16 });
    try std.testing.expectEqual(@as(u32, 3), lowering.patch_control_points);
    try std.testing.expect(lowering.requires_factor_buffer);
}

test "Vulkan mesh pipeline lowering preserves optional task stage" {
    const lowering = try VulkanMeshPipelineLowering.fromDescriptor(.{
        .mesh_entry_point = "mesh_main",
        .task_entry_point = "task_main",
        .mesh_threads_per_threadgroup = 64,
        .task_threads_per_threadgroup = 32,
    }, .{ .mesh_shaders = true, .task_shaders = true }, .{
        .max_mesh_threads_per_threadgroup = 128,
        .max_task_threads_per_threadgroup = 64,
    });
    try std.testing.expectEqualStrings("mesh_main", lowering.mesh_entry_point);
    try std.testing.expectEqualStrings("task_main", lowering.task_entry_point.?);
    try std.testing.expectEqual(@as(u32, 64), lowering.mesh_threads_per_threadgroup);
}

test "Metal mesh pipeline lowering maps task stage to object function metadata" {
    const lowering = try MetalMeshPipelineLowering.fromDescriptor(.{
        .mesh_entry_point = "mesh_main",
        .task_entry_point = "object_main",
        .mesh_threads_per_threadgroup = 32,
        .task_threads_per_threadgroup = 16,
    }, .{ .mesh_shaders = true, .task_shaders = true }, .{
        .max_mesh_threads_per_threadgroup = 64,
        .max_task_threads_per_threadgroup = 32,
    });
    try std.testing.expectEqualStrings("mesh_main", lowering.mesh_entry_point);
    try std.testing.expectEqualStrings("object_main", lowering.object_entry_point.?);
    try std.testing.expectEqual(@as(u32, 16), lowering.object_threads_per_threadgroup);
}

test "advanced geometry shader stages are classified for Slang reflection" {
    try std.testing.expect(ShaderStage.tessellation_control.isAdvancedGeometry());
    try std.testing.expect(ShaderStage.tessellation_evaluation.isAdvancedGeometry());
    try std.testing.expect(ShaderStage.mesh.isAdvancedGeometry());
    try std.testing.expect(ShaderStage.task.isAdvancedGeometry());
    try std.testing.expect(!ShaderStage.vertex.isAdvancedGeometry());

    try validateShaderStageReflectionShape(.{
        .stage = .mesh,
        .entry_point = "mesh_main",
    });
}

test "acceleration structure descriptors estimate build sizes" {
    const descriptor = AccelerationStructureDescriptor{
        .kind = .bottom_level,
        .primitive_count = 2,
        .allow_update = true,
    };
    try descriptor.validate(.{ .acceleration_structures = true });
    const sizes = estimateAccelerationStructureBuildSizes(descriptor);
    try std.testing.expect(sizes.result_size > 0);
    try std.testing.expect(sizes.scratch_size >= sizes.result_size);
    try std.testing.expect(sizes.update_scratch_size > 0);

    try (AccelerationStructureInstanceDescriptor{
        .instance_count = 1,
    }).validate(.{ .acceleration_structures = true });
}

test "Vulkan ray tracing lowering counts shader groups" {
    const groups = [_]RayTracingShaderGroupDescriptor{
        .{ .kind = .ray_generation, .entry_point = "raygen" },
        .{ .kind = .miss, .entry_point = "miss" },
        .{ .kind = .hit, .entry_point = "closest_hit" },
    };
    const lowering = try VulkanRayTracingPipelineLowering.fromDescriptor(.{
        .shader_groups = groups[0..],
        .max_recursion_depth = 2,
    }, .{ .ray_tracing = true }, .{ .max_ray_tracing_recursion_depth = 4 });
    try std.testing.expectEqual(@as(u32, 1), lowering.ray_generation_groups);
    try std.testing.expectEqual(@as(u32, 1), lowering.miss_groups);
    try std.testing.expectEqual(@as(u32, 1), lowering.hit_groups);
    try std.testing.expectEqual(@as(u32, 2), lowering.max_recursion_depth);
}

test "Metal ray tracing lowering counts function table entries" {
    const groups = [_]RayTracingShaderGroupDescriptor{
        .{ .kind = .ray_generation, .entry_point = "raygen" },
        .{ .kind = .miss, .entry_point = "miss" },
    };
    const intersections = [_]MetalIntersectionFunctionDescriptor{
        .{ .entry_point = "intersect_triangle" },
    };
    const lowering = try MetalRayTracingLowering.fromDescriptor(.{
        .shader_groups = groups[0..],
        .max_recursion_depth = 1,
    }, intersections[0..], .{ .ray_tracing = true }, .{ .max_ray_tracing_recursion_depth = 2 });
    try std.testing.expectEqual(@as(u32, 3), lowering.function_table_entries);
    try std.testing.expectEqual(@as(u32, 1), lowering.intersection_function_count);
}

test "shader binding table layout computes group offsets" {
    const layout = try ShaderBindingTableLayout.fromDescriptor(.{
        .stride = 64,
        .ray_generation_count = 1,
        .miss_count = 2,
        .hit_count = 3,
        .callable_count = 1,
    }, .{ .ray_tracing = true }, .{ .shader_binding_table_alignment = 64 });
    try std.testing.expectEqual(@as(u64, 0), layout.ray_generation_offset);
    try std.testing.expectEqual(@as(u64, 64), layout.miss_offset);
    try std.testing.expectEqual(@as(u64, 192), layout.hit_offset);
    try std.testing.expectEqual(@as(u64, 384), layout.callable_offset);
    try std.testing.expectEqual(@as(u64, 448), layout.total_size);
}

test "ray tracing descriptors reject missing groups and invalid limits" {
    const miss_only = [_]RayTracingShaderGroupDescriptor{
        .{ .kind = .miss, .entry_point = "miss" },
    };
    try std.testing.expectError(AdvancedFeatureError.InvalidRayTracingPipeline, (RayTracingPipelineDescriptor{
        .shader_groups = miss_only[0..],
    }).validate(.{ .ray_tracing = true }, .{ .max_ray_tracing_recursion_depth = 4 }));
    try std.testing.expectError(AdvancedFeatureError.InvalidRayTracingPipeline, (RayTracingPipelineDescriptor{
        .shader_groups = &.{.{ .kind = .ray_generation, .entry_point = "raygen" }},
        .max_recursion_depth = 8,
    }).validate(.{ .ray_tracing = true }, .{ .max_ray_tracing_recursion_depth = 4 }));
    try std.testing.expectError(AdvancedFeatureError.InvalidAccelerationStructureDescriptor, (AccelerationStructureInstanceDescriptor{
        .instance_count = 0,
    }).validate(.{ .acceleration_structures = true }));
    try std.testing.expectError(AdvancedFeatureError.InvalidShaderBindingTable, (ShaderBindingTableDescriptor{
        .stride = 12,
    }).validate(.{ .ray_tracing = true }, .{ .shader_binding_table_alignment = 64 }));
}

test "texture usage can detect empty usage" {
    try std.testing.expect((TextureUsage{}).isEmpty());
    try std.testing.expect(!(TextureUsage{ .shader_read = true }).isEmpty());
}

test "texture descriptor classifies resource shapes" {
    try std.testing.expectEqual(TextureShape.one_d_array, (TextureDescriptor{
        .dimension = .one_d,
        .format = .rgba8_unorm,
        .width = 64,
        .depth_or_array_layers = 3,
    }).shape());

    const cube = TextureDescriptor{
        .format = .rgba8_unorm,
        .width = 64,
        .height = 64,
        .depth_or_array_layers = 6,
    };
    try std.testing.expect(cube.isArray());
    try std.testing.expect(cube.isCubeCompatible());
    try std.testing.expectEqual(@as(u32, 1), cube.cubeCount());
    try std.testing.expectEqual(TextureShape.cube_compatible, cube.shape());

    try std.testing.expectEqual(TextureShape.cube_array_compatible, (TextureDescriptor{
        .format = .rgba8_unorm,
        .width = 64,
        .height = 64,
        .depth_or_array_layers = 12,
    }).shape());
    try std.testing.expectEqual(TextureShape.multisampled, (TextureDescriptor{
        .format = .rgba8_unorm,
        .width = 64,
        .height = 64,
        .sample_count = 4,
        .usage = .{ .render_attachment = true },
        .storage_mode = .private,
    }).shape());
}

test "texture view descriptor resolves defaults from texture" {
    const resolved = try (TextureViewDescriptor{}).resolveForTexture(.{
        .format = .rgba8_unorm,
        .width = 64,
        .height = 64,
        .depth_or_array_layers = 4,
        .mip_level_count = 3,
    });

    try std.testing.expectEqual(TextureFormat.rgba8_unorm, resolved.format);
    try std.testing.expectEqual(TextureViewDimension.two_d_array, resolved.dimension);
    try std.testing.expectEqual(@as(u32, 0), resolved.base_mip_level);
    try std.testing.expectEqual(@as(u32, 3), resolved.mip_level_count);
    try std.testing.expectEqual(@as(u32, 0), resolved.base_array_layer);
    try std.testing.expectEqual(@as(u32, 4), resolved.array_layer_count);
}

test "texture view descriptor validates ranges and format compatibility" {
    const texture = TextureDescriptor{
        .format = .rgba8_unorm,
        .width = 64,
        .height = 64,
        .depth_or_array_layers = 2,
        .mip_level_count = 2,
    };

    try std.testing.expectError(TextureError.InvalidTextureViewRange, (TextureViewDescriptor{
        .base_mip_level = 2,
    }).resolveForTexture(texture));
    try std.testing.expectError(TextureError.InvalidTextureViewRange, (TextureViewDescriptor{
        .base_array_layer = 2,
    }).resolveForTexture(texture));
    try std.testing.expectError(TextureError.UnsupportedTextureViewFormat, (TextureViewDescriptor{
        .format = .bgra8_unorm,
    }).resolveForTexture(texture));
    try std.testing.expectError(TextureError.UnsupportedTextureViewDimension, (TextureViewDescriptor{
        .dimension = .two_d,
    }).resolveForTexture(texture));
}

test "sampler descriptor validates lod range" {
    try (SamplerDescriptor{}).validate();
    try std.testing.expectError(SamplerError.InvalidLodRange, (SamplerDescriptor{
        .lod_min_clamp = 4,
        .lod_max_clamp = 1,
    }).validate());
    try std.testing.expectError(SamplerError.InvalidMaxAnisotropy, (SamplerDescriptor{
        .max_anisotropy = 0.5,
    }).validate());
}

test "sampler descriptor validates feature-gated fields" {
    const disabled_features = DeviceFeatures{};
    const default_limits = defaultDeviceLimits(.metal);

    try std.testing.expectError(SamplerError.UnsupportedCompareSampler, (SamplerDescriptor{
        .compare_function = .less,
    }).validateForDevice(disabled_features, default_limits));
    try std.testing.expectError(SamplerError.UnsupportedSamplerAnisotropy, (SamplerDescriptor{
        .max_anisotropy = 4,
    }).validateForDevice(disabled_features, default_limits));
    try std.testing.expectError(SamplerError.UnsupportedSamplerBorderColor, (SamplerDescriptor{
        .border_color = .opaque_black,
    }).validateForDevice(disabled_features, default_limits));
    try std.testing.expectError(SamplerError.UnsupportedSamplerBorderColor, (SamplerDescriptor{
        .address_mode_u = .clamp_to_border,
    }).validateForDevice(disabled_features, default_limits));

    try (SamplerDescriptor{
        .compare_function = .less,
    }).validateForDevice(defaultDeviceFeatures(.metal), default_limits);
    try (SamplerDescriptor{
        .address_mode_u = .clamp_to_border,
        .address_mode_v = .clamp_to_border,
        .border_color = .opaque_white,
    }).validateForDevice(defaultDeviceFeatures(.metal), default_limits);

    try (SamplerDescriptor{
        .max_anisotropy = 4,
    }).validateForDevice(.{ .sampler_anisotropy = true }, .{ .max_sampler_anisotropy = 8 });
    try std.testing.expectError(SamplerError.InvalidMaxAnisotropy, (SamplerDescriptor{
        .max_anisotropy = 16,
    }).validateForDevice(.{ .sampler_anisotropy = true }, .{ .max_sampler_anisotropy = 8 }));

    const cache_key = SamplerCacheKeyDescriptor{
        .descriptor = .{ .max_anisotropy = 4 },
    };
    try cache_key.validateForDevice(.{ .sampler_anisotropy = true }, .{ .max_sampler_anisotropy = 8 });
    try std.testing.expect(cache_key.policy.allowsReuse());

    const disabled_key = SamplerCacheKeyDescriptor{
        .policy = .{ .mode = .disabled },
    };
    try disabled_key.validate();
    try std.testing.expect(!disabled_key.policy.allowsReuse());
    try std.testing.expect(!disabled_key.policy.recordsDiagnostics());
    try std.testing.expect((ObjectCachePolicy{ .mode = .diagnostics_only }).recordsDiagnostics());
    try std.testing.expect(!(ObjectCachePolicy{ .mode = .diagnostics_only }).allowsReuse());
}

test "heap descriptor is gated by device features" {
    try std.testing.expectError(HeapError.UnsupportedHeaps, (HeapDescriptor{
        .size = 1024,
    }).validate(defaultDeviceFeatures(.vulkan)));
    try std.testing.expectError(HeapError.InvalidHeapSize, (HeapDescriptor{}).validate(.{ .heaps = true }));
    const heap = HeapDescriptor{
        .size = 4096,
        .storage_mode = .device_local,
    };
    try heap.validate(.{ .heaps = true });
    try (HeapAllocationDescriptor{
        .size = 1024,
        .alignment = 256,
    }).validate(heap);
    try std.testing.expectError(HeapError.InvalidHeapAlignment, (HeapAllocationDescriptor{
        .size = 1024,
        .alignment = 0,
    }).validate(heap));
    try std.testing.expectError(HeapError.HeapOutOfMemory, (HeapAllocationDescriptor{
        .size = 8192,
    }).validate(heap));
}

test "bind group layout descriptor validates resource bindings" {
    const layout_entries = [_]BindGroupLayoutEntry{
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
        .{
            .binding = 3,
            .resource = .compare_sampler,
            .visibility = .{ .fragment = true },
        },
    };
    const layout = BindGroupLayoutDescriptor{ .entries = layout_entries[0..] };

    try layout.validate();
    try std.testing.expectEqual(BindingResourceKind.uniform_buffer, layout.entryForBinding(0).?.resource);
    try std.testing.expect(layout.entryForBinding(9) == null);
    try std.testing.expect(layout.containsBinding(1));
    try std.testing.expectEqual(BindingLocation{ .group = 3, .binding = 1 }, layout.locationForBinding(3, 1).?);
    try std.testing.expect(layout.locationForBinding(3, 9) == null);
    try std.testing.expectEqual(@as(usize, 1), layout.resourceCount(.sampler));
    try std.testing.expectEqual(@as(usize, 1), layout.resourceCount(.compare_sampler));
    try std.testing.expect(BindingResourceKind.storage_buffer.isBuffer());
    try std.testing.expect(BindingResourceKind.sampled_texture.isTexture());
    try std.testing.expect(BindingResourceKind.sampler.isSampler());
    try std.testing.expect(BindingResourceKind.compare_sampler.isSampler());
    try std.testing.expect(BindingResourceKind.storage_texture.isWritable());

    const storage_buffer_entry = BindGroupLayoutEntry{
        .binding = 4,
        .resource = .storage_buffer,
        .visibility = .{ .compute = true },
        .storage_access = .read,
    };
    try storage_buffer_entry.validate();
    try std.testing.expectEqual(StorageAccess.read, storage_buffer_entry.resolvedStorageAccess().?);
    const storage_texture_entry = BindGroupLayoutEntry{
        .binding = 5,
        .resource = .storage_texture,
        .visibility = .{ .compute = true },
    };
    try storage_texture_entry.validate();
    try std.testing.expectEqual(StorageAccess.write, storage_texture_entry.resolvedStorageAccess().?);
    try std.testing.expectError(BindingError.InvalidStorageAccess, (BindGroupLayoutEntry{
        .binding = 6,
        .resource = .uniform_buffer,
        .visibility = .{ .compute = true },
        .storage_access = .read,
    }).validate());

    try std.testing.expectError(BindingError.MissingBindGroupLayoutEntry, (BindGroupLayoutDescriptor{}).validate());

    const hidden_entries = [_]BindGroupLayoutEntry{
        .{
            .binding = 0,
            .resource = .uniform_buffer,
            .visibility = .{},
        },
    };
    try std.testing.expectError(BindingError.EmptyShaderVisibility, (BindGroupLayoutDescriptor{
        .entries = hidden_entries[0..],
    }).validate());

    const duplicate_entries = [_]BindGroupLayoutEntry{
        .{
            .binding = 0,
            .resource = .uniform_buffer,
            .visibility = .{ .vertex = true },
        },
        .{
            .binding = 0,
            .resource = .sampler,
            .visibility = .{ .fragment = true },
        },
    };
    try std.testing.expectError(BindingError.DuplicateBinding, (BindGroupLayoutDescriptor{
        .entries = duplicate_entries[0..],
    }).validate());

    const invalid_array_entries = [_]BindGroupLayoutEntry{
        .{
            .binding = 0,
            .resource = .uniform_buffer,
            .visibility = .{ .vertex = true },
            .array_count = 0,
        },
    };
    try std.testing.expectError(BindingError.InvalidBindingArrayCount, (BindGroupLayoutDescriptor{
        .entries = invalid_array_entries[0..],
    }).validate());

    const invalid_dynamic_entries = [_]BindGroupLayoutEntry{
        .{
            .binding = 0,
            .resource = .sampled_texture,
            .visibility = .{ .fragment = true },
            .dynamic_offset = true,
        },
    };
    try std.testing.expectError(BindingError.InvalidDynamicBindingResource, (BindGroupLayoutDescriptor{
        .entries = invalid_dynamic_entries[0..],
    }).validate());

    const bindless_ranges = [_]DescriptorIndexingRange{.{
        .binding = 8,
        .resource = .sampled_texture,
        .visibility = .{ .fragment = true },
        .descriptor_count = 16,
        .partially_bound = true,
    }};
    try std.testing.expectError(AdvancedFeatureError.UnsupportedDescriptorIndexing, (DescriptorIndexingLayoutDescriptor{
        .ranges = bindless_ranges[0..],
    }).validate(.{}, .{}));
    try (DescriptorIndexingLayoutDescriptor{
        .ranges = bindless_ranges[0..],
    }).validate(.{ .descriptor_indexing = true }, .{ .max_bindless_descriptors_per_range = 16 });
    try std.testing.expectError(AdvancedFeatureError.InvalidDescriptorIndexingCount, (DescriptorIndexingLayoutDescriptor{
        .ranges = bindless_ranges[0..],
    }).validate(.{ .descriptor_indexing = true }, .{ .max_bindless_descriptors_per_range = 4 }));
    try std.testing.expectError(AdvancedFeatureError.UnsupportedArgumentBuffers, (DescriptorIndexingLayoutDescriptor{
        .model = .argument_buffer,
        .ranges = bindless_ranges[0..],
    }).validate(.{}, .{}));

    const valid_dynamic_entries = [_]BindGroupLayoutEntry{
        .{
            .binding = 0,
            .resource = .storage_buffer,
            .visibility = .{ .compute = true },
            .dynamic_offset = true,
        },
    };
    try (BindGroupLayoutDescriptor{
        .entries = valid_dynamic_entries[0..],
    }).validate();

    const cache_key = BindGroupLayoutCacheKeyDescriptor{
        .entries = valid_dynamic_entries[0..],
    };
    try cache_key.validate();
    try std.testing.expect(cache_key.asLayoutDescriptor().containsBinding(0));
    try std.testing.expectError(BindingError.MissingBindGroupLayoutEntry, (BindGroupLayoutCacheKeyDescriptor{}).validate());
}

test "bind group descriptor validates entries against layout" {
    const layout_entries = [_]BindGroupLayoutEntry{
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
    const layout = BindGroupLayoutDescriptor{ .entries = layout_entries[0..] };
    const entries = [_]BindGroupEntry{
        .{
            .binding = 0,
            .resource = .{ .uniform_buffer = .{ .offset = 16, .size = 64 } },
        },
        .{
            .binding = 1,
            .resource = .{ .sampled_texture = .{} },
        },
        .{
            .binding = 2,
            .resource = .{ .sampler = .{} },
        },
    };
    const bind_group = BindGroupDescriptor{
        .layout = layout,
        .entries = entries[0..],
    };

    try bind_group.validate();
    try std.testing.expectEqual(BindingResourceKind.sampler, bind_group.entryForBinding(2).?.resource.resourceKind());

    try std.testing.expectError(BindingError.MissingBindGroupEntry, (BindGroupDescriptor{
        .layout = layout,
        .entries = entries[0..2],
    }).validate());

    const extra_entries = [_]BindGroupEntry{
        .{
            .binding = 0,
            .resource = .{ .uniform_buffer = .{} },
        },
        .{
            .binding = 1,
            .resource = .{ .sampled_texture = .{} },
        },
        .{
            .binding = 2,
            .resource = .{ .sampler = .{} },
        },
        .{
            .binding = 3,
            .resource = .{ .sampler = .{} },
        },
    };
    try std.testing.expectError(BindingError.ExtraBindGroupEntry, (BindGroupDescriptor{
        .layout = layout,
        .entries = extra_entries[0..],
    }).validate());

    const mismatched_entries = [_]BindGroupEntry{
        .{
            .binding = 0,
            .resource = .{ .uniform_buffer = .{} },
        },
        .{
            .binding = 1,
            .resource = .{ .sampler = .{} },
        },
        .{
            .binding = 2,
            .resource = .{ .sampler = .{} },
        },
    };
    try std.testing.expectError(BindingError.BindingResourceKindMismatch, (BindGroupDescriptor{
        .layout = layout,
        .entries = mismatched_entries[0..],
    }).validate());

    const duplicate_entries = [_]BindGroupEntry{
        .{
            .binding = 0,
            .resource = .{ .uniform_buffer = .{} },
        },
        .{
            .binding = 0,
            .resource = .{ .uniform_buffer = .{} },
        },
        .{
            .binding = 2,
            .resource = .{ .sampler = .{} },
        },
    };
    try std.testing.expectError(BindingError.DuplicateBinding, (BindGroupDescriptor{
        .layout = layout,
        .entries = duplicate_entries[0..],
    }).validate());

    const invalid_range_entries = [_]BindGroupEntry{
        .{
            .binding = 0,
            .resource = .{ .uniform_buffer = .{ .size = 0 } },
        },
        .{
            .binding = 1,
            .resource = .{ .sampled_texture = .{} },
        },
        .{
            .binding = 2,
            .resource = .{ .sampler = .{} },
        },
    };
    try std.testing.expectError(BindingError.InvalidBufferBindingRange, (BindGroupDescriptor{
        .layout = layout,
        .entries = invalid_range_entries[0..],
    }).validate());
}

test "bind group descriptor accepts compute storage buffers" {
    const layout_entries = [_]BindGroupLayoutEntry{
        .{
            .binding = 0,
            .resource = .storage_buffer,
            .visibility = .{ .compute = true },
        },
    };
    const entries = [_]BindGroupEntry{
        .{
            .binding = 0,
            .resource = .{ .storage_buffer = .{ .offset = 0, .size = 16 } },
        },
    };
    const bind_group = BindGroupDescriptor{
        .layout = .{ .entries = layout_entries[0..] },
        .entries = entries[0..],
    };

    try bind_group.validate();
    try std.testing.expectEqual(BindingResourceKind.storage_buffer, bind_group.entryForBinding(0).?.resource.resourceKind());
}

test "bind group descriptor accepts compare samplers" {
    const layout_entries = [_]BindGroupLayoutEntry{
        .{
            .binding = 0,
            .resource = .compare_sampler,
            .visibility = .{ .fragment = true },
        },
    };
    const entries = [_]BindGroupEntry{
        .{
            .binding = 0,
            .resource = .{ .compare_sampler = .{} },
        },
    };
    const bind_group = BindGroupDescriptor{
        .layout = .{ .entries = layout_entries[0..] },
        .entries = entries[0..],
    };

    try bind_group.validate();
    try std.testing.expectEqual(BindingResourceKind.compare_sampler, bind_group.entryForBinding(0).?.resource.resourceKind());
}

test "bind group descriptor accepts compute storage textures" {
    const layout_entries = [_]BindGroupLayoutEntry{
        .{
            .binding = 0,
            .resource = .storage_texture,
            .visibility = .{ .compute = true },
        },
    };
    const entries = [_]BindGroupEntry{
        .{
            .binding = 0,
            .resource = .{ .storage_texture = .{} },
        },
    };
    const bind_group = BindGroupDescriptor{
        .layout = .{ .entries = layout_entries[0..] },
        .entries = entries[0..],
    };

    try bind_group.validate();
    try std.testing.expectEqual(BindingResourceKind.storage_texture, bind_group.entryForBinding(0).?.resource.resourceKind());
}

test "dynamic offset list validates dynamic buffer bindings" {
    const layout_entries = [_]BindGroupLayoutEntry{
        .{
            .binding = 0,
            .resource = .uniform_buffer,
            .visibility = .{ .vertex = true },
            .dynamic_offset = true,
        },
        .{
            .binding = 1,
            .resource = .storage_buffer,
            .visibility = .{ .compute = true },
            .dynamic_offset = true,
        },
        .{
            .binding = 2,
            .resource = .sampler,
            .visibility = .{ .fragment = true },
        },
    };
    const layout = BindGroupLayoutDescriptor{ .entries = layout_entries[0..] };
    const limits = DeviceLimits{
        .min_uniform_buffer_offset_alignment = 256,
        .min_storage_buffer_offset_alignment = 64,
    };
    const offsets = [_]DynamicOffset{
        .{ .binding = 0, .offset = 256 },
        .{ .binding = 1, .offset = 128 },
    };
    const dynamic_offsets = DynamicOffsetList{ .offsets = offsets[0..] };

    try dynamic_offsets.validate(layout, limits);
    try std.testing.expectEqual(@as(u64, 128), dynamic_offsets.offsetForBinding(1).?);
    try std.testing.expect(dynamic_offsets.offsetForBinding(9) == null);

    try std.testing.expectError(BindingError.MissingDynamicOffset, (DynamicOffsetList{
        .offsets = offsets[0..1],
    }).validate(layout, limits));

    const misaligned_offsets = [_]DynamicOffset{
        .{ .binding = 0, .offset = 128 },
        .{ .binding = 1, .offset = 128 },
    };
    try std.testing.expectError(BindingError.InvalidDynamicOffsetAlignment, (DynamicOffsetList{
        .offsets = misaligned_offsets[0..],
    }).validate(layout, limits));

    const extra_offsets = [_]DynamicOffset{
        .{ .binding = 0, .offset = 256 },
        .{ .binding = 1, .offset = 128 },
        .{ .binding = 2, .offset = 0 },
    };
    try std.testing.expectError(BindingError.ExtraDynamicOffset, (DynamicOffsetList{
        .offsets = extra_offsets[0..],
    }).validate(layout, limits));

    const duplicate_offsets = [_]DynamicOffset{
        .{ .binding = 0, .offset = 256 },
        .{ .binding = 0, .offset = 512 },
    };
    try std.testing.expectError(BindingError.DuplicateBinding, (DynamicOffsetList{
        .offsets = duplicate_offsets[0..],
    }).validate(layout, limits));
}

test "dynamic offset list addresses dynamic buffer array elements" {
    const layout_entries = [_]BindGroupLayoutEntry{.{
        .binding = 4,
        .resource = .uniform_buffer,
        .visibility = .{ .vertex = true },
        .array_count = 2,
        .dynamic_offset = true,
    }};
    const layout = BindGroupLayoutDescriptor{ .entries = layout_entries[0..] };
    const limits = DeviceLimits{ .min_uniform_buffer_offset_alignment = 256 };
    const offsets = [_]DynamicOffset{
        .{ .binding = 4, .array_element = 0, .offset = 256 },
        .{ .binding = 4, .array_element = 1, .offset = 512 },
    };

    try (DynamicOffsetList{ .offsets = offsets[0..] }).validate(layout, limits);
    try std.testing.expectEqual(@as(u64, 512), (DynamicOffsetList{
        .offsets = offsets[0..],
    }).offsetForBindingElement(4, 1).?);

    try std.testing.expectError(BindingError.MissingDynamicOffset, (DynamicOffsetList{
        .offsets = offsets[0..1],
    }).validate(layout, limits));

    const out_of_range_offsets = [_]DynamicOffset{
        .{ .binding = 4, .array_element = 0, .offset = 256 },
        .{ .binding = 4, .array_element = 2, .offset = 512 },
    };
    try std.testing.expectError(BindingError.ExtraDynamicOffset, (DynamicOffsetList{
        .offsets = out_of_range_offsets[0..],
    }).validate(layout, limits));

    const duplicate_offsets = [_]DynamicOffset{
        .{ .binding = 4, .array_element = 0, .offset = 256 },
        .{ .binding = 4, .array_element = 0, .offset = 512 },
    };
    try std.testing.expectError(BindingError.DuplicateBinding, (DynamicOffsetList{
        .offsets = duplicate_offsets[0..],
    }).validate(layout, limits));
}

test "static sampler descriptor is feature gated" {
    const descriptor = StaticSamplerDescriptor{
        .binding = 0,
        .visibility = .{ .fragment = true },
        .sampler = .{},
    };

    try std.testing.expectError(BindingError.UnsupportedStaticSampler, descriptor.validate(.{}));
    try descriptor.validate(.{ .static_samplers = true });

    try std.testing.expectError(BindingError.EmptyShaderVisibility, (StaticSamplerDescriptor{
        .binding = 1,
        .visibility = .{},
        .sampler = .{},
    }).validate(.{ .static_samplers = true }));
}

test "small constant descriptor validates feature and limit gates" {
    const bytes = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const features = DeviceFeatures{ .small_constants = true };
    const limits = DeviceLimits{
        .max_small_constant_bytes = 16,
        .small_constant_alignment = 4,
    };
    try (SmallConstantDescriptor{
        .visibility = .{ .vertex = true },
        .offset = 4,
        .bytes = bytes[0..],
    }).validate(features, limits);

    try std.testing.expectError(SmallConstantError.UnsupportedSmallConstants, (SmallConstantDescriptor{
        .visibility = .{ .vertex = true },
        .bytes = bytes[0..4],
    }).validate(.{}, limits));

    try std.testing.expectError(SmallConstantError.EmptySmallConstantVisibility, (SmallConstantDescriptor{
        .visibility = .{},
        .bytes = bytes[0..4],
    }).validate(features, limits));

    try std.testing.expectError(SmallConstantError.EmptySmallConstantData, (SmallConstantDescriptor{
        .visibility = .{ .fragment = true },
    }).validate(features, limits));

    try std.testing.expectError(SmallConstantError.InvalidSmallConstantAlignment, (SmallConstantDescriptor{
        .visibility = .{ .fragment = true },
        .offset = 2,
        .bytes = bytes[0..4],
    }).validate(features, limits));

    try std.testing.expectError(SmallConstantError.SmallConstantDataTooLarge, (SmallConstantDescriptor{
        .visibility = .{ .compute = true },
        .offset = 12,
        .bytes = bytes[0..8],
    }).validate(features, limits));
}

test "root constant descriptors validate ranges and writes" {
    const bytes = [_]u8{0} ** 16;
    const features = DeviceFeatures{ .root_constants = true };
    const limits = DeviceLimits{
        .max_root_constant_bytes = 32,
        .root_constant_alignment = 4,
    };
    const ranges = [_]RootConstantRange{
        .{
            .visibility = .{ .vertex = true },
            .offset = 0,
            .size = 16,
        },
        .{
            .visibility = .{ .fragment = true },
            .offset = 16,
            .size = 16,
        },
    };
    const layout = RootConstantLayoutDescriptor{ .ranges = ranges[0..] };

    try layout.validate(features, limits);
    try (RootConstantWriteDescriptor{
        .offset = 4,
        .bytes = bytes[0..8],
    }).validate(layout, features, limits);
    try std.testing.expect(layout.rangeContainingWrite(.{
        .offset = 20,
        .bytes = bytes[0..8],
    }) != null);

    try std.testing.expectError(RootConstantError.UnsupportedRootConstants, layout.validate(.{}, limits));
    try std.testing.expectError(RootConstantError.MissingRootConstantRange, (RootConstantLayoutDescriptor{}).validate(features, limits));

    const empty_visibility_ranges = [_]RootConstantRange{.{
        .visibility = .{},
        .offset = 0,
        .size = 4,
    }};
    try std.testing.expectError(RootConstantError.EmptyRootConstantVisibility, (RootConstantLayoutDescriptor{
        .ranges = empty_visibility_ranges[0..],
    }).validate(features, limits));

    const empty_range = [_]RootConstantRange{.{
        .visibility = .{ .vertex = true },
        .offset = 0,
        .size = 0,
    }};
    try std.testing.expectError(RootConstantError.InvalidRootConstantRange, (RootConstantLayoutDescriptor{
        .ranges = empty_range[0..],
    }).validate(features, limits));

    const misaligned_range = [_]RootConstantRange{.{
        .visibility = .{ .vertex = true },
        .offset = 2,
        .size = 4,
    }};
    try std.testing.expectError(RootConstantError.InvalidRootConstantAlignment, (RootConstantLayoutDescriptor{
        .ranges = misaligned_range[0..],
    }).validate(features, limits));

    const oversized_range = [_]RootConstantRange{.{
        .visibility = .{ .vertex = true },
        .offset = 24,
        .size = 16,
    }};
    try std.testing.expectError(RootConstantError.RootConstantRangeTooLarge, (RootConstantLayoutDescriptor{
        .ranges = oversized_range[0..],
    }).validate(features, limits));

    try std.testing.expectError(RootConstantError.EmptyRootConstantWrite, (RootConstantWriteDescriptor{
        .offset = 0,
    }).validate(layout, features, limits));

    try std.testing.expectError(RootConstantError.InvalidRootConstantAlignment, (RootConstantWriteDescriptor{
        .offset = 2,
        .bytes = bytes[0..4],
    }).validate(layout, features, limits));

    try std.testing.expectError(RootConstantError.RootConstantWriteOutOfRange, (RootConstantWriteDescriptor{
        .offset = 12,
        .bytes = bytes[0..8],
    }).validate(layout, features, limits));
}

test "pipeline layout cache key validates layouts and constants" {
    const layout_entries = [_]BindGroupLayoutEntry{.{
        .binding = 0,
        .resource = .uniform_buffer,
        .visibility = .{ .vertex = true },
    }};
    const bind_layouts = [_]BindGroupLayoutCacheKeyDescriptor{.{
        .entries = layout_entries[0..],
    }};
    const bytes = [_]u8{0} ** 16;
    const small_constants = [_]SmallConstantDescriptor{.{
        .visibility = .{ .vertex = true },
        .bytes = bytes[0..8],
    }};
    const root_ranges = [_]RootConstantRange{.{
        .visibility = .{ .fragment = true },
        .offset = 0,
        .size = 16,
    }};
    const features = DeviceFeatures{
        .small_constants = true,
        .root_constants = true,
    };
    const limits = DeviceLimits{
        .max_small_constant_bytes = 16,
        .max_root_constant_bytes = 16,
    };

    try (PipelineLayoutCacheKeyDescriptor{
        .bind_group_layouts = bind_layouts[0..],
        .small_constants = small_constants[0..],
        .root_constant_layout = .{ .ranges = root_ranges[0..] },
    }).validate(features, limits);
    try (PipelineLayoutCacheKeyDescriptor{}).validate(features, limits);
    try std.testing.expectError(SmallConstantError.UnsupportedSmallConstants, (PipelineLayoutCacheKeyDescriptor{
        .small_constants = small_constants[0..],
    }).validate(.{}, limits));
}

test "bind group layout rejects non-compute storage textures" {
    const fragment_entries = [_]BindGroupLayoutEntry{
        .{
            .binding = 0,
            .resource = .storage_texture,
            .visibility = .{ .fragment = true },
        },
    };
    try std.testing.expectError(BindingError.InvalidStorageTextureVisibility, (BindGroupLayoutDescriptor{
        .entries = fragment_entries[0..],
    }).validate());

    const mixed_entries = [_]BindGroupLayoutEntry{
        .{
            .binding = 0,
            .resource = .storage_texture,
            .visibility = .{ .fragment = true, .compute = true },
        },
    };
    try std.testing.expectError(BindingError.InvalidStorageTextureVisibility, (BindGroupLayoutDescriptor{
        .entries = mixed_entries[0..],
    }).validate());
}

test "texture replace region descriptor resolves tight upload layout" {
    const pixels = [_]u8{0} ** 16;
    const resolved = try (TextureReplaceRegionDescriptor{
        .bytes = pixels[0..],
    }).resolveForTexture(.{
        .format = .rgba8_unorm,
        .width = 2,
        .height = 2,
    }, .{
        .size = .{ .width = 2, .height = 2 },
    });

    try std.testing.expectEqual(@as(usize, 8), resolved.bytes_per_row);
    try std.testing.expectEqual(@as(usize, 16), resolved.bytes_per_image);
    try std.testing.expectEqual(@as(usize, 16), resolved.required_bytes);
}

test "texture replace region descriptor validates region and byte layout" {
    const pixels = [_]u8{0} ** 16;
    const texture = TextureDescriptor{
        .format = .rgba8_unorm,
        .width = 2,
        .height = 2,
    };

    try std.testing.expectError(TextureError.InvalidTextureRegion, (TextureReplaceRegionDescriptor{
        .bytes = pixels[0..],
    }).resolveForTexture(texture, .{
        .origin = .{ .x = 1 },
        .size = .{ .width = 2, .height = 1 },
    }));
    try std.testing.expectError(TextureError.InvalidBytesPerRow, (TextureReplaceRegionDescriptor{
        .bytes = pixels[0..],
        .bytes_per_row = 7,
    }).resolveForTexture(texture, .{
        .size = .{ .width = 2, .height = 2 },
    }));
    try std.testing.expectError(TextureError.UploadBytesTooSmall, (TextureReplaceRegionDescriptor{
        .bytes = pixels[0..8],
    }).resolveForTexture(texture, .{
        .size = .{ .width = 2, .height = 2 },
    }));
    try std.testing.expectError(TextureError.UnsupportedTextureUploadFormat, (TextureReplaceRegionDescriptor{
        .bytes = pixels[0..],
    }).resolveForTexture(.{
        .format = .depth32_float,
        .width = 2,
        .height = 2,
        .usage = .{ .render_attachment = true },
    }, .{
        .size = .{ .width = 2, .height = 2 },
    }));
}

test "texture upload 2d descriptor converts to replace region descriptor" {
    const pixels = [_]u8{0} ** 16;
    const replace = (TextureUpload2DDescriptor{
        .bytes = pixels[0..],
        .mip_level = 1,
        .slice = 2,
        .bytes_per_row = 8,
    }).asReplaceRegionDescriptor();

    try std.testing.expectEqualSlices(u8, pixels[0..], replace.bytes);
    try std.testing.expectEqual(@as(u32, 1), replace.mip_level);
    try std.testing.expectEqual(@as(u32, 2), replace.slice);
    try std.testing.expectEqual(@as(usize, 8), replace.bytes_per_row);
    try std.testing.expectEqual(@as(usize, 0), replace.bytes_per_image);
}

test "generate mipmaps descriptor resolves mip and layer ranges" {
    const texture = TextureDescriptor{
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

    const resolved = try (GenerateMipmapsDescriptor{
        .base_mip_level = 1,
        .base_array_layer = 1,
        .array_layer_count = 1,
    }).resolveForTexture(texture);
    try std.testing.expectEqual(@as(u32, 1), resolved.base_mip_level);
    try std.testing.expectEqual(@as(u32, 3), resolved.mip_level_count);
    try std.testing.expectEqual(@as(u32, 1), resolved.base_array_layer);
    try std.testing.expectEqual(@as(u32, 1), resolved.array_layer_count);

    try std.testing.expectError(TextureError.UnsupportedMipmapGeneration, (GenerateMipmapsDescriptor{}).resolveForTexture(.{
        .format = .depth32_float,
        .width = 8,
        .height = 8,
        .mip_level_count = 4,
        .usage = .{
            .copy_source = true,
            .copy_destination = true,
        },
    }));
    try std.testing.expectError(TextureError.UnsupportedMipmapGeneration, (GenerateMipmapsDescriptor{}).resolveForTexture(.{
        .format = .rgba8_unorm,
        .width = 8,
        .height = 8,
        .mip_level_count = 4,
        .usage = .{ .shader_read = true },
    }));
}

test "default adapter info tracks selected backend" {
    const adapter = defaultAdapterInfo(.metal);

    try std.testing.expectEqual(Backend.metal, adapter.backend);
    try std.testing.expect(adapter.name.len != 0);
}

test "default device limits expose public slot constants" {
    const limits = defaultDeviceLimits(.vulkan);

    try std.testing.expectEqual(default_max_vertex_buffer_slots, limits.max_vertex_buffer_slots);
    try std.testing.expectEqual(default_max_bind_group_slots, limits.max_bind_group_slots);
}

test "default device features expose completed period 2 gates" {
    const features = defaultDeviceFeatures(.metal);

    try std.testing.expect(features.native_handles);
    try std.testing.expect(features.debug_labels);
    try std.testing.expect(features.texture_1d);
    try std.testing.expect(features.texture_2d);
    try std.testing.expect(features.texture_3d);
    try std.testing.expect(features.texture_arrays);
    try std.testing.expect(features.cube_textures);
    try std.testing.expect(features.multisample_textures);
    try std.testing.expect(features.sampler_compare);
    try std.testing.expect(features.sampler_anisotropy);
    try std.testing.expect(features.sampler_border_color);
    try std.testing.expect(features.depth_bias);
    try std.testing.expect(features.wireframe_fill_mode);
    try std.testing.expect(features.blend_state);
    try std.testing.expect(features.independent_blend);
    try std.testing.expect(features.stencil_state);
    try std.testing.expect(features.vertex_instance_step_rate);
    try std.testing.expect(!features.heaps);
    try std.testing.expect(!features.multi_surface);
}

test "default device features separate period23 defaults from escape hatches" {
    const backends = [_]Backend{ .vulkan, .metal };
    for (backends) |backend| {
        const features = defaultDeviceFeatures(backend);

        try std.testing.expect(features.explicit_resource_barriers);
        try std.testing.expect(features.fences);
        try std.testing.expect(features.events);
        try std.testing.expect(features.occlusion_queries);
        try std.testing.expect(features.timestamp_queries);

        try std.testing.expect(!features.timeline_fences);
        try std.testing.expect(!features.shared_events);
        try std.testing.expect(!features.multi_queue);
        try std.testing.expect(!features.dedicated_compute_queue);
        try std.testing.expect(!features.dedicated_transfer_queue);
        try std.testing.expect(!features.queue_ownership_transfer);
        try std.testing.expect(!features.pipeline_statistics_queries);
    }
}

test "default capability reports keep advanced backend gates closed" {
    const report = defaultDeviceCapabilityReport(.vulkan);

    try std.testing.expectEqual(Backend.vulkan, report.backend);
    try std.testing.expectEqual(DeviceCapabilitySource.defaults, report.source);
    try std.testing.expect(report.features.runtime_slang);
    try std.testing.expect(report.native_features.runtime_slang);
    try std.testing.expect(!report.features.descriptor_indexing);
    try std.testing.expect(!report.features.argument_buffers);
    try std.testing.expect(!report.features.sparse_buffers);
    try std.testing.expect(!report.features.external_textures);
    try std.testing.expect(!report.features.tessellation);
    try std.testing.expect(!report.features.mesh_shaders);
    try std.testing.expect(!report.features.ray_tracing);
    try std.testing.expect(!report.features.driver_pipeline_cache);
}

test "default format capabilities describe current portable formats" {
    const color = defaultFormatCapabilities(.rgba8_unorm);
    try std.testing.expect(color.sampled);
    try std.testing.expect(color.storage);
    try std.testing.expect(color.color_attachment);
    try std.testing.expect(color.linear_filter);
    try std.testing.expect(color.mipmapped);
    try std.testing.expect(color.mipmap_generation);
    try std.testing.expect(color.supportsTextureUsage(.{
        .shader_read = true,
        .shader_write = true,
        .render_attachment = true,
        .copy_source = true,
        .copy_destination = true,
    }));

    const depth = defaultFormatCapabilities(.depth32_float);
    try std.testing.expect(!depth.color_attachment);
    try std.testing.expect(depth.depth_stencil_attachment);
    try std.testing.expect(depth.supportsTextureUsage(.{ .render_attachment = true }));
    const depth_stencil = defaultFormatCapabilities(.depth32_float_stencil8);
    try std.testing.expect(!depth_stencil.color_attachment);
    try std.testing.expect(depth_stencil.depth_stencil_attachment);
    try std.testing.expect(depth_stencil.supportsTextureUsage(.{ .render_attachment = true }));
    try std.testing.expect(!depth.supportsTextureDescriptor(.{
        .format = .depth32_float,
        .width = 16,
        .height = 16,
        .usage = .{ .shader_read = true },
    }));
}

test "texture copy compatibility keeps channel order explicit" {
    try std.testing.expect(textureFormatsCopyCompatible(.rgba8_unorm, .rgba8_unorm_srgb));
    try std.testing.expect(textureFormatsCopyCompatible(.bgra8_unorm, .bgra8_unorm_srgb));
    try std.testing.expect(!textureFormatsCopyCompatible(.rgba8_unorm, .bgra8_unorm));
    try std.testing.expect(!textureFormatsCopyCompatible(.depth32_float, .depth32_float_stencil8));
}

test "texture format helpers classify current portable formats" {
    try std.testing.expectEqual(TextureFormatKind.color, textureFormatKind(.rgba8_unorm));
    try std.testing.expectEqual(TextureFormatKind.depth, textureFormatKind(.depth32_float));
    try std.testing.expectEqual(TextureFormatKind.depth_stencil, textureFormatKind(.depth32_float_stencil8));
    try std.testing.expect(isColorFormat(.bgra8_unorm));
    try std.testing.expect(isDepthFormat(.depth32_float));
    try std.testing.expect(isDepthFormat(.depth32_float_stencil8));
    try std.testing.expect(!isStencilFormat(.depth32_float));
    try std.testing.expect(isStencilFormat(.depth32_float_stencil8));
    try std.testing.expect(!isDepthStencilFormat(.depth32_float));
    try std.testing.expect(isDepthStencilFormat(.depth32_float_stencil8));
    try std.testing.expect(!isCompressedFormat(.rgba8_unorm));
    try std.testing.expect(isSrgbFormat(.rgba8_unorm_srgb));
    try std.testing.expectEqual(@as(usize, 4), textureFormatBytesPerPixel(.rgba8_unorm));
}
