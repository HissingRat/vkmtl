# Native Semantic Coverage Inventory

Status: Period 46 query/specialization update, 2026-07-12.

This document is the authoritative inventory for backend semantic coverage. It
answers a different question from `public-api-inventory.md`:

- the public API inventory records what a vkmtl caller can name;
- this inventory records whether Metal and Vulkan can execute the promised
  behavior, how they do it, and what evidence exists.

The long-term target is semantic coverage, not a one-call-to-one-call wrapper.
A vkmtl operation may lower to one native call, several native calls, hidden
resources, or a vkmtl state machine. It is supported only when the complete
documented behavior is preserved. If a backend cannot preserve that behavior,
vkmtl must report a capability-gated or typed unsupported result.

This document remains the compact feature-family view. Period 45 adds the
source-driven detail in `period45/metal-semantic-ledger.md`. Period 45 recorded
the historical 99-unit/77-gap baseline. Period 46 split broad query/counter
rows into 101 stable Metal semantic units, retains the complete 78-protocol
map, and routes all 75 remaining incomplete units exactly once. It is a
coverage inventory, not a claim that incomplete source semantics are
executable.

## Source Baseline And Scope

The initial source audit is pinned to these repository inputs rather than to an
unversioned claim of "all current APIs":

- Metal: the non-deprecated Metal framework surface visible in the macOS 26.2
  SDK used for this baseline, plus Apple's Metal feature-set tables. API
  availability still depends on OS and GPU family. MetalKit, MetalFX, and Metal
  Performance Shaders are adjacent frameworks and remain outside the baseline
  until explicitly admitted.
- Vulkan: core 1.3, which the current instance requests, using Vulkan-Headers
  1.3.283, plus each KHR/EXT capability explicitly loaded by the backend.
  Vendor extensions are not implied by core coverage.

Changing either source baseline requires an inventory update. A newer Vulkan
driver version observed in a test does not silently raise the Vulkan API
baseline, and compiling with a newer Apple SDK does not silently add every new
Metal semantic to vkmtl's supported set.

## Coverage Status

Every backend cell uses exactly one semantic status:

| Status | Meaning |
| --- | --- |
| `native-exact` | The backend directly executes the complete vkmtl contract with native GPU facilities. |
| `composed-exact` | Several native operations and/or vkmtl state tracking execute the complete contract. |
| `emulated-exact` | A compatibility path, hidden resource, or CPU/runtime mechanism preserves the complete observable contract. |
| `unsupported` | The backend cannot preserve the contract; the path is rejected before native work. |
| `incomplete` | A public shape, query, validation, plan, partial lowering, or no-op exists, but the complete executable contract is not proven. |
| `not-applicable` | The semantic is intentionally backend-specific and has no contract on this backend. |

Only `native-exact`, `composed-exact`, and `emulated-exact` are executable
support. `Device.features()` may report a capability only when its selected
backend cell is one of those three states and all device-specific gates and
limits pass. A native API capability reported by `Device.nativeFeatures()` does
not upgrade an `incomplete` cell.

Performance is part of the contract only when the public API explicitly says
so. An implementation may preserve transient attachment lifetime semantics
with ordinary device memory, for example, but it must not claim a hardware
memoryless guarantee unless the backend can provide that stronger property.

## Evidence Status

Semantic status and evidence are separate. Each row uses the strongest current
evidence class:

| Evidence | Meaning |
| --- | --- |
| `inspection` | Lowering was identified in source, but no focused execution evidence is recorded here. |
| `unit` | Deterministic validation or command-record tests exist. |
| `gpu-smoke` | The path executed on at least one physical backend device. |
| `gpu-pixels` | Deterministic GPU output/readback was checked. |
| `gpu-soak` | The executable path participated in a bounded physical-device soak. |
| `missing` | No evidence sufficient for an executable claim exists. |

Evidence on one adapter proves that path and configuration, not every device
that reports the capability. Device feature, limit, and format queries remain
mandatory.

## Current Portable And Capability-Gated Surface

The entries below are a conservative snapshot of the current implementation.
Grouped rows share one semantic contract; a group must be split when one member
develops a different lowering or support state.

### Device, Resource, And Shader Fundamentals

| ID | Semantic contract | Public owner | Metal | Vulkan | Evidence / current gap |
| --- | --- | --- | --- | --- | --- |
| DEV-01 | Backend selection, adapter/device discovery, capability report | root, `diagnostics` | `native-exact` | `native-exact` | `gpu-smoke`; native and usable features are reported separately. |
| DEV-02 | Command queue/buffer creation, commit, completion, presentation | `command`, `presentation` | `native-exact` | `native-exact` | `gpu-soak`. |
| RES-01 | Buffer creation, upload, mapping, copy, and destruction | `resource`, `transfer` | `native-exact` | `native-exact` | `gpu-pixels` for representative upload/copy/readback. |
| RES-02 | 1D/2D/3D, array, cube, and multisample texture fundamentals | `resource` | `native-exact` | `native-exact` | `unit` plus representative `gpu-pixels`; full shape/format matrix remains unobserved. |
| RES-03 | Texture views with mip/layer ranges and exact current format | `resource` | `native-exact` | `native-exact` | `unit`; format reinterpretation is a separate incomplete semantic. |
| RES-04 | Sampler filtering, comparison, anisotropy, and fixed border color | `resource` | `native-exact` | `native-exact` | `unit`; device gates still apply. |
| RES-05 | Full-texture mipmap generation | `transfer` | `native-exact` | `native-exact` | `unit`; partial mip/layer ranges remain incomplete. |
| RES-06 | Current portable texture formats and format capability queries | `resource` | `composed-exact` | `native-exact` | `unit`; Metal uses a conservative table, Vulkan queries format properties. The current format enum is not complete Metal format coverage. |
| SHD-01 | Build-time Slang compilation and embedded runtime shader resolution | `shader` | `composed-exact` | `composed-exact` | Hosted build and `gpu-pixels`; MSL and SPIR-V are produced before runtime. |
| SHD-02 | Reflection-derived binding and vertex metadata | `shader`, `binding`, `render` | `composed-exact` | `composed-exact` | `unit` and representative rendering. |
| SHD-03 | Shader specialization constants/function constants by stable numeric ID | `shader` | `native-exact` | `native-exact` | `gpu-pixels` on Metal plus unit coverage for both mappings; Metal specializes vertex, fragment, and compute functions, while Vulkan uses specialization info. Generated names are diagnostic only. |

### Rendering, Binding, Compute, And Transfer

| ID | Semantic contract | Public owner | Metal | Vulkan | Evidence / current gap |
| --- | --- | --- | --- | --- | --- |
| REN-01 | Render pipelines, indexed/direct draw, viewport, scissor, cull, depth, stencil, blend | `render` | `native-exact` | `native-exact` | Representative `gpu-pixels`; not every state combination is physically observed. |
| REN-02 | MRT, offscreen targets, MSAA color resolve | `render` | `native-exact` | `native-exact` | `unit` and representative `gpu-pixels`. |
| REN-03 | Base vertex/base instance and instance step rate | `render` | `native-exact` | `native-exact` | `unit`; Vulkan divisor support is capability-gated. |
| REN-04 | Indirect and explicit multi-draw behavior | `render` | `composed-exact` | `composed-exact` | `unit`; implementations may expand a multi-draw into repeated native draws. |
| REN-05 | Wireframe/line fill and depth bias | `render` | `native-exact` | `native-exact` | `unit`; native capability gates apply. |
| REN-06 | Conservative rasterization | `render` | `incomplete` | `incomplete` | Public capability exists, but complete lowering/evidence is absent. |
| REN-07 | Depth/stencil resolve and texture-view format reinterpretation | `render`, `resource` | `incomplete` | `incomplete` | Currently typed unsupported. |
| BND-01 | Ordinary bind groups, dynamic offsets, resource arrays | `binding` | `composed-exact` | `native-exact` | `unit` and representative rendering. |
| BND-02 | Root/small constants | `binding` | `native-exact` | `native-exact` | `unit`; Metal bytes and Vulkan push-constant lowering are backend-specific. |
| BND-03 | Bindless tables, descriptor indexing, and argument buffers | `binding` | `incomplete` | `incomplete` | Runtime/table contracts exist, but usable features remain conservatively closed and large-table GPU evidence is missing. |
| CMP-01 | Compute pipeline and direct dispatch | `compute` | `native-exact` | `native-exact` | `gpu-pixels` through deterministic compute readback. |
| CMP-02 | Indirect compute dispatch | `compute` | `native-exact` | `native-exact` | `unit`; focused physical-device evidence is not recorded. |
| CMP-03 | Shader atomics and threadgroup memory capability contract | `compute` | `incomplete` | `incomplete` | Public feature fields exist; complete query/lowering/evidence audit is pending. |
| XFR-01 | Buffer/texture copies across current color mip/layer/slice ranges | `transfer` | `composed-exact` | `native-exact` | `gpu-pixels`; Metal may loop over slices. |
| XFR-02 | Unaligned buffer fill | `transfer` | `native-exact` | `composed-exact` | `unit`; Vulkan uses a staging-copy fallback. |
| XFR-03 | Scaled texture blit | `transfer` | `unsupported` | `native-exact` | Metal returns typed `UnsupportedTextureBlit`; Vulkan is format-capability-gated. |
| XFR-04 | Partial mip generation, custom border colors, packed depth/stencil parity | `transfer`, `resource` | `incomplete` | `incomplete` | Some backend-specific subsets exist; no complete portable semantic is claimed. |

### Synchronization, Queries, Memory, And Production Paths

| ID | Semantic contract | Public owner | Metal | Vulkan | Evidence / current gap |
| --- | --- | --- | --- | --- | --- |
| SYN-01 | Portable resource-state hazards and required execution ordering | `sync` | `composed-exact` | `composed-exact` | `unit`; Metal combines state validation with native encoder ordering, Vulkan emits barriers/layout transitions. |
| SYN-02 | Runtime binary fences and events | `sync` | `emulated-exact` | `emulated-exact` | `unit`; these are runtime objects, not yet native submit synchronization. |
| SYN-03 | Timeline/shared-event native submit semantics | `sync` | `incomplete` | `incomplete` | Validation/runtime state exists; driver submit wait/signal integration is deferred. |
| SYN-04 | Logical compute/transfer queues with graphics fallback | `command`, `sync` | `emulated-exact` | `emulated-exact` | `unit`; exact for the documented logical fallback contract. |
| SYN-05 | Physical dedicated queues and Vulkan queue-family ownership | `command`, `sync` | `incomplete` | `incomplete` | Planning and hazard validation exist; physical execution/evidence does not. |
| QRY-01 | Logical timestamp sequence and CPU/marker profiling fallback | `diagnostics` | `emulated-exact` | `emulated-exact` | `unit`; explicitly not GPU time. |
| QRY-02 | Capability-gated native GPU timestamp ticks, CPU readback, and GPU resolve | `diagnostics` | `native-exact` | `native-exact` | `unit`; Metal requires the common timestamp set plus draw/dispatch/blit sampling, Vulkan requires host reset plus graphics-queue timestamp bits. Tick-to-duration calibration remains outside this row. |
| QRY-03 | Boolean occlusion visibility, where zero is occluded and nonzero is visible | `diagnostics`, render encoder | `composed-exact` | `native-exact` | `gpu-smoke` on Metal plus unit/inspection for both mappings; Metal uses pass scratch plus canonical copy, Vulkan uses non-precise query pools. Vulkan physical rerun remains useful evidence, not a capability prerequisite. |
| QRY-04 | Pipeline statistics and multi-counter result shapes | `diagnostics` | `incomplete` | `incomplete` | `unit`; the current one-`u64`-per-query contract cannot represent variable multi-counter results, so the feature remains closed. |
| MEM-01 | Heap reservation, aliasing, and transient allocation planning | `resource`, `diagnostics` | `incomplete` | `incomplete` | Deterministic plans exist; resources are not created from native heaps. |
| MEM-02 | Transient attachment lifetime semantic | `render` | `composed-exact` | `composed-exact` | The API treats transient as a lifetime/performance hint; a hardware memoryless guarantee is not currently exposed. |
| MEM-03 | Hardware memoryless/lazily allocated attachment guarantee | none | `incomplete` | `incomplete` | Metal memoryless and Vulkan transient/lazily-allocated mappings need a separate precise contract and lowering. Vulkan cannot promise that physical backing is never allocated. |
| MEM-04 | Native memory budget and pressure telemetry | `diagnostics` | `incomplete` | `incomplete` | Current physical runs report fallback data. |
| MEM-05 | Native sparse/tiled resources and residency page binding | `resource`, `native` | `incomplete` | `incomplete` | Plans and churn maps exist; driver resources/page commits do not. |
| PRD-01 | Runtime object reuse and persistent driver pipeline artifacts | `diagnostics` | `incomplete` | `incomplete` | Diagnostics/plans exist; native handle pools, `MTLBinaryArchive`, and `VkPipelineCache` consumption remain deferred. |

### Advanced Geometry, Ray Tracing, Interop, And Diagnostics

| ID | Semantic contract | Public owner | Metal | Vulkan | Evidence / current gap |
| --- | --- | --- | --- | --- | --- |
| GEO-01 | Tessellation pipeline and patch draw | `render` | `incomplete` | `incomplete` | Public plans exist; visible native executable pipeline hooks are missing. |
| GEO-02 | Mesh/object/task pipeline and dispatch | `render` | `incomplete` | `incomplete` | Public plans exist; visible native executable pipeline hooks are missing. |
| RT-01 | Basic native acceleration structure, RT pipeline, dispatch, and presentation | `ray_tracing` | `native-exact` | `native-exact` | Visible physical Metal and Vulkan paths are recorded. Device capability gates apply. |
| RT-02 | Mesh BLAS/TLAS scene execution | `ray_tracing` | `native-exact` | `native-exact` | Metal visible scene evidence and Vulkan procedural superset evidence exist; shared scene-layout/multi-instance breadth remains incomplete. |
| RT-03 | Procedural geometry and custom intersection | `ray_tracing` | `incomplete` | `native-exact` | Vulkan procedural output is observed; Metal intersection-function-table lowering is deferred. |
| RT-04 | AS update/refit/compaction, ray query, complex/callable SBT behavior | `ray_tracing` | `incomplete` | `incomplete` | Planning and validation are broader than executable native evidence. Vulkan native capability queries do not by themselves close this row. |
| INT-01 | External memory/texture import and external synchronization | `interop` | `incomplete` | `incomplete` | Wrappers, plans, ownership validation, and matrix exist; OS/driver import and submit hooks do not. |
| INT-02 | Native handles | `native` | `native-exact` | `native-exact` | Borrowed escape hatch; lifetime and backend tagging are part of the contract. |
| INT-03 | Native command insertion | `native` | `incomplete` | `incomplete` | Public callback/gate exists; validated native command-handle lowering remains deferred. |
| DBG-01 | Object and encoder labels/markers | `command`, `diagnostics` | `native-exact` | `native-exact` | `gpu-smoke`; Vulkan requires debug utils. |
| DBG-02 | Command-buffer marker groups | `command` | `native-exact` | `incomplete` | Vulkan currently validates scope without a native command-buffer marker. |
| DBG-03 | Native capture | `diagnostics` | `native-exact` | `unsupported` | Metal developer-tools capture is opt-in; Vulkan capture is external-tool territory in the current contract. |

## Metal Source-Coverage Ledger

Period 45 established the source ledger; Period 46 refined it to 101 units by
splitting exact occlusion/timestamp subsets from broader counter/statistics
semantics. Missing vkmtl concepts remain explicit `missing-contract` entries;
their presence in the ledger does not admit public API or claim execution.

| Source family | Current inventory state | Required action |
| --- | --- | --- |
| Core device, queues, command buffers, resources, render/compute/blit encoders | Audited | Executable common rows plus Periods 46-48 gaps. |
| Pixel/vertex formats, texture types/views, sampler variants | Audited/incomplete | Period 47 closes format and resource breadth. |
| Heaps, placement resources, residency sets, sparse resources | Audited/incomplete | Period 49 owns native allocation and residency. |
| Argument buffers/tables and indirect command buffers | Audited/incomplete | Period 50 owns scalable binding and generated commands. |
| Function constants, dynamic libraries, linked functions, function pointers | Audited/incomplete | Period 46 completed numeric-ID function constants; Period 50 owns linking breadth. |
| Tessellation, object/mesh shaders, layered rendering, amplification | Audited/incomplete | Period 51 owns executable advanced geometry. |
| Tile shaders, imageblocks, raster-order groups, programmable blending | Audited/missing-contract | Period 51 decides exact composition or unsupported. |
| Counter sample buffers, GPU timestamps, statistics, capture scopes | Audited/incomplete | Period 46 completed native timestamp/Boolean visibility subsets; Period 54 owns calibrated and device-specific counter breadth. |
| Ray tracing maintenance, function tables, motion, callable/intersection breadth | Audited/incomplete | Period 52 owns RT breadth. |
| Fast resource loading / Metal I/O | Audited/missing-contract | Period 53 owns I/O and transfer composition. |
| Metal 4 command allocators, argument tables, pipeline datasets, flexible pipeline state | Audited/incomplete | Period 54 owns the new command/pipeline model. |
| External sharing, IOSurface, shared events, platform handles | Audited/incomplete | Period 53 owns real imports and synchronization. |
| MetalKit, MetalFX, Metal Performance Shaders | Out of current scope | These adjacent frameworks are excluded from the Metal core baseline until explicitly admitted. |

The Vulkan side must also record which core version and extension set supplies
each composed implementation. "Vulkan supports it" is not sufficient without
the exact feature/extension query, limits, and fallback behavior.

## Maintenance Rules

Update this inventory in the same change when any of the following occurs:

- a `DeviceFeatures`, `DeviceLimits`, or `FormatCapabilities` field is added or
  changes meaning;
- a backend lowering moves between planning, validation, emulation, composed,
  native, or unsupported states;
- a public operation begins or stops submitting native GPU work;
- a fallback changes observable behavior or gains a performance guarantee;
- physical-device evidence is added, invalidated, or narrowed;
- the supported Metal SDK baseline, Vulkan core version, or Vulkan extension
  policy changes.

Every executable row must identify its public contract, both backend mappings,
capability/limit gates, and focused evidence. If the two backends preserve
different observable behavior, they are not one row: split the semantic or
mark one backend incomplete/unsupported.

## Follow-Up Order

The source audit and Period 46 native query/specialization slice are complete.
The updated exactly-once gap routing establishes Periods 47-54; Period 47 is
next. `period45/gap-backlog.md` records the remaining dependency order and
acceptance boundaries.
