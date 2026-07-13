# Public API Migration Map

Status: implemented Phase 0 allocation for the completed pre-tag breaking
migration.

This document records the concrete decisions required by Phase 0 of
`api-migration-roadmap.md`. It is the implementation checklist for the current
breaking migration, while `public-api-inventory.md` remains the measured source
snapshot.

## Final Root Set

The final root target is 68 declarations: 13 namespace facades, 27 portable
core declarations, and 28 approved common aliases.

### Namespace Facades: 13

```text
binding
command
compute
diagnostics
interop
native
presentation
ray_tracing
render
resource
shader
sync
transfer
```

### Portable Core: 27

```text
BackendPreference
Backend
AdapterDeviceType
AdapterPowerPreference
AdapterInfo
AdapterSelectionDescriptor
AdapterList
BackendAvailability
BackendSelectionOptions
BackendSelectionError
Extent2D
selectBackend
enumerateAdapters
WindowContext
WindowContextOptions
Buffer
MappedBufferRange
Texture
TextureView
SamplerState
ShaderModule
RenderPipelineState
ComputePipelineState
Device
Queue
Surface
Swapchain
```

The prototype-only `Context`, `ContextOptions`, and opaque `Adapter` declarations
are not retained. `WindowContext`, adapter enumeration/selection, and the
runtime owners supersede them.

### Common Root Aliases: 28

These names remain convenient root aliases but also have canonical namespace
paths:

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

No other flat alias is retained without a later root-admission decision.

## Canonical Namespace Corrections

The original line-range inventory is corrected as follows:

- `ProgrammableStageDescriptor` belongs to `shader`.
- resource access, usage, hazard, and transition records belong to `sync`.
- debug label, group, and signpost records belong to `command`.
- `PipelineError` belongs to `render`.
- texture upload, replace-region, mipmap, and their resolved records belong to
  `transfer`.
- `VulkanSurfaceProvider` belongs to `native.vulkan` even though the portable
  surface source carries it as an explicit escape hatch.
- sparse descriptors, mapping, and residency plans belong to `resource`, while
  `Sparse*Lowering{Mode}` and `planSparse*Lowering` belong to `native` because
  they select a backend implementation;
- `RayQueryPlan` is portable query-planning output and does not expose a
  lowering field or public lowering-mode enum;
- backend tessellation, mesh, and ray tracing lowering records belong to
  `native.vulkan` or `native.metal`.
- runtime render-pass attachment descriptors, not the older core shapes, are
  the canonical `render` declarations.

`ShaderReflection` becomes `shader.Reflection`; it is not retained at root.

## Native Name Map

Common native declarations move under `native` with the redundant prefix
removed:

| Old root | Canonical path |
| --- | --- |
| `NativeHandles` | `native.Handles` |
| `NativeHandleLifetime` | `native.HandleLifetime` |
| `NativeHandleView` | `native.HandleView` |
| `nativeHandleView` | `native.handleView` |
| `NativeCommandEncoderKind` | `native.CommandEncoderKind` |
| `NativeCommandInsertionPoint` | `native.CommandInsertionPoint` |
| `NativeCommandCallback` | `native.CommandCallback` |
| `NativeCommandInsertionDescriptor` | `native.CommandInsertionDescriptor` |
| `SparseBufferLoweringMode` | `native.SparseBufferLoweringMode` |
| `SparseBufferLowering` | `native.SparseBufferLowering` |
| `SparseTextureLoweringMode` | `native.SparseTextureLoweringMode` |
| `SparseTextureLowering` | `native.SparseTextureLowering` |

The two sparse lowering operations follow those result types:

```text
resource.planSparseBufferLowering  -> native.planSparseBufferLowering
resource.planSparseTextureLowering -> native.planSparseTextureLowering
```

Backend declarations move under the matching backend namespace and also drop
the backend prefix. Examples include:

```text
VulkanNativeHandles -> native.vulkan.Handles
VulkanSurfaceProvider -> native.vulkan.SurfaceProvider
VulkanTessellationDrawLowering -> native.vulkan.TessellationDrawLowering
VulkanMeshDispatchLowering -> native.vulkan.MeshDispatchLowering
VulkanRayTracingPipelineLowering -> native.vulkan.RayTracingPipelineLowering
MetalNativeHandles -> native.metal.Handles
MetalTessellationDrawLowering -> native.metal.TessellationDrawLowering
MetalMeshDispatchLowering -> native.metal.MeshDispatchLowering
MetalIntersectionFunctionDescriptor -> native.metal.IntersectionFunctionDescriptor
MetalRayTracingMappingDescriptor -> native.metal.RayTracingMappingDescriptor
MetalRayTracingExecutionMapping -> native.metal.RayTracingExecutionMapping
```

## Explicit Internalization

The following declarations have no supported application consumer and are not
re-exported through a canonical facade:

- `Context`, `ContextOptions`, and opaque `Adapter`;
- `NativeAdvancedClosureFeature`, `native_advanced_closure_features`,
  `nativeAdvancedClosureTarget`, `nativeAdvancedClosureHasPublicRuntimeContract`,
  `NativeAdvancedClosureDescriptor`, and `NativeAdvancedClosurePlan`;
- `BindGroupResourceDescriptor`, `BindGroupEntryDescriptor`,
  `BindGroupDescriptorShape`, `BindGroupShapeResource`, `BindGroupShapeEntry`,
  and `BindGroupShapeDescriptor`;
- `ClearColorLike` as a public alias; callers use `ClearColor`;
- `RayQueryLoweringMode`; callers consume the portable fields of
  `ray_tracing.RayQueryPlan`, while backend lowering remains internal;
- neutral backend-union lowering planners used only to select an implementation
  record;
- native driver-cache validation scaffolding used only by the runtime planner.

The underlying implementation declarations may remain in internal modules for
tests and backend work. Internal presence is not public reachability.

## Runtime Handle Representation Decision

All 36 guarded exported runtime handles are methods-only wrappers with exactly
one field named `_state`. Value-owned handles store their implementation as inline opaque
bytes. Heap-owned or borrowed views use `*anyopaque`; specifically,
`WindowContext` owns the runtime allocation and `Device`, `Surface`, and
`Swapchain` borrow views into it. Queue, command, resource, pipeline, binding,
synchronization, interop, and ray tracing wrappers retain value-oriented usage
without exposing their state record.

No public handle field may name or structurally expose `BackendRuntime`, an
`Impl` union, `ResourceTracker`, a debug record, or any other private state.
Direct field mutation and struct-literal construction are unsupported; callers
use factories and public methods. The API guard treats the 36-name runtime
handle list, the single `_state` field, and its opaque-storage form as an exact
allowlist.

`SurfaceSource.vulkan` is separately approved as the only native callback
exception inside presentation integration. Its canonical callback type is
`native.vulkan.SurfaceProvider`; this decision does not allow other native
fields in portable descriptors.

## Device Owner Decision

`Device` keeps natural device ownership and the smallest common query surface:

```text
selectedBackend
adapterInfo
features
nativeFeatures
limits
capabilityReport
getFormatCaps
makeAccelerationStructure
makeRayTracingPipelineState
makeShaderBindingTable
makeFence
makeEvent
makeQuerySet
makeHeap
queue
queueWithDescriptor
compileRenderShader
compileComputeShader
compileRayTracingShader
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

This reduces `Device` from 108 to 34 public methods. Specialized validation,
planning, diagnostics, and backend mapping become domain facade operations that
take a `Device` value or pointer explicitly.

The canonical operation groups are:

- `binding`: descriptor-indexing validation and resource-table pressure;
- `resource`: portable sparse validation/residency planning and transient
  allocation diagnostics;
- `interop`: external descriptor validation, import/usage planning,
  diagnostics, and capability matrices;
- `render`: portable tessellation and mesh validation/planning;
- `ray_tracing`: acceleration-structure, pipeline, SBT, dispatch, query, and
  stress validation/planning;
- `diagnostics`: cache, parity, object-cache, runtime, memory-budget, and
  capture-name plans;
- `command`: queue capability and selection planning;
- `sync`: synchronization capability queries;
- `presentation`: present-mode queries and surface collections;
- `native`: native command validation and sparse backend lowering;
- `native.vulkan` and `native.metal`: explicit backend lowering operations.

The final migrated-operation allocation is six operations under `resource`,
three under `native`, and 60 under the other listed facades, for the unchanged
total of 69 operations removed from `Device` and given canonical facade owners.

`planNativeAdvancedClosure`, neutral lowering selectors, and native
driver-cache validation remain internal.

## WindowContext Owner Decision

`WindowContext` keeps exactly these ten methods:

```text
init
deinit
selectedBackend
adapterInfo
nativeHandles
nativeHandleView
device
queue
surface
swapchain
```

The other 46 compatibility forwards are removed. Their replacements already
exist on `Device`, `Queue`, `Surface`, `Swapchain`, or a canonical facade.
In-tree examples and tools do not use the forwards; runtime tests and user-facing
API documentation must be updated during the migration.

## Breaking Cutover Rule

The facade additions, caller migration, owner convergence, and root cleanup are
reviewed as separate implementation slices, but this pre-tag effort has one
intentional compatibility boundary. No removed name is restored as a second
long-lived alias merely to reduce the size of the diff.
