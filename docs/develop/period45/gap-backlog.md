# Period 45 Native Semantic Gap Backlog

Status: accepted routing baseline.

The Metal semantic ledger contains 99 stable semantic units. At Period 45
closeout, 77 have at least one incomplete backend outcome. Every incomplete ID
is assigned exactly once in `gap-routing.tsv`.

Periods 46-47 refined broad query and common-workload rows, so the current
ledger contains 107 units and exactly-once routes 81 incomplete IDs.

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

Priority: common workload coverage.

- Native limits and memory property reporting needed by ordinary resources.
- Full format/vertex-format, texture view/swizzle, buffer-address, sampler, and
  storage/hazard mode decisions.
- Remaining render-pass attachments, bindings, dynamic raster states, compute
  binding/dispatch, managed-resource synchronization, and reflection breadth.

Acceptance: common Metal semantics are either exact on both backends or
capability-gated with precise typed unsupported outcomes.

## Period 48: Native Synchronization, Queues, And Presentation Timing

Priority: cross-submit correctness.

- Native Metal fences/events/shared events and Vulkan semaphore/fence mappings.
- Physical compute/transfer queues, queue ownership, callbacks, and lifecycle
  status.
- Scheduled/minimum-duration presentation semantics where backend support
  exists.

Acceptance: portable runtime emulation and native GPU synchronization are
reported as separate capabilities and evidence lanes.

## Period 49: Native Heaps, Residency, Sparse Resources, And Memoryless

Priority: production memory behavior and voxel-world prerequisites.

- Heap-backed resource allocation and aliasing.
- Residency sets, sparse/tiled resources, and physical page commits.
- Hardware memoryless/lazily allocated attachment contract separated from the
  portable transient-lifetime hint.

Acceptance: physical memory/residency evidence exists before enabling usable
features or the voxel-world production pressure claim.

## Period 50: Binding Tables, Indirect Commands, And Pipeline Persistence

Priority: scalable submission and artifact reuse.

- Argument encoders/tables, descriptor indexing, and function tables.
- Indirect command buffers and Vulkan device-generated/secondary command
  equivalents.
- Dynamic/linked shader functions, object/view pooling, Metal binary archive,
  and Vulkan pipeline-cache consumption.

Acceptance: large-table and persistent-cache GPU evidence replaces current
planning-only reports.

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

Period 47 is active. Period 46 closed the placeholder-query correctness gap and
added the capability-gated native measurement foundation; Phase 1 of Period 47
separates its portable targets from the advanced remainders routed to later
periods.
