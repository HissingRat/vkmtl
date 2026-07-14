# Period 45 Native Semantic Gap Backlog

Status: accepted routing baseline.

The Metal semantic ledger contains 99 stable semantic units. At Period 45
closeout, 77 have at least one incomplete backend outcome. Every incomplete ID
is assigned exactly once in `gap-routing.tsv`.

Periods 46-53 refined broad query, common-workload, synchronization, memory,
binding, indirect-command, artifact, advanced-raster, ray-tracing, interop,
I/O, and topology rows. The current ledger retains an exact-once route for
every remaining incomplete ID.

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

Status: complete.

Priority: specialized rendering after the common path is complete.

- [x] Execute Vulkan tessellation and mesh-only Metal/Vulkan pipelines.
- [x] Keep task/object artifacts and advanced-stage resource binding closed at
  their pinned-compiler/public-visibility boundaries.
- [x] Close variable-rate maps, layered amplification, logical attachment
  mapping, tile/imageblock memory, raster ordering, programmable blending,
  depth clip, and sample positions with precise unsupported decisions.

Acceptance: complete. A visible public Metal mesh run and forced Vulkan
build/unit evidence prove the enabled paths; unsupported rows retain no usable
feature flag.

## Period 52: Ray Tracing Breadth

Status: complete.

Priority: complete the already executable RT vertical slice.

- [x] Execute ordinary triangle/AABB/instance geometry plus
  update/refit/compaction commands and exact build/update size queries.
- [x] Close compacted-size query, function/intersection tables, Vulkan ray
  query execution, callable/complex SBT execution, motion/curves, and Metal 4
  AS descriptors precisely.
- [x] Record headless physical Metal maintenance/AABB/multi-instance evidence
  and the exact Vulkan RT-machine rerun command.

Acceptance: complete. Native Metal stress covers each enabled maintenance and
ordinary geometry path. No shader-table path is enabled without a driver-bound
artifact/table implementation.

## Period 53: External Interop, Metal I/O, And Device Topology

Status: complete.

Priority: integration with larger applications.

- [x] Execute same-device Metal buffer/texture and single-plane IOSurface
  imports through ordinary vkmtl resources.
- [x] Report Metal/Vulkan selected-device identity and native peer-group
  membership without claiming cross-device execution.
- [x] Close external synchronization, native insertion, Metal I/O/compression,
  and cross-device execution precisely unsupported under the current shapes.

Acceptance: complete. Borrowed Metal buffer, raw texture, and IOSurface owners
survived real GPU copy/readback, device topology was queried physically, and missing
synchronization/I/O/insertion state is documented rather than approximated.

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

Periods 52-53 are complete. Remaining incomplete semantic units are routed
exactly once to Period 54, which is the next slice.
