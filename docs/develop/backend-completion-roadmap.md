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

- [ ] Explicit resource barrier command lowering.
- [ ] Fence and timeline fence runtime objects.
- [ ] Event / shared event runtime objects.
- [ ] Dedicated compute and transfer queues.
- [ ] Queue ownership transfer rules for Vulkan and no-op/validation mapping for
  Metal.
- [ ] Occlusion, timestamp, and pipeline statistics query pools and encoder
  commands.

Expected result: vkmtl can support profiling, readback-heavy tools, async
compute/transfer experiments, and explicit synchronization escape hatches.

## Wave 5: Resource And Transfer Utilities

Tracked in `docs/develop/period24/`.

- [ ] Automatic mipmap generation.
- [ ] Non-4-byte-aligned `fillBuffer` fallback on Vulkan.
- [ ] Broader texture copy format coverage.
- [ ] Sampler border-color lowering where supported.
- [ ] Heap-backed resource creation.
- [ ] Transient allocation behavior.

Expected result: texture tools, streaming systems, and memory-sensitive
applications need fewer app-side workarounds.

## Wave 6: Platform And Interop

Tracked in `docs/develop/period25/`.

- [ ] Multi-surface / multi-window runtime support.
- [ ] External memory / texture import.
- [ ] External semaphore / shared event interop.
- [ ] Native command insertion escape hatch.
- [ ] Backend capability dump example and conformance checks.

Expected result: vkmtl can sit inside larger native apps and tooling without
owning every resource itself.

## Wave 7: Object Cache And Production Hardening

Tracked in `docs/develop/period26/`.

- [ ] Native object reuse for shader modules, layouts, pipelines, and samplers.
- [ ] Vulkan driver pipeline cache integration.
- [ ] Metal binary archive integration.
- [ ] Persistent runtime cache versioning.
- [ ] Diagnostics for cache misses, creation cost, and resource churn.
- [ ] Long-run stability commands.

Expected result: completed backend paths are fast enough and observable enough
for real applications instead of only examples.

## Wave 8: Advanced Resource And Geometry Features

Tracked in `docs/develop/period27/`.

- [ ] Sparse / tiled buffer lowering.
- [ ] Sparse / tiled texture residency backend lowering.
- [ ] Residency and page commit API.
- [ ] Tessellation lowering where supported.
- [ ] Mesh / task shader lowering where supported.

Expected result: advanced backend-specific power is exposed through explicit
capability-gated APIs while the portable core remains clean.

## Wave 9: Ray Tracing And Native Advanced Parity

Tracked in `docs/develop/period28/`.

- [ ] Acceleration structure backend lowering.
- [ ] Ray tracing pipeline lowering.
- [ ] Shader binding table and ray dispatch commands.
- [ ] Metal ray tracing mapping.
- [ ] Native advanced escape hatches.
- [ ] True backend-native multi-draw optimization.
- [ ] Maintained parity matrix.

Expected result: high-end backend-specific features become explicit, testable,
and documented instead of implicit holes in the abstraction.

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
