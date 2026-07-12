# Pre-Tag API Migration Guide

This guide updates callers from the prototype flat API to the intentional
Period 1 Phase 9 surface. The cutover is breaking because vkmtl has not yet made
a tagged compatibility promise. It reorganizes names and owners without
intentionally changing backend behavior.

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
records. Each of the 35 guarded exported handles now has exactly one `_state`
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
