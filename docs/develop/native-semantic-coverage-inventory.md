# Native Semantic Coverage Inventory

Status: Period 52 complete plus additive headless runtime, 2026-07-14.

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
rows into 101 units. Period 47 Phase 1 split six advanced remainders from its
portable targets, producing 107 stable Metal semantic units and retaining the
complete 78-protocol map. Period 48 closes six synchronization, queue,
lifecycle, hazard, and presentation rows. Period 49 closes eight memory,
residency, cache, and optimization rows. Period 50 splits CPU-authored reusable
commands from GPU-authored mutation, producing 109 Metal semantic units; it
closes scalable tables, reusable command lists, linked-function decisions, and
driver artifacts. Period 51 closes eight advanced geometry/raster rows through
executable mesh/tessellation subsets or precise unsupported decisions. Period
52 closes ordinary RT maintenance/geometry breadth and the remaining advanced
RT routes through executable paths or precise unsupported decisions.
The additive headless slice creates real Metal/Vulkan device and queue owners
without presentation objects. Metal has physical compute, transfer, and
texture-backed offscreen evidence; Vulkan has implementation and forced-build
evidence, while a physical loader/device rerun remains pending.
It is a coverage inventory, not a claim that incomplete source semantics are
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
| DEV-01 | Backend selection, adapter/device discovery, capability report, and ordinary execution limits | root, `diagnostics` | `native-exact` | `native-exact` | `gpu-smoke`; native and usable features are reported separately, while queried resource/dispatch/threadgroup limits feed validation. |
| DEV-02 | Command queue/buffer creation, commit, lifecycle callbacks, immediate presentation, and capability-gated timing | `command`, `presentation` | `native-exact` | `composed-exact` | `gpu-pixels` on Metal for callback-once and minimum-duration presentation; Vulkan callbacks compose submit/queue completion and timed presentation remains feature-closed. |
| DEV-03 | No-surface runtime initialization with device/queues, presentation exclusion, and texture-backed offscreen commands | root, `command`, `render` | `native-exact` | `native-exact` | Metal `gpu-pixels` covers headless compute, transfer, and offscreen clear/readback. Vulkan has focused tests and forced-build evidence; physical execution awaits a host with a Vulkan loader/device. Current-drawable commands fail before backend presentation work. |
| RES-01 | Buffer creation, upload, mapping, copy, and destruction | `resource`, `transfer` | `native-exact` | `native-exact` | `gpu-pixels` for representative upload/copy/readback. |
| RES-02 | 1D/2D/3D, array, cube, and multisample texture fundamentals | `resource` | `native-exact` | `native-exact` | `unit` plus representative `gpu-pixels`; full shape/format matrix remains unobserved. |
| RES-03 | Texture views with mip/layer ranges and exact current format | `resource` | `native-exact` | `native-exact` | `unit`; format reinterpretation is a separate incomplete semantic. |
| RES-04 | Sampler filtering, addressing, LOD, comparison, anisotropy, normalized/unnormalized coordinates, and fixed border color | `resource` | `native-exact` | `native-exact` | `unit`; unnormalized coordinates use the documented shared constraint set and device gates still apply. |
| RES-05 | Full-texture mipmap generation | `transfer` | `native-exact` | `native-exact` | `unit`; partial mip/layer ranges remain incomplete. |
| RES-06 | Finite portable texture/vertex formats and format capability queries | `resource`, `render` | `composed-exact` | `native-exact` | `unit`; Period 47 covers the documented normalized, integer, floating-point, depth, stencil, and vertex-input set. Metal uses a conservative capability table and Vulkan queries format properties; unallocated native formats remain unsupported. |
| RES-07 | Capability-gated shader-visible buffer GPU address | `resource`, `diagnostics` | `native-exact` | `native-exact` | `gpu-smoke` on Apple M4 Pro plus Vulkan unit/inspection; callers declare `shader_device_address`, creation checks the usable feature, and zero/unavailable native addresses return typed errors. |
| RES-08 | Automatic/shared/managed/private portable storage behavior and CPU/GPU visibility boundaries | `resource`, `transfer` | `native-exact` | `composed-exact` | `gpu-pixels` on Metal plus Vulkan unit/inspection; Metal composes `didModifyRange` and `synchronizeResource`, Vulkan uses host-coherent managed buffers, and private CPU access is rejected. |
| SHD-01 | Build-time Slang compilation and embedded runtime shader resolution | `shader` | `composed-exact` | `composed-exact` | Hosted build and `gpu-pixels`; MSL and SPIR-V are produced before runtime. |
| SHD-02 | Reflection-derived buffer/texture/sampler kinds, arrays, storage access, and vertex metadata | `shader`, `binding`, `render` | `composed-exact` | `composed-exact` | `unit` and representative rendering; schema 1 keeps advanced backend-only protocols outside the portable metadata. |
| SHD-03 | Shader specialization constants/function constants by stable numeric ID | `shader` | `native-exact` | `native-exact` | `gpu-pixels` on Metal plus unit coverage for both mappings; Metal specializes vertex, fragment, and compute functions, while Vulkan uses specialization info. Generated names are diagnostic only. |

### Rendering, Binding, Compute, And Transfer

| ID | Semantic contract | Public owner | Metal | Vulkan | Evidence / current gap |
| --- | --- | --- | --- | --- | --- |
| REN-01 | Render pipelines, indexed/direct draw, viewport, scissor, cull, depth, stencil, blend | `render` | `native-exact` | `native-exact` | Representative `gpu-pixels`; not every state combination is physically observed. |
| REN-02 | MRT, offscreen targets, MSAA color resolve | `render` | `native-exact` | `native-exact` | `unit` and representative `gpu-pixels`. |
| REN-03 | Base vertex/base instance and instance step rate | `render` | `native-exact` | `native-exact` | `unit`; Vulkan divisor support is capability-gated. |
| REN-04 | Indirect/explicit multi-draw and CPU-authored reusable draw lists | `render`, `command` | `composed-exact` | `composed-exact` | `gpu-smoke` on Metal for native ICB execution; Vulkan and Metal paths whose active shader pipeline is not ICB-compatible expand immutable commands into repeated native draws. GPU-authored mutation is excluded. |
| REN-05 | Wireframe/line fill and depth bias | `render` | `native-exact` | `native-exact` | `unit`; native capability gates apply. |
| REN-06 | Conservative rasterization | `render` | `incomplete` | `incomplete` | Public capability exists, but complete lowering/evidence is absent. |
| REN-07 | Depth/stencil resolve and texture-view format reinterpretation | `render`, `resource` | `incomplete` | `incomplete` | Compatible linear/sRGB texture views and component swizzles are native-exact in Period 47; depth/stencil resolve remains typed unsupported. |
| BND-01 | Ordinary render/compute bind groups, dynamic offsets, resource arrays | `binding` | `composed-exact` | `native-exact` | `unit` and representative render/compute `gpu-pixels`. |
| BND-02 | Root/small constants | `binding` | `native-exact` | `native-exact` | `unit`; Metal bytes and Vulkan push-constant lowering are backend-specific. |
| BND-03 | Bindless tables, descriptor indexing, and argument buffers | `binding` | `native-exact` | `native-exact` | Metal `gpu-smoke` covers a 65-slot argument buffer; Vulkan descriptor-indexing feature enablement, set allocation/update/binding, and compatible pipeline layouts have unit/forced-build evidence. |
| CMP-01 | Compute pipeline, direct dispatch, and ceil-composed logical-thread dispatch | `compute` | `native-exact` | `native-exact` | `gpu-pixels` through deterministic compute readback; shaders own out-of-logical-grid bounds checks after ceil composition. |
| CMP-02 | Indirect compute dispatch and CPU-authored reusable dispatch lists | `compute`, `command` | `composed-exact` | `composed-exact` | `unit`; ordinary buffer-indirect dispatch is native, reusable slots use Metal ICB when available and exact direct dispatch expansion otherwise. GPU-authored mutation is excluded. |
| CMP-03 | 32-bit integer storage-buffer/threadgroup atomics and threadgroup memory within queried limits | `compute` | `native-exact` | `native-exact` | `gpu-pixels` on Metal proves deterministic atomic/shared-memory output; Vulkan has unit/compile evidence and core semantic inspection. Storage-texture and wider atomic families are not promised. |
| XFR-01 | Buffer/texture copies across current color mip/layer/slice ranges | `transfer` | `composed-exact` | `native-exact` | `gpu-pixels`; Metal may loop over slices. |
| XFR-02 | Unaligned buffer fill | `transfer` | `native-exact` | `composed-exact` | `unit`; Vulkan uses a staging-copy fallback. |
| XFR-03 | Scaled texture blit | `transfer` | `unsupported` | `native-exact` | Metal returns typed `UnsupportedTextureBlit`; Vulkan is format-capability-gated. |
| XFR-04 | Partial mip generation, custom border colors, packed depth/stencil parity | `transfer`, `resource` | `incomplete` | `incomplete` | Some backend-specific subsets exist; no complete portable semantic is claimed. |

### Synchronization, Queries, Memory, And Production Paths

| ID | Semantic contract | Public owner | Metal | Vulkan | Evidence / current gap |
| --- | --- | --- | --- | --- | --- |
| SYN-01 | Portable resource-state hazards and required execution ordering | `sync` | `composed-exact` | `composed-exact` | `unit`; Metal combines state validation with native encoder ordering, Vulkan emits barriers/layout transitions. |
| SYN-02 | Runtime binary fences and ordinary events | `sync` | `emulated-exact` | `emulated-exact` | `unit`; these remain exact runtime objects and are not reported as native submit synchronization. |
| SYN-03 | Native monotonic host and GPU-submit synchronization | `sync` | `native-exact` | `native-exact` | `gpu-pixels` on Metal plus unit/forced-Vulkan build; Metal uses shared events and Vulkan uses timeline semaphores. Metal-only shared events and Vulkan timeline support remain capability-gated; external handles are excluded. |
| SYN-04 | Queue selection with explicit graphics fallback | `command`, `sync` | `composed-exact` | `composed-exact` | `unit` plus Metal `gpu-pixels`; fallback is explicit and physical work queues are selected only when the usable capability opens. |
| SYN-05 | Physical work queues, cross-queue dependencies, and exclusive portable ownership | `command`, `sync` | `composed-exact` | `composed-exact` | Metal `gpu-pixels` exercised a separate transfer queue. Vulkan queries work families, uses timeline dependencies and concurrent resource sharing, and preserves vkmtl logical ownership; physical Vulkan rerun remains useful evidence. |
| QRY-01 | Logical timestamp sequence and CPU/marker profiling fallback | `diagnostics` | `emulated-exact` | `emulated-exact` | `unit`; explicitly not GPU time. |
| QRY-02 | Capability-gated native GPU timestamp ticks, CPU readback, and GPU resolve | `diagnostics` | `native-exact` | `native-exact` | `unit`; Metal requires the common timestamp set plus draw/dispatch/blit sampling, Vulkan requires host reset plus graphics-queue timestamp bits. Tick-to-duration calibration remains outside this row. |
| QRY-03 | Boolean occlusion visibility, where zero is occluded and nonzero is visible | `diagnostics`, render encoder | `composed-exact` | `native-exact` | `gpu-smoke` on Metal plus unit/inspection for both mappings; Metal uses pass scratch plus canonical copy, Vulkan uses non-precise query pools. Vulkan physical rerun remains useful evidence, not a capability prerequisite. |
| QRY-04 | Pipeline statistics and multi-counter result shapes | `diagnostics` | `incomplete` | `incomplete` | `unit`; the current one-`u64`-per-query contract cannot represent variable multi-counter results, so the feature remains closed. |
| MEM-01 | Native placement heaps, heap-backed buffers/textures, exact requirements, and alias planning | `resource`, `diagnostics` | `native-exact` | `native-exact` | `gpu-pixels` on Metal plus unit/forced-Vulkan build; resources bind at validated reserved offsets and must be destroyed before the heap. Alias offset reuse remains caller-lifetime-controlled. |
| MEM-02 | Transient attachment lifetime semantic | `render` | `composed-exact` | `composed-exact` | The API treats transient as a lifetime/performance hint; a hardware memoryless guarantee is not currently exposed. |
| MEM-03 | Hardware memoryless attachment guarantee | `resource`, `render` | `native-exact` | `unsupported` | Metal native creation probe plus physical memoryless MSAA resolve. Vulkan lazily allocated memory cannot promise no physical backing; `transient` remains a separate hint. |
| MEM-04 | Native memory budget and pressure telemetry | `diagnostics` | `native-exact` | `native-exact` | Metal `gpu-smoke` reports recommended working set/current allocation; Vulkan uses queried `VK_EXT_memory_budget` device-local heaps and otherwise reports fallback. |
| MEM-05 | Native sparse/tiled resources, residency sets, and page binding | `resource`, `native` | `unsupported` | `unsupported` | Plans and churn maps remain deterministic, but current descriptors do not identify native resources. Usable sparse/residency features stay closed. |
| PRD-01 | Persistent driver render/compute pipeline artifacts | `diagnostics`, pipeline descriptors | `native-exact` | `native-exact` | Metal `gpu-smoke` consumes/populates/serializes `MTLBinaryArchive`; Vulkan consumes/persists `VkPipelineCache` with deterministic identity and stale-data recovery. |
| PRD-02 | Runtime native object and resource-view pooling | `missing-contract` | `incomplete` | `incomplete` | No lifetime-safe portable pool owner exists; Metal 4 resource/view pools remain routed to Period 54. |

### Advanced Geometry, Ray Tracing, Interop, And Diagnostics

| ID | Semantic contract | Public owner | Metal | Vulkan | Evidence / current gap |
| --- | --- | --- | --- | --- | --- |
| GEO-01 | Tessellation pipeline and patch draw under the source-only artifact contract | `render` | `unsupported` | `native-exact` | Vulkan compiles schema-2 SPIR-V, enables tessellation, creates patch-list pipelines, and draws patches. The pinned Slang Metal target rejects hull/domain stages. |
| GEO-02 | Resource-free mesh pipeline and dispatch; optional task/object stage separately gated | `render` | `native-exact` | `native-exact` | Physical Metal mesh rendering plus Vulkan forced-build/unit evidence. Pinned task/object compilation crashes, so usable task support stays false on both backends. |
| RT-01 | Basic native acceleration structure, RT pipeline, dispatch, and presentation | `ray_tracing` | `native-exact` | `native-exact` | Visible physical Metal and Vulkan paths are recorded. Device capability gates apply. |
| RT-02 | Mesh BLAS/TLAS scene execution | `ray_tracing` | `native-exact` | `native-exact` | Metal physical evidence includes a TLAS over two distinct BLAS sources; Vulkan supports the same source array. Non-default instance metadata is outside the executable contract. |
| RT-03 | Triangle and AABB BLAS geometry input | `ray_tracing` | `native-exact` | `native-exact` | Physical Metal headless evidence builds both forms; Vulkan procedural scene evidence already exercises AABB input. |
| RT-04 | Custom intersection execution | `ray_tracing` | `unsupported` | `native-exact` | Vulkan procedural pixels are observed. Metal schema-2 artifacts have no linked intersection function or driver-bound table. |
| RT-05 | AS build-update, update/refit, and compact copy | `ray_tracing` | `native-exact` | `native-exact` | Metal physical stress covers 32 alternating maintenance operations plus compact copy. Vulkan uses native update and compact-copy commands with unit/forced-build evidence. |
| RT-06 | Post-build compacted-size query and result ownership | `ray_tracing` | `unsupported` | `unsupported` | Build/update size queries are exact; no public asynchronous post-build compact-size result contract exists. |
| RT-07 | Ray query from ordinary compute/render stages | `ray_tracing` | `unsupported` | `unsupported` | Metal has no identical inline-query contract. Vulkan extension/feature availability is diagnostic-only because ordinary stages cannot bind an AS through the current contract. |
| RT-08 | Callable shaders and complex executable SBT/function-table layouts | `ray_tracing` | `unsupported` | `unsupported` | Schema 2 has no callable artifact or record-payload contract; planning counts do not create callable regions or multiple program groups. |
| RT-09 | Motion, curves, and row-major advanced AS geometry | `ray_tracing` | `unsupported` | `unsupported` | No admitted keyframe/control-point/instance layout and no enabled Vulkan extension set preserve the full contract. |
| RT-10 | Metal 4 AS descriptor families | `ray_tracing` | `unsupported` | `not-applicable` | The current runtime owns classic AS descriptors and has no Metal 4 descriptor/resource-layout contract. |
| INT-01 | External memory/texture import and external synchronization | `interop` | `incomplete` | `incomplete` | Wrappers, plans, ownership validation, and matrix exist; OS/driver import and submit hooks do not. |
| INT-02 | Native handles | `native` | `native-exact` | `native-exact` | Borrowed escape hatch; lifetime and backend tagging are part of the contract. |
| INT-03 | Native command insertion | `native` | `incomplete` | `incomplete` | Public callback/gate exists; validated native command-handle lowering remains deferred. |
| DBG-01 | Object and encoder labels/markers | `command`, `diagnostics` | `native-exact` | `native-exact` | `gpu-smoke`; Vulkan requires debug utils. |
| DBG-02 | Command-buffer marker groups | `command` | `native-exact` | `incomplete` | Vulkan currently validates scope without a native command-buffer marker. |
| DBG-03 | Native capture | `diagnostics` | `native-exact` | `unsupported` | Metal developer-tools capture is opt-in; Vulkan capture is external-tool territory in the current contract. |

## Metal Source-Coverage Ledger

Period 45 established the source ledger; Periods 46-52 refined it to 111 units
by splitting exact query subsets, Period 47's portable targets from their
advanced remainders, and CPU-authored reusable commands from GPU-authored
mutation. Missing vkmtl concepts remain explicit `missing-contract` entries;
their presence in the ledger does not admit public API or claim execution.

| Source family | Current inventory state | Required action |
| --- | --- | --- |
| Core device, queues, command buffers, resources, render/compute/blit encoders | Audited | Executable common rows plus native synchronization, physical queue, lifecycle, and timed Metal presentation work completed in Period 48. |
| Pixel/vertex formats, texture types/views, sampler variants | Audited/incomplete | Period 47 closed the allocated common subset; unallocated native breadth stays explicit. |
| Heaps, placement resources, residency sets, sparse resources | Audited | Period 49 executes native placement heaps and closes residency/sparse execution as unsupported under the current handle-free mapping contract. |
| Argument buffers/tables and indirect command buffers | Audited | Period 50 executes classic argument-buffer/descriptor-indexing tables and CPU-authored reusable command lists. GPU mutation is explicitly unsupported; Metal 4 argument tables stay in Period 54. |
| Function constants, dynamic libraries, linked functions, function pointers | Audited | Period 46 completed numeric-ID function constants. Period 50 closes linked functions, stitching, and dynamic libraries unsupported under manifest schema 1; Period 52 closes RT function tables under the same artifact boundary. |
| Tessellation, object/mesh shaders, layered rendering, amplification | Audited | Period 51 executes Vulkan tessellation and mesh-only paths on both backends; task/object artifacts, advanced-stage bindings, and layered/amplified rendering are precisely unsupported under current contracts. |
| Tile shaders, imageblocks, raster-order groups, programmable blending | Audited | Period 51 closes these unsupported because the current pass/shader contracts cannot preserve their observable memory and ordering semantics. |
| Counter sample buffers, GPU timestamps, statistics, capture scopes | Audited/incomplete | Period 46 completed native timestamp/Boolean visibility subsets; Period 54 owns calibrated and device-specific counter breadth. |
| Ray tracing maintenance, function tables, motion, callable/intersection breadth | Audited | Period 52 executes ordinary AS maintenance/AABB/multi-source TLAS paths and closes the remaining advanced contracts precisely unsupported. |
| Fast resource loading / Metal I/O | Audited/missing-contract | Period 53 owns I/O and transfer composition. |
| Metal 4 command allocators, argument tables, pipeline datasets, flexible pipeline state | Audited/incomplete | Period 54 owns the new command/pipeline model. |
| External sharing, IOSurface, shared-event handles, platform handles | Audited/incomplete | Period 53 owns real imports and external synchronization; Period 48 covers only same-device native shared events. |
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

The source audit and Periods 46-52 are complete. The updated exactly-once gap
routing establishes Periods 53-54; Period 53 is next.
`period45/gap-backlog.md` records the remaining dependency order and
acceptance boundaries.
