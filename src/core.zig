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
    render_pipelines: bool = true,
    compute_pipelines: bool = true,
    bind_groups: bool = true,
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
};

pub const DeviceLimits = struct {
    max_vertex_buffer_slots: u32 = default_max_vertex_buffer_slots,
    max_bind_group_slots: u32 = default_max_bind_group_slots,
    max_color_attachments: u32 = 4,
    max_sample_count: u32 = 4,
    min_uniform_buffer_offset_alignment: u64 = 256,
    min_storage_buffer_offset_alignment: u64 = 256,
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
        error.ShaderReflectionVisibilityMismatch,
        error.InvalidVertexStride,
        error.InvalidVertexAttributeOffset,
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
        error.EmptyDebugGroupLabel,
        error.DebugGroupStackOverflow,
        error.DebugGroupStackUnderflow,
        error.UnclosedDebugGroup,
        error.InvalidVertexCount,
        error.InvalidIndexCount,
        error.InvalidInstanceCount,
        error.InvalidIndexBufferOffset,
        error.InvalidThreadgroupCount,
        error.InvalidCopySize,
        error.InvalidCopyBufferRange,
        error.InvalidCopyTextureRegion,
        error.InvalidCopyTextureSlice,
        error.InvalidCopyBufferLayout,
        error.TextureCopySizeOverflow,
        error.MissingBindGroupLayoutEntry,
        error.EmptyShaderVisibility,
        error.DuplicateBinding,
        error.MissingBindGroupEntry,
        error.ExtraBindGroupEntry,
        error.BindingResourceKindMismatch,
        error.InvalidBufferBindingRange,
        error.InvalidStorageTextureVisibility,
        error.MissingSurfaceSource,
        error.InvalidSurfaceExtent,
        error.InvalidSurfaceHandle,
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
        error.InvalidRenderPassAttachment,
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

pub fn defaultDeviceFeatures(_: Backend) DeviceFeatures {
    return .{
        .native_handles = true,
        .debug_labels = true,
    };
}

pub fn defaultDeviceLimits(_: Backend) DeviceLimits {
    return .{};
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
    };
}

pub const ShaderSourceLanguage = enum {
    slang,
    spirv,
    msl,
};

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
};

pub const ShaderReflectionArtifact = struct {
    path: []const u8,
};

pub const ShaderReflectionBinding = struct {
    binding: u32,
    resource: BindingResourceKind,
    visibility: ShaderVisibility,
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

    pub fn validate(self: ProgrammableStageDescriptor, expected_stage: ShaderStage) ShaderError!void {
        try self.module.validate();
        if (self.stage != expected_stage) return ShaderError.UnexpectedShaderStage;
        if (self.entry_point.len == 0) return ShaderError.EmptyShaderEntryPoint;
        if (self.reflection) |reflection| try reflection.validate();
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
    step_function: VertexStepFunction = .per_vertex,
    attributes: []const VertexAttributeDescriptor = &.{},

    pub fn validate(self: VertexBufferLayoutDescriptor) PipelineError!void {
        if (self.stride == 0 and self.attributes.len != 0) return PipelineError.InvalidVertexStride;
        for (self.attributes) |attribute| {
            if (attribute.offset > self.stride or vertexFormatSize(attribute.format) > self.stride - attribute.offset) {
                return PipelineError.InvalidVertexAttributeOffset;
            }
        }
    }
};

pub const VertexDescriptor = struct {
    buffers: []const VertexBufferLayoutDescriptor = &.{},

    pub fn validate(self: VertexDescriptor) PipelineError!void {
        for (self.buffers) |buffer| {
            try buffer.validate();
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

pub const ColorWriteMask = struct {
    red: bool = true,
    green: bool = true,
    blue: bool = true,
    alpha: bool = true,
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

pub const DepthStencilDescriptor = struct {
    format: TextureFormat = .automatic,
    depth_compare_function: CompareFunction = .always,
    depth_write_enabled: bool = false,

    pub fn validate(self: DepthStencilDescriptor) PipelineError!void {
        if (!isDepthFormat(self.format)) return PipelineError.InvalidDepthStencilFormat;
    }
};

pub const RenderPipelineColorAttachmentDescriptor = struct {
    format: TextureFormat = .automatic,
    write_mask: ColorWriteMask = .{},
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
    sample_count: u32 = 1,
    color_attachments: []const RenderPipelineColorAttachmentDescriptor = &.{},
    depth_stencil: ?DepthStencilDescriptor = null,

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
        try validateSampleCount(self.sample_count);
        for (self.color_attachments) |attachment| {
            if (attachment.format == .automatic) return PipelineError.InvalidColorAttachmentFormat;
            if (!isColorFormat(attachment.format)) return PipelineError.InvalidColorAttachmentFormat;
        }
        if (self.depth_stencil) |depth_stencil| try depth_stencil.validate();
    }
};

pub const ComputePipelineDescriptor = struct {
    label: ?[]const u8 = null,
    compute: ProgrammableStageDescriptor,
    bind_group_layouts: []const BindGroupLayoutDescriptor = &.{},

    pub fn validate(self: ComputePipelineDescriptor) (ShaderError || BindingError)!void {
        try self.compute.validate(.compute);
        for (self.bind_group_layouts) |layout| {
            try layout.validate();
        }
        try validateProgrammableStageReflection(self.compute, .compute, self.bind_group_layouts);
    }
};

pub const ShaderError = error{
    EmptyShaderSource,
    EmptyShaderArtifactPath,
    EmptyShaderEntryPoint,
    EmptyShaderReflectionPath,
    InvalidShaderReflection,
    ShaderReflectionReadFailed,
    ShaderReflectionStageMismatch,
    ShaderReflectionEntryPointMismatch,
    ShaderReflectionMissingBindGroupLayout,
    ShaderReflectionMissingBinding,
    ShaderReflectionBindingKindMismatch,
    ShaderReflectionVisibilityMismatch,
    UnexpectedShaderStage,
};

pub const PipelineError = error{
    MissingColorAttachment,
    InvalidColorAttachmentFormat,
    InvalidDepthStencilFormat,
    InvalidSampleCount,
    UnsupportedSampleCount,
    InvalidVertexStride,
    InvalidVertexAttributeOffset,
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
    if (!visibilityContains(layout_entry.visibility, reflection.visibility)) {
        return ShaderError.ShaderReflectionVisibilityMismatch;
    }
}

fn validateShaderStageReflectionShape(reflection: ShaderStageReflection) ShaderError!void {
    if (reflection.entry_point.len == 0) return ShaderError.InvalidShaderReflection;
    for (reflection.bind_groups) |bind_group| {
        for (bind_group.bindings) |binding| {
            if (binding.visibility.isEmpty()) return ShaderError.InvalidShaderReflection;
        }
    }
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

    pub fn validate(self: RenderPassDepthAttachmentDescriptor) CommandEncodingError!void {
        if (!std.math.isFinite(self.clear_depth) or self.clear_depth < 0 or self.clear_depth > 1) {
            return CommandEncodingError.InvalidDepthClearValue;
        }
    }
};

pub const RenderPassDescriptor = struct {
    label: ?[]const u8 = null,
    color_attachments: []const RenderPassColorAttachmentDescriptor = &.{},
    depth_attachment: ?RenderPassDepthAttachmentDescriptor = null,

    pub fn validate(self: RenderPassDescriptor) CommandEncodingError!void {
        if (self.color_attachments.len == 0) return CommandEncodingError.MissingColorAttachment;
        if (self.depth_attachment) |depth_attachment| try depth_attachment.validate();
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

    pub fn validate(self: BindGroupBinding) CommandEncodingError!void {
        if (self.index >= max_bind_group_slots) return CommandEncodingError.InvalidBindGroupIndex;
    }
};

pub const DrawPrimitivesDescriptor = struct {
    primitive_type: PrimitiveTopology = .triangle,
    vertex_start: u32 = 0,
    vertex_count: u32 = 0,
    instance_count: u32 = 1,

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

    pub fn validate(self: DrawIndexedPrimitivesDescriptor) CommandEncodingError!void {
        if (self.index_count == 0) return CommandEncodingError.InvalidIndexCount;
        if (self.instance_count == 0) return CommandEncodingError.InvalidInstanceCount;
        if (self.index_buffer_offset % indexTypeSize(self.index_type) != 0) {
            return CommandEncodingError.InvalidIndexBufferOffset;
        }
    }
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
    index_buffer_set: bool = false,

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

    pub fn dispatchThreadgroups(
        self: *ComputeCommandEncoderDebugState,
        descriptor: DispatchThreadgroupsDescriptor,
    ) CommandEncodingError!void {
        try self.requirePipeline();
        try descriptor.validate();
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
    EmptyDebugGroupLabel,
    DebugGroupStackOverflow,
    DebugGroupStackUnderflow,
    UnclosedDebugGroup,
    InvalidDepthClearValue,
    DepthStateRenderPassMismatch,
    SampleCountRenderPassMismatch,
    InvalidVertexCount,
    InvalidIndexCount,
    InvalidInstanceCount,
    InvalidIndexBufferOffset,
    InvalidCopySize,
    InvalidCopyBufferRange,
    InvalidCopyTextureRegion,
    InvalidCopyTextureSlice,
    InvalidCopyBufferLayout,
    InvalidCopyBufferUsage,
    InvalidCopyTextureUsage,
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
    repeat,
    mirror_repeat,
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

    pub fn validate(self: SamplerDescriptor) SamplerError!void {
        if (self.lod_min_clamp > self.lod_max_clamp) return SamplerError.InvalidLodRange;
    }
};

pub const SamplerError = error{
    InvalidLodRange,
};

pub const ShaderVisibility = struct {
    vertex: bool = false,
    fragment: bool = false,
    compute: bool = false,

    pub fn isEmpty(self: ShaderVisibility) bool {
        return !self.vertex and !self.fragment and !self.compute;
    }
};

pub const BindingResourceKind = enum {
    uniform_buffer,
    storage_buffer,
    storage_texture,
    sampled_texture,
    sampler,
};

pub const BindGroupLayoutEntry = struct {
    binding: u32,
    resource: BindingResourceKind,
    visibility: ShaderVisibility,
};

pub const BindGroupLayoutDescriptor = struct {
    label: ?[]const u8 = null,
    entries: []const BindGroupLayoutEntry = &.{},

    pub fn validate(self: BindGroupLayoutDescriptor) BindingError!void {
        if (self.entries.len == 0) return BindingError.MissingBindGroupLayoutEntry;

        for (self.entries, 0..) |entry, i| {
            if (entry.visibility.isEmpty()) return BindingError.EmptyShaderVisibility;
            if (entry.resource == .storage_texture and (entry.visibility.vertex or entry.visibility.fragment or !entry.visibility.compute)) {
                return BindingError.InvalidStorageTextureVisibility;
            }
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

pub const BindGroupResource = union(BindingResourceKind) {
    uniform_buffer: BufferBindingDescriptor,
    storage_buffer: BufferBindingDescriptor,
    storage_texture: TextureViewBindingDescriptor,
    sampled_texture: TextureViewBindingDescriptor,
    sampler: SamplerBindingDescriptor,

    pub fn resourceKind(self: BindGroupResource) BindingResourceKind {
        return switch (self) {
            .uniform_buffer => .uniform_buffer,
            .storage_buffer => .storage_buffer,
            .storage_texture => .storage_texture,
            .sampled_texture => .sampled_texture,
            .sampler => .sampler,
        };
    }

    pub fn validate(self: BindGroupResource) BindingError!void {
        switch (self) {
            .uniform_buffer, .storage_buffer => |buffer| try buffer.validate(),
            .storage_texture, .sampled_texture, .sampler => {},
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

pub const BindingError = error{
    MissingBindGroupLayoutEntry,
    EmptyShaderVisibility,
    DuplicateBinding,
    MissingBindGroupEntry,
    ExtraBindGroupEntry,
    BindingResourceKindMismatch,
    InvalidBufferBindingRange,
    InvalidStorageTextureVisibility,
};

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
        .depth32_float => unreachable,
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
    };
}

pub fn isColorFormat(format: TextureFormat) bool {
    return textureFormatKind(format) == .color;
}

pub fn isDepthFormat(format: TextureFormat) bool {
    return textureFormatKind(format) == .depth;
}

pub fn isStencilFormat(format: TextureFormat) bool {
    return textureFormatKind(format) == .stencil;
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
        => false,
    };
}

fn checkedMul(comptime T: type, a: anytype, b: anytype) error{Overflow}!T {
    return try std.math.mul(T, @as(T, @intCast(a)), @as(T, @intCast(b)));
}

fn checkedAdd(comptime T: type, a: T, b: T) error{Overflow}!T {
    return try std.math.add(T, a, b);
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
};

pub const SurfaceResizePolicy = enum {
    recreate,
    suspend_when_zero,
};

pub const SurfaceState = enum {
    unconfigured,
    configured,
    suspended,
};

pub const PresentationDescriptor = struct {
    extent: Extent2D,
    format: TextureFormat = .automatic,
    present_mode: PresentMode = .fifo,
    resize_policy: SurfaceResizePolicy = .suspend_when_zero,
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

    pub fn isEmpty(self: BufferUsage) bool {
        return !self.copy_source and
            !self.copy_destination and
            !self.vertex and
            !self.index and
            !self.uniform and
            !self.storage;
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
};

pub const Surface = struct {
    backend: Backend,
    descriptor: SurfaceDescriptor,
    state: SurfaceState = .unconfigured,
    presentation: ?PresentationDescriptor = null,

    pub fn selectedBackend(self: Surface) Backend {
        return self.backend;
    }

    pub fn provider(self: Surface) SurfaceProvider {
        return self.descriptor.source.?.provider;
    }

    pub fn configure(self: *Surface, descriptor: PresentationDescriptor) SurfaceError!void {
        if (descriptor.extent.isZero()) {
            if (descriptor.resize_policy == .suspend_when_zero) {
                self.state = .suspended;
                self.presentation = descriptor;
                return;
            }
            return SurfaceError.InvalidSurfaceExtent;
        }

        self.state = .configured;
        self.presentation = descriptor;
    }

    pub fn resize(self: *Surface, extent: Extent2D) SurfaceError!void {
        var descriptor = self.presentation orelse return SurfaceError.InvalidSurfaceExtent;
        descriptor.extent = extent;
        try self.configure(descriptor);
    }
};

pub const SurfaceHandle = struct {
    index: u32,
    generation: u32,
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
    }

    pub fn get(self: *SurfaceCollection, handle: SurfaceHandle) SurfaceError!*Surface {
        return &(try self.entryPtr(handle)).surface;
    }

    pub fn resize(self: *SurfaceCollection, handle: SurfaceHandle, extent: Extent2D) SurfaceError!void {
        try (try self.get(handle)).resize(extent);
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
}

test "debug group stack validates labels and nesting" {
    var stack = DebugGroupStack{ .max_depth = 1 };

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

    try std.testing.expectError(SurfaceError.InvalidSurfaceExtent, surface.configure(.{
        .extent = .{ .width = 0, .height = 480 },
        .resize_policy = .recreate,
    }));
}

test "surface collection manages multiple neutral surfaces" {
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

    try std.testing.expectEqual(@as(usize, 2), collection.liveCount());
    try std.testing.expectEqual(Backend.metal, (try collection.get(handle_a)).selectedBackend());
    try collection.resize(handle_b, .{ .width = 800, .height = 600 });
    try std.testing.expectEqual(@as(u32, 800), (try collection.get(handle_b)).presentation.?.extent.width);

    try collection.remove(handle_a);
    try std.testing.expectEqual(@as(usize, 1), collection.liveCount());
    try std.testing.expectError(SurfaceError.InvalidSurfaceHandle, collection.get(handle_a));
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
        .vertex_descriptor = .{ .buffers = vertex_buffers[0..] },
        .bind_group_layouts = bind_group_layouts[0..],
        .color_attachments = color_attachments[0..],
    }).validate();

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
}

test "draw descriptors validate counts and index alignment" {
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
}

test "command debug state validates render pass ordering" {
    const color_attachments = [_]RenderPassColorAttachmentDescriptor{.{}};
    var command_buffer = CommandBufferDebugState{};
    var encoder = try command_buffer.makeRenderCommandEncoder(.{
        .color_attachments = color_attachments[0..],
    });

    try std.testing.expectError(CommandEncodingError.InvalidCommandBufferState, command_buffer.commit());
    try std.testing.expectError(CommandEncodingError.MissingRenderPipelineState, encoder.drawPrimitives(.{
        .vertex_count = 3,
    }));

    try encoder.setRenderPipelineState();
    try encoder.setVertexBuffer(.{ .index = 0 });
    try encoder.drawPrimitives(.{ .vertex_count = 3 });
    try encoder.endEncoding(&command_buffer);
    try std.testing.expectError(CommandEncodingError.InvalidRenderCommandEncoderState, encoder.drawPrimitives(.{
        .vertex_count = 3,
    }));

    try command_buffer.presentDrawable();
    try command_buffer.commit();
    try std.testing.expectError(CommandEncodingError.InvalidCommandBufferState, command_buffer.presentDrawable());
}

test "command debug state validates blit pass ordering" {
    var command_buffer = CommandBufferDebugState{};
    var encoder = try command_buffer.makeBlitCommandEncoder();

    try std.testing.expectError(CommandEncodingError.InvalidCommandBufferState, command_buffer.commit());
    try encoder.copyBufferToBuffer(.{ .size = 4 }, 8, 8);
    try encoder.endEncoding(&command_buffer);
    try std.testing.expectError(CommandEncodingError.InvalidBlitCommandEncoderState, encoder.copyBufferToBuffer(.{ .size = 4 }, 8, 8));
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
    try encoder.dispatchThreadgroups(.{
        .threadgroup_count_x = 1,
        .threads_per_threadgroup_x = 4,
    });
    try encoder.endEncoding(&command_buffer);
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
    };
    const layout = BindGroupLayoutDescriptor{ .entries = layout_entries[0..] };

    try layout.validate();
    try std.testing.expectEqual(BindingResourceKind.uniform_buffer, layout.entryForBinding(0).?.resource);
    try std.testing.expect(layout.entryForBinding(9) == null);

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
    try std.testing.expect(!features.multi_surface);
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
    try std.testing.expect(!depth.supportsTextureDescriptor(.{
        .format = .depth32_float,
        .width = 16,
        .height = 16,
        .usage = .{ .shader_read = true },
    }));
}

test "texture format helpers classify current portable formats" {
    try std.testing.expectEqual(TextureFormatKind.color, textureFormatKind(.rgba8_unorm));
    try std.testing.expectEqual(TextureFormatKind.depth, textureFormatKind(.depth32_float));
    try std.testing.expect(isColorFormat(.bgra8_unorm));
    try std.testing.expect(isDepthFormat(.depth32_float));
    try std.testing.expect(!isStencilFormat(.depth32_float));
    try std.testing.expect(!isDepthStencilFormat(.depth32_float));
    try std.testing.expect(!isCompressedFormat(.rgba8_unorm));
    try std.testing.expect(isSrgbFormat(.rgba8_unorm_srgb));
    try std.testing.expectEqual(@as(usize, 4), textureFormatBytesPerPixel(.rgba8_unorm));
}
