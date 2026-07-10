# Public API Inventory

Status: initial inventory established and refreshed after Period 42 on
2026-07-10.

This document records the current public surface and assigns every flat root
export a canonical API domain. It is an inventory and migration input, not a
claim that every existing declaration is stable.

Use this document together with `public-api-rules.md`. Update it whenever a
public declaration is added, removed, renamed, moved to a namespace, or changes
compatibility status.

## Scope And Counting Rules

The baseline covers:

- every `pub const` reachable directly from `src/vkmtl.zig`
- public methods on runtime types exported by the root module
- root names used by in-tree examples
- known compatibility aliases and `WindowContext` forwarding methods

The root count is produced by:

```sh
rg -c '^pub const ' src/vkmtl.zig
```

The current result is 492. It includes the seven initial domain namespace facades
and the separate `ShaderReflection` module export. Tests declared in
`src/vkmtl.zig` are not API entries.

`src/runtime/window_context.zig` currently contains 514 `pub fn` declarations.
Fourteen belong to module-private or non-root helper types; 500 are methods on
runtime types reachable through the current root exports.

## Snapshot Summary

| Surface | Count | Decision |
| --- | ---: | --- |
| Flat root exports | 492 | Frozen against uncontrolled growth; seven are domain namespace facades |
| Provisional root-core candidates | 30 | Keep at root unless the detailed audit finds a conflict |
| Common domain aliases to review for root retention | 28 | Decide during namespace facade work |
| Distinct root names referenced by examples | 41 | Migration regression set; capability dump now uses two facades |
| `Device` public methods | 108 | Split common owner operations from advanced domain planning |
| `WindowContext` public methods | 56 | Keep 10 owner/lifecycle methods; review 46 compatibility forwards |
| Command and render/compute/blit encoder methods | 87 | Keep operation methods on their natural encoder owners |

The inventory does not set a hard root count by subtraction. A declaration may
have a canonical domain namespace and retain a root alias only when it satisfies
the root admission rules.

## Complete Root Allocation

This table assigns all 492 current root exports to one canonical domain. Source
line ranges refer to the post-Period-42 snapshot of `src/vkmtl.zig`.

| Canonical domain | Count | Current source lines | Disposition |
| --- | ---: | --- | --- |
| root namespace facades | 7 | 7-13 | Canonical domain entry points; expand without new flat type aliases |
| root portable core | 30 | 15-21, 29-31, 112-115, 433-434, 447-448, 457-459, 472-473, 478-480, 496-499 | Provisional root keep |
| `diagnostics` | 56 | 22-23, 25-28, 32-60, 69-73, 91-95, 245, 270-276, 435, 476, 495 | Namespace; selected common aliases may remain |
| `resource` | 79 | 24, 61-68, 120-121, 301-305, 334-377, 425-432, 436-445, 477 | Namespace; common resource aliases reviewed separately |
| `sync` | 22 | 74-87, 90, 466-470, 474-475 | Namespace |
| `transfer` | 10 | 88-89, 284-291 | Namespace |
| `native` | 16 | 96-111 | Namespace; backend-lowering helpers require visibility review |
| `presentation` | 17 | 116-119, 411-423 | Namespace; common surface aliases reviewed separately |
| `shader` | 32 | 3, 122-144, 244, 449-455 | Namespace |
| `render` | 72 | 145-177, 229-241, 246-269, 424, 456 | Namespace; includes advanced geometry planning |
| `ray_tracing` | 51 | 178-228 | Namespace; backend-specific lowering records require review |
| `compute` | 8 | 242-243, 277-282 | Namespace |
| `command` | 14 | 283, 292-300, 491-494 | Namespace; runtime command objects remain root candidates |
| `interop` | 35 | 306-333, 460-465, 471 | Namespace |
| `binding` | 43 | 378-410, 481-490 | Namespace; common bind group objects reviewed separately |
| **Total** | **492** | | |

`presentation` and `command` were added to the namespace plan while building
this inventory because surface/presentation contracts and command lifecycle
state did not fit cleanly in the earlier domain list.

## Provisional Root-Core Candidates

These 30 names form the initial root keep set. They are common owners,
selection types, or runtime objects rather than advanced descriptors.

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
ContextOptions
Context
Adapter
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

This is provisional rather than a stability promise. In particular,
`Context`, `ContextOptions`, and `Adapter` must be compared with the runtime
owner API before the first compatibility release.

## Common Root Alias Review Set

These 28 domain declarations are common enough to consider retaining as root
aliases. Their canonical definitions should still live in the listed domain.

| Canonical domain | Names |
| --- | --- |
| `diagnostics` | `DeviceFeatures`, `DeviceLimits` |
| `presentation` | `SurfaceProvider`, `SurfaceSource`, `SurfaceDescriptor`, `PresentMode`, `PresentationDescriptor` |
| `resource` | `FormatCapabilities`, `TextureFormat`, `BufferUsage`, `ResourceStorageMode`, `TextureUsage`, `BufferDescriptor`, `TextureDescriptor`, `TextureViewDescriptor`, `SamplerDescriptor` |
| `shader` | `ShaderModuleDescriptor`, `ProgrammableStageDescriptor` |
| `render` | `VertexDescriptor`, `RenderPipelineColorAttachmentDescriptor`, `RenderPipelineDescriptor`, `RenderPassDescriptor`, `ClearColor` |
| `compute` | `ComputePipelineDescriptor` |
| `binding` | `BindGroupLayoutDescriptor`, `BindGroupDescriptor`, `BindGroupEntry` |
| `command` | `CommandBufferDescriptor` |

Retaining all 28 would produce a 58-name root before any additional decisions,
which is within the working target. Retention still depends on actual quick-start
value and long-term naming stability; this table is not an automatic allowlist.

## Namespace-Only And Visibility Review

All current exports outside the two sets above should migrate toward their
canonical domain without a permanent flat alias unless a later review records a
specific root-admission justification.

The following groups need extra scrutiny because their current names expose
backend lowering, migration scaffolding, or implementation-shaped data:

### Backend And Lowering Records

```text
VulkanSurfaceProvider
VulkanTessellationLowering
MetalTessellationLowering
VulkanTessellationDrawLowering
MetalTessellationFactorBufferOwnership
MetalTessellationDrawLowering
VulkanMeshPipelineLowering
MetalMeshPipelineLowering
VulkanMeshDispatchLowering
MetalMeshDispatchLowering
VulkanRayTracingPipelineLowering
MetalIntersectionFunctionDescriptor
MetalRayTracingLowering
MetalRayTracingMappingDescriptor
MetalRayTracingMappingPlan
MetalRayTracingExecutionMapping
```

Disposition: move to `native.vulkan`, `native.metal`, or an explicitly
backend-specific advanced subnamespace if users genuinely need them. Otherwise
internalize them after their public planning consumers are migrated.

### Native Closure Planning

```text
NativeAdvancedClosureFeature
native_advanced_closure_features
nativeAdvancedClosureTarget
nativeAdvancedClosureHasPublicRuntimeContract
NativeAdvancedClosureDescriptor
NativeAdvancedClosurePlan
```

Disposition: treat as diagnostics/roadmap scaffolding until a user-facing use
case proves it belongs in supported API. Do not retain flat aliases.

### Shape Compatibility Aliases

```text
BindGroupResourceDescriptor
BindGroupEntryDescriptor
BindGroupDescriptorShape
BindGroupShapeResource
BindGroupShapeEntry
BindGroupShapeDescriptor
ClearColorLike
```

Disposition: compatibility-only. Migrate examples and docs to canonical runtime
or domain names, then remove these aliases at the planned compatibility cleanup.

### Resolved And Debug State Types

`Resolved*`, `*DebugState`, encoder state, cache-plan, parity-plan, pressure-plan,
and lowering-plan types remain public only when a public method returns them or
users need them for deterministic validation. They belong in their domain or
`diagnostics`, never as new root aliases. Unreferenced records should be
internalized during the detailed namespace migration.

## Runtime Owner Method Inventory

The root alias count understates the public surface because exported runtime
objects expose many methods.

| Owner | Public methods | Current direction |
| --- | ---: | --- |
| `Device` | 108 | Keep common creation/query methods; move advanced planning and validation behind domains |
| `WindowContext` | 56 | Reduce to lifecycle and owner access; compatibility forwards stop growing |
| `RenderCommandEncoder` | 28 | Natural owner; retain command methods |
| `ComputeCommandEncoder` | 20 | Natural owner; retain command methods |
| `BlitCommandEncoder` | 21 | Natural owner; retain command methods |
| `CommandBuffer` | 18 | Natural owner; retain lifecycle and encoder creation |
| `Texture` | 19 | Natural owner; review utility breadth during resource namespace work |
| `TextureView` | 18 | Natural owner; retain view lifetime/query operations |
| `AccelerationStructure` | 15 | `ray_tracing`; advanced capability-gated owner |
| `Buffer` | 14 | Natural owner; retain mapping/read/write operations |
| `ShaderBindingTable` | 13 | `ray_tracing`; advanced capability-gated owner |
| `ResourceTable` | 13 | `binding`; advanced capability-gated owner |

`Device` currently contains:

- 40 `plan*` methods
- 19 `validate*` methods
- 24 `make*` methods
- 3 `compile*` methods
- 22 other query, diagnostics, queue, presentation, and utility methods

The 59 planning/validation methods are the main owner-surface migration target.
Do not add another advanced `Device.plan*` or `Device.validate*` method without a
documented exception. Period 42 common format queries may remain direct when
they satisfy the root and owner admission rules.

## WindowContext Compatibility Inventory

The following 10 `WindowContext` methods are provisional lifecycle, identity,
or owner-access methods:

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

The remaining 46 methods are compatibility forwards or convenience APIs that
must not be used as precedent for new methods:

```text
objectCacheDiagnostics
runtimeDiagnostics
writeCaptureName
planDriverPipelineCache
planRuntimeCache
planPipelineArtifactCache
planAccelerationStructureMaintenance
planTopLevelAccelerationStructureLayout
planRayQuery
planComplexShaderBindingTable
planRayTracingStress
queueWithDescriptor
queueCapabilities
syncCapabilities
presentModeSupport
resolvePresentMode
makeSurfaceCollection
compileRenderShader
compileComputeShader
compileRayTracingShader
resize
clear
makeCommandBuffer
makeCommandBufferWithDescriptor
makeFence
makeEvent
makeQuerySet
makeHeap
memoryBudgetReport
transientAllocationDiagnostics
makeBuffer
makeShaderModule
makeRenderPipelineState
makeComputePipelineState
makeBindGroupLayout
makeAdvancedBindGroupLayout
planResourceTablePressure
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

Canonical owners are `Device`, `Queue`, `Surface`, `Swapchain`, or the relevant
domain facade. In-tree examples already use `Device` and `Queue` for most common
creation and command paths; migration must finish before these forwards are
removed.

## Example Regression Set

In-tree examples reference 41 distinct root names directly. This is the minimum
source migration and compatibility regression set:

```text
AccelerationStructureBuildDescriptor
AccelerationStructureGeometryDescriptor
AccelerationStructureGeometryResources
AdapterInfo
AdvancedBindingModel
Backend
BindGroupEntry
BindGroupLayoutDescriptor
DescriptorIndexingRange
Device
Extent2D
ExternalHandleKind
ExternalTextureDescriptor
MeshDispatchDescriptor
MeshPipelineDescriptor
MetalIntersectionFunctionDescriptor
PresentMode
PresentationDescriptor
ProgrammableStageDescriptor
RayTracingCapabilityDiagnostics
RayTracingPipelineDescriptor
RayTracingShaderGroupDescriptor
RenderPipelineColorAttachmentDescriptor
RenderPipelineDescriptor
ShaderBindingTableDescriptor
ShaderReflection
Size3D
SparseResidencyMap
SparseTextureKind
SurfaceCollection
SurfaceDescriptor
SurfaceInfo
TessellationDescriptor
TessellationPatchDrawDescriptor
Texture
TextureView
VertexDescriptor
VulkanSurfaceProvider
WindowContext
diagnostics
resource
```

Example use does not automatically justify a root alias. Advanced examples must
migrate to canonical domain or native namespaces. Ordinary examples define the
strongest root-retention evidence.

## Period 42 Guardrail

Period 42 added and refined format, copy, attachment, and resource-state API in
these canonical destinations:

- format classification and format capabilities: `resource`
- buffer/texture copies, row pitch, blits, and readback: `transfer`
- attachments, resolve behavior, and render-pass semantics: `render`
- command lifecycle and encoding errors: `command`
- resource state and layout transitions: `sync`
- surface presentation format behavior: `presentation`
- capability reports and unsupported diagnostics: `diagnostics`

The implementation added seven namespace facades and no new flat type alias.
Future declarations in these areas continue to use the same destinations; a
temporary root alias requires an explicit compatibility reason in the active
phase docs.

The Period 42 namespace additions are:

| Namespace | New canonical declarations or behavior |
| --- | --- |
| `resource` | `TextureAspect`, aspect-byte and aspect-resolution helpers |
| `transfer` | copy layout requirements, aspect-aware copy descriptors, scaled blit descriptors |
| `render` | `TextureResolveDescriptor` and resolve validation |
| `command` | command lifecycle state and typed command-encoding errors |
| `sync` | texture subresource ranges, summaries, and per-subresource tracker |
| `presentation` | canonical presentation descriptor and present-mode facade |
| `diagnostics` | copy-alignment limits and capability-report fields |

Compatibility impact: existing flat aliases and owner methods remain. Copy
descriptors gained defaulted fields, capability records and limits gained
defaulted fields, and new failures are typed validation/unsupported errors.

## Update Checklist

When the public surface changes:

- [ ] Recount root exports and runtime public methods.
- [ ] Assign each new declaration one canonical domain.
- [ ] Record any root alias and its admission justification.
- [ ] Update compatibility and visibility-review lists.
- [ ] Update the example regression set when examples adopt new public names.
- [ ] Keep the category total equal to the root export count.
- [ ] Run the validation required by `public-api-rules.md`.
