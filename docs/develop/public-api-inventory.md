# Public API Inventory

Status: `v0.1.0` compatibility baseline, refreshed on 2026-07-11.

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

The result is 68:

- 13 domain facade entry points;
- 27 portable root declarations;
- 28 approved common aliases whose canonical definitions remain in facades.

Runtime public functions are counted independently because methods on exported
objects are also API:

```sh
rg -c '^[ ]*pub fn ' src/runtime/window_context.zig
```

The current result is 405: six module-level operations and 399 methods. Facade
free functions are declared as `pub const` aliases and therefore are not part
of that 405 count.

The two owner surfaces targeted by the migration now measure:

```text
Device         34 public methods
WindowContext  10 public methods
```

## Package And Shader Build Contract

The package exports one supported module named `vkmtl`. Repository example
support modules, tools, and tests are not consumer module exports. Package
specific build options are not part of the 68-name Zig root count, but they are
part of the release compatibility surface:

| Dependency option | Type | Contract |
| --- | --- | --- |
| `shader_manifest` | source-backed `std.Build.LazyPath` | consumer manifest; defaults to the repository `shaders/manifest.json` |
| `slangc` | string path | explicit build-time compiler for a host without a pinned Slang package |

The shader manifest uses schema version 1:

| Array | Entry fields |
| --- | --- |
| `render_shaders` | `name`, `source`, `vertex_entry`, `fragment_entry` |
| `compute_shaders` | `name`, `source`, `entry` |
| `ray_tracing_shaders` | `name`, `source`, `metal_ray_generation_source`, `ray_generation_entry`, `miss_entry`, `closest_hit_entry`, `any_hit_entry`, `intersection_entry` |

Names are unique across every array and use lowercase portable
`[a-z0-9_.-]+`; `.` and `..` are rejected. Shader source paths are relative to
the manifest and must remain inside the LazyPath owner's logical root. Generated
manifests are not supported by schema version 1. The build tracks the manifest,
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

### Portable Root: 27

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

These names are common owners, backend selection concepts, or ordinary runtime
objects. The prototype `Context`, `ContextOptions`, and opaque `Adapter` are not
part of the final root.

### Approved Common Aliases: 28

These names remain at root for the quick-start path, but the listed facade is
their canonical definition and must preserve exact type identity.

| Canonical facade | Root aliases |
| --- | --- |
| `diagnostics` | `DeviceFeatures`, `DeviceLimits` |
| `presentation` | `SurfaceProvider`, `SurfaceSource`, `SurfaceDescriptor`, `PresentMode`, `PresentationDescriptor` |
| `resource` | `FormatCapabilities`, `TextureFormat`, `BufferUsage`, `ResourceStorageMode`, `TextureUsage`, `BufferDescriptor`, `TextureDescriptor`, `TextureViewDescriptor`, `SamplerDescriptor` |
| `shader` | `ShaderModuleDescriptor`, `ProgrammableStageDescriptor` |
| `render` | `VertexDescriptor`, `RenderPipelineColorAttachmentDescriptor`, `RenderPipelineDescriptor`, `RenderPassDescriptor`, `ClearColor` |
| `compute` | `ComputePipelineDescriptor` |
| `binding` | `BindGroupLayoutDescriptor`, `BindGroupDescriptor`, `BindGroupEntry` |
| `command` | `CommandBufferDescriptor` |

## Canonical Facade Inventory

The declaration count is the number of `pub const` entries in the facade file.
The operation count is the subset that aliases callable functions; module and
data constants are excluded. Counts are not intended to be summed into a
unique-type total because facades intentionally share type identity with root
aliases and with types used by other domains.

| Facade file | Declarations | Operations | Primary ownership |
| --- | ---: | ---: | --- |
| `api/resource.zig` | 74 | 18 | formats, buffers, textures, samplers, heaps, portable sparse resources, transient allocation |
| `api/transfer.zig` | 19 | 0 | copy, fill, upload, blit, mipmap, and resolved transfer descriptors |
| `api/render.zig` | 65 | 6 | pipeline, pass, draw, tessellation, and mesh rendering |
| `api/sync.zig` | 31 | 1 | usage transitions, barriers, fences, events, queues, synchronization capabilities |
| `api/presentation.zig` | 19 | 4 | surfaces, present modes, frame pacing, surface collections |
| `api/diagnostics.zig` | 80 | 16 | capabilities, cache/stability plans, profiling, capture, reports, memory budgets |
| `api/command.zig` | 16 | 2 | command lifecycle, encoders, labels, queue capability and selection planning |
| `api/shader.zig` | 33 | 2 | source, reflection, specialization, compiler inputs and results |
| `api/binding.zig` | 41 | 2 | layouts, bind groups, resource tables, offsets, constants |
| `api/compute.zig` | 8 | 0 | compute pipeline and dispatch descriptors, atomics, threadgroup memory |
| `api/ray_tracing.zig` | 53 | 11 | acceleration structures, RT pipelines, SBTs, dispatch, queries, stress plans |
| `api/interop.zig` | 49 | 21 | external resource contracts, platform import planning and diagnostics |
| `api/native.zig` | 20 | 4 | neutral native handles, insertion, sparse lowering, and backend-lowering escape hatches |

The nested native modules are measured separately:

| Native facade | Declarations | Operations |
| --- | ---: | ---: |
| `api/native/vulkan.zig` | 9 | 2 |
| `api/native/metal.zig` | 15 | 4 |

Across the 13 top-level facades, this is 508 declarations and 87 callable
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

All 35 guarded exported runtime handles now expose one implementation-storage
field named `_state` and no other field. Value-owned resources, pipelines, binding
objects, synchronization objects, command buffers, encoders, queues, and
similar wrappers use inline opaque byte storage. `WindowContext` owns a
heap-allocated runtime state, while `Device`, `Surface`, and `Swapchain` expose
borrowed `*anyopaque` views into it.

Consequently, the public field graph no longer reaches `BackendRuntime`, a
backend `Impl` union, `ResourceTracker`, debug state, or a private state record.
Construction, queries, mutation, and destruction go through documented public
methods. Direct struct literals and reads or writes of `_state` are unsupported
even though Zig can spell the field name. `zig build run-api-guard` locks the
35-name handle set and this single-field representation alongside the root and
owner-method allowlists.

## Runtime Owner Inventory

The current major runtime owner counts are:

| Owner | Public methods | Direction |
| --- | ---: | --- |
| `Device` | 34 | creation, compilation, common queries, and queue access |
| `WindowContext` | 10 | lifecycle, identity, native-view, and owner access only |
| `RenderCommandEncoder` | 28 | natural render command owner |
| `ComputeCommandEncoder` | 20 | natural compute command owner |
| `BlitCommandEncoder` | 21 | natural transfer command owner |
| `CommandBuffer` | 18 | lifecycle and encoder creation |
| `Texture` | 19 | resource lifetime and texture operations |
| `TextureView` | 18 | view lifetime and queries |
| `AccelerationStructure` | 14 | capability-gated RT owner |
| `Buffer` | 14 | mapping, read, write, and lifetime |
| `ShaderBindingTable` | 13 | capability-gated RT owner |
| `ResourceTable` | 13 | advanced binding owner |

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

## Verification Commands

```sh
zig build run-api-guard
# API guard passed: root=68 (facades=13 core=27 aliases=28),
# Device methods=34, WindowContext methods=10, runtime handles=35

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
- [ ] Recount the 68-name root and all changed facades.
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
