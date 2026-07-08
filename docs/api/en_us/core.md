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

Presentation helpers include `PresentModeSupport`,
`PresentModeResolution`, `defaultPresentModeSupport(...)`, and
`FramePacingDiagnostics`. `Device.presentModeSupport()` and
`WindowContext.presentModeSupport()` expose the conservative support table for
the selected backend, while `resolvePresentMode(...)` reports whether a
requested present mode fell back. `SurfaceCollection.framePacingDiagnostics(...)`
reports per-surface configured state, selected mode, vsync intent, generation,
frame-in-flight state, and submitted/completed frame serials.

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
validated public shape for automatic mip generation; blit encoders can generate
full-texture mip chains with `generateMipmaps(...)`.

Runtime `TextureView` stores the resolved view format, dimension, mip range,
and layer range. Query them with `descriptor()`, `baseMipLevel()`,
`mipLevelCount()`, `baseArrayLayer()`, and `arrayLayerCount()`.

`SamplerDescriptor` includes compare, anisotropy, and border-color fields.
Those advanced fields are capability-gated by `DeviceFeatures.sampler_compare`,
`DeviceFeatures.sampler_anisotropy`, `DeviceFeatures.sampler_border_color`, and
`DeviceLimits.max_sampler_anisotropy`. Compare samplers and anisotropy now lower
to Vulkan/Metal sampler creation. Fixed border colors also lower to Vulkan and
Metal sampler creation when address modes use `clamp_to_border`; custom border
colors remain out of scope.

`HeapDescriptor` defines explicit heap planning. `Device.makeHeap(...)` is
feature-gated by `DeviceFeatures.heaps` and returns a runtime `Heap` that tracks
aligned reservations through `reserve(...)`. Default resource creation still
owns memory internally; native Vulkan `VkDeviceMemory` suballocation and Metal
`MTLHeap`-backed buffer/texture creation are future backend work.

Sparse and tiled resource shapes are represented by
`SparseBufferMappingDescriptor`, `SparseTextureMappingDescriptor`, and
`SparseMappingCommitDescriptor`. They validate page size, region alignment, and
residency intent behind `DeviceFeatures.sparse_buffers`,
`DeviceFeatures.sparse_textures`, and `DeviceFeatures.tiled_textures`. Native
residency management is future backend work. Period 27 adds
`SparseBufferLowering`, `SparseTextureLowering`,
`Device.planSparseBufferLowering(...)`, and
`Device.planSparseTextureLowering(...)` so advanced applications can inspect
native page size, texture page grids, page counts, and backend mapping before
runtime sparse object creation is enabled. `SparseMappingCommitPlan` and
`Device.planSparseMappingCommit(...)` summarize commit/evict counts, buffer
bytes, and texture pages for residency update batches.

External interop shapes are represented by `ExternalHandleDescriptor`,
`ExternalMemoryDescriptor`, `ExternalBufferDescriptor`,
`ExternalTextureDescriptor`, and `ExternalSemaphoreDescriptor`. They validate
handle kind, selected backend compatibility, resource shape, ownership, and
feature gates. Runtime wrappers include `ExternalMemory`, `ExternalBuffer`,
and `ExternalTexture`, created with `Device.makeExternalMemory(...)`,
`Device.makeExternalBuffer(...)`, and `Device.makeExternalTexture(...)`.
External synchronization wrappers include `ExternalSemaphore` and
`ExternalEvent`, created with `Device.makeExternalSemaphore(...)` and
`Device.makeExternalEvent(...)`. `ExternalSynchronizationDescriptor` can be
passed to `CommandBuffer.commitWithExternalSynchronization(...)` for portable
backend/lifetime validation before native wait/signal lowering exists.
Native handle import/export remains explicit future backend work.

Starting in Period 2, runtime resources record portable usage state.
`ResourceUsageState` can classify read-after-write, write-after-read, and
write-after-write hazards. Blit copies, render attachments, vertex buffers, and
index buffers already feed this state. Explicit barrier commands also update
the same tracked state.

Manual barriers are an advanced escape hatch. `BufferBarrierDescriptor` and
`TextureBarrierDescriptor` validate ranges and before/after usage transitions,
and `ResourceUsageState.applyExplicitBarrier(...)` records the tracked
transition. Use `BlitCommandEncoder.bufferBarrier(...)` /
`textureBarrier(...)` or the matching compute encoder methods when an
application needs an explicit synchronization point. Vulkan lowers these calls
to `vkCmdPipelineBarrier`; Metal treats them as validation/no-op synchronization
markers because ordinary Metal encoders already define most resource ordering.
The path is gated by `DeviceFeatures.explicit_resource_barriers`; ordinary code
should keep using the automatic usage-tracking path.

Fence and event synchronization has runtime objects.
`Device.makeFence(...)` creates a `Fence` from `FenceDescriptor`; use
`signal(...)`, `wait(...)`, `reset(...)`, and `currentValue()` for explicit
CPU-visible state. Binary fences are available through `DeviceFeatures.fences`;
timeline fences remain gated by `DeviceFeatures.timeline_fences`.
`Device.makeEvent(...)` creates an `Event` with `signal(...)`, `wait(...)`,
`reset()`, and `isSignaled()`. Shared events remain gated by
`DeviceFeatures.shared_events`. Queue-submit integration is still a later
backend step.

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

Persistent runtime cache planning uses `RuntimeCacheManifestDescriptor`,
`RuntimeCachePlanDescriptor`, and `RuntimeCachePlan`. The manifest records
schema version, backend, source hash, and toolchain identity. Plans classify
existing metadata as compatible, missing, stale, backend-mismatched,
source-mismatched, or toolchain-mismatched while keeping the existing Slang
artifact files inspectable.

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
`ShaderSpecializationDescriptor` data for shader variants. The descriptor layer
validates duplicate IDs, duplicate names, and empty names. Runtime pipeline
fingerprints include specialization inputs so variant caches can distinguish
them. Vulkan lowers specialization values into pipeline specialization info
when `DeviceFeatures.shader_specialization` is enabled. Backends that do not
advertise that feature still reject non-empty specialization descriptors with
`UnsupportedShaderSpecialization`.

Render pipeline raster state includes cull mode, front face, fill mode, depth
bias, and a conservative-rasterization flag. Cull mode and front face are part
of the existing lowered path. Depth bias now lowers through pipeline binding and
dynamic encoder commands. Wireframe / line fill mode lowers on Metal and on
Vulkan devices that expose `wireframe_fill_mode`. Conservative rasterization
remains capability-gated and is rejected with a typed unsupported error until a
native mapping is added.

Color attachment pipeline state includes write masks and optional
`RenderPipelineBlendDescriptor` values. Blend descriptors carry separate RGB and
alpha factors/operations, and each attachment may specify its own descriptor.
Non-empty blend state is currently feature-gated by `DeviceFeatures.blend_state`;
different per-attachment blend descriptors also require
`DeviceFeatures.independent_blend`. Blend state and independent per-attachment
blend now lower to Vulkan and Metal with the MRT path.

Depth/stencil state includes `depth_test_enabled`, depth compare/write fields,
and a `StencilDescriptor` with front/back operations plus read/write masks.
Depth state and combined depth/stencil state lower to Vulkan and Metal.
`depth32_float_stencil8` is the first stencil-capable format. Separate
stencil-only attachments remain unsupported until the attachment model grows
beyond the combined depth/stencil path.

Vertex layouts support multiple buffers and attributes. A
`VertexBufferLayoutDescriptor` may specify an explicit `buffer_index`; when it
is omitted, the descriptor keeps the existing array-index mapping. Validation
rejects duplicate resolved buffer indices, duplicate attribute locations,
invalid strides/offsets, and zero instance step rates. Non-default
`instance_step_rate` now lowers to Metal vertex descriptor step rates and to
Vulkan vertex binding divisors when the selected device exposes
`vertex_instance_step_rate`.

`TessellationDescriptor` represents future tessellation pipeline extension
state. It is gated by `DeviceFeatures.tessellation`, validates patch control
point counts and required stage presence, and is intentionally separate from the
base render pipeline path until backend lowering is fully executable. Period 27
adds `TessellationLowering` and `Device.planTessellationLowering(...)` so
advanced applications can inspect Vulkan patch metadata or Metal factor-buffer
requirements from native feature reports.

`MeshPipelineDescriptor` represents future mesh/task shader pipeline metadata.
It is gated by `DeviceFeatures.mesh_shaders` and `DeviceFeatures.task_shaders`,
validates mesh and optional task entry points plus workgroup limits, and remains
outside the base render pipeline until backend execution is enabled. Period 27
adds `MeshPipelineLowering` and `Device.planMeshPipelineLowering(...)` so
applications can inspect Vulkan task/mesh metadata or Metal object/mesh
metadata from native feature reports.

Ray tracing is isolated in advanced descriptors:
`AccelerationStructureDescriptor`, `RayTracingPipelineDescriptor`, and
`ShaderBindingTableDescriptor`. They validate acceleration structure shape,
ray-generation shader group presence, recursion depth, and shader binding table
alignment behind `DeviceFeatures.acceleration_structures` and
`DeviceFeatures.ray_tracing`. Period 28 adds
`AccelerationStructureBuildDescriptor`, `AccelerationStructureBuildPlan`, and
`Device.planAccelerationStructureBuild(...)` so applications can inspect
geometry counts, build/update mode, result size, scratch size, and compaction
intent before native acceleration-structure objects are executable.
`RayTracingPipelineLowering` and `Device.planRayTracingPipelineLowering(...)`
expose Vulkan shader-group counts or Metal function-table metadata from native
feature reports before executable ray tracing pipelines are enabled.
`RayDispatchDescriptor`, `RayDispatchPlan`, and `Device.planRayDispatch(...)`
combine shader binding table layout with dispatch dimensions and total ray
counts before native ray dispatch commands are available. Metal-specific ray
tracing differences are explicit through `MetalRayTracingMappingDescriptor`,
`MetalRayTracingMappingPlan`, and `Device.planMetalRayTracingMapping(...)`.

Period 29 adds public runtime contracts for those advanced paths:
`AccelerationStructure` and `Device.makeAccelerationStructure(...)`,
`CommandBuffer.encodeAccelerationStructureBuild(...)`,
`RayTracingPipelineState` and `Device.makeRayTracingPipelineState(...)`,
`ShaderBindingTable` and `Device.makeShaderBindingTable(...)`,
`CommandBuffer.dispatchRays(...)`, and
`MetalRayTracingExecutionMapping` /
`Device.makeMetalRayTracingExecutionMapping(...)`. These APIs are gated by
native feature reports and validate ownership, resource ranges, and command
intent.

Period 30 adds backend-private runtime records to those objects: acceleration
structure handles/build records, ray tracing pipeline metadata, SBT records,
dispatch records, Metal table metadata, advanced-inventory routing, and parity
diagnostics. Driver-level ray tracing pixels and broader native parity are
split after Period30: Period31 now has the first Metal visible
ray-intersection triangle through the public render path, Period32 owns the
first Vulkan pixel-producing ray traced triangle, and Period32+ owns broader
native coverage.

## Bindings

Shader resource binding starts with public descriptors:

- `BindGroupLayoutDescriptor`
- `BindGroupDescriptor`
- `BindGroupLayout`
- `BindGroup`
- `ShaderVisibility`
- `BindingResourceKind`

Advanced binding shapes are capability-gated. `DescriptorIndexingLayoutDescriptor`
and `DescriptorIndexingRange` describe bindless-style ranges for Vulkan
descriptor indexing or Metal argument buffer layouts. They validate descriptor
counts, shader visibility, and the selected `AdvancedBindingModel`.
`Device.makeAdvancedBindGroupLayout(...)` snapshots those ranges into a
backend-aware `AdvancedBindGroupLayout` with descriptor count and range-flag
queries.

`Device.makeResourceTable(...)` creates a `ResourceTable` from an
`AdvancedBindGroupLayout`. Tables support `update(...)`, `clear(...)`, partial
binding validation, update-after-bind validation, and render/compute command
binding through `setResourceTable(...)`. Ordinary `BindGroup` remains the
portable path; resource tables are the advanced descriptor-indexing /
argument-buffer path.

The first resource classes are uniform buffers, storage buffers, storage
textures, sampled textures, samplers, and compare samplers. Layout entries also
carry `array_count` and `dynamic_offset` metadata. The descriptor layer
validates that array counts are non-zero, dynamic offsets are used only with
buffers, and storage textures are compute-only.

Runtime bind group creation validates layout shape, resource class, backend
match, whether referenced resources are alive, and whether storage resources
satisfy the declared access intent. Native lowering supports single resources
and resource arrays for uniform buffers, storage buffers, sampled textures,
storage textures, samplers, and compare samplers. A single binding uses
`BindGroupEntry.resource`; an array binding sets `BindGroupEntry.resources` and
must provide exactly `BindGroupLayoutEntry.array_count` resources:

```zig
const texture_resources = [_]vkmtl.BindGroupResource{
    .{ .sampled_texture = &albedo_view },
    .{ .sampled_texture = &normal_view },
};
const sampler_resources = [_]vkmtl.BindGroupResource{
    .{ .sampler = &linear_sampler },
    .{ .sampler = &nearest_sampler },
};
const entries = [_]vkmtl.BindGroupEntry{
    .{ .binding = 0, .resource = texture_resources[0], .resources = texture_resources[0..] },
    .{ .binding = 1, .resource = sampler_resources[0], .resources = sampler_resources[0..] },
};
```

Dynamic buffer offsets work for single buffer bindings and buffer arrays.
`DynamicOffset.array_element` addresses one element of a dynamic buffer array;
the default value `0` preserves the single-resource ABI. Render and compute
encoders expose `setBindGroup(...)` for debug-validated command recording.

Storage resources can specify `BindGroupLayoutEntry.storage_access` as
`.read`, `.write`, or `.read_write`. The metadata is valid only for storage
buffers and storage textures. Storage buffers default to read-write access;
storage textures default to write access. Runtime bind group creation checks
buffer `storage` usage and texture `shader_read` / `shader_write` usage against
that access intent and records portable storage read/write usage transitions.

`StaticSamplerDescriptor` records the immutable/static sampler policy. Static
samplers are layout-owned in concept and remain feature-gated by
`DeviceFeatures.static_samplers`; ordinary runtime bind groups still use live
`SamplerState` resources.

`DynamicOffset` and `DynamicOffsetList` are the public validation shape for
dynamic buffer offsets. Render and compute encoder `setBindGroup(...)` calls can
pass per-bind offsets through `BindGroupBinding.dynamic_offsets`:

```zig
try encoder.setBindGroup(&bind_group, .{
    .index = 0,
    .dynamic_offsets = &.{.{ .binding = 0, .array_element = 0, .offset = 256 }},
});
```

They validate that every dynamic buffer binding has one offset, that no
non-dynamic binding receives an offset, that every dynamic buffer array element
has one offset, and that offsets satisfy
`DeviceLimits.min_uniform_buffer_offset_alignment` or
`DeviceLimits.min_storage_buffer_offset_alignment`. Vulkan lowers them to
dynamic descriptor offsets; Metal adds them to the buffer base offset when
binding.

`SmallConstantDescriptor` is the first portable shape for small per-draw or
per-dispatch constant data. It is gated by `DeviceFeatures.small_constants`,
`DeviceLimits.max_small_constant_bytes`, and
`DeviceLimits.small_constant_alignment`. Command encoder lowering is not wired
yet.

`RootConstantRange`, `RootConstantLayoutDescriptor`, and
`RootConstantWriteDescriptor` define the push/root-constant equivalent. They
are gated by `DeviceFeatures.root_constants`,
`DeviceLimits.max_root_constant_bytes`, and
`DeviceLimits.root_constant_alignment`. Render and compute pipeline descriptors
carry an optional `root_constant_layout` so pipeline compatibility can be
validated against the selected device. Render and compute encoders expose
`setRootConstants(...)`. Vulkan lowers writes to `vkCmdPushConstants`; Metal
lowers writes through `set*Bytes` on a reserved root-constant buffer slot.

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
A non-graphics descriptor falls back to the graphics queue when `multi_queue`
is not supported and fallback is allowed. When `DeviceFeatures.multi_queue` and
the relevant dedicated queue gate are enabled, `queueWithDescriptor(...)`
returns a logical compute or transfer queue view. Current backends still record
commands through the existing native command queue until dedicated native queue
families are enabled.

`QueueOwnershipTransferDescriptor` is executable from blit and compute encoders
through `bufferOwnershipTransfer(...)` and `textureOwnershipTransfer(...)`.
Resources track their current owner queue with `ownerQueue()`. Access from the
wrong logical queue returns `InvalidQueueOwnershipState`; Metal currently maps
ownership transfers to validation/no-op behavior, while Vulkan queue-family
lowering remains tied to future native dedicated queue support.

Render passes can target the current drawable or an explicit texture view.
Texture-backed color attachments can also provide a single-sample
`resolve_target` when rendering from an MSAA texture. The descriptor model also
includes stencil attachments, transient attachment hints, and multiple color
attachments. Texture-backed MRT render passes lower to Vulkan and Metal, while
current-drawable render passes remain single-color. `transient` is currently
preserved as a no-op performance hint. Combined depth/stencil attachments lower
through the depth attachment path; separate stencil-only attachments still
return typed unsupported errors.

Dynamic render state descriptors include `Viewport`, `ScissorRect`,
`BlendColor`, `StencilReference`, and `DepthBiasDescriptor`.
`RenderCommandEncoder` exposes matching setters. These setters validate inputs
portably and lower to native Vulkan and Metal dynamic-state commands.
`BlendColor`, `StencilReference`, and `DepthBiasDescriptor` affect final output
only when the active render pipeline enables matching blend, stencil, or
depth-bias state.

Direct draw descriptors include `base_instance`; indexed draw descriptors also
include `base_vertex`. These base fields now lower to native Vulkan and Metal
direct draw commands. Indirect draw lowers to the native backend and requires
indirect buffers to use `.indirect` usage; `draw_count > 1` is expanded by
stride into multiple single indirect draw commands. Explicit
`drawPrimitivesMulti(...)` and `drawIndexedPrimitivesMulti(...)` lower through
repeated direct draws for now, with room to replace that loop with a true
backend-native multi-draw path later.

Runtime query support starts with portable `QuerySet` objects. Timestamp queries
can be written from blit, compute, and render encoders, occlusion queries can be
begun and ended from render encoders, and query data can be read back directly
or resolved into a buffer. Query ranges, result alignment, resource ownership,
and availability are validated by vkmtl. Pipeline statistics queries remain
feature-gated until the native backend lowering is filled in.

Transfer work uses a Metal-style blit encoder:

```zig
var queue = context.queue();
var command_buffer = try queue.makeCommandBuffer();
var blit = try command_buffer.makeBlitCommandEncoder();
try blit.copyBufferToBuffer(&source, &destination, .{ .size = byte_count });
try blit.endEncoding();
try command_buffer.commit();
```

The lowered blit slice supports buffer-to-buffer, buffer-to-texture,
texture-to-buffer, and texture-to-texture copies. Texture-to-texture copies can
address mip levels and copy multiple array layers with `slice_count`. Color
formats can copy across the same copy class, such as `rgba8_unorm` to
`rgba8_unorm_srgb`; copies still reject channel-order changes, depth/stencil
formats, and MSAA textures.
`BlitCommandEncoder.fillBuffer(...)` also lowers to the native backend. Metal
supports arbitrary byte ranges. Vulkan keeps native `vkCmdFillBuffer` for
4-byte-aligned ranges and uses a staging-copy fallback for unaligned ranges.
`BlitCommandEncoder.generateMipmaps(...)` validates format support, copy usage,
sample count, and mip count through `GenerateMipmapsDescriptor`. Vulkan lowers
full-texture generation through image blits, and Metal lowers full-texture
generation through `generateMipmapsForTexture`. Partial mip/layer ranges remain
unsupported until the backend parity matrix decides how to expose those
differences.

Advanced users can insert explicit barriers from blit encoders with
`bufferBarrier(...)` and `textureBarrier(...)`. These methods validate the
descriptor against the tracked resource state before touching the backend.

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

`DispatchThreadgroupsIndirectDescriptor` represents indirect dispatch
arguments. Indirect buffers use `BufferUsage.indirect`; runtime
`dispatchThreadgroupsIndirect(...)` validates usage, offset, alignment, and
threadgroup size before lowering to Vulkan `vkCmdDispatchIndirect` or the Metal
indirect dispatch path. Metal needs `threads_per_threadgroup_*`, so those fields
stay in the descriptor; the Vulkan backend ignores them.

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

`ObjectCachePolicy` controls whether a descriptor requests reuse, disables
diagnostics, or records diagnostics only. Cacheable object descriptors carry a
defaulted `cache_policy` field. `ObjectCacheDiagnostics` reports lookup hits,
misses, creation attempts, equivalent recreation attempts, bypassed reuse,
suppressed diagnostics, and total creation time. Read snapshots with
`device.objectCacheDiagnostics()` or `context.objectCacheDiagnostics()`.
`device.runtimeDiagnostics()` and `context.runtimeDiagnostics()` return the
same object-cache snapshot together with live resource count, deferred
retirement count, and submitted/completed work serials.

These diagnostics now run through the runtime object-cache lookup path for
shader modules, bind group layouts, render pipelines, compute pipelines, and
samplers. They still do not prove that a backend-native handle was reused;
lifetime-safe native handle pooling is future backend work.

Driver-level cache identity is represented separately by
`DriverCacheIdentityDescriptor` and `DriverPipelineCacheDescriptor`. Vulkan
pipeline cache and Metal binary archive support are gated by
`DeviceFeatures.driver_pipeline_cache` and `DeviceFeatures.metal_binary_archive`.
Identity includes backend, device, driver, shader hash, and schema version so
future disk cache invalidation can be explicit.
`Device.planDriverPipelineCache(...)` validates against native feature reports
and returns `DriverPipelineCachePlan`, including whether the path already exists
and whether shutdown should store a new blob. Pipeline creation does not consume
native driver cache objects yet.

## Stability Diagnostics

`StabilityRunDescriptor` describes opt-in long-run checks without forcing them
into default tests. It can plan resource churn, presentation resize/recreate
cycles, shader-cache warm/cold cycles, upload/readback cycles, and Vulkan
unaligned `fillBuffer(...)` fallback checks:

```zig
const plan = try vkmtl.StabilityRunDescriptor{
    .iterations = 120,
}.plan();

const diagnostics = vkmtl.StabilityRunDiagnostics.fromPlan(plan);
```

`StabilityRunPlan` contains expected counters. `StabilityRunDiagnostics` can
also record runtime snapshots, including pending retirement warnings and maximum
live resources observed. The current opt-in command is:

```sh
zig build run-stability-plan -- --iterations 120
```

Native GPU soak loops and persistent staging-buffer pools remain backend
hardening work.

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
are created, and they are synchronized to native object labels when the backend
supports it. `label()` returns the current borrowed label, and `setLabel(null)`
clears it.

Capture-friendly names can be built with `CaptureNameDescriptor` or the runtime
helpers `device.writeCaptureName(...)` / `context.writeCaptureName(...)`.
If the descriptor omits `backend`, the runtime helper fills in the selected
backend:

```zig
var name_buffer: [96]u8 = undefined;
const capture_name = try device.writeCaptureName(.{
    .scope = "frame",
    .name = "main-pass",
    .frame_index = frame_index,
}, name_buffer[0..]);
```

Debug groups and signposts are validated portably. Empty labels, underflow,
overflow, and unclosed groups become `CommandEncodingError` values.
`DebugSignpostDescriptor` is the shape-only marker descriptor, and command
buffers plus render/blit/compute encoders expose `insertDebugSignpost(...)`.
Metal command-buffer and encoder markers lower to Metal debug APIs. Vulkan
render/blit/compute encoder markers lower to `EXT_debug_utils` while the command
buffer is recording. Vulkan command-buffer-level markers remain portable
validation only because vkmtl allows them before an encoder exists, while native
Vulkan markers require a recording command buffer.

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

Native command insertion is similarly explicit. Render, compute, and blit
encoders expose `insertNativeCommands(...)` with
`NativeCommandInsertionDescriptor`. The descriptor validates the feature gate,
callback, and encoder kind before invoking user code. Backends keep the feature
disabled until real command-buffer / command-encoder native handle views are
available.

`NativeAdvancedClosureDescriptor`, `NativeAdvancedClosurePlan`, and
`Device.planNativeAdvancedClosure(...)` expose the current native-advanced
implementation backlog as data for tooling and roadmap checks. The plan
distinguishes public runtime contracts from backend-private native lowering.

`BackendParitySemanticsDescriptor`, `BackendParitySemanticsPlan`, and
`Device.planBackendParitySemantics(...)` expose current parity decisions for
partial mip/layer ranges, depth/stencil and MSAA copies, custom sampler border
colors, and opt-in GPU soak planning.
