# Project API

vkmtl exposes backend-neutral descriptors and runtime wrappers through the
public `vkmtl` module. User code should not import `backend/vulkan`,
`backend/metal`, raw Vulkan bindings, or Metal bridge headers.

Windowed examples still use `WindowContext` to assemble backend selection,
surfaces, presentation, and shader-cache configuration. Starting in Period 2,
the long-term resource entry point is `Device`, and the long-term
command-buffer / submit entry point is `Queue`. `WindowContext` remains a
window convenience owner and forwards resource and command helpers to those
views.

## Backend Selection

Applications choose a backend with `BackendPreference`:

- `.auto`
- `.vulkan`
- `.metal`

The selected backend can be queried with `selectedBackend()` on contexts and
runtime resource wrappers.

## Surfaces And Presentation

Windowing integration stays outside the core API. Examples use the external
`zig_glfw` package plus `examples/common.zig` glue to convert a GLFW window into
public descriptors:

- `SurfaceDescriptor`
- `PresentationDescriptor`

For Vulkan, that glue also supplies a `VulkanSurfaceProvider` with the instance
extensions, proc-address lookup, and surface-creation callback required by the
backend. Examples pass the resulting descriptors to `WindowContext.init(...)`.

Starting in Period 2, `WindowContext.surface()` and
`WindowContext.swapchain()` expose runtime views. `Surface` keeps the
window/provider descriptor information. `Swapchain` owns presentation-chain
resize, and the current clear-screen helper lives at `Swapchain.clear(...)`.
`WindowContext.resize(...)` and `WindowContext.clear(...)` remain compatibility
forwards.

`SurfaceCollection` is the first multi-surface management shape. It can track
multiple neutral surface presentation states for one selected backend and uses
generation handles for resize/remove validation. It does not create multiple
native swapchains yet; complete native multi-window support is gated by
`DeviceFeatures.multi_surface`.

## Resources

Starting in Period 2, the long-term resource creation entry point is the runtime
`Device`. `WindowContext.device()` returns a device view for the current
context. Existing `WindowContext.make*` methods remain as compatibility
forwards.

- `makeBuffer(BufferDescriptor)`
- `makeTexture(TextureDescriptor)`
- `makeSamplerState(SamplerDescriptor)`

`Device` also exposes the first capability-query shape:

- `vkmtl.enumerateAdapters(allocator, BackendSelectionOptions)`
- `AdapterSelectionDescriptor`
- `adapterInfo()`
- `features()`
- `limits()`
- `getFormatCaps(TextureFormat)`

Current adapter enumeration uses the same availability and ordering rules as
backend selection and returns conservative `AdapterInfo` values for each
available backend. `AdapterSelectionDescriptor.backend` forces the selected
backend, while `AdapterSelectionDescriptor.name` is validated against the
resolved runtime adapter name. After runtime context creation,
`context.adapterInfo()` and `device.adapterInfo()` try to return
backend-queried selected-adapter name/vendor/type. `Device.limits()` now asks
the selected runtime backend for known limits; format capabilities still use the
portable default table until backend-specific format queries are added.

Buffers created with CPU-visible storage can be updated with
`buffer.replaceBytes(...)` and read back with `buffer.readBytes(...)`.
Period 3 also exposes explicit range mapping:

```zig
var mapped = try buffer.mapRange(.{
    .offset = 0,
    .length = buffer.length(),
    .mode = .{ .read = true, .write = true },
});
defer mapped.deinit();

const bytes = mapped.bytes();
```

`BufferMapDescriptor` validates range and access mode. Private buffers are not
CPU-visible; upload or readback for those resources should use transfer paths.

Textures create views through `texture.makeTextureView(...)`, and upload
helpers include `texture.replaceRegion(...)` and `texture.replaceAll2D(...)`.
`TextureDescriptor.shape()` classifies 1D, 2D, 3D, array,
cube-compatible, cube-array-compatible, and multisampled textures.
Cube textures are currently represented as 2D textures with six layers per
cube; cube-specific view dimensions are reserved for the texture-view phase.

Format helpers include `textureFormatKind(...)`, `isColorFormat(...)`,
`isDepthFormat(...)`, `isSrgbFormat(...)`, and
`textureFormatBytesPerPixel(...)`. `FormatCapabilities` reports sampled,
storage, attachment, filter, mip, blend, and copy support for the currently
implemented portable formats.

Mipmap helpers include `mipDimension(...)`,
`maxMipLevelCountForExtent(...)`, `TextureDescriptor.maxMipLevelCount()`, and
`TextureDescriptor.mipExtent(level)`. Texture descriptors reject mip counts
larger than the texture extent can support. `GenerateMipmapsDescriptor` is a
validated public shape for future automatic mip generation; current command
encoders still require explicit upload or copy operations for each mip level.

Runtime `TextureView` stores the resolved view format, dimension, mip range,
and layer range. Query them with `descriptor()`, `baseMipLevel()`,
`mipLevelCount()`, `baseArrayLayer()`, and `arrayLayerCount()`.

`SamplerDescriptor` includes compare, anisotropy, and border-color fields.
Those advanced fields are capability-gated by `DeviceFeatures.sampler_compare`,
`DeviceFeatures.sampler_anisotropy`, `DeviceFeatures.sampler_border_color`, and
`DeviceLimits.max_sampler_anisotropy`. They are disabled by default until the
backend mappings are implemented.

`HeapDescriptor` defines the future advanced memory/heap shape. Default
resource creation still owns memory internally, and `DeviceFeatures.heaps` is
false until explicit Vulkan/Metal heap allocation is implemented.

Starting in Period 2, runtime resources record portable usage state.
`ResourceUsageState` can classify read-after-write, write-after-read, and
write-after-write hazards. Blit copies, render attachments, vertex buffers, and
index buffers already feed this state. Later Vulkan barrier lowering should
consume these transitions.

Manual barriers are an advanced escape hatch. `BufferBarrierDescriptor` and
`TextureBarrierDescriptor` validate ranges and before/after usage transitions,
and `ResourceUsageState.applyExplicitBarrier(...)` records an explicit tracked
transition. Native explicit-barrier commands are gated by
`DeviceFeatures.explicit_resource_barriers` and disabled by default; ordinary
code should keep using the automatic usage-tracking path.

Fence and event synchronization is descriptor-only in this period.
`FenceDescriptor`, `FenceSignalDescriptor`, and `FenceWaitDescriptor` validate
binary and timeline-style fence values behind `DeviceFeatures.fences` and
`DeviceFeatures.timeline_fences`. `EventDescriptor` plus event wait/signal
descriptor shapes are gated by `DeviceFeatures.events` and
`DeviceFeatures.shared_events`. Runtime fence/event objects are future work.

## Shaders And Pipelines

Slang is the source language. Applications usually embed `.slang` files and
compile them through `Device` at startup:

```zig
const source = @embedFile("shaders/glow.slang");
var device = context.device();
var compiled = try device.compileRenderShader("glow", source, .{
    .vertex_entry = "vs_main",
    .fragment_entry = "fs_main",
});
defer compiled.deinit();
```

The compiled handle chooses the correct cached artifact for the selected
backend:

```zig
const stages = compiled.stageDescriptors(context.selectedBackend());
```

Compute shaders use `compileComputeShader(...)` and
`CompiledComputeShader.stageDescriptor(...)`.

Runtime compilation writes SPIR-V, MSL, and reflection JSON into an automatically
managed shader cache. By default, the cache lives under `vkmtl-cache` beside the
executable. If callers set `WindowContextOptions.process_args = init.args`,
vkmtl automatically parses `--cache-dir <path>` or `--cache-dir=<path>`.
Application code does not need to parse that argument itself.

Precedence is: explicit `WindowContextOptions.shader_cache_dir` > `--cache-dir`
runtime argument > default `vkmtl-cache`.

Programmable stages can optionally attach reflection data with
`ProgrammableStageDescriptor.reflection`. Runtime pipeline creation validates
reflection artifacts or inline reflection data against the explicit
`bind_group_layouts` before creating backend pipelines. `ShaderReflection`
also exposes helpers that derive bind group layout descriptors from attached
stage reflection:

```zig
var layouts = try vkmtl.ShaderReflection.deriveRenderPipelineBindGroupLayouts(
    allocator,
    stages.vertex,
    stages.fragment,
);
defer layouts.deinit();
```

Reflection can also derive a single-buffer vertex descriptor from a vertex
stage's `vertex_inputs`; the caller still supplies stride because the current
reflection artifact records attribute layout but not host vertex struct size:

```zig
var vertex_descriptor = try vkmtl.ShaderReflection.deriveSingleBufferVertexDescriptor(
    allocator,
    stages.vertex,
    .{ .stride = @sizeOf(Vertex) },
);
defer vertex_descriptor.deinit();
```

`ProgrammableStageDescriptor.specialization` accepts
`ShaderSpecializationDescriptor` data for future shader variants.
`ShaderLibraryCacheKeyDescriptor` also includes specialization inputs so future
variant caches can distinguish them. The descriptor layer validates duplicate
IDs, duplicate names, and empty names. Runtime pipeline creation currently
rejects non-empty specialization data with `UnsupportedShaderSpecialization`
instead of ignoring it.

Render pipeline raster state includes cull mode, front face, fill mode, depth
bias, and a conservative-rasterization flag. Cull mode and front face are part
of the existing lowered path. Non-default fill mode, enabled depth bias, and
conservative rasterization are feature-gated and currently rejected with typed
unsupported errors during runtime pipeline creation.

Color attachment pipeline state includes write masks and optional
`RenderPipelineBlendDescriptor` values. Blend descriptors carry separate RGB and
alpha factors/operations, and each attachment may specify its own descriptor.
Non-empty blend state is currently feature-gated by `DeviceFeatures.blend_state`;
different per-attachment blend descriptors also require
`DeviceFeatures.independent_blend`.

Depth/stencil state includes `depth_test_enabled`, depth compare/write fields,
and a `StencilDescriptor` with front/back operations plus read/write masks.
Depth state is part of the lowered first slice. Stencil state is represented and
validated, but the current format list has no stencil-capable format yet, so
stencil-enabled descriptors are rejected until that format support lands.

Vertex layouts support multiple buffers and attributes. A
`VertexBufferLayoutDescriptor` may specify an explicit `buffer_index`; when it
is omitted, the descriptor keeps the existing array-index mapping. Validation
rejects duplicate resolved buffer indices, duplicate attribute locations,
invalid strides/offsets, and zero instance step rates. Non-default
`instance_step_rate` is represented but gated until backend lowering is wired.

## Bindings

Shader resource binding starts with public descriptors:

- `BindGroupLayoutDescriptor`
- `BindGroupDescriptor`
- `BindGroupLayout`
- `BindGroup`
- `ShaderVisibility`
- `BindingResourceKind`

The first resource classes are uniform buffers, storage buffers, storage
textures, sampled textures, samplers, and compare samplers. Layout entries also
carry `array_count` and `dynamic_offset` metadata. The descriptor layer
validates that array counts are non-zero, dynamic offsets are used only with
buffers, and storage textures are compute-only.

Runtime bind group creation validates layout shape, resource class, backend
match, whether referenced resources are alive, and whether storage textures
were created with `shader_write` usage. Current native lowering supports only
single resources (`array_count = 1`) and rejects dynamic-offset layouts with
typed `UnsupportedResourceArray` / `UnsupportedDynamicBinding` errors until the
later backend lowering phases. Render and compute encoders expose
`setBindGroup(...)` for debug-validated command recording.

Storage resources can specify `BindGroupLayoutEntry.storage_access` as
`.read`, `.write`, or `.read_write`. The metadata is valid only for storage
buffers and storage textures. Storage buffers default to read-write access;
storage textures default to write access. Runtime bind group creation checks
buffer `storage` usage and texture `shader_read` / `shader_write` usage against
that access intent and records portable storage read/write usage transitions.

`DynamicOffset` and `DynamicOffsetList` are the public validation shape for the
future dynamic-offset command path. They validate that every dynamic buffer
binding has one offset, that no non-dynamic binding receives an offset, and that
offsets satisfy `DeviceLimits.min_uniform_buffer_offset_alignment` or
`DeviceLimits.min_storage_buffer_offset_alignment`.

`SmallConstantDescriptor` is the first portable shape for small per-draw or
per-dispatch constant data. It is gated by `DeviceFeatures.small_constants`,
`DeviceLimits.max_small_constant_bytes`, and
`DeviceLimits.small_constant_alignment`. Command encoder lowering is not wired
yet.

`RootConstantRange`, `RootConstantLayoutDescriptor`, and
`RootConstantWriteDescriptor` define the push/root-constant equivalent. They
are gated by `DeviceFeatures.root_constants`,
`DeviceLimits.max_root_constant_bytes`, and
`DeviceLimits.root_constant_alignment`. The current API validates ranges and
writes, but command encoder lowering to Vulkan push constants or Metal inline
constants is still future work.

`BindGroupDescriptor` is the runtime descriptor that points at live resources.
For pure descriptor validation or tests, root exports also expose the shape-only
aliases `BindGroupResourceDescriptor`, `BindGroupEntryDescriptor`, and
`BindGroupDescriptorShape`.

Pipelines that use shader resources should include matching
`bind_group_layouts` in their render or compute pipeline descriptor. Those
layouts can be written manually or derived from reflection with
`ShaderReflection.deriveRenderPipelineBindGroupLayouts(...)` and
`ShaderReflection.deriveComputePipelineBindGroupLayouts(...)`. Vulkan uses the
layouts to build the native pipeline layout, allocate descriptor sets, write
descriptors, and bind them during command encoding.

If a stage supplies reflection data, vkmtl checks that the reflected bind group
indices, binding numbers, resource kinds, and shader visibility match those
pipeline layouts. The example suite attaches runtime-generated reflection
artifacts to every shader-backed pipeline. `zig build test` covers the runtime
reflection parser and the layouts used or derived by those examples.

Metal expands the same bind groups into explicit vertex, fragment, or compute
resource calls based on each layout entry's `ShaderVisibility`.

## Commands

Rendering uses Metal-like command names:

```zig
var queue = context.queue();
var command_buffer = try queue.makeCommandBuffer();
var encoder = try command_buffer.makeRenderCommandEncoder(render_pass);
try encoder.setRenderPipelineState(&pipeline);
try encoder.setVertexBuffer(&vertex_buffer, .{ .index = 0 });
try encoder.drawPrimitives(.{ .primitive_type = .triangle, .vertex_count = 3 });
try encoder.endEncoding();
try command_buffer.presentDrawable();
try command_buffer.commit();
```

`Queue.makeCommandBufferWithDescriptor(...)` accepts a
`CommandBufferDescriptor` for a borrowed label and future pooling/reuse hints.
The default `makeCommandBuffer()` path remains equivalent to an empty
descriptor. `CommandBuffer.state()` reports the portable lifecycle state.
Command buffers are still one-shot after `commit()`; pooled or reusable command
buffers are represented by descriptor fields and rejected by feature gates until
native reset/pooling is implemented.

`QueueKind`, `QueueCapabilities`, and `QueueDescriptor` define the multi-queue
selection vocabulary. `Device.queue()` still returns the default graphics queue,
and `Device.queueWithDescriptor(.{})` is the explicit form of that default.
Dedicated compute/transfer queues and queue ownership transfers are represented
by descriptors and feature gates, but runtime selection currently returns typed
unsupported errors for non-graphics queues.

Render passes can target the current drawable or an explicit texture view.
Texture-backed color attachments can also provide a single-sample
`resolve_target` when rendering from an MSAA texture. The descriptor model also
includes stencil attachments, transient attachment hints, and multiple color
attachments. Current runtime lowering supports one color attachment and returns
typed unsupported errors for stencil, transient, and MRT paths until native
lowering is implemented.

Dynamic render state descriptors include `Viewport`, `ScissorRect`,
`BlendColor`, `StencilReference`, and `DepthBiasDescriptor`.
`RenderCommandEncoder` exposes matching setters. These setters currently
validate their inputs and return `UnsupportedDynamicRenderState` until backend
lowering is wired.

Direct draw descriptors include `base_instance`; indexed draw descriptors also
include `base_vertex`. Non-zero base fields are currently rejected with typed
unsupported errors. Indirect and multi-draw descriptor shapes are available, and
`RenderCommandEncoder` exposes matching methods that validate inputs before
returning unsupported until backend lowering exists.

Query support is currently descriptor-only. `QuerySetDescriptor` covers
occlusion, timestamp, and pipeline statistics queries with feature gates.
`QueryResolveDescriptor` and `QueryReadbackDescriptor` validate query ranges and
result alignment, but runtime query pools and encoder commands are future work.

Transfer work uses a Metal-style blit encoder:

```zig
var queue = context.queue();
var command_buffer = try queue.makeCommandBuffer();
var blit = try command_buffer.makeBlitCommandEncoder();
try blit.copyBufferToBuffer(&source, &destination, .{ .size = byte_count });
try blit.endEncoding();
try command_buffer.commit();
```

The lowered blit slice supports buffer-to-buffer, buffer-to-texture, and
texture-to-buffer copies. `CopyTextureToTextureDescriptor` and
`FillBufferDescriptor` are public validation shapes now, and
`BlitCommandEncoder.copyTextureToTexture(...)` / `fillBuffer(...)` validate
resource usage and ranges before returning typed unsupported errors until native
lowering is implemented.

Compute work uses a Metal-style compute encoder:

```zig
var queue = context.queue();
var command_buffer = try queue.makeCommandBuffer();
var compute = try command_buffer.makeComputeCommandEncoder();
try compute.setComputePipelineState(&pipeline);
try compute.setBindGroup(&bind_group, .{ .index = 0 });
try compute.dispatchThreadgroups(.{
    .threadgroup_count_x = 1,
    .threads_per_threadgroup_x = 4,
});
try compute.endEncoding();
try command_buffer.commit();
```

The first compute slice supports storage-buffer and storage-texture
write/readback validation. `DispatchThreadgroupsDescriptor` validates dispatch
grid and threadgroup dimensions against `DeviceLimits`; `DispatchThreadsDescriptor`
and `ComputeCommandEncoder.dispatchThreads(...)` are convenience APIs that
resolve total thread counts into threadgroup counts before using the same
backend path.

`DispatchThreadgroupsIndirectDescriptor` represents future indirect dispatch
arguments. Indirect buffers use `BufferUsage.indirect`; runtime
`dispatchThreadgroupsIndirect(...)` validates usage, offset, and alignment
before returning `UnsupportedDispatchIndirect` until backend lowering lands.

Advanced compute shader requirements can be declared with
`ComputeAtomicDescriptor` and `ThreadgroupMemoryDescriptor`. These are
validation shapes gated by `DeviceFeatures.compute_atomics`,
`DeviceFeatures.compute_threadgroup_memory`, and
`DeviceLimits.max_compute_threadgroup_memory_bytes`; vkmtl does not infer them
from Slang source yet.

`ComputePipelineCacheKeyDescriptor` defines the inputs that Period 8 object
caches must include for compute pipelines: shader source identity, backend,
compile profile, entry point, bind group layouts, the unified
`PipelineLayoutCacheKeyDescriptor`, and specialization constants. It is a
validation shape only; native compute pipeline object caching is still future
work.

## Object Cache Diagnostics

Period 8 exposes cache-key and diagnostic shapes for expensive native objects:

- `ShaderModuleCacheKeyDescriptor`
- `BindGroupLayoutCacheKeyDescriptor`
- `PipelineLayoutCacheKeyDescriptor`
- `RenderPipelineCacheKeyDescriptor`
- `ComputePipelineCacheKeyDescriptor`
- `SamplerCacheKeyDescriptor`

`ObjectCachePolicy` controls whether a key requests reuse, disables
diagnostics, or records diagnostics only. `ObjectCacheDiagnostics` reports
hits, misses, creation attempts, equivalent recreation attempts, bypassed reuse,
suppressed diagnostics, and total creation time. Read snapshots with
`device.objectCacheDiagnostics()` or `context.objectCacheDiagnostics()`.

These diagnostics currently count repeated key-equivalent runtime object
creation attempts. They do not yet prove that a backend-native handle was
reused.

## Debug Labels And Groups

Runtime resources, command buffers, and command encoders expose borrowed debug
labels:

```zig
buffer.setLabel("vertices");
try render_encoder.pushDebugGroup("opaque pass");
try render_encoder.insertDebugSignpost("draw batch");
try render_encoder.popDebugGroup();
```

Descriptor labels are copied into runtime wrappers when resources or pipelines
are created. `label()` returns the current borrowed label, and `setLabel(null)`
clears it.

Debug groups and signposts are validated portably. Empty labels, underflow,
overflow, and unclosed groups become `CommandEncodingError` values.
`DebugSignpostDescriptor` is the shape-only marker descriptor, and command
buffers plus render/blit/compute encoders expose `insertDebugSignpost(...)`.
Native Vulkan debug-utils markers and Metal GPU capture markers can be lowered
behind this API later.

## Error Classification

vkmtl keeps precise Zig error names. Applications that need broader handling can
call:

```zig
const category = vkmtl.classifyError(err);
```

Current categories include validation, unsupported feature, backend, device
lost, surface lost, resource lifetime, shader compilation, and unknown.

## Native Handle Escape Hatch

Advanced users can explicitly call `context.nativeHandles()` to fetch borrowed
backend-native handles. The API returns a `NativeHandles` tagged union. The
Vulkan branch exposes instance/device/surface/queue handle values, and the
Metal branch exposes device/command queue/layer/view opaque pointers.

These handles are only valid while the vkmtl owner is alive. Code that uses
them is no longer backend-neutral.
