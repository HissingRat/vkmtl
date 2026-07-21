# Native Semantic Coverage Inventory

Status: Period 56 plus the post-Period-56 RT resource-binding and voxel PTGI
slice complete, updated 2026-07-21. Vulkan legacy RT and corrected canonical
composition both have physical execution and visual-orientation evidence.
General raster-coordinate physical Vulkan evidence passes. The material-bound
PTGI path has Metal physical execution; Vulkan has build, focused-test, and
forced-compile validation only for this new path. A first Windows RTX attempt
selected the Vulkan hybrid path and loaded all shaders but exposed an
example-startup sampled-image transition error before the first streamed
chunk. A follow-up interactive Windows RTX rerun no longer reproduced that
startup failure after the guard; bounded PTGI pixel evidence remains pending.
The current Metal PTGI records are dirty-source development snapshots, not
exact release-commit evidence.

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
Post-Period-56 physical Vulkan voxel pressure on commit `7d88ffe` satisfied its
resource/work bounds but exposed that ordinary geometry rasterization still
used Vulkan's opposite clip-space Y orientation. The backend now lowers the
portable positive-height, top-left viewport to an adjusted negative-height
Vulkan viewport while retaining direct winding names. Metal now lowers the
existing winding and cull descriptors into native encoder state rather than
relying on native defaults. An asymmetric back-culled triangle readback guards
the top/bottom and facing contract. Physical Metal and Vulkan both report
top-left raster/composition orientation; the corrected Vulkan run returned
zero channel delta and all three voxel profiles drained pending work within
their 9/81/289 resident bounds.
The historical pre-PTGI textured hybrid-RT voxel slice preserved those bounds and added a
deterministic seven-tile atlas, indexed per-chunk triangle BLAS objects, a
then-nearest-49-instance TLAS, and full-resolution sun/sky visibility consumed by
the raster pass. Metal API Validation and deterministic readback prove native
instance traversal and nontrivial visibility. Metal compute dispatch now
declares the bound TLAS and every BLAS referenced indirectly by that TLAS as
read resources, preserving native residency throughout longer runs. Finite
validation reads visibility after pending work drains and again on the final
frame; a 300-frame Metal soak retained non-zero hit and occlusion counts.
Vulkan shader/build/unit evidence passes, but a physical Vulkan hybrid run has
not yet been recorded.
The subsequent RT resource-binding slice reuses one ordinary bind group for
application buffers, textures, and samplers. Metal lowers it to compute-kernel
slots and Vulkan lowers it to the RT descriptor set; bindings 0/1/2 remain
reserved for the AS, primary output, and inline data, while the application
range is 3 through 14. The voxel example uses that contract for a
material-aware `rgba16_float` hardware-RT result with one path of at most three
sequential cosine-weighted diffuse segments per covered opaque pixel per frame,
temporal accumulation with rejection and clamping, and four edge-aware a-trous
passes before an independently authored fixed-exposure presentation. Every
path hit performs independent sun/moon next-event estimation, albedo propagates
throughput, and terminal residual environment is added once. Water keeps a
separate one-segment specular reflection. Ray generation traces sequentially
with native recursion depth one; this is example policy, not a new public or
native RT semantic. The `primary_rays` diagnostic counts dispatch threads, not
the additional path segments. Example-private frame data carries nonzero x/z
chunk bounds only after the published TLAS contains the complete contiguous
square for the active profile. Initial and moving sparse subsets publish zero
extent, disabling diffuse-miss environment. Once complete, residual environment
and the outer-edge blend are admitted only for a path confirmed to cross
terrain top before a horizontal side; side misses contribute nothing and
cannot leak later-bounce sky light. Camera, lighting, resize, and source
discontinuities reset history; an outer 16-block band blends bounded indirect
lighting back to the current sky environment only for a confirmed terrain-top
exit. Finite acceptance rejects
non-finite or negative raw/reconstructed radiance and requires nonzero direct,
shadowed, indirect, and reconstructed pixels. The current bounded TLAS covers the complete
17 x 17 resident neighborhood (up to 289 instances), and secondary hits read
an exact material-column volume produced by the CPU terrain sampler. The SEUS
package was a visual-strategy reference
only: no source, shader organization, constants, or assets were copied, and no
pixel identity is claimed. The clean-room experimental three-bounce refinement
does not claim that default SEUS PTGI E12 uses three bounces. Metal API
Validation physically executes complete 9- and 169-source smoke/default
neighborhoods with `ptgi_bounces=3` on an Apple M4 Pro; the source
bound remains 289. Vulkan unit/build/compile validation proves only the
mapping and must not be reported as physical PTGI execution.
The wider default neighborhood is fed by an example-private scheduler: one CPU
mesh worker holds at most one ticket, rejects stale results, and falls back to
synchronous meshing if worker startup fails. Interactive/finite admission is
one/two completed meshes per frame under the existing 8 MiB upload limit. GPU
upload, BLAS build, and command submission remain synchronous. TLAS publication
normally batches four frames, with bootstrap, drain, and replacement forcing an
immediate rebuild and old BLAS owners retiring only after replacement
publication. This is workload policy, not a new semantic row or a change to
the synchronous command-buffer contract.
The additive headless slice creates real Metal/Vulkan device and queue owners
without presentation objects. Metal has physical compute, transfer, and
texture-backed offscreen evidence. The same `7d88ffe` Windows Vulkan run
created a real NVIDIA GeForce RTX 5080 device and completed transfer, compute,
texture-backed render readback, native query, and reset/reuse checks; this is
historical evidence and not a substitute for an exact future release commit.
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
| DEV-03 | No-surface runtime initialization with device/queues, presentation exclusion, and texture-backed offscreen commands | root, `command`, `render` | `native-exact` | `native-exact` | Metal `gpu-pixels` covers headless compute, transfer, and offscreen clear/readback. On clean commit `7d88ffe`, physical Windows Vulkan loaded `vulkan-1.dll`, selected an NVIDIA GeForce RTX 5080, and completed HeadlessContext transfer, compute, and offscreen readback. Focused tests and the full forced `x86_64-windows` install graph cover the backend-private loader and stubs. Current-drawable commands fail before backend presentation work. |
| DEV-04 | Selected-device stable identity and native peer-group membership diagnostics | `diagnostics` | `native-exact` | `native-exact` | Physical Metal reports registry and peer-group properties. Vulkan reports device UUID plus selected physical-device-group index/count/subset allocation; neither backend claims peer allocation or cross-device command execution. |
| RES-01 | Buffer creation, upload, mapping, copy, and destruction | `resource`, `transfer` | `native-exact` | `native-exact` | `gpu-pixels` for representative upload/copy/readback. |
| RES-02 | 1D/2D/3D, array, cube, and multisample texture fundamentals | `resource` | `native-exact` | `native-exact` | `unit` plus representative `gpu-pixels`; full shape/format matrix remains unobserved. |
| RES-03 | Texture views with mip/layer ranges and exact current format | `resource` | `native-exact` | `native-exact` | `unit`; format reinterpretation is a separate incomplete semantic. |
| RES-04 | Sampler filtering, addressing, LOD, comparison, anisotropy, normalized/unnormalized coordinates, and fixed border color | `resource` | `native-exact` | `native-exact` | `unit`; unnormalized coordinates use the documented shared constraint set and device gates still apply. |
| RES-05 | Full-texture mipmap generation | `transfer` | `native-exact` | `native-exact` | `unit`; partial mip/layer ranges remain incomplete. |
| RES-06 | Finite portable texture/vertex formats and format capability queries | `resource`, `render` | `composed-exact` | `native-exact` | `unit` plus Period 55 Metal `gpu-pixels`; Period 47 covers the documented normalized, integer, floating-point, depth, stencil, and vertex-input set. Period 55 admits sampled-plus-storage `rgba16_float` as the capability-gated accumulation format used by `ray_traced_scene` on both backends; the post-Period-56 voxel PTGI example reuses that gate for scene-linear radiance. The format imposes no color-space, exposure, or tone-mapping contract on generic caller-owned RT output. Period 56 bounds presentation to `bgra8_unorm_srgb` and `bgra8_unorm`; Metal advertises presentation only for its selected layer format, and Vulkan selects the exact standard-SDR pair or returns typed unsupported rather than choosing an arbitrary fallback. Other native formats remain capability-gated or unsupported. |
| RES-07 | Capability-gated shader-visible buffer GPU address | `resource`, `diagnostics` | `native-exact` | `native-exact` | `gpu-smoke` on Apple M4 Pro plus Vulkan unit/inspection; callers declare `shader_device_address`, creation checks the usable feature, and zero/unavailable native addresses return typed errors. |
| RES-08 | Automatic/shared/managed/private portable storage behavior and CPU/GPU visibility boundaries | `resource`, `transfer` | `native-exact` | `composed-exact` | `gpu-pixels` on Metal plus Vulkan unit/inspection; Metal composes `didModifyRange` and `synchronizeResource`, Vulkan uses host-coherent managed buffers, and private CPU access is rejected. |
| PRS-01 | Bounded SDR presentation request/selection, requested-versus-actual extent, exact current-drawable pipeline matching, terminal-safe resize, and legacy raw-copy compatibility | `presentation`, `render`, `ray_tracing` | `composed-exact` | `composed-exact` | Period 56 keeps request and selection separate, maps the selected BGRA8 format to the Metal layer or exact Vulkan surface pair, and rejects mismatched drawable pipelines before native bind/draw. Metal publishes resize only after depth allocation. Vulkan keeps healthy same-request resize cheap, forces recovery after present/acquire invalidation, re-queries changed requests, gates non-zero resize and clear on zero active command buffers, and gives clear a dedicated pool; destructive recreation failure permanently returns `SurfaceLost`. Legacy drawable RT is graphics-queue-only, dispatches into caller linear BGRA8, copies bytes unchanged, presents implicitly, and rejects duplicate present; Metal preflights drawable/extent/staging before compute. Deterministic/build/package evidence is complete. Physical Metal automatic/sRGB/linear runs retain the documented offscreen-readback boundary and selected-drawable smoke; both legacy formats submit three frames under API Validation. Vulkan legacy raw copy submits three frames with correctly oriented visible output. After its fullscreen Y-flip fix, canonical Vulkan submits, presents, and completes 3000 frames with the same top-left orientation. No HDR, tone mapping, gamma, or gamut conversion is part of the contract. |
| SHD-01 | Build-time Slang compilation and embedded runtime shader resolution | `shader` | `composed-exact` | `composed-exact` | Hosted build and `gpu-pixels`; MSL and SPIR-V are produced before runtime. |
| SHD-02 | Reflection-derived buffer/texture/sampler kinds, arrays, storage access, and vertex metadata | `shader`, `binding`, `render` | `composed-exact` | `composed-exact` | `unit` and representative rendering; schema 1 keeps advanced backend-only protocols outside the portable metadata. |
| SHD-03 | Shader specialization constants/function constants by stable numeric ID | `shader` | `native-exact` | `native-exact` | `gpu-pixels` on Metal plus unit coverage for both mappings; Metal specializes vertex, fragment, and compute functions, while Vulkan uses specialization info. Generated names are diagnostic only. |

### Rendering, Binding, Compute, And Transfer

| ID | Semantic contract | Public owner | Metal | Vulkan | Evidence / current gap |
| --- | --- | --- | --- | --- | --- |
| REN-01 | Metal-like clip/NDC Y, positive top-left public viewport/scissor, winding/cull parity, render pipelines, indexed/direct draw, depth, stencil, and blend | `render` | `native-exact` | `native-exact` | Metal sets native viewport, winding, and cull encoder state. Vulkan lowers to `y + height` and negative native height (core 1.1 or `VK_KHR_maintenance1`) while keeping winding names direct. Unit lowering checks plus an asymmetric counter-clockwise, back-culled top/bottom readback cover the contract. Physical Metal and Vulkan both pass; Vulkan reports zero channel delta and both top-left orientation markers. |
| REN-02 | MRT, offscreen targets, MSAA color resolve | `render` | `native-exact` | `native-exact` | `unit` and representative `gpu-pixels`. |
| REN-03 | Base vertex/base instance and instance step rate | `render` | `native-exact` | `native-exact` | `unit`; Vulkan divisor support is capability-gated. |
| REN-04 | Indirect/explicit multi-draw and CPU-authored reusable draw lists | `render`, `command` | `composed-exact` | `composed-exact` | `gpu-smoke` on Metal for native ICB execution; Vulkan and Metal paths whose active shader pipeline is not ICB-compatible expand immutable commands into repeated native draws. GPU-authored mutation is excluded. |
| REN-05 | Wireframe/line fill and depth bias | `render` | `native-exact` | `native-exact` | `unit`; native capability gates apply. |
| REN-06 | Conservative rasterization | `render` | `incomplete` | `incomplete` | Public capability exists, but complete lowering/evidence is absent. |
| REN-07 | Depth/stencil resolve and texture-view format reinterpretation | `render`, `resource` | `incomplete` | `incomplete` | Compatible linear/sRGB texture views and component swizzles are native-exact in Period 47; depth/stencil resolve remains typed unsupported. |
| BND-01 | Ordinary render/compute bind groups, dynamic offsets, resource arrays | `binding` | `composed-exact` | `native-exact` | `unit` and representative render/compute `gpu-pixels`. Vulkan generically transitions sampled/storage textures before compute dispatch and render sampling, covers arrays and storage access masks, and makes compute writes visible to downstream shader stages. The new barrier route has focused/unit and forced-build evidence; its physical Vulkan refresh remains pending. |
| BND-02 | Root/small constants | `binding` | `native-exact` | `native-exact` | `unit`; Metal bytes and Vulkan push-constant lowering are backend-specific. |
| BND-03 | Bindless tables, descriptor indexing, and argument/Metal 4 compatible tables | `binding` | `composed-exact` | `native-exact` | Metal `gpu-smoke` covers a 65-slot argument buffer plus explicit resource-use residency; Vulkan descriptor-indexing feature enablement, set allocation/update/binding, and compatible pipeline layouts have unit/forced-build evidence. Raw Metal 4 table identity is not promised. |
| BND-04 | One bounded RT application bind group over ordinary buffers, textures, samplers, and fixed resource arrays | `binding`, `ray_tracing` | `native-exact` | `native-exact` | Bindings 0/1/2 are reserved for AS/output/inline data; one group uses 3-14 without dynamic offsets. Metal lowers the group to compute-kernel buffer/texture/sampler slots and physically executes the material-column buffer, atlas texture, and sampler route under API Validation. The build-time shader path uses Slang Metal target reflection to normalize generated MSL resource namespaces back to vkmtl logical slots and fails conflicts instead of relying on target compaction; fixed arrays have reflection/unit evidence rather than physical PTGI coverage. Vulkan lowers the RT group to its descriptor set and currently has focused unit, full-build, and forced-compile validation for the new route. A first Windows RTX attempt reached hybrid selection and shader loading but an example startup frame bound undefined PTGI scratch after its render pass had begun, so no dispatch/pixel evidence was produced. A follow-up interactive rerun no longer reproduced the startup failure after the guard; bounded PTGI dispatch/pixel evidence remains pending. |
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
| RT-01 | Basic native acceleration structure, RT pipeline, optional application resources, caller-owned texture dispatch, and presentation | `ray_tracing`, `binding` | `native-exact` | `native-exact` | Period 55 writes a generic caller-owned accumulation texture and Period 56 preserves canonical composition plus raw-copy legacy presentation without assigning color conversion to vkmtl. The later bounded bind group lets RT shaders read application material data and write auxiliary resources under BND-04. The voxel example now writes full-resolution `rgba16_float` material-aware radiance and direct visibility, launches one example-private diffuse path of at most three sequential cosine-weighted segments per covered opaque pixel, performs independent sun/moon next-event estimation at each hit, propagates throughput by albedo, and adds terminal residual environment once. Its frame data publishes nonzero x/z bounds only for a complete contiguous active-profile TLAS square; sparse initial/moving subsets use zero extent. Residual environment and the outer-edge blend require confirmed terrain-top escape, so side misses add nothing and cannot leak later-bounce sky light. Water reflection remains one segment. Ray generation traces sequentially with pipeline recursion depth one, so this does not add recursive-shader or public RT semantics. Temporal and four-pass a-trous reconstruction remain outside the RT command. Metal API Validation physically executes that material-bound path and its finite acceptance rejects invalid raw/reconstructed radiance while requiring nonzero direct and indirect results. Vulkan canonical and legacy RT retain earlier physical evidence. The new bind-group/PTGI route has build, unit, and forced-compile evidence; its first Windows RTX startup attempt selected the route but failed before dispatch because the example tried to bind undefined PTGI scratch inside an active render pass. A follow-up interactive rerun no longer reproduced that failure after the guard; bounded physical PTGI pixel evidence is still pending. Device, format, resource-usage, layout, and lifetime gates apply. |
| RT-02 | Mesh BLAS/TLAS scene execution | `ray_tracing` | `native-exact` | `native-exact` | The voxel slice executes indexed per-chunk triangle BLAS objects and a TLAS covering the complete bounded 17 x 17 resident neighborhood, up to 289 sources. Vulkan instance storage covers the complete primitive count and supports either one repeated source or exactly N sources. Each Metal AS wrapper retains the build and traversal state needed for later maintenance and dispatch. TLAS source/instance replacement is transactional: failure restores the prior descriptor sources and instance contents, while successful build/update publishes the replacement state. Dispatch declares the TLAS plus its complete indirect BLAS set as read resources; pipeline-reflected AS kind is checked separately. Current physical Metal PTGI evidence covers complete 9/169-source smoke/default neighborhoods and is recorded in `validation.md`; 289 remains the executable source bound rather than a physical observation in this slice. Physical Vulkan evidence for this exact material-bound workload remains pending; earlier Vulkan multi-source and ordinary RT evidence still supports the semantic status. Non-default instance metadata remains outside the executable contract. |
| RT-03 | Triangle and AABB BLAS geometry input | `ray_tracing` | `native-exact` | `native-exact` | Physical Metal evidence builds both forms and now includes indexed voxel triangles. Metal queries the real selected geometry descriptor, reserves the component maximum of ordinary/refit sizes, expands the result allocation when final geometry requires it, and rechecks final scratch capacity after TLAS sources are attached. Vulkan allocation takes the component maximum across triangle/AABB geometry and update/compaction variants; the voxel correction also makes indexed triangle primitive counts and TLAS instance allocation exact. Descriptor-exact Vulkan sizing for arbitrary multi-geometry arrays remains a separate follow-up. Vulkan procedural scene evidence exercises AABB input; physical Vulkan hybrid voxel execution is pending. |
| RT-04 | Custom intersection execution | `ray_tracing` | `unsupported` | `native-exact` | Vulkan procedural pixels are observed. Metal schema-2 artifacts have no linked intersection function or driver-bound table. |
| RT-05 | AS build-update, update/refit, and compact copy | `ray_tracing` | `native-exact` | `native-exact` | Metal physical stress covers 32 alternating maintenance operations plus compact copy. Metal TLAS build/update commits wrapper state transactionally, and TLAS compact copy propagates the complete descriptor, backing-resource, traversal-dependency, and update-sizing state required for later maintenance and dispatch. Vulkan uses native update and compact-copy commands with unit/forced-build evidence. |
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

The source audit, Periods 46-56, and the post-Period-56 RT resource-binding and
voxel PTGI implementation are complete. Metal
automatic/sRGB/linear offscreen pixels plus selected-drawable smoke and both
legacy formats are recorded for Period 56. Vulkan legacy raw-copy physical
evidence and the corrected canonical 3000-frame visual run are recorded. The
general raster-coordinate correction has deterministic and physical Metal
evidence. Corrected physical Vulkan asymmetric-raster and smoke/default/stress
voxel raster evidence is also recorded. The material-bound PTGI route has
physical Metal execution. Its Vulkan physical smoke/default lane and the
future exact-release-commit refresh are still needed; unit, build, and forced-
compile validation are not substitutes. The exactly-once gap-routing file is
empty because all 111 audited Metal semantic units now have an executable or
precise unsupported outcome. New native-semantic implementation
periods must be created from a new SDK/baseline audit or an explicit decision
to allocate one of the currently unsupported contracts; no incomplete Period
45 route remains. Application-level workload periods such as Period 19 may
exercise the closed surface without creating a semantic route in advance.
