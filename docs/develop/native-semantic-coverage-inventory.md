# Native Semantic Coverage Inventory

Status: Period 56 complete, updated 2026-07-16. Vulkan legacy RT and corrected
canonical composition both have physical execution and visual-orientation
evidence.

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
source-driven detail in `data/metal-semantic-ledger.md`. Period 45 recorded
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
RT routes through executable paths or precise unsupported decisions. Period 53
executes same-device Metal raw-buffer/raw-texture and single-plane IOSurface
imports, reports selected-device topology on both backends, and closes external
synchronization, native insertion, Metal I/O/compression, and cross-device
execution precisely unsupported under the current contracts.
Period 54 closes the final 20 source-ledger routes: exact occlusion counting
executes on both backends, resource tables and explicit barriers preserve the
admitted Metal 4 observable semantics through existing compatibility layers,
and the remaining allocator/pipeline/dataset/tensor/ML/counter contracts are
precisely unsupported rather than exposed through a broad feature flag.
Period 55 makes the basic RT output contract composable: both backends write a
generic caller-owned accumulation texture, and the Vulkan lowering leaves it in
sampled layout. The `ray_traced_scene` example uses one shared
reference-preserving display path: it applies the sRGB EOTF to its reference
values, then lets the `bgra8_unorm_srgb` attachment perform the matching sRGB
encode. Tone mapping is application policy, not part of the vkmtl RT command or
backend semantic. Metal has a three-frame physical API Validation run plus an
offscreen shared-display readback with at most one byte of channel error. The
new shared-display Vulkan path now builds, submits, presents, and completes
three physical frames. Its first screenshot exposed a vertical composition
flip; after the fragment-position UV fix, the corrected Vulkan path completed
3000 frames with the established top-left orientation.
Period 56 makes presentation format resolution observable and deterministic.
`PresentationDescriptor.format` remains the request, while
`Swapchain.selectedFormat()` reports the concrete SDR BGRA8 selection. Metal
configures the layer from that selection; Vulkan chooses the exact standard-SDR
pair independent of enumeration order. Current-drawable pipelines require an
exact selected-format match. The legacy drawable RT command now dispatches
into the caller's linear BGRA8 output on both backends and performs only a raw
byte transfer to the selected linear or sRGB drawable. None of these operations
adds HDR, tone mapping, gamma, or gamut conversion. Unit, default-build, forced
Vulkan, and package-consumer evidence is complete. Physical Metal
automatic/sRGB/linear offscreen pixels plus selected-drawable bind/present
smoke and both legacy raw-copy formats are recorded under API Validation.
The descriptor extent remains the request while `Swapchain.extent()` reports
the actual native drawable extent. Healthy same-request resize is cheap;
present/acquire recovery forces rebuild, and changed requests re-query native
state. Vulkan resize and clear reject uncommitted command buffers before
mutation, clear owns a dedicated pool, and failed commits retire backend,
query, and serial state before temporary resources are destroyed. Metal
publishes resize only after depth allocation and preflights legacy drawable and
staging failures before compute dispatch. Legacy presentation is
graphics-queue-only. Destructive Vulkan recreation failure permanently loses
presentation, preventing stale framebuffer/image-view use. Normal and poisoned
Vulkan teardown wait graphics fences and the presentation queue before
destroying swapchain images, semaphores, or the swapchain handle.
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
| DEV-02 | Command queue/buffer creation, commit, lifecycle callbacks, immediate presentation, and capability-gated timing | `command`, `presentation` | `native-exact` | `composed-exact` | `gpu-pixels` on Metal for callback-once and minimum-duration presentation; Vulkan callbacks compose submit/queue completion and timed presentation remains feature-closed. Failed commits terminalize/deinitialize backend state, release active/query borrows, retire the work serial, and report failed lifecycle; Vulkan waits submitted work before temporary-resource destruction. |
| DEV-03 | No-surface runtime initialization with device/queues, presentation exclusion, and texture-backed offscreen commands | root, `command`, `render` | `native-exact` | `native-exact` | Metal `gpu-pixels` covers headless compute, transfer, and offscreen clear/readback. Vulkan has focused tests and forced-build evidence; the backend-private Windows loader opens `vulkan-1.dll` without relying on Zig 0.16's unsupported Windows `std.DynLib` branch, and the full `x86_64-windows` forced-Vulkan install graph cross-compiles. Physical Windows loader/device execution remains pending. Current-drawable commands fail before backend presentation work. |
| DEV-04 | Selected-device stable identity and native peer-group membership diagnostics | `diagnostics` | `native-exact` | `native-exact` | Physical Metal reports registry and peer-group properties. Vulkan reports device UUID plus selected physical-device-group index/count/subset allocation; neither backend claims peer allocation or cross-device command execution. |
| RES-01 | Buffer creation, upload, mapping, copy, and destruction | `resource`, `transfer` | `native-exact` | `native-exact` | `gpu-pixels` for representative upload/copy/readback. |
| RES-02 | 1D/2D/3D, array, cube, and multisample texture fundamentals | `resource` | `native-exact` | `native-exact` | `unit` plus representative `gpu-pixels`; full shape/format matrix remains unobserved. |
| RES-03 | Texture views with mip/layer ranges and exact current format | `resource` | `native-exact` | `native-exact` | `unit`; format reinterpretation is a separate incomplete semantic. |
| RES-04 | Sampler filtering, addressing, LOD, comparison, anisotropy, normalized/unnormalized coordinates, and fixed border color | `resource` | `native-exact` | `native-exact` | `unit`; unnormalized coordinates use the documented shared constraint set and device gates still apply. |
| RES-05 | Full-texture mipmap generation | `transfer` | `native-exact` | `native-exact` | `unit`; partial mip/layer ranges remain incomplete. |
| RES-06 | Finite portable texture/vertex formats and format capability queries | `resource`, `render` | `composed-exact` | `native-exact` | `unit` plus Period 55 Metal `gpu-pixels`; Period 47 covers the documented normalized, integer, floating-point, depth, stencil, and vertex-input set. Period 55 admits sampled-plus-storage `rgba16_float` as the capability-gated accumulation format used by `ray_traced_scene` on both backends; the format does not impose a color-space or tone-mapping contract on generic caller-owned RT output. Period 56 bounds presentation to `bgra8_unorm_srgb` and `bgra8_unorm`; Metal advertises presentation only for its selected layer format, and Vulkan selects the exact standard-SDR pair or returns typed unsupported rather than choosing an arbitrary fallback. Other native formats remain capability-gated or unsupported. |
| RES-07 | Capability-gated shader-visible buffer GPU address | `resource`, `diagnostics` | `native-exact` | `native-exact` | `gpu-smoke` on Apple M4 Pro plus Vulkan unit/inspection; callers declare `shader_device_address`, creation checks the usable feature, and zero/unavailable native addresses return typed errors. |
| RES-08 | Automatic/shared/managed/private portable storage behavior and CPU/GPU visibility boundaries | `resource`, `transfer` | `native-exact` | `composed-exact` | `gpu-pixels` on Metal plus Vulkan unit/inspection; Metal composes `didModifyRange` and `synchronizeResource`, Vulkan uses host-coherent managed buffers, and private CPU access is rejected. |
| PRS-01 | Bounded SDR presentation request/selection, requested-versus-actual extent, exact current-drawable pipeline matching, terminal-safe resize, and legacy raw-copy compatibility | `presentation`, `render`, `ray_tracing` | `composed-exact` | `composed-exact` | Period 56 keeps request and selection separate, maps the selected BGRA8 format to the Metal layer or exact Vulkan surface pair, and rejects mismatched drawable pipelines before native bind/draw. Metal publishes resize only after depth allocation. Vulkan keeps healthy same-request resize cheap, forces recovery after present/acquire invalidation, re-queries changed requests, gates non-zero resize and clear on zero active command buffers, and gives clear a dedicated pool; destructive recreation failure permanently returns `SurfaceLost`. Legacy drawable RT is graphics-queue-only, dispatches into caller linear BGRA8, copies bytes unchanged, presents implicitly, and rejects duplicate present; Metal preflights drawable/extent/staging before compute. Deterministic/build/package evidence is complete. Physical Metal automatic/sRGB/linear runs retain the documented offscreen-readback boundary and selected-drawable smoke; both legacy formats submit three frames under API Validation. Vulkan legacy raw copy submits three frames with correctly oriented visible output. After its fullscreen Y-flip fix, canonical Vulkan submits, presents, and completes 3000 frames with the same top-left orientation. No HDR, tone mapping, gamma, or gamut conversion is part of the contract. |
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
| BND-03 | Bindless tables, descriptor indexing, and argument/Metal 4 compatible tables | `binding` | `composed-exact` | `native-exact` | Metal `gpu-smoke` covers a 65-slot argument buffer plus explicit resource-use residency; Vulkan descriptor-indexing feature enablement, set allocation/update/binding, and compatible pipeline layouts have unit/forced-build evidence. Raw Metal 4 table identity is not promised. |
| CMP-01 | Compute pipeline, direct dispatch, and ceil-composed logical-thread dispatch | `compute` | `native-exact` | `native-exact` | `gpu-pixels` through deterministic compute readback; shaders own out-of-logical-grid bounds checks after ceil composition. |
| CMP-02 | Indirect compute dispatch and CPU-authored reusable dispatch lists | `compute`, `command` | `composed-exact` | `composed-exact` | `unit`; ordinary buffer-indirect dispatch is native, reusable slots use Metal ICB when available and exact direct dispatch expansion otherwise. GPU-authored mutation is excluded. |
| CMP-03 | 32-bit integer storage-buffer/threadgroup atomics and threadgroup memory within queried limits | `compute` | `native-exact` | `native-exact` | `gpu-pixels` on Metal proves deterministic atomic/shared-memory output; Vulkan has unit/compile evidence and core semantic inspection. Storage-texture and wider atomic families are not promised. |
| CMP-04 | Typed tensor resources and machine-learning pipeline/encoder execution | `missing-contract` | `unsupported` | `unsupported` | No portable tensor type/layout/view ownership, ML graph/pipeline, reflection, dispatch, or exact Vulkan mapping contract exists. Ordinary compute is not treated as equivalent ML execution. |
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
| CMD-01 | Separate reusable command allocator, resettable whole command buffers, commit options, feedback, and explicit residency lists | `missing-contract` | `unsupported` | `unsupported` | Current command buffers are one-shot and have no allocator/reset/reuse, residency-list, commit-option, or asynchronous feedback-result owner. |
| QRY-01 | Logical timestamp sequence and CPU/marker profiling fallback | `diagnostics` | `emulated-exact` | `emulated-exact` | `unit`; explicitly not GPU time. |
| QRY-02 | Capability-gated native GPU timestamp ticks, CPU readback, and GPU resolve | `diagnostics` | `native-exact` | `native-exact` | `unit`; Metal requires the common timestamp set plus draw/dispatch/blit sampling, Vulkan requires host reset plus graphics-queue timestamp bits. Tick-to-duration calibration remains outside this row. |
| QRY-03 | Boolean occlusion visibility, where zero is occluded and nonzero is visible | `diagnostics`, render encoder | `composed-exact` | `native-exact` | `gpu-smoke` on Metal plus unit/inspection for both mappings; Metal uses pass scratch plus canonical copy, Vulkan uses non-precise query pools. Vulkan physical rerun remains useful evidence, not a capability prerequisite. |
| QRY-04 | Pipeline statistics and multi-counter result shapes | `diagnostics` | `unsupported` | `unsupported` | `unit`; the current one-`u64`-per-query contract cannot represent typed variable multi-counter results, calibration, availability, and overflow, so the feature is explicitly closed. |
| QRY-05 | Exact rasterized sample counts | `diagnostics`, render encoder | `native-exact` | `native-exact` | Metal counting visibility and Vulkan precise occlusion queries share the same one-`u64` exact-count contract; device capability gates apply. |
| MEM-01 | Native placement heaps, heap-backed buffers/textures, exact requirements, and alias planning | `resource`, `diagnostics` | `native-exact` | `native-exact` | `gpu-pixels` on Metal plus unit/forced-Vulkan build; resources bind at validated reserved offsets and must be destroyed before the heap. Alias offset reuse remains caller-lifetime-controlled. |
| MEM-02 | Transient attachment lifetime semantic | `render` | `composed-exact` | `composed-exact` | The API treats transient as a lifetime/performance hint; a hardware memoryless guarantee is not currently exposed. |
| MEM-03 | Hardware memoryless attachment guarantee | `resource`, `render` | `native-exact` | `unsupported` | Metal native creation probe plus physical memoryless MSAA resolve. Vulkan lazily allocated memory cannot promise no physical backing; `transient` remains a separate hint. |
| MEM-04 | Native memory budget and pressure telemetry | `diagnostics` | `native-exact` | `native-exact` | Metal `gpu-smoke` reports recommended working set/current allocation; Vulkan uses queried `VK_EXT_memory_budget` device-local heaps and otherwise reports fallback. |
| MEM-05 | Native sparse/tiled resources, residency sets, and page binding | `resource`, `native` | `unsupported` | `unsupported` | Plans and churn maps remain deterministic, but current descriptors do not identify native resources. Usable sparse/residency features stay closed. |
| PRD-01 | Persistent driver render/compute pipeline artifacts | `diagnostics`, pipeline descriptors | `native-exact` | `native-exact` | Metal `gpu-smoke` consumes/populates/serializes `MTLBinaryArchive`; Vulkan consumes/persists `VkPipelineCache` with deterministic identity and stale-data recovery. |
| PRD-02 | Runtime native object and resource-view pooling | `missing-contract` | `unsupported` | `unsupported` | No lifetime-safe portable pool owner, eviction policy, or child-view invalidation contract exists. |
| PRD-03 | Metal 4 flexible pipelines, compiler/archive binary functions, and pipeline dataset serialization | `missing-contract` | `unsupported` | `unsupported` | The source-backed precompile contract has no runtime compiler task, binary link unit, flexible pipeline object graph, or cross-backend dataset schema. Ordinary driver caches remain PRD-01. |
| SHD-04 | Function logs plus tensor/payload/table/advanced-threadgroup reflection | `missing-contract` | `unsupported` | `unsupported` | Function-log callback/container lifetime and advanced binding owners are absent; the supported portable reflection subset remains SHD-02. |

### Advanced Geometry, Ray Tracing, Interop, And Diagnostics

| ID | Semantic contract | Public owner | Metal | Vulkan | Evidence / current gap |
| --- | --- | --- | --- | --- | --- |
| GEO-01 | Tessellation pipeline and patch draw under the source-only artifact contract | `render` | `unsupported` | `native-exact` | Vulkan compiles schema-2 SPIR-V, enables tessellation, creates patch-list pipelines, and draws patches. The pinned Slang Metal target rejects hull/domain stages. |
| GEO-02 | Resource-free mesh pipeline and dispatch; optional task/object stage separately gated | `render` | `native-exact` | `native-exact` | Physical Metal mesh rendering plus Vulkan forced-build/unit evidence. Pinned task/object compilation crashes, so usable task support stays false on both backends. |
| RT-01 | Basic native acceleration structure, RT pipeline, caller-owned texture dispatch, and presentation | `ray_tracing` | `native-exact` | `native-exact` | Period 55 writes a generic caller-owned accumulation texture on both backends and leaves Vulkan output ready for fragment sampling. The `ray_traced_scene` fullscreen pass applies the sRGB EOTF to its reference values before the explicitly requested `bgra8_unorm_srgb` attachment performs the matching encode, preserving the established display bytes without making that transform a vkmtl RT semantic. Period 56 keeps this texture-plus-composition path canonical and makes legacy drawable dispatch use the caller's `bgra8_unorm` output followed by a raw byte transfer on both backends. Metal API Validation covers the canonical route plus three-frame legacy sRGB and linear runs with `trace_driver_submitted=true`. Vulkan canonical and legacy routes both build, submit, present, and finish; legacy visual orientation passes, and corrected canonical composition completed 3000 frames with the same top-left orientation. Device and format capability gates apply. |
| RT-02 | Mesh BLAS/TLAS scene execution | `ray_tracing` | `native-exact` | `native-exact` | Metal physical evidence includes a TLAS over two distinct BLAS sources; Vulkan supports the same source array. Non-default instance metadata is outside the executable contract. |
| RT-03 | Triangle and AABB BLAS geometry input | `ray_tracing` | `native-exact` | `native-exact` | Physical Metal headless evidence builds both forms. Metal AS allocation takes the maximum of triangle/AABB and ordinary/update native sizes, while command validation uses the selected plan's exact scratch size. For the current Vulkan single-geometry sizing templates, allocation likewise takes the component maximum across triangle/AABB geometry and all four update/compaction combinations because native build-size queries are not monotonic across flags; the first Period 56 Windows reruns exposed the earlier combined-flags upper-bound assumption before driver submission, and both post-fix routes subsequently built BLAS/TLAS objects and submitted RT work. Descriptor-exact sizing for arbitrary multi-geometry arrays is not established by this fix and remains a separate follow-up. Vulkan procedural scene evidence exercises AABB input. |
| RT-04 | Custom intersection execution | `ray_tracing` | `unsupported` | `native-exact` | Vulkan procedural pixels are observed. Metal schema-2 artifacts have no linked intersection function or driver-bound table. |
| RT-05 | AS build-update, update/refit, and compact copy | `ray_tracing` | `native-exact` | `native-exact` | Metal physical stress covers 32 alternating maintenance operations plus compact copy. Vulkan uses native update and compact-copy commands with unit/forced-build evidence. |
| RT-06 | Post-build compacted-size query and result ownership | `ray_tracing` | `unsupported` | `unsupported` | Build/update sizing is native-query-backed for the admitted single-geometry execution paths; descriptor-exact Vulkan sizing for arbitrary multi-geometry arrays remains follow-up. No public asynchronous post-build compact-size result contract exists. |
| RT-07 | Ray query from ordinary compute/render stages | `ray_tracing` | `unsupported` | `unsupported` | Metal has no identical inline-query contract. Vulkan extension/feature availability is diagnostic-only because ordinary stages cannot bind an AS through the current contract. |
| RT-08 | Callable shaders and complex executable SBT/function-table layouts | `ray_tracing` | `unsupported` | `unsupported` | Schema 2 has no callable artifact or record-payload contract; planning counts do not create callable regions or multiple program groups. |
| RT-09 | Motion, curves, and row-major advanced AS geometry | `ray_tracing` | `unsupported` | `unsupported` | No admitted keyframe/control-point/instance layout and no enabled Vulkan extension set preserve the full contract. |
| RT-10 | Metal 4 AS descriptor families | `ray_tracing` | `unsupported` | `not-applicable` | The current runtime owns classic AS descriptors and has no Metal 4 descriptor/resource-layout contract. |
| INT-01 | External buffer/texture import into ordinary resource execution | `interop` | `native-exact` | `unsupported` | Physical Metal readback covers borrowed raw `MTLBuffer` and single-plane IOSurface imports; raw `MTLTexture` uses the same validated wrapper path. Vulkan import remains closed until descriptors carry complete allocation/image/handle-consumption metadata. |
| INT-02 | Native handles | `native` | `native-exact` | `native-exact` | Borrowed escape hatch; lifetime and backend tagging are part of the contract. |
| INT-03 | Native command insertion | `native` | `unsupported` | `unsupported` | The callback has context device/queue handles but no active native command-buffer/encoder handle; the usable feature remains false. |
| INT-04 | External semaphore/event import and submit synchronization | `interop` | `unsupported` | `unsupported` | Current wait/signal arrays lack payload values and binary/timeline import ownership rules. Planning and native handle availability do not submit external synchronization. |
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
| Pixel/vertex formats, texture types/views, sampler variants | Audited/incomplete | Period 47 closed the allocated common subset; Period 55 exercises sampled-plus-storage `rgba16_float` as the `ray_traced_scene` accumulation target without assigning generic RT output a fixed color space. Period 56 makes the selected SDR BGRA8 presentation format observable and exact without adding a content transform. Unallocated native breadth stays explicit. |
| Heaps, placement resources, residency sets, sparse resources | Audited | Period 49 executes native placement heaps and closes residency/sparse execution as unsupported under the current handle-free mapping contract. |
| Argument buffers/tables and indirect command buffers | Audited | Period 50 executes resource tables and CPU-authored reusable command lists. Period 54 confirms the admitted Metal 4 table semantics are composed through that layer; raw table identity and GPU mutation remain unsupported. |
| Function constants, dynamic libraries, linked functions, function pointers | Audited | Period 46 completed numeric-ID function constants. Period 50 closes linked functions, stitching, and dynamic libraries unsupported under manifest schema 1; Period 52 closes RT function tables under the same artifact boundary. |
| Tessellation, object/mesh shaders, layered rendering, amplification | Audited | Period 51 executes Vulkan tessellation and mesh-only paths on both backends; task/object artifacts, advanced-stage bindings, and layered/amplified rendering are precisely unsupported under current contracts. |
| Tile shaders, imageblocks, raster-order groups, programmable blending | Audited | Period 51 closes these unsupported because the current pass/shader contracts cannot preserve their observable memory and ordering semantics. |
| Counter sample buffers, GPU timestamps, statistics, capture scopes | Audited | Period 46 completed native timestamp/Boolean visibility; Period 54 adds exact-count visibility and closes pass attachments, calibration, counter heaps, pipeline statistics, device-specific counters, and function logs unsupported under current result/lifetime shapes. |
| Ray tracing maintenance, function tables, motion, callable/intersection breadth | Audited | Period 52 executes ordinary AS maintenance/AABB/multi-source TLAS paths and closes the remaining advanced contracts precisely unsupported. Period 55 adds caller-owned texture dispatch plus the `ray_traced_scene` reference-preserving shared display path. Period 56 makes the legacy drawable route honor the caller output and raw-copy bytes without reopening advanced routes or assigning color conversion to vkmtl. |
| Fast resource loading / Metal I/O | Audited | Period 53 closes MTLIO and compressed-stream execution unsupported: synchronous file reads/staging do not preserve async status, cancellation, priority, queue ordering, or scratch/compression semantics. |
| Metal 4 command allocators, argument tables, pipeline datasets, flexible pipeline state | Audited | Resource-table and barrier effects compose exactly through existing contracts. Allocator/reusable-buffer/feedback, flexible-pipeline, compiler/archive/dataset, tensor, and ML object models are precisely unsupported. |
| External sharing, IOSurface, shared-event handles, platform handles | Audited | Period 53 executes Metal raw resource and IOSurface imports. Export and external synchronization remain precisely unsupported; Period 48 covers only vkmtl-owned same-device native shared events. |
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

The source audit and Periods 46-56 are complete. Metal
automatic/sRGB/linear offscreen pixels plus selected-drawable smoke and both
legacy formats are recorded for Period 56. Vulkan legacy raw-copy physical
evidence and the corrected canonical 3000-frame visual run are recorded. The
exactly-once gap-routing file is empty because all 111
audited Metal semantic units now have an
executable or precise unsupported outcome. New native-semantic implementation
periods must be created from a new SDK/baseline audit or an explicit decision
to allocate one of the currently unsupported contracts; no incomplete Period
45 route remains. Application-level workload periods such as Period 19 may
exercise the closed surface without creating a semantic route in advance.
