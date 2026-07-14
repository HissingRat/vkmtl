const core = @import("core.zig");
const runtime = @import("runtime/window_context.zig");
const headless_runtime = @import("runtime/headless_context.zig");

pub const resource = @import("api/resource.zig");
pub const transfer = @import("api/transfer.zig");
pub const render = @import("api/render.zig");
pub const sync = @import("api/sync.zig");
pub const presentation = @import("api/presentation.zig");
pub const diagnostics = @import("api/diagnostics.zig");
pub const command = @import("api/command.zig");
pub const shader = @import("api/shader.zig");
pub const binding = @import("api/binding.zig");
pub const compute = @import("api/compute.zig");
pub const ray_tracing = @import("api/ray_tracing.zig");
pub const interop = @import("api/interop.zig");
pub const native = @import("api/native.zig");

pub const BackendPreference = core.BackendPreference;
pub const Backend = core.Backend;
pub const AdapterDeviceType = core.AdapterDeviceType;
pub const AdapterPowerPreference = core.AdapterPowerPreference;
pub const AdapterInfo = core.AdapterInfo;
pub const AdapterSelectionDescriptor = core.AdapterSelectionDescriptor;
pub const AdapterList = core.AdapterList;
pub const BackendAvailability = core.BackendAvailability;
pub const BackendSelectionOptions = core.BackendSelectionOptions;
pub const BackendSelectionError = core.BackendSelectionError;
pub const Extent2D = core.Extent2D;
pub const selectBackend = core.selectBackend;
pub const enumerateAdapters = core.enumerateAdapters;
pub const WindowContext = runtime.WindowContext;
pub const WindowContextOptions = runtime.WindowContextOptions;
pub const HeadlessContext = headless_runtime.HeadlessContext;
pub const Buffer = runtime.Buffer;
pub const MappedBufferRange = runtime.MappedBufferRange;
pub const Texture = runtime.Texture;
pub const TextureView = runtime.TextureView;
pub const SamplerState = runtime.SamplerState;
pub const ShaderModule = runtime.ShaderModule;
pub const RenderPipelineState = runtime.RenderPipelineState;
pub const ComputePipelineState = runtime.ComputePipelineState;
pub const Device = runtime.Device;
pub const Queue = runtime.Queue;
pub const Surface = runtime.Surface;
pub const Swapchain = runtime.Swapchain;

pub const DeviceFeatures = diagnostics.DeviceFeatures;
pub const DeviceLimits = diagnostics.DeviceLimits;
pub const SurfaceProvider = presentation.SurfaceProvider;
pub const SurfaceSource = presentation.SurfaceSource;
pub const SurfaceDescriptor = presentation.SurfaceDescriptor;
pub const PresentMode = presentation.PresentMode;
pub const PresentationDescriptor = presentation.PresentationDescriptor;
pub const FormatCapabilities = resource.FormatCapabilities;
pub const TextureFormat = resource.TextureFormat;
pub const BufferUsage = resource.BufferUsage;
pub const ResourceStorageMode = resource.ResourceStorageMode;
pub const TextureUsage = resource.TextureUsage;
pub const BufferDescriptor = resource.BufferDescriptor;
pub const TextureDescriptor = resource.TextureDescriptor;
pub const TextureViewDescriptor = resource.TextureViewDescriptor;
pub const SamplerDescriptor = resource.SamplerDescriptor;
pub const ShaderModuleDescriptor = shader.ShaderModuleDescriptor;
pub const ProgrammableStageDescriptor = shader.ProgrammableStageDescriptor;
pub const VertexDescriptor = render.VertexDescriptor;
pub const RenderPipelineColorAttachmentDescriptor = render.RenderPipelineColorAttachmentDescriptor;
pub const RenderPipelineDescriptor = render.RenderPipelineDescriptor;
pub const RenderPassDescriptor = render.RenderPassDescriptor;
pub const ClearColor = render.ClearColor;
pub const ComputePipelineDescriptor = compute.ComputePipelineDescriptor;
pub const BindGroupLayoutDescriptor = binding.BindGroupLayoutDescriptor;
pub const BindGroupDescriptor = binding.BindGroupDescriptor;
pub const BindGroupEntry = binding.BindGroupEntry;
pub const CommandBufferDescriptor = command.CommandBufferDescriptor;

test "facades preserve canonical declaration identity" {
    comptime {
        if (resource.TextureFormat != TextureFormat) @compileError("resource.TextureFormat identity drift");
        if (shader.ProgrammableStageDescriptor != ProgrammableStageDescriptor) @compileError("shader.ProgrammableStageDescriptor identity drift");
        if (render.RenderPassDescriptor != RenderPassDescriptor) @compileError("render.RenderPassDescriptor identity drift");
        if (render.RenderPassColorAttachmentDescriptor != runtime.RenderPassColorAttachmentDescriptor) @compileError("render attachment identity drift");
        if (binding.BindGroupDescriptor != BindGroupDescriptor) @compileError("binding.BindGroupDescriptor identity drift");
        if (command.CommandBufferDescriptor != CommandBufferDescriptor) @compileError("command.CommandBufferDescriptor identity drift");
        if (!@hasDecl(shader, "Reflection")) @compileError("shader.Reflection facade is missing");
        if (!@hasDecl(native, "vulkan") or !@hasDecl(native, "metal")) @compileError("native backend facades are missing");
        if (!@hasDecl(native, "SparseBufferLowering") or !@hasDecl(native, "planSparseBufferLowering")) @compileError("native sparse buffer lowering is missing");
        if (!@hasDecl(native, "SparseTextureLowering") or !@hasDecl(native, "planSparseTextureLowering")) @compileError("native sparse texture lowering is missing");
        if (@hasDecl(resource, "SparseBufferLowering") or @hasDecl(resource, "planSparseBufferLowering")) @compileError("native sparse buffer lowering leaked into resource");
        if (@hasDecl(resource, "SparseTextureLowering") or @hasDecl(resource, "planSparseTextureLowering")) @compileError("native sparse texture lowering leaked into resource");
        if (@hasDecl(ray_tracing, "RayQueryLoweringMode")) @compileError("ray query lowering leaked into the portable facade");
        if (!@hasDecl(binding, "validateDescriptorIndexingLayout")) @compileError("binding operations are missing");
        if (!@hasDecl(ray_tracing, "planAccelerationStructureBuild")) @compileError("ray tracing operations are missing");
    }
}

test "resource tracker records retain and release counts" {
    var tracker = runtime.ResourceTracker{};

    try @import("std").testing.expect(!tracker.hasLeaks());

    tracker.retain(.texture);
    tracker.retain(.texture_view);
    tracker.retain(.sampler_state);
    tracker.retain(.shader_module);
    tracker.retain(.render_pipeline_state);
    tracker.retain(.compute_pipeline_state);
    tracker.retain(.bind_group_layout);
    tracker.retain(.bind_group);
    try @import("std").testing.expect(tracker.hasLeaks());

    tracker.release(.bind_group);
    tracker.release(.bind_group_layout);
    tracker.release(.compute_pipeline_state);
    tracker.release(.texture_view);
    tracker.release(.sampler_state);
    tracker.release(.shader_module);
    tracker.release(.render_pipeline_state);
    tracker.release(.texture);
    try @import("std").testing.expect(!tracker.hasLeaks());
}

test "runtime command wrappers expose Metal-style ordering" {
    comptime {
        if (!@hasDecl(runtime.CommandBuffer, "makeRenderCommandEncoder")) @compileError("render encoder creation is missing");
        if (!@hasDecl(runtime.RenderCommandEncoder, "endEncoding")) @compileError("render encoder completion is missing");
        if (!@hasDecl(runtime.CommandBuffer, "presentDrawable")) @compileError("presentation encoding is missing");
        if (!@hasDecl(runtime.CommandBuffer, "commit")) @compileError("command buffer commit is missing");
    }
}

test "runtime command buffer exposes lifecycle status" {
    comptime {
        if (!@hasDecl(runtime.CommandBuffer, "state")) @compileError("command buffer lifecycle status is missing");
        if (!@hasDecl(runtime.CommandBuffer, "label")) @compileError("command buffer labels are missing");
        if (!@hasDecl(runtime.CommandBuffer, "commit")) @compileError("command buffer commit is missing");
    }
}
