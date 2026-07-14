# Pre-Tag API Migration Guide

This guide updates callers from the prototype flat API to the intentional
Period 1 Phase 9 surface. The cutover is breaking because vkmtl has not yet made
a tagged compatibility promise. It reorganizes names and owners without
intentionally changing backend behavior.

## Post-Tag Additive Headless Owner

`HeadlessContext` is an additive `v0.1.x` root declaration and requires no
migration for existing callers. New no-window code may replace window setup
with `HeadlessContext.init(...)` and continue using the same borrowed `Device`
and `Queue` API. It intentionally has no `Surface`, `Swapchain`, current
drawable, presentation method, or presentation-shaped native-handle view.

Existing `WindowContext` source and behavior are unchanged.

## Period 52 v0.2.0 Ray Tracing Maintenance Update

Existing callers need no source change. New maintenance code supplies
`vkmtl.ray_tracing.AccelerationStructureMaintenanceResources` to
`CommandBuffer.encodeAccelerationStructureMaintenance(...)`:

```zig
try command_buffer.encodeAccelerationStructureMaintenance(refit_plan, .{
    .source = &acceleration_structure,
    .scratch = &scratch_buffer,
});
```

Compaction uses a distinct `.destination` and no scratch resource. Create
update/refit sources with `AccelerationStructureDescriptor.allow_update = true`.
Build a compactable source with
`AccelerationStructureBuildFlags.allow_compaction = true`.
Keep the source's build-input buffers and TLAS instance-source AS objects alive
through every update/refit submission that reuses them.
`AccelerationStructureBuildPlan.allow_update` and
`AccelerationStructureMaintenancePlan.scratch_alignment` are additive fields.

Basic RT/AS execution now appears in `Device.features()` when complete on the
selected backend. Do not infer executable ray query, callable SBT, or Metal
custom intersection from `nativeFeatures()`: those native/planning facts remain
closed until the shader artifact, binding, and native table/record paths are
complete.

## Period 51 v0.2.0 Advanced Geometry Update

Schema version 2 adds `tessellation_shaders` and `mesh_shaders` while schema 1
remains accepted. Resolve advanced artifacts with
`vkmtl.shader.compileTessellationShader(...)` or
`vkmtl.shader.compileMeshShader(...)`, create the pipeline through
`vkmtl.render.makeTessellationPipelineState(...)` or
`vkmtl.render.makeMeshPipelineState(...)`, and encode through the corresponding
render-encoder draw method. No new `Device` factory or flat-root alias is
added.

Existing callers need no source change. Callers that adopt the new enums,
descriptors, methods, limits, or schema fields target `v0.2.0`. Query usable
features before creation: Metal tessellation is unsupported under the current
Slang artifact contract, and `task_shaders` remains false because the pinned
compiler cannot stably produce task/object artifacts. Mesh and tessellation
advanced stages are currently resource-free; `ShaderVisibility` has not yet
admitted their binding stages. Mesh layouts may use fragment-only visibility;
other visibility returns `UnsupportedMeshShaderBindings` before backend work.

## Period 50 v0.2.0 Binding, Indirect Command, And Driver Cache Update

Render and compute pipeline descriptors now accept
`resource_table_layouts` and `driver_cache`. Both fields default to empty/null,
so ordinary callers need no change. A resource table must be bound at the
absolute pipeline-layout index after ordinary bind-group layouts and must match
the descriptor used to create that pipeline; mismatches now return
`ResourceTablePipelineLayoutMismatch` before backend work.

Create reusable CPU-authored command lists through the canonical command
facade:

```zig
var commands = try vkmtl.command.makeIndirectCommandBuffer(&device, .{
    .kind = .render,
    .max_command_count = 1,
});
defer commands.deinit();
try commands.encodeDrawPrimitives(0, .{ .vertex_count = 3 });
try encoder.executeIndirectCommands(&commands, .{ .count = 1 });
```

The list inherits the active encoder's pipeline and resources. It does not
permit shader/GPU mutation of command slots. Metal uses a native ICB when the
device exposes it; Vulkan and native-unavailable paths expand the immutable
commands exactly.

To persist driver artifacts, set a backend-matching
`diagnostics.DriverPipelineCacheDescriptor` in `driver_cache`. Vulkan consumes
and updates `VkPipelineCache`; Metal consumes, populates, and serializes
`MTLBinaryArchive`. Identity mismatches and invalid native data fall back to an
empty cache. `read_only = true` prevents writes.

The new command handle/types/methods, feature/limit fields, pipeline fields,
and binding/command errors target `v0.2.0`. Exhaustive switches over
`BindingError` or `CommandEncodingError` need corresponding arms.

## Period 49 v0.2.0 Heap And Memoryless Update

`Device.makeHeap(...)` now creates native placement storage when `heaps` is
reported. Query `heap.bufferAllocationRequirements(...)` or
`heap.textureAllocationRequirements(...)`, reserve that exact shape, then pass
the returned allocation to `makeBufferAt(...)` or `makeTextureAt(...)`.
Heap-backed resources must be destroyed before the heap;
`liveResourceCount()` exposes the current child count.

`ResourceStorageMode.memoryless` requests a hardware memoryless render
attachment. It is non-CPU-visible, must have one mip, and may not be sampled,
stored, or copied. A memoryless pass cannot load prior contents or store its
attachment; multisample resolve remains valid with `.store_action =
.dont_care`. Metal exposes this lane when a native probe succeeds. Vulkan
returns `UnsupportedMemorylessStorage` because lazily allocated memory cannot
guarantee the same allocation behavior.

Native memory-budget reports replace caller estimates with device/driver budget
and current usage. Sparse/tiled lowering and residency maps remain planning
only; their usable feature fields stay false until a resource-bound native
commit contract exists.

These enum, feature, method, and error-set additions target `v0.2.0`.
Exhaustive switches over `ResourceStorageMode`, `BufferError`, `TextureError`,
or `HeapError` need corresponding new arms.

## Period 48 v0.2.0 Synchronization And Presentation Update

`timeline_fences` now means a native monotonic object with host query,
host wait/signal, and GPU submission wait/signal. Vulkan lowers it to a
timeline semaphore; Metal lowers it to `MTLSharedEvent`. Binary fences and
ordinary events retain their exact runtime fallback behavior. `shared_events`
is native on Metal and does not imply external-handle sharing.

`CommandBufferDescriptor` adds nullable `lifecycle_callback` and
`lifecycle_context` fields. Existing literals retain their behavior. When the
callback is present, the selected device must report
`command_buffer_lifecycle_callbacks`; scheduled and completed notifications are
delivered exactly once during the current synchronous commit path. Callers must
not assume callback thread identity or reentrant command-buffer use.

`CommandBuffer.presentDrawableWithDescriptor(...)` accepts
`presentation.PresentDrawableDescriptor`. Immediate presentation is the
default. Scheduled-time and minimum-duration modes require a nonzero
nanosecond value and their matching feature. Setting
`allow_immediate_fallback = true` explicitly permits immediate presentation on
an unsupported backend. `presentDrawable()` remains the unchanged immediate
convenience path.

This update adds command/presentation enum and error-set members and targets
`v0.2.0`. Exhaustive `CommandEncodingError` switches must handle
`UnsupportedCommandBufferLifecycleCallbacks`,
`UnsupportedScheduledPresentation`,
`UnsupportedMinimumDurationPresentation`, `InvalidPresentationTiming`, and
`SynchronizationBackendFailure`.

## Period 46 v0.2.0 Query Update

Existing render-pass literals continue to compile because
`RenderPassDescriptor.occlusion_query_set` defaults to null. Callers that use
occlusion queries must now create the set first, bind its pointer in the pass
descriptor, and pass the same pointer to encoder begin/end calls. This replaces
the former unusable placeholder lane with native zero/nonzero visibility.

`QueryError` adds `QueryBackendFailure` for the newly executable native
readback path. Ordinary `try`/propagation code needs no change; exhaustive
switches need one new arm, so this update targets `v0.2.0` rather than a
`v0.1.x` patch. Invalid pass/query association uses the existing
`InvalidRenderCommandEncoderState`. Timestamp callers must continue to
inspect `QuerySet.resultSource()`: `native_gpu` now means raw native ticks, not
a calibrated duration. Shader specialization descriptors use the same stable
numeric ID on Vulkan and Metal; optional names do not control native lookup.

## Period 47 v0.2.0 Resource-Limit And Sampler Update

`DeviceLimits` adds maximum buffer length, 1D/2D/3D texture dimensions, and
texture array-layer limits. `Device.makeBuffer(...)` and
`Device.makeTexture(...)` now reject descriptors beyond those selected-device
limits with `BufferLengthExceedsDeviceLimit` and
`TextureExtentExceedsDeviceLimit`.

`SamplerDescriptor.normalized_coordinates` defaults to `true`, so existing
literals keep their behavior. For unnormalized texel coordinates, set it to
`false` and also use equal min/mag filters, `not_mipmapped`, clamp-to-edge on
all axes, both LOD clamps at zero, no comparison, unit anisotropy, and no border
color. Invalid combinations return `InvalidUnnormalizedCoordinates`.

These additions target `v0.2.0`: ordinary `try` propagation is unchanged, but
exhaustive switches over `BufferError`, `TextureError`, or `SamplerError` need
one new arm each.

Texture views may now reinterpret `rgba8_unorm` with `rgba8_unorm_srgb`, or
`bgra8_unorm` with `bgra8_unorm_srgb`. Other cross-format pairs remain typed
unsupported. `TextureViewDescriptor.component_mapping` defaults to identity;
use `vkmtl.resource.TextureComponentMapping` for explicit zero/one/R/G/B/A
swizzles. Exhaustive `TextureError` switches also need an
`UnsupportedTextureViewComponentMapping` arm.

`TextureFormat` and `VertexFormat` now contain the finite common set listed in
`period47/phase2.md`. Existing enum values retain their meaning, but exhaustive
switches must add arms for normalized/integer/floating-point texture formats,
depth16/stencil8, half vertex inputs, normalized 8-bit vertex inputs, and
signed/unsigned 32-bit vertex inputs. Use `Device.getFormatCaps(...)` for every
new texture format; enum presence does not override the selected device's
native capability result.

To request a shader-visible address, first check
`device.features().buffer_gpu_address`, create the buffer with
`usage.shader_device_address = true`, then call `buffer.gpuAddress()`.
Addresses are process/device-lifetime values, not portable serialized handles.
Exhaustive `BufferError` switches must add `UnsupportedBufferGpuAddress`,
`BufferMissingGpuAddressUsage`, and `BufferGpuAddressUnavailable`.

Private texture CPU uploads now return `TextureNotCpuVisible` on both backends.
Use a copy-source staging buffer and a transfer encoder for private textures.
Automatic, shared, and managed modes retain their documented CPU upload path.

Texture-backed render attachments now honor every color attachment and native
load/store actions. Combined depth/stencil requires the depth and stencil
descriptors to reference the same depth-stencil view. Current-drawable passes
continue to require color clear/store and depth clear/dont-care; other actions
return `UnsupportedRenderPassAttachmentAction`. Add that arm to exhaustive
`RuntimeError` switches.

`ShaderReflectionBinding.storage_access` now carries `.read`, `.write`, or
`.read_write` through schema-1 reflection and derived layouts. Existing values
default exactly as before. Pipeline validation can now return
`ShaderReflectionBindingAccessMismatch`; exhaustive `ShaderError` switches need
that v0.2.0 arm.

The existing `compute_atomics` and `compute_threadgroup_memory` fields now open
only for the executable 32-bit integer storage-buffer/threadgroup subset and
queried shared-memory limit. Do not infer storage-texture or 64-bit atomics.
`dispatchThreads` uses ceiling division, so shaders must reject extra final
threadgroup invocations when the logical count is not divisible.

Managed buffers require no new API. Existing `replaceBytes`, map/unmap, and
`readBytes` boundaries automatically compose Metal managed synchronization and
Vulkan host-coherent visibility.

## Migration Rules

Apply these rules in order:

1. Keep using the approved common root names listed in
   `public-api-inventory.md`.
2. For an advanced flat type, add its canonical domain prefix:
   `vkmtl.Name` becomes `vkmtl.domain.Name`.
3. Replace `vkmtl.ShaderReflection` with `vkmtl.shader.Reflection`.
4. Move backend-specific names under `vkmtl.native.vulkan` or
   `vkmtl.native.metal`, then remove the redundant backend prefix. Move
   backend-selected neutral lowering records and operations under
   `vkmtl.native`.
5. Replace specialized `device.method(args)` calls with
   `vkmtl.domain.method(device, args)`.
6. Replace removed `WindowContext` convenience methods with the natural owner
   or domain facade.
7. Replace runtime-handle struct literals or implementation-field access with
   the documented factory and methods for that handle.

Facade operations use the former receiver as their first argument. Former
value-receiver methods therefore usually migrate mechanically:

```zig
const lowering = try device.planSparseTextureLowering(descriptor);
```

becomes:

```zig
const lowering = try vkmtl.native.planSparseTextureLowering(device, descriptor);
```

The Metal RT execution mapping factory is the pointer-receiver exception:

```zig
var mapping = try vkmtl.native.metal.makeRayTracingExecutionMapping(
    &device,
    descriptor,
);
```

## Root Type Migration

Most removed flat names keep the same final component under a domain. Important
mappings used by examples and common advanced paths are:

| Old path | Canonical path |
| --- | --- |
| `vkmtl.ShaderReflection` | `vkmtl.shader.Reflection` |
| `vkmtl.AdvancedBindingModel` | `vkmtl.binding.AdvancedBindingModel` |
| `vkmtl.DescriptorIndexingRange` | `vkmtl.binding.DescriptorIndexingRange` |
| `vkmtl.Size3D` | `vkmtl.resource.Size3D` |
| `vkmtl.SparseResidencyMap` | `vkmtl.resource.SparseResidencyMap` |
| `vkmtl.SparseTextureKind` | `vkmtl.resource.SparseTextureKind` |
| `vkmtl.SparseBufferMappingDescriptor` | `vkmtl.resource.SparseBufferMappingDescriptor` |
| `vkmtl.SparseBufferLoweringMode` | `vkmtl.native.SparseBufferLoweringMode` |
| `vkmtl.SparseBufferLowering` | `vkmtl.native.SparseBufferLowering` |
| `vkmtl.SparseTextureLoweringMode` | `vkmtl.native.SparseTextureLoweringMode` |
| `vkmtl.SparseTextureLowering` | `vkmtl.native.SparseTextureLowering` |
| `vkmtl.SurfaceCollection` | `vkmtl.presentation.SurfaceCollection` |
| `vkmtl.SurfaceInfo` | `vkmtl.presentation.SurfaceInfo` |
| `vkmtl.RayTracingCapabilityDiagnostics` | `vkmtl.diagnostics.RayTracingCapabilityDiagnostics` |
| `vkmtl.ExternalHandleKind` | `vkmtl.interop.ExternalHandleKind` |
| `vkmtl.ExternalTextureDescriptor` | `vkmtl.interop.ExternalTextureDescriptor` |
| `vkmtl.TessellationDescriptor` | `vkmtl.render.TessellationDescriptor` |
| `vkmtl.TessellationPatchDrawDescriptor` | `vkmtl.render.TessellationPatchDrawDescriptor` |
| `vkmtl.MeshPipelineDescriptor` | `vkmtl.render.MeshPipelineDescriptor` |
| `vkmtl.MeshDispatchDescriptor` | `vkmtl.render.MeshDispatchDescriptor` |
| `vkmtl.AccelerationStructureBuildDescriptor` | `vkmtl.ray_tracing.AccelerationStructureBuildDescriptor` |
| `vkmtl.AccelerationStructureGeometryDescriptor` | `vkmtl.ray_tracing.AccelerationStructureGeometryDescriptor` |
| `vkmtl.AccelerationStructureGeometryResources` | `vkmtl.ray_tracing.AccelerationStructureGeometryResources` |
| `vkmtl.RayTracingPipelineDescriptor` | `vkmtl.ray_tracing.RayTracingPipelineDescriptor` |
| `vkmtl.RayTracingShaderGroupDescriptor` | `vkmtl.ray_tracing.RayTracingShaderGroupDescriptor` |
| `vkmtl.ShaderBindingTableDescriptor` | `vkmtl.ray_tracing.ShaderBindingTableDescriptor` |
| `vkmtl.VulkanSurfaceProvider` | `vkmtl.native.vulkan.SurfaceProvider` |
| `vkmtl.MetalIntersectionFunctionDescriptor` | `vkmtl.native.metal.IntersectionFunctionDescriptor` |

The following common names intentionally remain available at root:

```text
DeviceFeatures
DeviceLimits
SurfaceProvider
SurfaceSource
SurfaceDescriptor
PresentMode
PresentationDescriptor
FormatCapabilities
TextureFormat
BufferUsage
ResourceStorageMode
TextureUsage
BufferDescriptor
TextureDescriptor
TextureViewDescriptor
SamplerDescriptor
ShaderModuleDescriptor
ProgrammableStageDescriptor
VertexDescriptor
RenderPipelineColorAttachmentDescriptor
RenderPipelineDescriptor
RenderPassDescriptor
ClearColor
ComputePipelineDescriptor
BindGroupLayoutDescriptor
BindGroupDescriptor
BindGroupEntry
CommandBufferDescriptor
```

New code may use their canonical facade paths when that improves clarity, but
the root aliases are approved rather than temporary compatibility names.

## Native Short-Name Migration

Entering a backend namespace removes the redundant backend prefix:

| Old flat path | New native path |
| --- | --- |
| `VulkanNativeHandles` | `native.vulkan.Handles` |
| `MetalNativeHandles` | `native.metal.Handles` |
| `NativeHandles` | `native.Handles` |
| `NativeHandleLifetime` | `native.HandleLifetime` |
| `NativeHandleView` | `native.HandleView` |
| `nativeHandleView` | `native.handleView` |
| `NativeCommandEncoderKind` | `native.CommandEncoderKind` |
| `NativeCommandInsertionPoint` | `native.CommandInsertionPoint` |
| `NativeCommandCallback` | `native.CommandCallback` |
| `NativeCommandInsertionDescriptor` | `native.CommandInsertionDescriptor` |
| `resource.SparseBufferLoweringMode` | `native.SparseBufferLoweringMode` |
| `resource.SparseBufferLowering` | `native.SparseBufferLowering` |
| `resource.SparseTextureLoweringMode` | `native.SparseTextureLoweringMode` |
| `resource.SparseTextureLowering` | `native.SparseTextureLowering` |
| `VulkanSurfaceProvider` | `native.vulkan.SurfaceProvider` |
| `VulkanTessellationLowering` | `native.vulkan.TessellationLowering` |
| `VulkanTessellationDrawLowering` | `native.vulkan.TessellationDrawLowering` |
| `VulkanMeshPipelineLowering` | `native.vulkan.MeshPipelineLowering` |
| `VulkanMeshDispatchLowering` | `native.vulkan.MeshDispatchLowering` |
| `VulkanRayTracingPipelineLowering` | `native.vulkan.RayTracingPipelineLowering` |
| `MetalTessellationLowering` | `native.metal.TessellationLowering` |
| `MetalTessellationFactorBufferOwnership` | `native.metal.TessellationFactorBufferOwnership` |
| `MetalTessellationDrawLowering` | `native.metal.TessellationDrawLowering` |
| `MetalMeshPipelineLowering` | `native.metal.MeshPipelineLowering` |
| `MetalMeshDispatchLowering` | `native.metal.MeshDispatchLowering` |
| `MetalIntersectionFunctionDescriptor` | `native.metal.IntersectionFunctionDescriptor` |
| `MetalRayTracingLowering` | `native.metal.RayTracingLowering` |
| `MetalRayTracingMappingDescriptor` | `native.metal.RayTracingMappingDescriptor` |
| `MetalRayTracingMappingPlan` | `native.metal.RayTracingMappingPlan` |
| `MetalRayTracingExecutionMapping` | `native.metal.RayTracingExecutionMapping` |

Neutral lowering unions live under `native.TessellationLowering`,
`native.MeshPipelineLowering`, and `native.RayTracingPipelineLowering`. Sparse
lowering results and their planners also live directly under `native`:

```text
resource.planSparseBufferLowering  -> native.planSparseBufferLowering
resource.planSparseTextureLowering -> native.planSparseTextureLowering
```

`SurfaceSource.vulkan` remains supported with the canonical callback type
`native.vulkan.SurfaceProvider`. It is the sole approved native callback
exception in presentation integration, not a general license to add native
fields to portable descriptors.

Backend planning operations are shortened in the same way:

```text
Device.planVulkanTessellationPatchDraw -> native.vulkan.planTessellationPatchDraw
Device.planVulkanMeshDispatch          -> native.vulkan.planMeshDispatch
Device.planMetalTessellationPatchDraw  -> native.metal.planTessellationPatchDraw
Device.planMetalMeshDispatch           -> native.metal.planMeshDispatch
Device.planMetalRayTracingMapping      -> native.metal.planRayTracingMapping
Device.makeMetalRayTracingExecutionMapping
                                      -> native.metal.makeRayTracingExecutionMapping
```

## WindowContext Migration

`WindowContext` now owns only lifecycle, identity, native-view, and owner
access. Its 46 former forwards have the following replacements.

### Use Device Directly: 23

```text
queueWithDescriptor
compileRenderShader
compileComputeShader
compileRayTracingShader
makeFence
makeEvent
makeQuerySet
makeHeap
makeBuffer
makeShaderModule
makeRenderPipelineState
makeComputePipelineState
makeBindGroupLayout
makeAdvancedBindGroupLayout
makeResourceTable
makeBindGroup
makeTexture
makeExternalMemory
makeExternalBuffer
makeExternalSemaphore
makeExternalEvent
makeExternalTexture
makeSamplerState
```

For example:

```zig
const device = context.device();
var buffer = try device.makeBuffer(descriptor);
```

### Use Queue Or Swapchain: 4

```text
WindowContext.makeCommandBuffer               -> Queue.makeCommandBuffer
WindowContext.makeCommandBufferWithDescriptor -> Queue.makeCommandBufferWithDescriptor
WindowContext.resize                          -> Swapchain.resize
WindowContext.clear                           -> Swapchain.clear
```

### Use Facade Operations: 19

| Former WindowContext method | Replacement |
| --- | --- |
| `objectCacheDiagnostics` | `diagnostics.objectCacheDiagnostics(device)` |
| `runtimeDiagnostics` | `diagnostics.runtimeDiagnostics(device)` |
| `writeCaptureName` | `diagnostics.writeCaptureName(device, ...)` |
| `planDriverPipelineCache` | `diagnostics.planDriverPipelineCache(device, ...)` |
| `planRuntimeCache` | `diagnostics.planRuntimeCache(device, ...)` |
| `planPipelineArtifactCache` | `diagnostics.planPipelineArtifactCache(device, ...)` |
| `memoryBudgetReport` | `diagnostics.memoryBudgetReport(device, ...)` |
| `planAccelerationStructureMaintenance` | `ray_tracing.planAccelerationStructureMaintenance(device, ...)` |
| `planTopLevelAccelerationStructureLayout` | `ray_tracing.planTopLevelAccelerationStructureLayout(device, ...)` |
| `planRayQuery` | `ray_tracing.planRayQuery(device, ...)` |
| `planComplexShaderBindingTable` | `ray_tracing.planComplexShaderBindingTable(device, ...)` |
| `planRayTracingStress` | `ray_tracing.planRayTracingStress(device, ...)` |
| `queueCapabilities` | `command.queueCapabilities(device)` |
| `syncCapabilities` | `sync.syncCapabilities(device)` |
| `presentModeSupport` | `presentation.presentModeSupport(device)` |
| `resolvePresentMode` | `presentation.resolvePresentMode(device, ...)` |
| `makeSurfaceCollection` | `presentation.makeSurfaceCollection(device)` |
| `transientAllocationDiagnostics` | `resource.transientAllocationDiagnostics(device, ...)` |
| `planResourceTablePressure` | `binding.planResourceTablePressure(device, ...)` |

## Device Method Migration

`Device` keeps 34 common query, creation, compilation, and queue methods. Of the
74 methods removed from the owner, 69 became facade free functions:

### Binding: 2

```text
validateDescriptorIndexingLayout
planResourceTablePressure
```

### Resource: 6

```text
validateSparseMappingCommit
planSparseMappingCommit
planSparseResidencyChurn
validateSparseBufferDescriptor
validateSparseTextureDescriptor
transientAllocationDiagnostics
```

### Interop: 21

```text
validateExternalTextureDescriptor
validateExternalMemoryDescriptor
validateExternalBufferDescriptor
validateExternalSemaphoreDescriptor
validateExternalEventDescriptor
planExternalMemoryImportForPlatform
planExternalBufferImportForPlatform
planExternalTextureImportForPlatform
planExternalTextureUsageForPlatform
planExternalSemaphoreImportForPlatform
planExternalEventImportForPlatform
diagnoseExternalInteropImportForPlatform
planExternalMemoryImport
planExternalBufferImport
planExternalTextureImport
planExternalTextureUsage
planExternalSemaphoreImport
planExternalEventImport
diagnoseExternalInteropImport
externalInteropCapabilityMatrix
externalInteropCapabilityMatrixForPlatform
```

### Render: 6

```text
validateTessellationDescriptor
validateTessellationPatchDrawDescriptor
planTessellationPatchDraw
validateMeshPipelineDescriptor
validateMeshDispatchDescriptor
planMeshDispatch
```

### Ray Tracing: 10

```text
validateAccelerationStructureDescriptor
planAccelerationStructureBuild
planAccelerationStructureMaintenance
planTopLevelAccelerationStructureLayout
validateRayTracingPipelineDescriptor
validateShaderBindingTableDescriptor
planComplexShaderBindingTable
planRayDispatch
planRayQuery
planRayTracingStress
```

### Diagnostics: 9

```text
validateDriverPipelineCacheDescriptor
planDriverPipelineCache
planRuntimeCache
planPipelineArtifactCache
planBackendParitySemantics
objectCacheDiagnostics
runtimeDiagnostics
writeCaptureName
memoryBudgetReport
```

### Command, Sync, And Presentation: 6

```text
command.queueCapabilities
command.planQueue
sync.syncCapabilities
presentation.presentModeSupport
presentation.resolvePresentMode
presentation.makeSurfaceCollection
```

### Native: 9

```text
native.validateCommandInsertionDescriptor
native.planSparseBufferLowering
native.planSparseTextureLowering
native.vulkan.planTessellationPatchDraw
native.vulkan.planMeshDispatch
native.metal.planTessellationPatchDraw
native.metal.planMeshDispatch
native.metal.planRayTracingMapping
native.metal.makeRayTracingExecutionMapping
```

This redistribution changes the `resource` and `native` subtotals but preserves
the 69 facade operations migrated from `Device`.

## Removed Without A Supported Replacement

The following Device planning or validation methods were prototype inspection
or duplicated internal validation and have no public free-function replacement:

```text
planTessellationLowering
planMeshPipelineLowering
planRayTracingPipelineLowering
validateNativeDriverPipelineCacheDescriptor
planNativeAdvancedClosure
```

`ray_tracing.RayQueryLoweringMode` also has no supported replacement.
`ray_tracing.RayQueryPlan` no longer contains a `lowering` field; consume its
`backend`, shader-stage, depth, and requirement fields instead. The concrete
query lowering decision is internal.

The following debug and roadmap records also have no supported replacement:

```text
NativeAdvancedClosureFeature
native_advanced_closure_features
nativeAdvancedClosureTarget
nativeAdvancedClosureHasPublicRuntimeContract
NativeAdvancedClosureDescriptor
NativeAdvancedClosurePlan
CommandBufferDebugState
RenderCommandEncoderDebugState
BlitCommandEncoderDebugState
ComputeCommandEncoderDebugState
```

Other removed compatibility names have conceptual replacements:

```text
ContextOptions -> WindowContextOptions
Context        -> WindowContext
Adapter        -> AdapterInfo and WindowContext.adapterInfo()
ClearColorLike -> ClearColor or render.ClearColor
BindGroupResourceDescriptor -> binding.BindGroupResource
BindGroupEntryDescriptor    -> binding.BindGroupEntry
BindGroupDescriptorShape    -> binding.BindGroupDescriptor
BindGroupShapeResource      -> binding.BindGroupResource
BindGroupShapeEntry         -> binding.BindGroupEntry
BindGroupShapeDescriptor    -> binding.BindGroupDescriptor
```

These mappings describe the supported public route. They do not assert that
the underlying core declarations were physically deleted.

## Runtime Handle Layout Migration

Runtime objects are no longer application-constructible implementation
records. Each of the 36 guarded exported handles now has exactly one `_state`
field containing inline opaque bytes or an opaque runtime pointer. Backend
unions,
`BackendRuntime`, `Impl`, `ResourceTracker`, descriptor/debug records, and
private state records are no longer reachable through handle fields.

Existing code that already used the supported pattern remains unchanged:

```zig
const device = context.device();
var buffer = try device.makeBuffer(descriptor);
defer buffer.deinit();

const backend = buffer.selectedBackend();
```

Code that initialized a handle with a struct literal, read or wrote its former
implementation fields, or directly manipulates `_state` has no layout-level
replacement. Use the relevant `Device`, `Queue`, `Surface`, or `Swapchain`
factory and the handle's public query, mutation, and `deinit` methods. The
`_state` field is deliberately unsupported application API, regardless of
whether Zig permits spelling its name.

`WindowContext` owns the heap runtime state. `Device`, `Surface`, and
`Swapchain` are borrowed opaque views; retaining one beyond its context remains
invalid. Other runtime handles preserve their existing value-oriented call
syntax with inline opaque state. This cutover changes source-visible layout,
not the documented destruction order or backend behavior.

## Before And After Examples

Shader reflection:

```zig
// Before
var layouts = try vkmtl.ShaderReflection.deriveRenderPipelineBindGroupLayouts(
    allocator,
    vertex,
    fragment,
);

// After
var layouts = try vkmtl.shader.Reflection.deriveRenderPipelineBindGroupLayouts(
    allocator,
    vertex,
    fragment,
);
```

Ray tracing planning:

```zig
// Before
const plan = try device.planAccelerationStructureBuild(descriptor);

// After
const plan = try vkmtl.ray_tracing.planAccelerationStructureBuild(
    device,
    descriptor,
);
```

Platform interop:

```zig
// Before
const plan = try device.planExternalTextureUsage(descriptor);

// After
const plan = try vkmtl.interop.planExternalTextureUsage(device, descriptor);
```

Backend-specific tessellation:

```zig
// Before
const lowering = try device.planVulkanTessellationPatchDraw(descriptor);

// After
const lowering = try vkmtl.native.vulkan.planTessellationPatchDraw(
    device,
    descriptor,
);
```

## Validation

After migrating a caller, run:

```sh
zig fmt --check build.zig src examples tools
zig build run-api-guard
zig build test --summary all
zig build
git diff --check
```

For repository-wide API checks:

```sh
zig build run-api-guard

rg -n 'vkmtl\.(ShaderReflection|Vulkan[A-Z]|Metal[A-Z])' \
  examples docs/api docs/usage README.md
```

The final search should produce no supported usage of removed flat paths.
Historical phase documents may intentionally preserve old names as a record of
the implementation sequence.
