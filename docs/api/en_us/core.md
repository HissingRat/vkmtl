# Project API

vkmtl exposes backend-neutral descriptors and runtime wrappers through the
public `vkmtl` module. User code should not import `backend/vulkan`,
`backend/metal`, raw Vulkan bindings, or Metal bridge headers.

Windowed examples use `WindowContext` to assemble backend selection, surfaces,
and presentation. Resource creation belongs to `Device`, command-buffer
creation and submission belong to `Queue`, and presentation resize/clear
belongs to `Swapchain`. `WindowContext` provides access to those owners but
does not forward their operations.

No-window work uses `HeadlessContext`. It owns backend device and queue state
without a surface, swapchain, drawable, or presentation queue. Its `Device`
and `Queue` views use the same resource, shader, pipeline, and command API as a
windowed context.

## Backend Selection

Applications choose a backend with `BackendPreference`:

- `.auto`
- `.vulkan`
- `.metal`

The selected backend can be queried with `selectedBackend()` on contexts and
runtime resource wrappers.

Create a headless owner when presentation is not needed:

```zig
var context = try vkmtl.HeadlessContext.init(allocator, .{
    .app_name = "my compute job",
    .backend = .auto,
});
defer context.deinit();

var device = context.device();
var queue = context.queue();
```

`HeadlessContext.Options` also accepts `adapter_selection` and
`debug_backend_override`. Current-drawable render passes and presentation are
unavailable; texture-view-backed render passes remain supported. Destroy all
resources and finish submitted work before `HeadlessContext.deinit()`.

## Surfaces And Presentation

Windowing integration stays outside the core API. Examples use the external
`zig_glfw` package plus `examples/common.zig` glue to convert a GLFW window into
public descriptors:

- `SurfaceDescriptor`
- `PresentationDescriptor`

For Vulkan, that glue also supplies a
`vkmtl.native.vulkan.SurfaceProvider` with the instance extensions,
proc-address lookup, and surface-creation callback required by the backend.
Examples pass the resulting descriptors to `WindowContext.init(...)`.

Starting in Period 2, `WindowContext.surface()` and
`WindowContext.swapchain()` expose runtime views. `Surface` keeps the
window/provider descriptor information. `Swapchain` owns presentation-chain
resize, and the current clear-screen helper lives at `Swapchain.clear(...)`.

`vkmtl.presentation.SurfaceCollection` is the first multi-surface management shape. It can track
multiple neutral surface presentation states for one selected backend and uses
generation handles for resize/remove validation. It does not create multiple
native swapchains yet; complete native multi-window support is gated by
`DeviceFeatures.multi_surface`.

Presentation helpers under `vkmtl.presentation` include `PresentModeSupport`,
`PresentModeResolution`, `defaultPresentModeSupport(...)`, and
`FramePacingDiagnostics`.
`vkmtl.presentation.presentModeSupport(device)` exposes the conservative
support table for the selected backend, while
`vkmtl.presentation.resolvePresentMode(device, requested)` reports whether a
requested present mode fell back. `SurfaceCollection.framePacingDiagnostics(...)`
reports per-surface configured state, selected mode, vsync intent, generation,
frame-in-flight state, and submitted/completed frame serials.

## Resources

The runtime `Device` is the resource creation entry point.
`WindowContext.device()` and `HeadlessContext.device()` return a device view
for their current owner.

- `makeBuffer(BufferDescriptor)`
- `makeTexture(TextureDescriptor)`
- `makeSamplerState(SamplerDescriptor)`

## External Resource Imports And Device Topology

External ownership stays under `vkmtl.interop`. `Device.makeExternalMemory`,
`makeExternalBuffer`, and `makeExternalTexture` create owners whose
`importedBuffer()` or `importedTexture()` methods return a borrowed ordinary
resource when the selected backend executed the import. Keep that resource
within the external owner's lifetime and do not deinitialize it separately.

The executable Period 53 subset is Metal-only: same-device raw buffers,
single-mip/single-sample 2D or 2D-array raw textures, and single-plane
IOSurfaces. Vulkan imports, external synchronization, and native command
insertion return typed unsupported errors under the current contracts.

A raw Metal handle value must name a live Objective-C object of the declared
protocol. Property validation cannot make an arbitrary invalid pointer safe.

Query stable selected-device identity and native group membership with
`vkmtl.diagnostics.deviceTopology(device)`. The report intentionally does not
enable peer allocation, device masks, or cross-device submission.

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
the selected runtime backend for known limits. Vulkan queries native format
properties; Metal applies the documented conservative per-format table.

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
Managed synchronization is automatic at these boundaries: Metal publishes CPU
writes with `didModifyRange` and synchronizes GPU writes before a CPU map/read,
while Vulkan uses the current host-coherent managed allocation path. Callers do
not encode a separate managed-resource synchronization command.
Shader-visible addresses require `DeviceFeatures.buffer_gpu_address` and
`BufferUsage.shader_device_address`; `buffer.gpuAddress()` then returns the
native GPU address or a typed unsupported/unavailable error.

Automatic/shared/managed textures support the CPU upload helpers. Private
textures reject `replaceRegion(...)`; upload them through a staging buffer and
transfer encoder so Metal and Vulkan share one portable boundary.

Textures create views through `texture.makeTextureView(...)`, and upload
helpers include `texture.replaceRegion(...)` and `texture.replaceAll2D(...)`.
`TextureDescriptor.shape()` classifies 1D, 2D, 3D, array,
cube-compatible, cube-array-compatible, and multisampled textures.
Cube textures are currently represented as 2D textures with six layers per
cube; cube-specific view dimensions are reserved for the texture-view phase.

Format helpers include `textureFormatKind(...)`, `isColorFormat(...)`,
`isDepthFormat(...)`, `isSrgbFormat(...)`, and
`textureFormatBytesPerPixel(...)`. New code should use the canonical
`vkmtl.resource` and `vkmtl.diagnostics` namespaces for format types and
capability reports. `FormatCapabilities` independently reports sampling,
storage, attachment, filtering, mip, blend, exact-copy, scaled-blit,
presentation, depth/stencil copy, and color/depth/stencil resolve support.
`Device.getFormatCaps(format)` is queried from the selected backend; a native
feature is not reported as usable before vkmtl has a validated execution path.
The finite common set includes R/RG/RGBA normalized, integer, 16/32-bit float,
depth16/depth32, and stencil8 formats. Vertex formats include half x2/x4,
normalized 8-bit x2/x4, float32, and signed/unsigned 32-bit scalar/vector
inputs. Native formats outside the enum are intentionally unsupported.

Mipmap helpers include `mipDimension(...)`,
`maxMipLevelCountForExtent(...)`, `TextureDescriptor.maxMipLevelCount()`, and
`TextureDescriptor.mipExtent(level)`. Texture descriptors reject mip counts
larger than the texture extent can support. `GenerateMipmapsDescriptor` is a
validated public shape for automatic mip generation; blit encoders can generate
full-texture mip chains with `generateMipmaps(...)`.

Runtime `TextureView` stores the resolved view format, dimension, mip range,
and layer range. Query them with `descriptor()`, `baseMipLevel()`,
`mipLevelCount()`, `baseArrayLayer()`, and `arrayLayerCount()`.
Linear and sRGB variants of RGBA8 or BGRA8 are compatible view formats.
`TextureViewDescriptor.component_mapping` provides explicit zero, one, and
R/G/B/A swizzles; incompatible format pairs and depth/stencil swizzles fail
before native view creation.

`SamplerDescriptor` includes compare, anisotropy, and border-color fields.
Those advanced fields are capability-gated by `DeviceFeatures.sampler_compare`,
`DeviceFeatures.sampler_anisotropy`, `DeviceFeatures.sampler_border_color`, and
`DeviceLimits.max_sampler_anisotropy`. Compare samplers and anisotropy now lower
to Vulkan/Metal sampler creation. Fixed border colors also lower to Vulkan and
Metal sampler creation when address modes use `clamp_to_border`; custom border
colors remain out of scope.
`SamplerDescriptor.normalized_coordinates` defaults to true. A false value is
lowered by both backends only for the portable unnormalized-coordinate subset:
equal min/mag filters, no mipmapping, clamp-to-edge, zero LOD, no comparison,
unit anisotropy, and no border color.

`HeapDescriptor` defines native placement storage. `Device.makeHeap(...)` is
feature-gated by `DeviceFeatures.heaps`. Query exact backend requirements with
`bufferAllocationRequirements(...)` or `textureAllocationRequirements(...)`,
pass the result through `reserve(...)`, then create the placed resource with
`makeBufferAt(...)` or `makeTextureAt(...)`. Metal uses placement `MTLHeap`
resources; Vulkan binds buffers/images into one compatible `VkDeviceMemory`
allocation. Heap resources must be destroyed before the heap, and
`liveResourceCount()` reports outstanding children. `HeapAliasingDescriptor`
still validates disjoint-lifetime overlap; applications own the lifetime proof
before reusing an offset.

Memory diagnostics use `vkmtl.diagnostics.MemoryBudgetDescriptor` and
`vkmtl.diagnostics.memoryBudgetReport(device, descriptor)`. The report distinguishes native and fallback
sources, totals explicit usage, heap reservations, transient peak bytes, and
sparse residency bytes, and classifies pressure as unknown, nominal, warning,
critical, or over-budget. Metal uses recommended working-set/current-allocation
values. Vulkan uses `VK_EXT_memory_budget` when present. Otherwise the same
descriptor produces a clearly labeled fallback report.

`ResourceStorageMode.memoryless` requests hardware tile-memory attachment
storage. It is non-CPU-visible, render-attachment-only, and cannot load or store
persistent contents. Metal exposes it only after a native creation probe;
memoryless MSAA attachments may resolve into persistent textures. Vulkan keeps
the lane typed unsupported because lazily allocated memory cannot guarantee no
physical backing. The separate render-pass `transient` option remains only a
lifetime/performance hint.

Sparse and tiled resource shapes are represented by
`vkmtl.resource.SparseBufferMappingDescriptor`, `SparseTextureMappingDescriptor`, and
`SparseMappingCommitDescriptor`. They validate page size, region alignment, and
residency intent behind `DeviceFeatures.sparse_buffers`,
`DeviceFeatures.sparse_textures`, and `DeviceFeatures.tiled_textures`. Native
residency execution is intentionally unsupported by the current shape because
mapping descriptors do not identify actual resource handles. Period 27 adds
`vkmtl.native.SparseBufferLowering`, `vkmtl.native.SparseTextureLowering`,
`vkmtl.native.planSparseBufferLowering(device, descriptor)`, and
`vkmtl.native.planSparseTextureLowering(device, descriptor)` so advanced applications can inspect
native page size, texture page grids, page counts, and backend mapping before
runtime sparse object creation is enabled. `SparseMappingCommitPlan` and
`vkmtl.resource.planSparseMappingCommit(device, descriptor)` summarize commit/evict counts, buffer
bytes, and texture pages for residency update batches.
`SparseResidencyChurnDescriptor`, `SparseResidencyMap.runChurn(...)`, and
`vkmtl.resource.planSparseResidencyChurn(device, descriptor)` provide deterministic repeated
commit/evict pressure diagnostics while native page binding remains
unavailable. Native sparse feature queries do not open usable features.

External interop shapes under `vkmtl.interop` are represented by `ExternalHandleDescriptor`,
`ExternalMemoryDescriptor`, `ExternalBufferDescriptor`,
`ExternalTextureDescriptor`, and `ExternalSemaphoreDescriptor`. They validate
handle kind, selected backend compatibility, resource shape, ownership, and
feature gates. Runtime wrappers include `ExternalMemory`, `ExternalBuffer`,
and `ExternalTexture`, created with `Device.makeExternalMemory(...)`,
`Device.makeExternalBuffer(...)`, and `Device.makeExternalTexture(...)`.
`ExternalInteropImportPlan` records the backend/platform lane, process/device
scope, feature gate, and ownership for each wrapper.
`ExternalTextureUsageDescriptor` and
`vkmtl.interop.planExternalTextureUsage(device, descriptor)`
validate sampling, copy, and presentation intent before a texture wrapper is
used.
External synchronization wrappers include `ExternalSemaphore` and
`ExternalEvent`, created with `Device.makeExternalSemaphore(...)` and
`Device.makeExternalEvent(...)`. `ExternalSynchronizationDescriptor` can be
planned with `ExternalSynchronizationDescriptor.plan(...)` or passed to
`CommandBuffer.commitWithExternalSynchronization(...)` for portable
backend/lifetime/order validation before native wait/signal lowering exists.
Native handle import/export remains explicit future backend work.
`ExternalInteropCapabilityMatrix`, `ExternalInteropCapabilityEntry`, and
`vkmtl.interop.externalInteropCapabilityMatrix(device)` list handle kinds by
backend/platform and classify each path as `portable`, `capability_gated`,
`native_only`, or `unsupported`. This gives diagnostics a stable source before
native import code runs. `vkmtl.interop.diagnoseExternalInteropImport(device, descriptor)` returns an
`ExternalInteropImportDiagnostic` for issue reports when an import cannot be
planned.

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
timeline fences are gated by `DeviceFeatures.timeline_fences` and map to native
Vulkan timeline semaphores or Metal shared events.
`Device.makeEvent(...)` creates an `Event` with `signal(...)`, `wait(...)`,
`reset()`, and `isSignaled()`. Shared events are native Metal shared events and
remain gated by `DeviceFeatures.shared_events`; they do not promise external
handle import/export.

`vkmtl.sync.syncCapabilities(device)` summarizes
fence, timeline-fence, event, shared-event, host wait/signal, queue wait/signal,
and native support gates as `SyncCapabilities`. `SynchronizationDescriptor`
can be passed to `CommandBuffer.commitWithSynchronization(...)`. Native
timeline/shared-event operations are encoded into the backend submission;
binary fences and ordinary events keep their exact host-side fallback. Both
paths validate object lifetime, device/backend identity, and monotonic values.

## Shaders And Pipelines

Slang is the source language. Applications usually embed `.slang` files and
ask `Device` for the matching precompiled shader at startup:

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

Runtime does not spawn `slangc`, and it does not write shader artifacts to
disk. vkmtl resolves SPIR-V, MSL, and reflection JSON directly from build-time
precompiled blobs embedded in the executable. Inspectable build artifacts are
installed under `zig-out/shaders/<shader-name>/`.

Persistent runtime cache planning uses `RuntimeCacheManifestDescriptor`,
`RuntimeCachePlanDescriptor`, and `RuntimeCachePlan`. The manifest records
schema version, backend, and source hash. Plans classify existing metadata as
compatible, missing, stale, backend-mismatched, or source-mismatched. This
object/runtime cache planning is an advanced resource-cache facility; it is not
used for runtime shader compilation or shader artifact export.

Programmable stages can optionally attach reflection data with
`ProgrammableStageDescriptor.reflection`. Runtime pipeline creation validates
reflection artifacts or inline reflection data against the explicit
`bind_group_layouts` before creating backend pipelines.
`vkmtl.shader.Reflection` also exposes helpers that derive bind group layout
descriptors from attached stage reflection:

```zig
var layouts = try vkmtl.shader.Reflection.deriveRenderPipelineBindGroupLayouts(
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
var vertex_descriptor = try vkmtl.shader.Reflection.deriveSingleBufferVertexDescriptor(
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
them. Vulkan lowers values into pipeline specialization info; Metal creates
specialized vertex, fragment, and compute functions with
`MTLFunctionConstantValues`. Both paths use the required numeric `id`.
Generated MSL names may be rewritten, so the optional constant `name` is only
validation, diagnostics, and cache identity. Slang sources should declare an
explicit `[vk::constant_id(N)]` matching the descriptor ID. Backends that do
not advertise `DeviceFeatures.shader_specialization` reject non-empty
descriptors with `UnsupportedShaderSpecialization`.

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

`vkmtl.render.TessellationDescriptor` represents future tessellation pipeline extension
state. It is gated by `DeviceFeatures.tessellation`, validates patch control
point counts and required stage presence, and is intentionally separate from the
base render pipeline path until backend lowering is fully executable.
`TessellationPatchDrawDescriptor` and
`vkmtl.render.planTessellationPatchDraw(device, descriptor)` describe neutral
patch-list draw plans. Backend-specific inspection is explicit through
`vkmtl.native.vulkan.planTessellationPatchDraw(...)` and
`vkmtl.native.metal.planTessellationPatchDraw(...)`.

`vkmtl.render.MeshPipelineDescriptor` represents future mesh/task shader pipeline metadata.
It is gated by `DeviceFeatures.mesh_shaders` and `DeviceFeatures.task_shaders`,
validates mesh and optional task entry points plus workgroup limits, and remains
outside the base render pipeline until backend execution is enabled.
`MeshDispatchDescriptor` and `vkmtl.render.planMeshDispatch(device, descriptor)`
describe neutral mesh/task dispatch plans. Backend-specific inspection uses
`vkmtl.native.vulkan.planMeshDispatch(...)` or
`vkmtl.native.metal.planMeshDispatch(...)`.

Ray tracing is isolated under `vkmtl.ray_tracing` through
`AccelerationStructureDescriptor`, `RayTracingPipelineDescriptor`, and
`ShaderBindingTableDescriptor`. These declarations validate acceleration structure shape,
ray-generation shader group presence, recursion depth, and shader binding table
alignment behind `DeviceFeatures.acceleration_structures` and
`DeviceFeatures.ray_tracing`. Period 28 adds
`AccelerationStructureBuildDescriptor`, `AccelerationStructureBuildPlan`, and
`vkmtl.ray_tracing.planAccelerationStructureBuild(device, descriptor)` so applications can inspect
geometry counts, build/update mode, result size, scratch size, and compaction
intent before native acceleration-structure objects are executable.
Period 39 adds `AccelerationStructureMaintenanceDescriptor`,
`AccelerationStructureMaintenancePlan`, and
`vkmtl.ray_tracing.planAccelerationStructureMaintenance(device, descriptor)` for update, refit, and
compaction planning. Update/refit require
`DeviceFeatures.acceleration_structure_update` or
`DeviceFeatures.acceleration_structure_refit` plus an update-capable AS;
compaction requires `DeviceFeatures.acceleration_structure_compaction` and a
separate destination AS.
Period 52 makes those maintenance plans executable by passing
`AccelerationStructureMaintenanceResources` to
`CommandBuffer.encodeAccelerationStructureMaintenance(...)`. Update/refit use
a built, `allow_update` source plus AS scratch; compact uses a built source and
a distinct destination without scratch. The source must have been built with
`AccelerationStructureBuildFlags.allow_compaction`. Metal and Vulkan both submit native
update/refit/compact-copy commands. Build/update scratch sizes are native
queries; post-build compacted-size query remains unsupported.
Build-input buffers and TLAS instance-source AS objects referenced by the source
must remain alive through every update/refit submission that reuses them.
`TopLevelAccelerationStructureInstanceDescriptor`,
`TopLevelAccelerationStructureLayoutDescriptor`, and
`vkmtl.ray_tracing.planTopLevelAccelerationStructureLayout(device, descriptor)` describe backend-neutral
TLAS instance metadata: transforms, masks, custom indices, SBT record offsets,
material indices, triangle instances, procedural AABB instances, and mixed
geometry requirements.
`RayQueryDescriptor`, `RayQueryPlan`, and
`vkmtl.ray_tracing.planRayQuery(device, descriptor)` describes Vulkan ray-query
shader requirements. It is currently a planning/native-availability contract,
not executable support: Metal has no direct equivalent and ordinary Vulkan
compute/render bindings cannot yet bind an AS, so usable `ray_query` is false
on both backends.
Backend pipeline lowering remains internal to runtime pipeline creation.
`RayDispatchDescriptor`, `RayDispatchPlan`, and
`vkmtl.ray_tracing.planRayDispatch(device, sbt, descriptor)` combine shader
binding table layout with dispatch dimensions and total ray counts.
Metal-specific ray tracing inspection is explicit through
`vkmtl.native.metal.RayTracingMappingDescriptor`, `RayTracingMappingPlan`, and
`vkmtl.native.metal.planRayTracingMapping(device, descriptor)`.
`ComplexShaderBindingTableDescriptor`,
`ShaderBindingTableHitGroupRangeDescriptor`, and
`vkmtl.ray_tracing.planComplexShaderBindingTable(device, descriptor)` validates larger miss/hit/callable
record layouts, hit-group ranges, procedural hit ranges, total SBT record
limits, and callable shader feature requirements.
`RayTracingStressDescriptor`, `RayTracingStressPlan`, and
`vkmtl.ray_tracing.planRayTracingStress(device, descriptor)` combines AS maintenance, TLAS instance
metadata, complex SBT layout, optional ray query, dispatch dimensions, and
iteration count into one deterministic stress plan.

Period 29 adds public runtime contracts for those advanced paths:
`AccelerationStructure` and `Device.makeAccelerationStructure(...)`,
`CommandBuffer.encodeAccelerationStructureBuild(...)`,
`RayTracingPipelineState` and `Device.makeRayTracingPipelineState(...)`,
`ShaderBindingTable` and `Device.makeShaderBindingTable(...)`,
`CommandBuffer.dispatchRays(...)`, and
`vkmtl.native.metal.RayTracingExecutionMapping` /
`vkmtl.native.metal.makeRayTracingExecutionMapping(&device, descriptor)`.
Executable factories are gated by usable feature reports and validate
ownership, resource ranges, and command
intent. Supported Metal and Vulkan RT devices have both produced visible
physical-device output; the 9/9 release evidence does not promote unrelated
planning-only native pressure features.

Period 30 adds backend-private runtime records to those objects: acceleration
structure handles/build records, ray tracing pipeline metadata, SBT records,
dispatch records, Metal table metadata, advanced-inventory routing, and parity
diagnostics. Driver-level ray tracing pixels and broader native parity are
split after Period30: Period31 now has the first Metal visible ray traced scene
through a backend-private Metal command path, Period32 owns the first Vulkan
pixel-producing ray traced scene, Period33 owns the full native mesh ray traced
scene, Period34 owns the Vulkan procedural sphere / custom intersection path,
and Period35 owns shared scene data plus Metal procedural parity.

Period33 adds public acceleration-structure build-input plumbing. Mesh AS
builds can pass `AccelerationStructureGeometryResources.triangles` with a
vertex buffer, optional index buffer, `AccelerationStructureVertexFormat`,
`AccelerationStructureIndexType`, offsets, strides, and primitive counts.
Buffers used this way must be created with
`BufferUsage.acceleration_structure_build_input`. The same runtime shape also
has `AccelerationStructureGeometryResources.aabbs`; AABB descriptor and buffer
validation feed the Period34 Vulkan procedural sphere path. Period 52 adds
native Metal AABB BLAS build and lets one TLAS reference multiple distinct BLAS
sources. Non-default transform/mask/custom-index/SBT-offset metadata remains a
planning contract.

Period34 starts the procedural RT contract with
`RayTracingHitGroupKind.procedural`,
`RayTracingPipelineDescriptor.intersection`,
`DeviceFeatures.ray_tracing_procedural_geometry`, and
`DeviceFeatures.ray_tracing_custom_intersection`. These fields are descriptor
validation gates today: unsupported procedural/custom-intersection usage fails
before command submission. Vulkan now materializes intersection shader stages,
procedural hit groups, SBT records, and the procedural `ray_traced_scene`
acceptance path. Metal schema-2 artifacts contain no linked intersection
function or driver-bound table, so custom intersection/function tables remain
explicitly unsupported; a planning mapping does not claim a native table.

`Device.compileRayTracingShader(...)` returns a `CompiledRayTracingShader`.
Use `CompiledRayTracingShader.applyToPipelineDescriptor(backend, &descriptor)`
to attach the backend-specific ray tracing artifacts to a
`RayTracingPipelineDescriptor`. Vulkan currently receives Slang-generated
SPIR-V ray-generation, miss, closest-hit, any-hit, and intersection stages.
Metal receives the build-time precompiled Metal ray-generation artifact through
the same compiled shader object; direct Slang HLSL-RT-to-Metal-RT lowering is
still a compiler backend parity item rather than an example-side branch.

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
argument-buffer path. Render/compute pipelines declare compatible
`resource_table_layouts`; these slots follow ordinary `bind_group_layouts`, and
`setResourceTable(...)` rejects a mismatched slot/layout before native work.
Metal lowers the table to a real argument buffer and Vulkan to an enabled,
allocated, updated, and bound descriptor-indexing set. Vulkan supports
replacement updates after bind for ranges that opt in; clearing a Vulkan slot
must happen before its first command binding because the current baseline does
not require null descriptors. Table mutation must not race in-flight work; a
mutated table is rebound before later commands use its replacement resources.

CPU-authored reusable draw/dispatch lists live under `vkmtl.command`. Create an
`IndirectCommandBuffer`, encode fixed slots, then call the render or compute
encoder's `executeIndirectCommands(...)`. Slots inherit the active pipeline and
resources. Metal uses a native indirect command buffer when supported; Vulkan
expands the immutable range into exact direct commands. Shader/GPU mutation of
slots is not supported by this contract.

`vkmtl.binding.ResourceTablePressureDescriptor` and
`vkmtl.binding.planResourceTablePressure(device, descriptor)` summarize large table pressure before
allocation. The returned `ResourceTablePressurePlan` reports total descriptors,
per-resource descriptor counts, expected bound/unbound descriptors,
partially-bound and update-after-bind requirements, and worst-case updates in
flight. `canCreateTable()` tells whether the caller opted into the required
table semantics.

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
const texture_resources = [_]vkmtl.binding.BindGroupResource{
    .{ .sampled_texture = &albedo_view },
    .{ .sampled_texture = &normal_view },
};
const sampler_resources = [_]vkmtl.binding.BindGroupResource{
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
Pure descriptor validation uses the canonical `vkmtl.binding` declarations;
the former shape-only root aliases are no longer public.

Pipelines that use shader resources should include matching
`bind_group_layouts` in their render or compute pipeline descriptor. Those
layouts can be written manually or derived from reflection with
`vkmtl.shader.Reflection.deriveRenderPipelineBindGroupLayouts(...)` and
`vkmtl.shader.Reflection.deriveComputePipelineBindGroupLayouts(...)`. Vulkan uses the
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
`CommandBufferDescriptor` for a borrowed label, optional lifecycle callback,
and future pooling/reuse hints.
The default `makeCommandBuffer()` path remains equivalent to an empty
descriptor. `CommandBuffer.state()` reports the portable lifecycle state.
`CommandBuffer.lifecycleStatus()` reports encoding, scheduled, completed, or
failed. A configured callback receives scheduled and completed exactly once on
the current synchronous commit path; callback thread identity and reentrant use
are not promised.
Command buffers are still one-shot after `commit()`; pooled or reusable command
buffers are represented by descriptor fields and rejected by feature gates until
native reset/pooling is implemented.

`vkmtl.sync.QueueKind`, `QueueCapabilities`, `QueueDescriptor`, and
`QueueSelectionPlan` define the multi-queue selection vocabulary.
`vkmtl.command.queueCapabilities(device)` returns the current device's logical
queue capabilities, and `vkmtl.command.planQueue(device, descriptor)` reports
the requested kind, resolved kind, graphics
fallback state, dedicated logical queue state, and ownership-transfer support.
`Device.queue()` still returns the default graphics queue, and
`Device.queueWithDescriptor(.{})` is the explicit form of that default. A
non-graphics descriptor falls back to the graphics queue when `multi_queue` is
not supported and fallback is allowed. When `DeviceFeatures.multi_queue` and the
relevant dedicated queue gate are enabled, `queueWithDescriptor(...)` selects a
physical compute or transfer queue. Metal creates independent command queues.
Vulkan queries queue families and uses a dedicated family where one exists;
otherwise the descriptor's fallback policy applies.

`QueueOwnershipTransferDescriptor` is executable from blit and compute encoders
through `bufferOwnershipTransfer(...)` and `textureOwnershipTransfer(...)`.
Resources track their current owner queue with `ownerQueue()`. Access from the
wrong queue returns `InvalidQueueOwnershipState`. Metal composes native queue
ordering with tracked ownership. Vulkan resources shared by selected work
families use concurrent native sharing while vkmtl enforces exclusive logical
ownership; raw queue-family release/acquire control is not exposed.

`CommandBuffer.presentDrawableWithDescriptor(...)` adds capability-gated
presentation timing. `.immediate` is the default. `.at_monotonic_time` and
`.after_minimum_duration` require a nonzero nanosecond value and the matching
device feature. Unsupported timing returns a typed error unless
`allow_immediate_fallback` explicitly authorizes immediate presentation. Metal
maps both timed modes natively; Vulkan currently reports the timed modes
unsupported. `presentDrawable()` remains the immediate convenience call.

Render passes can target the current drawable or an explicit texture view.
Texture-backed color attachments can also provide a single-sample
`resolve_target` when rendering from an MSAA texture. The descriptor model also
includes stencil attachments, transient attachment hints, and multiple color
attachments. Every texture-backed MRT attachment and its load/store action now
lowers to Vulkan and Metal, while
current-drawable render passes remain single-color. `transient` is currently
preserved as a no-op performance hint. Combined depth/stencil attachments lower
when both descriptors reference the same depth-stencil view; separate
stencil-only and current-drawable stencil attachments remain typed unsupported.
Current-drawable attachments use their documented clear/store defaults and
reject other actions explicitly. Ordinary copy/readback of multisampled
textures is rejected; color resolve is the explicit path to a single-sample
target. Depth and stencil resolve targets are represented in the public shape
but return `UnsupportedTextureResolve` until both backends have validated
lowering.

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

Runtime query support starts with portable `vkmtl.diagnostics.QuerySet`
objects. Timestamp queries can be written from blit, compute, and render
encoders. An occlusion set must be bound when the render pass is created, and
begin/end must use that exact borrowed set:

```zig
var visibility = try device.makeQuerySet(.{
    .query_type = .occlusion,
    .count = 2,
});
defer visibility.deinit();

var render_encoder = try command_buffer.makeRenderCommandEncoder(.{
    .color_attachments = color_attachments,
    .occlusion_query_set = &visibility,
});
try render_encoder.beginOcclusionQuery(&visibility, 0);
// Encode the measured draws.
try render_encoder.endOcclusionQuery(&visibility);
```

Occlusion values are Boolean visibility: zero means no samples passed and any
nonzero value means visible. The magnitude is not a portable sample count.
Each slot can be written once between resets. The set must remain alive until
the synchronously completing command-buffer commit returns, and a resolve
destination must have `copy_destination` usage. Query ranges, result alignment,
same-device ownership, association, and availability are validated. Native
backend failures are distinct from `QueryNotReady`; pipeline statistics remain
typed unsupported.

Commit the producer before recording a separate resolve command buffer. The
current resolve path preflights native readiness and returns `QueryNotReady`
instead of recording a wait for work that has not been submitted.

Timestamp fallback values are deterministic logical sequence numbers;
`native_gpu` values are raw backend-native ticks. Call `resultSource()` before
interpreting them. The current API exposes no tick calibration, so even native
tick deltas must not be treated as durations.

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
`rgba8_unorm_srgb`; copies still reject channel-order changes and MSAA
textures. Copy descriptors now carry `TextureAspect`: `depth32_float` supports
explicit `.depth` copies and buffer readback, while packed depth/stencil copies
are capability-gated per aspect. An omitted `.all` resolves to color or depth
for single-aspect formats and is rejected for packed depth/stencil buffer
layouts. Runtime validation applies
`DeviceLimits.buffer_texture_copy_offset_alignment` and
`buffer_texture_copy_row_pitch_alignment` before backend encoding.

Scaled copies use the separate `BlitCommandEncoder.blitTexture(...)` path and
`vkmtl.transfer.BlitTextureDescriptor`. Vulkan lowers supported formats to
`vkCmdBlitImage`; Metal currently returns `UnsupportedTextureBlit`. Linear
filtering additionally requires the source format's linear-filter capability.
The canonical command error type is `vkmtl.command.CommandEncodingError`.
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
Texture state is tracked per mip and array layer and shared by views of the same
texture. `Texture.subresourceUsage(mip, layer)` exposes the portable tracked
state; Vulkan layouts and Metal encoder/resource state remain backend-private.
Partial explicit barriers validate the complete range transactionally.

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
backend path. Resolution uses ceiling division, so a non-divisible logical grid
launches extra invocations in the final threadgroup; the shader must bounds-check
against the requested logical thread count.

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
`DeviceLimits.max_compute_threadgroup_memory_bytes`. The executable portable
atomic subset is 32-bit integer storage-buffer and threadgroup add/min/max,
bitwise, exchange, and compare-exchange operations. Storage-texture and wider
atomic families are not implied. vkmtl does not infer requirements from Slang
source yet; the compute readback example proves the supported atomic/shared
memory path with deterministic GPU output.

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
`vkmtl.diagnostics.objectCacheDiagnostics(device)`.
`vkmtl.diagnostics.runtimeDiagnostics(device)` returns the
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
`vkmtl.diagnostics.planDriverPipelineCache(device, descriptor)` validates against native feature reports
and returns `DriverPipelineCachePlan`, including whether the path already exists
and whether shutdown should store a new blob. Supplying that descriptor as a
render/compute pipeline's `driver_cache` makes creation consume and update a
native Vulkan pipeline cache or Metal binary archive. Identity mismatch,
missing, or invalid native data falls back to an empty cache; read-only mode
never writes.

Pipeline artifact compatibility is represented by
`PipelineArtifactManifestDescriptor` and `PipelineArtifactCachePlanDescriptor`.
`vkmtl.diagnostics.planPipelineArtifactCache(device, descriptor)` classifies cache entries as compatible,
missing, stale schema, backend mismatch, shader hash mismatch, entry point
mismatch, reflection mismatch, format mismatch, or toolchain mismatch. This is
the portable invalidation contract for generated SPIR-V, MSL, and reflection
artifacts. Native pipeline-library breadth remains separate from the now
executable `VkPipelineCache` / `MTLBinaryArchive` persistence path.

## Stability Diagnostics

`vkmtl.diagnostics.StabilityRunDescriptor` describes opt-in long-run checks without forcing them
into default tests. It can plan resource churn, presentation resize/recreate
cycles, shader-cache warm/cold cycles, upload/readback cycles, and Vulkan
unaligned `fillBuffer(...)` fallback checks:

```zig
const plan = try vkmtl.diagnostics.StabilityRunDescriptor{
    .iterations = 120,
}.plan();

const diagnostics = vkmtl.diagnostics.StabilityRunDiagnostics.fromPlan(plan);
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

Descriptor and `setLabel(...)` labels are borrowed by runtime wrappers and are
synchronized to native object labels when the backend supports it. The caller
must keep the backing bytes alive and unchanged until the object is destroyed,
the label is replaced, or `setLabel(null)` clears it. The portable wrapper does
not allocate or copy label bytes. Labels must be valid UTF-8 without embedded
NUL bytes; object setters remain infallible for compatibility and do not
forward invalid encoding to native tools.

Capture-friendly names can be built with
`vkmtl.diagnostics.CaptureNameDescriptor` and
`vkmtl.diagnostics.writeCaptureName(device, descriptor, buffer)`. If the
descriptor omits `backend`, the helper fills in the selected backend:

```zig
var name_buffer: [96]u8 = undefined;
const capture_name = try vkmtl.diagnostics.writeCaptureName(device, .{
    .scope = "frame",
    .name = "main-pass",
    .frame_index = frame_index,
}, name_buffer[0..]);
```

Debug groups and signposts borrow their labels only for the call and validate
them portably. Empty labels, invalid UTF-8 or embedded NUL, underflow, overflow,
invalid scope state, and unclosed groups become `CommandEncodingError` values.
`vkmtl.command.DebugSignpostDescriptor` is the shape-only marker descriptor, and command
buffers plus render/blit/compute encoders expose `insertDebugSignpost(...)`.
Command-buffer groups may surround complete encoders, but command-buffer group
push/pop and signposts are only valid while no encoder is active. Encoder groups
are local to one encoder and must close before `endEncoding()`; command-buffer
groups must close before `commit()`.
Metal command-buffer and encoder markers lower to Metal debug APIs. Vulkan
render/blit/compute encoder markers lower to `EXT_debug_utils` while the command
buffer is recording. Vulkan command-buffer-level markers remain portable
validation only because vkmtl allows them before an encoder exists, while native
Vulkan markers require a recording command buffer.

`vkmtl.diagnostics.debugMarkerCapabilities(device)` reports each lane as
`native`, `validation_only`, or `unavailable`, so tooling does not have to infer
native visibility from the selected backend.

## Capture, Profiling, And Issue Reports

Metal capture is available through
`vkmtl.diagnostics.beginCaptureScope(&device, descriptor)`. The returned
`CaptureScope` borrows its label and backend owner, supports explicit `end()`,
and must finish before `WindowContext` is destroyed. The current destination is
Apple developer tools. Vulkan reports `UnsupportedCapture`; capture-manager
startup failures report `CaptureFailed`.

Timestamp `vkmtl.diagnostics.QuerySet` values may be deterministic command-order
sequences or raw native GPU ticks. Inspect `QuerySet.resultSource()` before
interpreting a value. Native ticks are exposed only when the selected backend's
complete query lane is executable, but vkmtl does not yet expose calibration,
so a tick delta is not a duration. Use
`vkmtl.diagnostics.planProfiling(device, descriptor)` to select native raw-tick,
CPU wall-clock fallback, or marker-only mode. Requiring native GPU timestamps
returns `UnsupportedGpuTimestamps` when the complete native lane is unavailable.

`vkmtl.diagnostics.issueReport(device, descriptor)` bundles backend and adapter
identity, exact error/category, usable and native features, limits, marker/
capture/profiling capabilities, and runtime diagnostics. The snapshot borrows
its strings. See `docs/usage/en_us/diagnostics.md` for the recommended issue
bundle and commands.

## Error Classification

vkmtl keeps precise Zig error names. Applications that need broader handling can
call:

```zig
const category = vkmtl.diagnostics.classifyError(err);
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
`vkmtl.native.CommandInsertionDescriptor`. The descriptor validates the feature gate,
callback, and encoder kind before invoking user code. Backends keep the feature
disabled until real command-buffer / command-encoder native handle views are
available.

The native-advanced closure inventory is internal planning data rather than a
supported public API.

`vkmtl.diagnostics.BackendParitySemanticsDescriptor`,
`BackendParitySemanticsPlan`, and
`vkmtl.diagnostics.planBackendParitySemantics(device, descriptor)` expose current parity decisions for
partial mip/layer ranges, depth/stencil and MSAA copies, custom sampler border
colors, and opt-in GPU soak planning. Depth/stencil copies are now reported as
capability-gated; ordinary MSAA copies remain typed unsupported.
