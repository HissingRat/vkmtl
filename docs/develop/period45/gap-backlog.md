# Period 45 Native Semantic Gap Backlog

Status: accepted routing baseline.

The Metal semantic ledger contains 99 stable semantic units. At Period 45
closeout, 77 have at least one incomplete backend outcome. Every incomplete ID
is assigned exactly once in `gap-routing.tsv`.

Periods 46-50 refined broad query, common-workload, synchronization, memory,
binding, indirect-command, and artifact rows, so the current ledger contains
109 units and exactly-once routes 42 incomplete
IDs.

The periods below are implementation slices, not promises to add all source
concepts to the public API. Each period must apply the public API admission
rules and may close a row with an exact implementation or a precise unsupported
decision.

## Period 46: Native Queries, Counters, And Specialization

Priority: correctness and truthful diagnostics.

- [x] Native Metal/Vulkan Boolean occlusion allocation, encoding, resolve, and
  readback.
- [x] Capability-gated raw native GPU timestamp paths, with logical fallback
  kept distinct and duration calibration deliberately unclaimed.
- [x] Metal numeric-ID function-constant specialization for vertex, fragment,
  and compute stages.
- [x] Keep pipeline statistics typed unsupported because the current result
  shape cannot represent variable multi-counter results.
- [x] Reroute exact sample counts, pass-boundary sampling, device-specific
  counters/statistics, and shader log state to Period 54 after splitting the
  broad source rows.

Acceptance: complete. Metal physical evidence observed visible=1 and empty=0,
plus readback/resolve agreement and reset/reuse. Both backend implementations
keep native timestamp support behind device gates; the current Metal evidence
host correctly selected `logical_sequence` because its full sampling-point set
was unavailable.

## Period 47: Core Resource, Format, Render, And Compute Breadth

Status: complete.

Priority: common workload coverage.

- Native limits and memory property reporting needed by ordinary resources.
- Full format/vertex-format, texture view/swizzle, buffer-address, sampler, and
  storage/hazard mode decisions.
- Remaining render-pass attachments, bindings, dynamic raster states, compute
  binding/dispatch, managed-resource synchronization, and reflection breadth.

Acceptance: common Metal semantics are either exact on both backends or
capability-gated with precise typed unsupported outcomes.

## Period 48: Native Synchronization, Queues, And Presentation Timing

Status: complete.

Priority: cross-submit correctness.

- [x] Native Metal shared events and Vulkan timeline-semaphore mappings.
- [x] Physical compute/transfer queues, queue ownership, callbacks, and lifecycle
  status.
- [x] Scheduled/minimum-duration presentation semantics where backend support
  exists.

Acceptance: complete. Portable runtime emulation and native GPU synchronization
are reported as separate capabilities and evidence lanes. Physical Metal
transfer/readback exercised native timeline/shared-event submission, a separate
transfer queue, and callback-once behavior; timed presentation passed the Metal
pixel regression. Vulkan compilation and deterministic unit coverage passed;
physical Vulkan Period 48 evidence remains a useful follow-up, not an upgraded
claim beyond queried gates.

## Period 49: Native Heaps, Residency, Sparse Resources, And Memoryless

Status: complete.

Priority: production memory behavior and voxel-world prerequisites.

- [x] Heap-backed resource allocation and aliasing.
- [x] Close residency sets and sparse/tiled physical commits as unsupported
  under the current handle-free mapping contract.
- [x] Hardware memoryless attachment contract separated from the
  portable transient-lifetime hint.

Acceptance: complete. Physical Metal evidence covers placement-heap buffers and
textures, native budget/current-allocation reporting, and memoryless MSAA
resolve. Vulkan heap and memory-budget paths pass focused compilation/unit
coverage and remain device-query gated. Sparse/residency usable features stay
closed, so no planning-only voxel-world pressure claim is made.

## Period 50: Binding Tables, Indirect Commands, And Pipeline Persistence

Status: complete.

Priority: scalable submission and artifact reuse.

- [x] Execute classic Metal argument buffers and Vulkan descriptor-indexing
  tables through compatible render/compute pipeline layouts.
- [x] Execute CPU-authored reusable draw/dispatch lists through Metal ICBs or
  exact direct-command expansion, while keeping GPU mutation unsupported.
- [x] Consume/persist Metal binary archives and Vulkan pipeline caches; close
  parallel encoders and manifest-schema-1 dynamic linking as unsupported.
- [x] Reroute RT function tables to Period 52 and Metal 4 argument/view-pool
  semantics to Period 54.

Acceptance: complete. A physical Metal run sampled a 65-slot argument buffer,
executed a native reusable ICB draw, and consumed a persistent binary archive.
Vulkan descriptor indexing, direct-command expansion, and pipeline-cache
consumption have forced-build/unit evidence; physical Vulkan rerun remains
useful evidence rather than an upgraded claim.

## Period 51: Advanced Rasterization And Geometry

Priority: specialized rendering after the common path is complete.

- Tessellation and mesh/object/task executable pipelines.
- Variable rasterization rate, layered rendering, amplification, and logical
  attachment mapping.
- Tile shaders, imageblocks, raster-order groups, and programmable blending via
  exact Vulkan extensions/composition or precise unsupported decisions.

Acceptance: visible examples and device gates prove every enabled path.

## Period 52: Ray Tracing Breadth

Priority: complete the already executable RT vertical slice.

- Full AS geometry/motion families, update/refit/compaction, and size queries.
- Metal intersection/visible function tables, Vulkan ray query, callable and
  complex SBT layouts.
- Metal 4 AS descriptor parity.

Acceptance: native stress evidence covers each enabled maintenance and shader
table path.

## Period 53: External Interop, Metal I/O, And Device Topology

Priority: integration with larger applications.

- External memory/texture/event import and native command insertion.
- Metal I/O file/compression queues mapped to OS I/O plus Vulkan transfer work.
- Peer-device/device-group topology where a stable portable contract exists.

Acceptance: ownership, process/device scope, synchronization, and failure
behavior are exercised with real imported resources.

## Period 54: Metal 4 Command Model, Pipeline Datasets, Tensor, And ML

Priority: newest specialized Metal framework surface.

- Command allocators, reusable command buffers, argument tables, and explicit
  barriers.
- Flexible Metal 4 pipelines, compiler tasks, archives, binary functions, and
  pipeline dataset serialization.
- Tensor resources and machine-learning pipeline/encoder semantics.
- Exact occlusion sample counts and pass-boundary sample attachments.
- Non-timestamp/device-specific counters, pipeline statistics result shapes,
  timestamp calibration, and shader/function log state.

Acceptance: each semantic receives an exact Vulkan composition or an explicit
unsupported result; no broad Metal 4 feature flag substitutes for per-semantic
gates.

## Next Slice

Period 50 is complete. Scalable resource tables, CPU-authored reusable command
lists, and persistent driver pipeline artifacts are executable; GPU-authored
command mutation and manifest-schema-1 runtime linking are precisely
unsupported. 42 incomplete semantic units remain routed to Periods 51-54.
Period 51 is next.
