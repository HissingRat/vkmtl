# Public API Inventory

Status: `v0.1.x` compatibility baseline plus additive headless owner, refreshed
on 2026-07-14.

This document records the public surface reachable through `src/vkmtl.zig`
after the Period 1 Phase 9 compatibility cutover. It is the source snapshot for
the first intentional compatibility surface; `public-api-rules.md` remains the
authoritative admission policy and `api-migration-guide.md` records how callers
move from the prototype surface.

The cutover is intentionally breaking. It changes public reachability and
method ownership, not backend behavior. Some declarations below the public
module remain declared `pub` in `src/core.zig` or implementation modules so
vkmtl internals can share them. An internal declaration is not public library
API unless it is reachable through `src/vkmtl.zig` or one of its facades.

## Counting Rules And Measured Baseline

Root declarations are counted with:

```sh
rg -c '^pub const ' src/vkmtl.zig
```

The result is 69:

- 13 domain facade entry points;
- 28 portable root declarations;
- 28 approved common aliases whose canonical definitions remain in facades.

Runtime public functions are counted independently because methods on exported
objects are also API:

```sh
rg -c '^[ ]*pub fn ' src/runtime/window_context.zig
rg -c '^[ ]*pub fn ' src/runtime/headless_context.zig
```

The current results are 445 in `window_context.zig` and six in
`headless_context.zig`. The former is 17 module-level operations and 428
methods; six module-level declarations are private cross-file context-owner
plumbing and are not reachable through `vkmtl`. Facade operations may be
`pub const` aliases or direct `pub fn` declarations and are counted separately
below.

The context and device owner surfaces now measure:

```text
Device           34 public methods
WindowContext    10 public methods
HeadlessContext   6 public methods
```

## Package And Shader Build Contract

The package exports one supported module named `vkmtl`. Repository example
support modules, tools, and tests are not consumer module exports. Package
specific build options are not part of the 69-name Zig root count, but they are
part of the release compatibility surface:

| Dependency option | Type | Contract |
| --- | --- | --- |
| `shader_manifest` | source-backed `std.Build.LazyPath` | consumer manifest; defaults to the repository `shaders/manifest.json` |
| `slangc` | string path | explicit build-time compiler for a host without a pinned Slang package |

Schema version 1 remains accepted. Schema version 2 retains its arrays and
adds the advanced geometry arrays below:

| Array | Entry fields |
| --- | --- |
| `render_shaders` | `name`, `source`, `vertex_entry`, `fragment_entry` |
| `compute_shaders` | `name`, `source`, `entry` |
| `ray_tracing_shaders` | `name`, `source`, `metal_ray_generation_source`, `ray_generation_entry`, `miss_entry`, `closest_hit_entry`, `any_hit_entry`, `intersection_entry` |
| `tessellation_shaders` | `name`, `source`, `vertex_entry`, `control_entry`, `evaluation_entry`, `fragment_entry` |
| `mesh_shaders` | `name`, `source`, `mesh_entry`, optional `task_entry`, `fragment_entry` |

Names are unique across every array and use lowercase portable
`[a-z0-9_.-]+`; `.` and `..` are rejected. Shader source paths are relative to
the manifest and must remain inside the LazyPath owner's logical root. Generated
manifests are not supported by either schema. The build tracks the manifest,
every declared Slang and Metal source, and Slang include/import dependencies
reported through depfiles. `b.path(...)` retains its build root as owner; a
scalar command-line path uses the `zig build` invocation directory as its root.
Absolute, drive-relative, UNC, and backslash paths are rejected. The build
generates the embedded SPIR-V/MSL/reflection module and never moves shader
compilation or cache writes into runtime.

## Complete Root Name Set

The following sets are explicit and replace the former source-line allocation.
No declaration outside these sets may be added to the flat root without a new
root-admission decision.

### Domain Facades: 13

```text
resource
transfer
render
sync
presentation
diagnostics
command
shader
binding
compute
ray_tracing
interop
native
```

`native.vulkan` and `native.metal` are nested under `native`; they are not
additional root declarations.

### Portable Root: 28

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
HeadlessContext
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

These names are common owners, backend selection concepts, or ordinary runtime
objects. The prototype `Context`, `ContextOptions`, and opaque `Adapter` are not
part of the final root.

### Approved Common Aliases: 28

These names remain at root for the quick-start path, but the listed facade is
their canonical definition and must preserve exact type identity.

| Canonical facade | Root aliases |
| --- | --- |
| `diagnostics` | `DeviceFeatures`, `DeviceLimits` |
| `presentation` | `SurfaceProvider`, `SurfaceSource`, `SurfaceDescriptor`, `PresentMode`, `PresentationTimingMode`, `PresentDrawableDescriptor`, `PresentationDescriptor` |
| `resource` | `FormatCapabilities`, `TextureFormat`, `BufferUsage`, `ResourceStorageMode`, `TextureUsage`, `BufferDescriptor`, `TextureDescriptor`, `TextureViewDescriptor`, `SamplerDescriptor` |
| `shader` | `ShaderModuleDescriptor`, `ProgrammableStageDescriptor` |
| `render` | `VertexDescriptor`, `RenderPipelineColorAttachmentDescriptor`, `RenderPipelineDescriptor`, `RenderPassDescriptor`, `ClearColor` |
| `compute` | `ComputePipelineDescriptor` |
| `binding` | `BindGroupLayoutDescriptor`, `BindGroupDescriptor`, `BindGroupEntry` |
| `command` | `CommandBufferDescriptor`, `CommandBufferLifecycleStatus`, `CommandBufferLifecycleCallback` |

## Canonical Facade Inventory

The declaration count is the number of `pub const` entries in the facade file.
The operation count is the subset that aliases callable functions; module and
data constants are excluded. Counts are not intended to be summed into a
unique-type total because facades intentionally share type identity with root
aliases and with types used by other domains.

| Facade file | Declarations | Operations | Primary ownership |
| --- | ---: | ---: | --- |
| `api/resource.zig` | 77 | 19 | formats, buffers, textures, samplers, heaps, portable sparse resources, transient allocation |
| `api/transfer.zig` | 19 | 0 | copy, fill, upload, blit, mipmap, and resolved transfer descriptors |
| `api/render.zig` | 67 | 8 | pipeline, pass, draw, tessellation, and mesh rendering |
| `api/sync.zig` | 31 | 1 | usage transitions, barriers, fences, events, queues, synchronization capabilities |
| `api/presentation.zig` | 21 | 4 | surfaces, present modes, timed drawable presentation, frame pacing, surface collections |
| `api/diagnostics.zig` | 80 | 16 | capabilities, cache/stability plans, profiling, capture, reports, memory budgets |
| `api/command.zig` | 23 | 3 | command lifecycle callbacks, reusable indirect command lists, encoders, labels, queue capability and selection planning |
| `api/shader.zig` | 39 | 4 | source, reflection, specialization, compiler inputs and results |
| `api/binding.zig` | 41 | 2 | layouts, bind groups, resource tables, offsets, constants |
| `api/compute.zig` | 8 | 0 | compute pipeline and dispatch descriptors, atomics, threadgroup memory |
| `api/ray_tracing.zig` | 54 | 11 | acceleration structures, RT pipelines, SBTs, dispatch, queries, stress plans |
| `api/interop.zig` | 49 | 21 | external resource contracts, platform import planning and diagnostics |
| `api/native.zig` | 20 | 4 | neutral native handles, insertion, sparse lowering, and backend-lowering escape hatches |

The nested native modules are measured separately:

| Native facade | Declarations | Operations |
| --- | ---: | ---: |
| `api/native/vulkan.zig` | 9 | 2 |
| `api/native/metal.zig` | 15 | 4 |

Across the 13 top-level facades, this is 526 declarations and 92 callable
operation aliases. Moving sparse lowering from `resource` to `native` changes
the ownership distribution without changing the operation total;
removing the public `RayQueryLoweringMode` removes one type declaration.

Semantic corrections applied during the migration include:

- programmable stages are canonical under `shader`, not `render`;
- resource usage state and hazards are canonical under `sync`;
- command label/group/signpost data is canonical under `command`;
- `PipelineError` is canonical under `render`;
- replace-region, upload, and mipmap descriptors are canonical under
  `transfer`;
- bind-group and resource-table encoder bindings are canonical under
  `binding`;
- `VulkanSurfaceProvider` moved to the explicit native Vulkan facade;
- portable sparse descriptors and residency work remain under `resource`, but
  backend-selected sparse lowering records and operations moved to `native`;
- `RayQueryPlan` no longer exposes a backend lowering mode;
- runtime render-pass descriptors use the runtime object-bearing shapes, not
  the earlier core-only planning shapes.

Post-baseline capability truth corrections preserve the declaration surface:

- `occlusion_queries` remains a public `DeviceFeatures` field. Period 46 makes
  it usable only when the selected backend can create, encode, reset, read, and
  resolve real zero/nonzero visibility results. `native_features` remains the
  raw adapter fact and may be true when an additional executable-path gate is
  missing.

Compile-time facade assertions in `src/vkmtl.zig` lock the sparse lowering
ownership and reject a reintroduced `ray_tracing.RayQueryLoweringMode` route.

## Native Namespace Shape

Backend prefixes are unnecessary after entering an explicit backend namespace.
The canonical native names are:

```text
native.Handles
native.HandleLifetime
native.HandleView
native.CommandEncoderKind
native.CommandInsertionPoint
native.CommandCallback
native.CommandInsertionDescriptor
native.TessellationLowering
native.MeshPipelineLowering
native.RayTracingPipelineLowering
native.SparseBufferLoweringMode
native.SparseBufferLowering
native.SparseTextureLoweringMode
native.SparseTextureLowering
native.handleView
native.validateCommandInsertionDescriptor
native.planSparseBufferLowering
native.planSparseTextureLowering

native.vulkan.Handles
native.vulkan.SurfaceProvider
native.vulkan.TessellationLowering
native.vulkan.TessellationDrawLowering
native.vulkan.MeshPipelineLowering
native.vulkan.MeshDispatchLowering
native.vulkan.RayTracingPipelineLowering
native.vulkan.planTessellationPatchDraw
native.vulkan.planMeshDispatch

native.metal.Handles
native.metal.TessellationLowering
native.metal.TessellationFactorBufferOwnership
native.metal.TessellationDrawLowering
native.metal.MeshPipelineLowering
native.metal.MeshDispatchLowering
native.metal.IntersectionFunctionDescriptor
native.metal.RayTracingLowering
native.metal.RayTracingMappingDescriptor
native.metal.RayTracingMappingPlan
native.metal.RayTracingExecutionMapping
native.metal.planTessellationPatchDraw
native.metal.planMeshDispatch
native.metal.planRayTracingMapping
native.metal.makeRayTracingExecutionMapping
```

`SurfaceSource.vulkan` still carries the Vulkan surface callback shape. It is
the only approved native callback exception in presentation integration and is
named through `native.vulkan`. The callback record uses opaque values rather
than raw Vulkan binding types; it is not precedent for another backend field in
a portable descriptor.

## Internalized Compatibility And Prototype Names

The following 20 root names are no longer reachable through `vkmtl`. Their
underlying implementation declarations may remain in non-public modules; this
list records public reachability, not physical source deletion.

### Prototype Owners: 3

```text
ContextOptions
Context
Adapter
```

### Native Closure Roadmap Scaffolding: 6

```text
NativeAdvancedClosureFeature
native_advanced_closure_features
nativeAdvancedClosureTarget
nativeAdvancedClosureHasPublicRuntimeContract
NativeAdvancedClosureDescriptor
NativeAdvancedClosurePlan
```

### Shape Compatibility Aliases: 6

```text
BindGroupResourceDescriptor
BindGroupEntryDescriptor
BindGroupDescriptorShape
BindGroupShapeResource
BindGroupShapeEntry
BindGroupShapeDescriptor
```

### Superseded Color And Debug Records: 5

```text
ClearColorLike
CommandBufferDebugState
RenderCommandEncoderDebugState
BlitCommandEncoderDebugState
ComputeCommandEncoderDebugState
```

Users should use `WindowContext`, `WindowContextOptions`, `AdapterInfo`, the
canonical `binding` runtime shapes, and `render.ClearColor`. The debug-state
records and native-closure roadmap inventory have no supported replacement.

`ray_tracing.RayQueryLoweringMode` was also removed from its former facade
path. `RayQueryPlan` retains the portable backend, shader-stage, depth, and
requirement fields but no longer exposes `lowering`. There is no replacement
public lowering-mode enum; backend selection stays internal to query planning.

## Runtime Handle Representation

All 37 guarded exported runtime handles now expose one implementation-storage
field named `_state` and no other field. Value-owned resources, pipelines, binding
objects, synchronization objects, command buffers, encoders, queues, and
similar wrappers use inline opaque byte storage. `WindowContext` and
`HeadlessContext` own a heap-allocated runtime state, while `Device`, `Surface`,
and `Swapchain` expose borrowed `*anyopaque` views into it.

Consequently, the public field graph no longer reaches `BackendRuntime`, a
backend `Impl` union, `ResourceTracker`, debug state, or a private state record.
Construction, queries, mutation, and destruction go through documented public
methods. Direct struct literals and reads or writes of `_state` are unsupported
even though Zig can spell the field name. `zig build run-api-guard` locks the
37-name handle set and this single-field representation alongside the root and
owner-method allowlists.

## Runtime Owner Inventory

The current major runtime owner counts are:

| Owner | Public methods | Direction |
| --- | ---: | --- |
| `Device` | 34 | creation, compilation, common queries, and queue access |
| `WindowContext` | 10 | lifecycle, identity, native-view, and owner access only |
| `HeadlessContext` | 6 | no-presentation lifecycle, identity, device, and queue access |
| `RenderCommandEncoder` | 31 | natural render command owner |
| `ComputeCommandEncoder` | 21 | natural compute command owner |
| `BlitCommandEncoder` | 21 | natural transfer command owner |
| `CommandBuffer` | 19 | lifecycle, encoder creation, and RT maintenance encoding |
| `Texture` | 19 | resource lifetime and texture operations |
| `TextureView` | 18 | view lifetime and queries |
| `AccelerationStructure` | 17 | capability-gated RT owner and maintenance evidence |
| `Buffer` | 15 | mapping, read, write, GPU address, and lifetime |
| `ShaderBindingTable` | 13 | capability-gated RT owner |
| `ResourceTable` | 13 | advanced binding owner |
| `IndirectCommandBuffer` | 11 | reusable CPU-authored draw/dispatch command-list owner |

### Device: 34 Retained Methods

Queries:

```text
selectedBackend
adapterInfo
features
nativeFeatures
limits
capabilityReport
getFormatCaps
```

Creation:

```text
makeAccelerationStructure
makeRayTracingPipelineState
makeShaderBindingTable
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

Compilation and queue access:

```text
compileRenderShader
compileComputeShader
compileRayTracingShader
queue
queueWithDescriptor
```

The other 74 former methods left `Device`: 69 are facade free functions and
five implementation/planning methods were removed from the supported surface.

| Canonical facade | Migrated Device operations | Count |
| --- | --- | ---: |
| `binding` | descriptor-indexing validation, resource-table pressure planning | 2 |
| `resource` | portable sparse validation/residency planning and transient-allocation diagnostics | 6 |
| `interop` | all external validation, platform and selected-platform planning, import diagnostics, capability matrices | 21 |
| `render` | portable tessellation and mesh validation/draw or dispatch planning | 6 |
| `ray_tracing` | acceleration-structure, pipeline, SBT, dispatch, query, and stress validation/planning | 10 |
| `diagnostics` | driver/runtime/artifact cache planning, parity planning, cache/runtime snapshots, capture naming, memory budget | 9 |
| `command` | queue capabilities and queue planning | 2 |
| `sync` | synchronization capabilities | 1 |
| `presentation` | present-mode support/resolution and surface collections | 3 |
| `native` | native command insertion validation and sparse backend lowering | 3 |
| `native.vulkan` | Vulkan tessellation and mesh planning | 2 |
| `native.metal` | Metal tessellation, mesh, RT mapping planning and RT mapping creation | 4 |
| **Total facade operations** |  | **69** |

The five removed Device methods are:

```text
planTessellationLowering
planMeshPipelineLowering
planRayTracingPipelineLowering
validateNativeDriverPipelineCacheDescriptor
planNativeAdvancedClosure
```

### WindowContext: 10 Retained Methods

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

Its former 46 creation, compilation, queue, swapchain, diagnostics, and planning
forwards were removed. Their final replacements are natural `Device`, `Queue`,
or `Swapchain` methods, or the facade operations summarized above and detailed
in `api-migration-guide.md`.

## Example Regression Set

Examples currently reference 26 distinct first-level `vkmtl` names. This is the
source regression set after migration:

```text
AdapterInfo
Backend
BindGroupEntry
BindGroupLayoutDescriptor
Device
Extent2D
PresentMode
PresentationDescriptor
ProgrammableStageDescriptor
Queue
RenderPipelineColorAttachmentDescriptor
RenderPipelineDescriptor
SurfaceDescriptor
Texture
TextureView
VertexDescriptor
WindowContext
binding
diagnostics
interop
native
presentation
ray_tracing
render
resource
shader
```

Advanced examples now use canonical nested paths, including
`shader.Reflection`, `ray_tracing.*`, `interop.*`, `render.*`,
`resource.*`, `native.vulkan.*`, and `native.metal.*`. Example use remains
regression evidence, not automatic root-admission justification.

## Period 46 v0.2.0 Query Update

Period 46 leaves the guarded counts unchanged: root 68, `Device` 34 methods,
`WindowContext` 10 methods, and 35 opaque runtime handles. It adds no facade
declaration, root alias, common-owner method, or runtime handle field.

The existing canonical `render.RenderPassDescriptor` gains one defaulted field:

```zig
occlusion_query_set: ?*diagnostics.QuerySet = null
```

The default preserves every existing render-pass literal. A non-null set is a
borrowed same-device occlusion set that must remain alive through synchronous
command-buffer completion; render-encoder occlusion commands must use that
exact set. This association is necessary because Metal chooses visibility
storage when the pass encoder is created.

`diagnostics.QueryError` gains `QueryBackendFailure` for the newly executable
native-readback lane, keeping driver failures distinct from `QueryNotReady`.
Invalid pass/query association reuses
`command.CommandEncodingError.InvalidRenderCommandEncoderState`. Ordinary
error propagation is unchanged, but callers with exhaustive `QueryError`
switches need one new arm.

The descriptor field is source-additive, but expanding the public error set is
a source break for exhaustive switches. Period 46 therefore targets `v0.2.0`
and is not eligible for a `v0.1.x` patch release.

Capability meaning changes with the executable path: `occlusion_queries`
means native zero/nonzero visibility, `timestamp_queries` may still use a
logical sequence fallback, `QuerySet.resultSource()` distinguishes native raw
GPU ticks from that fallback, and `shader_specialization` means both Vulkan and
Metal lower stable numeric specialization IDs. Pipeline statistics and GPU
timestamp-to-duration calibration remain closed.

## Period 47 v0.2.0 Resource-Limit And Sampler Update

This Period 47 slice leaves the guarded root, `Device`, `WindowContext`, and
opaque-handle counts unchanged. Existing canonical types gain these fields:

```text
DeviceLimits.max_buffer_length
DeviceLimits.max_texture_dimension_1d
DeviceLimits.max_texture_dimension_2d
DeviceLimits.max_texture_dimension_3d
DeviceLimits.max_texture_array_layers
SamplerDescriptor.normalized_coordinates
TextureViewDescriptor.component_mapping
```

The sampler field defaults to `true`. Setting it to `false` requests native
unnormalized coordinates and is accepted only with equal min/mag filters, no
mip filter, clamp-to-edge addressing, zero LOD clamps, no comparison, unit
anisotropy, and no explicit border color. `BufferError`, `TextureError`, and
`SamplerError` respectively gain `BufferLengthExceedsDeviceLimit`,
`TextureExtentExceedsDeviceLimit`, and `InvalidUnnormalizedCoordinates`.
The `resource` facade also adds `TextureComponent`,
`TextureComponentMapping`, and `textureViewFormatsCompatible`; `TextureError`
adds `UnsupportedTextureViewComponentMapping`.

`resource.TextureFormat` gains `r8_unorm`, `rg8_unorm`, `rgba8_uint`,
`rgba8_sint`, `r16_float`, `rg16_float`, `rgba16_float`, `r32_float`,
`rg32_float`, `rgba32_float`, `r32_uint`, `r32_sint`, `depth16_unorm`, and
`stencil8`. `render.VertexFormat` gains `float16x2`, `float16x4`, normalized
8-bit x2/x4, and signed/unsigned 32-bit scalar/x2/x3/x4 tags. These are enum
expansions inside existing canonical domains; no root alias or owner method is
added.

`diagnostics.DeviceFeatures` gains `buffer_gpu_address`, and
`resource.BufferUsage` gains `shader_device_address`. A buffer created with
that usage can call the new `Buffer.gpuAddress()` method; missing capability,
missing usage, or an unavailable zero native address returns a distinct
`BufferError`. `TextureError` gains `TextureNotCpuVisible` so private CPU
uploads fail consistently before backend access. `Buffer` now has 15 public
methods; its opaque one-field layout is unchanged.

`diagnostics.RuntimeError` gains `UnsupportedRenderPassAttachmentAction` for
non-default actions on the prebuilt current-drawable pass. Texture-backed MRT
and combined depth/stencil actions remain within existing render descriptors;
no root, `Device`, `WindowContext`, or handle method is added.

`shader.ShaderReflectionBinding` gains optional `storage_access`. Null keeps
the existing defaults (`read_write` for storage buffers and `write` for storage
textures); reflected fixed arrays continue to use `array_count`.
`ShaderError` gains `ShaderReflectionBindingAccessMismatch`. The existing
`compute_atomics` and `compute_threadgroup_memory` feature fields now mean the
executable 32-bit integer storage-buffer/threadgroup and shared-memory subset,
bounded by `max_compute_threadgroup_memory_bytes`.

Managed synchronization remains inside existing buffer methods and adds no
public command: Metal synchronizes managed GPU writes before CPU maps/reads and
publishes CPU writes after writes/unmap; Vulkan uses host-coherent managed
buffers. `dispatchThreads` remains an existing method with clarified
ceil-composition and shader bounds responsibility.

The additions belong to the existing canonical domains and
receive no new root aliases or owner methods. Field and error-set growth targets
`v0.2.0`; callers with exhaustive error switches must add arms.

## Period 48 v0.2.0 Synchronization And Presentation Update

Period 48 leaves the guarded root 68, `Device` 34, `WindowContext` 10, and 35
opaque-handle baselines unchanged. It adds two declarations to `command` and
two to `presentation`, bringing the top-level facade inventory to 512
declarations and 87 facade operations.

`command.CommandBufferLifecycleStatus` and
`CommandBufferLifecycleCallback` are canonical command declarations.
`CommandBufferDescriptor` gains nullable `lifecycle_callback` and
`lifecycle_context` fields. `CommandBuffer` gains `lifecycleStatus()` and
`presentDrawableWithDescriptor(...)`, bringing that handle to 15 public
methods without changing its opaque one-field representation.

`presentation.PresentationTimingMode` and `PresentDrawableDescriptor` are
canonical presentation declarations. `diagnostics.DeviceFeatures` gains
`command_buffer_lifecycle_callbacks`, `scheduled_presentation`, and
`minimum_duration_presentation`, for 90 fields total. The sync/queue feature
names retain their existing public allocation but now describe the complete
native execution paths documented in the semantic inventory.

`CommandEncodingError` gains
`UnsupportedCommandBufferLifecycleCallbacks`,
`UnsupportedScheduledPresentation`,
`UnsupportedMinimumDurationPresentation`, `InvalidPresentationTiming`, and
`SynchronizationBackendFailure`. These type, field, method, and error-set
additions target `v0.2.0`; defaults preserve the existing immediate one-shot
command path.

## Period 49 v0.2.0 Heap And Memoryless Update

Period 49 leaves the guarded root 68, `Device` 34, `WindowContext` 10, and 35
runtime-handle names unchanged. No facade declaration or operation is added, so
the top-level facade inventory remains 512 declarations and 87 operations.

The existing `resource.Heap` handle changes its private representation from
inline opaque bytes to `*anyopaque`; neither representation is stable API. It
gains `bufferAllocationRequirements`, `textureAllocationRequirements`,
`makeBufferAt`, `makeTextureAt`, and `liveResourceCount`, bringing the handle to
16 public methods. Its child-resource lifetime is now executable: buffers and
textures created from a heap must be destroyed before the heap.

`resource.ResourceStorageMode` gains `.memoryless`, and
`diagnostics.DeviceFeatures` gains `memoryless_attachments`, bringing the
feature inventory to 91 fields. `BufferError` and `TextureError` gain
`UnsupportedMemorylessStorage`; `TextureError` also gains
`InvalidMemorylessTexture`. `HeapError` gains `HeapAllocationTooSmall`,
`HeapAllocationNotReserved`, and `HeapResourceIncompatible`.

These enum, feature, method, lifetime, and error-set additions target `v0.2.0`.
Existing resource descriptors retain `.automatic` storage defaults.

## Period 50 v0.2.0 Binding, Indirect Command, And Driver Cache Update

Period 50 leaves the guarded root 68, `Device` 34, and `WindowContext` 10
baselines unchanged. The runtime-handle allowlist grows from 35 to 36 with the
canonical `command.IndirectCommandBuffer`; the handle has one opaque `_state`
field and 11 public methods.

The `command` facade gains `IndirectCommandKind`,
`IndirectCommandBufferDescriptor`, `IndirectCommandRange`,
`IndirectCommandBuffer`, and `makeIndirectCommandBuffer`, bringing that facade
to 23 declarations and three operations. Render and compute encoders each gain
`executeIndirectCommands(...)`, for 29 and 21 methods respectively. No new
`Device` factory or flat root alias is admitted.

`RenderPipelineDescriptor` and `ComputePipelineDescriptor` each gain defaulted
`resource_table_layouts` and `driver_cache` fields. The empty/null defaults
preserve ordinary pipeline literals. Resource-table layouts occupy pipeline
layout slots after ordinary bind-group layouts; runtime binding requires an
exact layout fingerprint match. `ResourceTablePipelineLayoutMismatch` records
violations before backend work.

`diagnostics.DeviceFeatures` gains `indirect_command_buffers`, bringing the
feature inventory to 92 fields. `DeviceLimits` gains
`max_indirect_command_count`. `CommandEncodingError` gains
`UnsupportedIndirectCommandBuffer`, `InvalidIndirectCommandKind`,
`InvalidIndirectCommandRange`, and `MissingIndirectCommand`.

These descriptor, feature, limit, handle, method, and error-set additions
target `v0.2.0`. CPU-authored command slots inherit active pipeline/resource
state. GPU-authored mutation, parallel child encoders, dynamic shader linking,
and runtime function stitching are not part of this allocation.

## Period 51 v0.2.0 Advanced Geometry Update

Period 51 leaves the guarded root 68, `Device` 34, `WindowContext` 10, and
36-handle allowlists unchanged. `render` gains
`TessellationRenderPipelineDescriptor`, `MeshRenderPipelineDescriptor`,
`makeTessellationPipelineState`, and `makeMeshPipelineState`; its declaration
and operation counts become 67 and eight. `RenderCommandEncoder` gains
`drawTessellationPatches(...)` and `drawMeshThreadgroups(...)`, bringing it to
31 public methods.

`shader` gains tessellation/mesh compile options, stage records, compiled
artifact owners, and two canonical compile functions, bringing it to 39
declarations and four operations. Shader manifest schema 2 adds
`tessellation_shaders` and `mesh_shaders`; schema 1 remains accepted without
behavior changes.

`DeviceLimits` gains mesh grid-axis limits in addition to the existing
tessellation and mesh/task thread limits. The existing `tessellation`,
`mesh_shaders`, and `task_shaders` feature fields now distinguish complete
execution from native query availability. The pinned compiler keeps usable
task/object support false, and Metal tessellation remains unsupported. The
advanced-stage binding visibility contract is also explicitly outside this
slice; `UnsupportedMeshShaderBindings` rejects non-fragment mesh-pipeline
layout visibility.

These additive descriptors, stage values, methods, feature meanings, limits,
and schema fields target `v0.2.0`. No `v0.1.x` declaration is removed or
renamed.

## Additive v0.1.x Headless Owner Update

`HeadlessContext` is admitted as the 28th portable root declaration because
backend-neutral GPU initialization without presentation is a common owner path
on both Metal and Vulkan. Its nested `Options` avoids allocating a second root
name. The six-method allowlist is exact:

```text
init
deinit
selectedBackend
adapterInfo
device
queue
```

The owner shares private runtime state, `Device`, `Queue`, resource, pipeline,
and command implementations with `WindowContext`. It adds no `Surface`,
`Swapchain`, current-drawable, present, `nativeHandles`, or `nativeHandleView`
route. The existing native-handle record is presentation-shaped, so returning
it would invent invalid sentinel semantics. A future device-only native escape
hatch requires a separate `native` allocation decision.

This update moves the current guard to root 69, `Device` 34,
`WindowContext` 10, `HeadlessContext` six, and 37 runtime handles. It is an
additive `v0.1.x` change: no existing root declaration, owner method, default,
or `WindowContext` behavior changes.

## Period 52 v0.2.0 Ray Tracing Maintenance Update

Period 52 leaves the guarded root, `Device`, `WindowContext`,
`HeadlessContext`, and runtime-handle name sets unchanged.
`ray_tracing.AccelerationStructureMaintenanceResources` is the one new facade
declaration, bringing that facade to 54 declarations and leaving its 11
operation aliases unchanged.

`CommandBuffer` gains
`encodeAccelerationStructureMaintenance(...)`, bringing it to 19 public
methods. `AccelerationStructure` gains maintenance count plus recorded/submitted
evidence queries, bringing it to 17 methods. The maintenance resource bundle
also owns a public validation method, so the total public functions in
`window_context.zig` become 445.

`AccelerationStructureBuildPlan.allow_update` preserves the native build flag
chosen by the AS descriptor or build flags.
`AccelerationStructureMaintenancePlan.scratch_alignment` preserves the
alignment used by public resource validation. Both are additive defaulted
fields; no existing field, enum tag, error, default, ownership rule, or method
is removed or renamed.

Callable/function-table/ray-query planning declarations remain reachable, but
execution factories use `features()` and keep those unsupported capability
bits false. This prevents a planning record or native query from becoming an
executable compatibility promise.

## Compatibility Impact

This is an intentional pre-tag breaking migration:

- unapproved flat aliases were removed;
- advanced types moved to domain or native namespaces;
- `ShaderReflection` moved to `shader.Reflection`;
- backend-prefixed native names became short names inside backend namespaces;
- sparse lowering records and operations moved from `resource` to `native`;
- `RayQueryPlan.lowering` and the public `RayQueryLoweringMode` were removed;
- 46 `WindowContext` forwards were removed;
- 74 specialized `Device` methods left the owner surface;
- prototype, compatibility-shape, debug-state, and roadmap-only names stopped
  being reachable through `vkmtl`;
- runtime objects stopped exposing their backend unions, trackers, descriptors,
  and debug/private records as directly mutable fields.

The migration does not claim that matching declarations vanished from
`src/core.zig`; it only removes their supported public route. Retained common
root aliases preserve exact type identity with their canonical facade types.
No backend execution, capability, descriptor-default, or lifetime semantics
were intentionally changed by this namespace and owner cutover. Code that used
runtime struct literals or implementation fields must move to public factories
and methods; there is intentionally no raw-layout compatibility layer.

The later `HeadlessContext` allocation is additive and does not reopen that
breaking cutover. Existing `WindowContext` callers require no migration.

## Verification Commands

```sh
zig build run-api-guard
# API guard passed: root=69 (facades=13 core=28 aliases=28),
# Device methods=34, WindowContext methods=10, HeadlessContext methods=6,
# runtime handles=37

awk '
  /^pub const Device = struct \{/ { active=1; next }
  /^pub const CaptureScope = struct \{/ { active=0 }
  active && /^    pub fn / { count++ }
  END { print count }
' src/runtime/window_context.zig
# 34

awk '
  /^pub const WindowContext = struct \{/ { active=1; next }
  active && /^    pub fn / { count++ }
  END { print count }
' src/runtime/window_context.zig
# 10

awk '
  /^pub const HeadlessContext = struct \{/ { active=1; next }
  active && /^    pub fn / { count++ }
  END { print count }
' src/runtime/headless_context.zig
# 6

for file in src/api/*.zig src/api/native/*.zig; do
  printf '%-38s ' "$file"
  rg -c '^pub const ' "$file"
done

zig fmt --check build.zig src examples tools tests/package_consumer
zig build run-api-guard
zig build test --summary all
zig build
zig build -Dvulkan
scripts/ci/run_package_smoke.sh
git diff --check
```

## Update Checklist

When the public surface changes:

- [ ] Assign each declaration one canonical lane and namespace.
- [ ] Record and justify any new flat root name.
- [ ] Recount the 69-name root and all changed facades.
- [ ] Recount affected runtime owner methods.
- [ ] Confirm every guarded runtime handle still has exactly one `_state`
  storage field and exposes no private implementation type.
- [ ] Update the example regression set.
- [ ] Update `api-migration-guide.md` for compatibility changes.
- [ ] Update the exact-name API guard after an approved allowlist change.
- [ ] Confirm public facades do not import backend-private bindings.
- [ ] Update the package/module and shader-manifest inventory when consumer
  build options or schema fields change.
- [ ] Run the validation required by `public-api-rules.md`.
