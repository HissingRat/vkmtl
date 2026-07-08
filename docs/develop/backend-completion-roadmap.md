# Backend Completion Roadmap

This document tracks the native-backend catch-up work after the first broad API
coverage pass. It is ordered by practical unblock value: features used by normal
rendering and examples come before advanced Vulkan/Metal parity work.

The work is tracked as new backend-completion periods instead of rewriting the
historical Period 1-19 phase docs. Period 20 starts the common render backend
completion pass.

## Completed Catch-Up Before Period 20

These items were completed while converting API shapes into native backend
paths. They are recorded here instead of rewriting the historical period notes:

- Backend object labels for real resources and pipelines.
- Metal markers and Vulkan encoder-level debug markers.
- Dynamic viewport, scissor, blend color, stencil reference, and depth-bias
  command lowering.
- Texture-to-texture copy and native `fillBuffer(...)` paths.
- Base vertex / base instance direct draw lowering.
- Indirect draw lowering, including runtime expansion for `draw_count > 1`.
- Explicit multi-draw expansion through repeated direct draw calls.
- Compute dispatch indirect lowering.
- Compare sampler and anisotropy lowering.
- Transient attachment metadata accepted as a no-op performance hint.
- Single color attachment blend state lowering.
- Pipeline depth-bias and wireframe / line fill mode lowering.
- Vertex instance step-rate lowering.
- Combined depth/stencil format and stencil pipeline state lowering.
- Multiple render target pipeline and texture-backed render pass lowering.

## Goal

Close the gap between public vkmtl API shapes and real Vulkan / Metal backend
lowering. Each slice should keep the backend boundary intact:

- public API stays backend-neutral
- runtime validation reports typed errors before backend calls
- Vulkan and Metal both receive an intentional mapping or a documented no-op
- docs and tests move with the implementation

## Wave 1: Common Render Backend

Tracked in `docs/develop/period20/`.

- [x] Blend state lowering for color attachments.
- [x] Pipeline depth-bias state lowering.
- [x] Wireframe / line fill mode where the backend supports it.
- [x] Vertex instance step-rate lowering.
- [x] Stencil render pass and stencil pipeline state lowering.
- [x] Multiple render target render pass and pipeline lowering.

Expected result: normal texture-backed forward/deferred-style render pipelines
can be expressed without hitting typed unsupported errors, except where a
backend truly lacks the feature. Current-drawable MRT, conservative
rasterization, and separate stencil-only attachments remain explicit deferred
items.

## Wave 2: Binding Backend

Tracked in `docs/develop/period21/`.

- [x] Dynamic buffer offsets in `setBindGroup(...)`.
- [x] Resource arrays for sampled textures, samplers, and buffers.
- [x] Advanced binding layout metadata and range summary queries.
- [x] Root-constant pipeline compatibility validation.
- [x] Shader specialization cache identity and typed rejection.

Expected result: material systems can use dynamic offsets and first-slice
resource arrays without manually flattening every binding into a unique slot.
Advanced descriptor tables, command-written constants, and shader variants are
planned in Wave 3.

## Wave 3: Binding ABI And Shader Variant Closure

Tracked in `docs/develop/period22/`.

This wave owns the explicit deferred items from Period 21:

- [x] Dynamic buffer arrays with per-array-element offset addressing.
- [x] Bindless resource table allocation, update, clear, and lifetime tracking.
- [x] Vulkan descriptor-indexing table binding and Metal argument-buffer
  command binding.
- [x] Immutable sampler and static sampler policy.
- [x] Root constant command writes and native Vulkan / Metal lowering.
- [x] Shader specialization variant validation and Vulkan native pipeline
  lowering.
- [ ] Metal function-constant specialization native lowering.

Expected result: the advanced binding and shader shapes stop being
metadata-only paths. Unsupported backend cases remain capability-gated, but
supported cases are executable.

## Wave 4: Command, Sync, And Queries

Tracked in `docs/develop/period23/`.

- [x] Explicit resource barrier command lowering.
- [x] Fence and event runtime objects.
- [x] Logical compute and transfer queue views with portable fallback.
- [x] Queue ownership transfer rules and Metal no-op/validation mapping.
- [x] Occlusion and timestamp query sets with encoder commands.
- [ ] Timeline fence, shared-event, native dedicated-queue, Vulkan queue-family
  transfer, and pipeline-statistics native lowering.

Expected result: vkmtl can support profiling, readback-heavy tools, async
compute/transfer experiments, and explicit synchronization escape hatches.

## Wave 5: Resource And Transfer Utilities

Tracked in `docs/develop/period24/`.

- [x] Full-texture automatic mipmap generation.
- [x] Non-4-byte-aligned `fillBuffer` fallback on Vulkan.
- [x] Broader texture copy format/layer coverage.
- [x] Fixed sampler border-color lowering where supported.
- [x] Heap planning and reservation diagnostics.
- [x] Transient allocation diagnostics.
- [ ] Partial mipmap ranges, depth/stencil/MSAA copies, custom border colors,
  and native heap-backed resource creation.

Expected result: texture tools, streaming systems, and memory-sensitive
applications need fewer app-side workarounds.

## Wave 6: Platform And Interop

Tracked in `docs/develop/period25/`.

- [x] Multi-surface / multi-window runtime support.
- [x] External memory / texture wrapper APIs.
- [x] External semaphore / shared event wrapper APIs.
- [x] Native command insertion escape hatch API.
- [x] Backend capability and interop matrix checks.
- [ ] Native multi-surface presentation, external memory/texture import,
  external sync wait/signal, and native command handle lowering.

Expected result: vkmtl can sit inside larger native apps and tooling without
owning every resource itself. Current Period 25 coverage provides public API,
typed validation, wrappers, and examples; native interop lowering is routed to
Period 30 Phase 5.

## Wave 7: Object Cache And Production Hardening

Tracked in `docs/develop/period26/`.

- [x] Object-cache lookup diagnostics for shader modules, layouts, pipelines,
  and samplers.
- [ ] Native object handle pooling for shader modules, layouts, pipelines, and
  samplers. Deferred to Period 30 Phase 5.
- [x] Driver pipeline cache / binary archive planning descriptors.
- [ ] Vulkan `VkPipelineCache` and Metal `MTLBinaryArchive` consumption.
  Deferred to Period 30 Phase 5.
- [x] Persistent runtime cache manifest versioning and compatibility planning.
- [ ] Automatic runtime cache manifest read/write. Deferred to Period 30 Phase
  5.
- [x] Diagnostics for cache misses, creation cost, resource churn, capture
  names, and runtime live-resource snapshots.
- [x] Long-run stability planning command.
- [ ] GPU-backed long-run soak loops. Deferred to Period 30 Phase 6.

Expected result: completed backend paths are fast enough and observable enough
for real applications instead of only examples.

## Wave 8: Advanced Resource And Geometry Features

Tracked in `docs/develop/period27/`.

- [x] Sparse / tiled buffer lowering plans.
- [x] Sparse / tiled texture lowering plans and page-grid metadata.
- [x] Residency and page commit planning API.
- [x] Tessellation lowering plans where supported.
- [x] Mesh / task shader lowering plans where supported.
- [ ] Native sparse/tiled runtime resources and page binding. Deferred to
  Period 30 Phase 5.
- [ ] Native tessellation and mesh/task executable pipeline creation. Deferred
  to Period 30 Phase 5.

Expected result: advanced backend-specific power is exposed through explicit
capability-gated planning APIs while the portable core remains clean. Period 29
owns the native executable backend closure.

## Wave 9: Ray Tracing And Native Advanced Parity

Tracked in `docs/develop/period28/`.

- [x] Acceleration structure build planning.
- [x] Ray tracing pipeline lowering plans.
- [x] Shader binding table and ray dispatch plans.
- [x] Metal ray tracing mapping plans.
- [x] Native advanced escape-hatch closure inventory.
- [x] Maintained parity matrix and Period 29 routing.
- [x] Public acceleration-structure runtime contract. Backend-private native
  handles are deferred to Period 30 Phase 1.
- [x] Public ray tracing pipeline runtime contract. Backend-private pipeline
  handles are deferred to Period 30 Phase 2.
- [x] Public SBT and ray dispatch runtime contract. Backend-private SBT records
  and dispatch are deferred to Period 30 Phase 3.
- [x] Public Metal ray tracing mapping runtime contract. Backend-private Metal
  dispatch integration is deferred to Period 30 Phase 4.
- [x] Native advanced escape-hatch runtime contract. Backend-private lowering is
  deferred to Period 30 Phase 5.
- [x] Parity semantic decisions and stress planning. Native soak validation is
  deferred to Period 30 Phase 6.

Expected result: high-end backend-specific features become explicit, testable,
and documented as planning/runtime-contract APIs. Period 30 owns executable
native backend closure.

## Wave 10: Native Advanced Runtime Contracts

Tracked in `docs/develop/period29/`.

- [x] Acceleration structure runtime contract.
- [x] Ray tracing pipeline runtime contract.
- [x] SBT and ray dispatch runtime contract.
- [x] Metal ray tracing execution mapping runtime contract.
- [x] Native advanced escape-hatch runtime contract.
- [x] Parity semantics and stress validation planning.
- [x] Native advanced runtime-contract examples.

Expected result: supported Vulkan and Metal adapters can be targeted through
stable public runtime contracts while backend-private native execution is
tracked in Period 30.

## Wave 11: Backend-Private Native Execution

Tracked in `docs/develop/period30/`.

- [x] Backend-private acceleration structure handle state and build command
  records. Direct driver AS handles are Period 31+ parity work.
- [x] Backend-private ray tracing pipeline handle metadata. Direct driver
  pipeline handles are Period 31+ parity work.
- [x] Backend-private SBT record metadata and ray dispatch command records.
  Direct driver dispatch calls are Period 31+ parity work.
- [ ] Native Metal ray tracing dispatch integration.
- [ ] Native advanced escape-hatch lowering.
- [ ] Native parity and soak validation.
- [ ] Pixel-producing native advanced examples.

Expected result: supported Vulkan and Metal adapters execute the high-end paths
that Period 29 made expressible through public runtime contracts.

## Slice Checklist

Before starting a backend-completion slice:

- [ ] Identify the public descriptor / method that already exists.
- [ ] Confirm current typed error or no-op behavior.
- [ ] Write down Vulkan mapping.
- [ ] Write down Metal mapping.
- [ ] Decide whether feature flags should open by default or follow native
  capability queries.
- [ ] Add or update focused tests.
- [ ] Update API docs and period notes.
