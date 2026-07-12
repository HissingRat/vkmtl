# Period 45 Native Semantic Gap Backlog

Status: accepted routing baseline.

The Metal semantic ledger contains 99 stable semantic units. At Period 45
closeout, 77 have at least one incomplete backend outcome. Every incomplete ID
is assigned exactly once in `gap-routing.tsv`.

The periods below are implementation slices, not promises to add all source
concepts to the public API. Each period must apply the public API admission
rules and may close a row with an exact implementation or a precise unsupported
decision.

## Period 46: Native Queries, Counters, And Specialization

Priority: correctness and truthful diagnostics.

- Native Metal/Vulkan occlusion result allocation, encoding, resolve, and
  readback.
- Native GPU timestamp/counter paths and pipeline statistics where possible.
- Metal function-constant specialization.
- Shader/compiler execution log diagnostics.

Acceptance: QRY-03 can become executable only after real GPU visibility values
are observed; logical timestamps remain separately named and reported.

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

Acceptance: each semantic receives an exact Vulkan composition or an explicit
unsupported result; no broad Metal 4 feature flag substitutes for per-semantic
gates.

## Next Slice

Period 46 is next. It closes the known occlusion-query correctness gap before
broader resource or production work and adds the native measurement foundation
needed by later evidence.
