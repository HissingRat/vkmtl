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
- [x] Metal function-constant specialization native lowering.

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
- [x] Capability-gated depth/stencil copy aspects and typed MSAA-copy
  rejection/resolve semantics.
- [ ] Partial mipmap generation ranges, custom border colors, and native
  heap-backed resource creation.

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
Period 32+ driver parity plan.

## Wave 7: Object Cache And Production Hardening

Tracked in `docs/develop/period26/`.

- [x] Object-cache lookup diagnostics for shader modules, layouts, pipelines,
  and samplers.
- [ ] Native object handle pooling for shader modules, layouts, pipelines, and
  samplers. Deferred to Period 32+ driver parity plan.
- [x] Driver pipeline cache / binary archive planning descriptors.
- [x] Vulkan `VkPipelineCache` and Metal `MTLBinaryArchive` consumption.
- [x] Persistent runtime cache manifest versioning and compatibility planning.
- [ ] Automatic runtime cache manifest read/write. Deferred to Period 30 Phase
  5.
- [x] Diagnostics for cache misses, creation cost, resource churn, capture
  names, and runtime live-resource snapshots.
- [x] Long-run stability planning command.
- [x] Common GPU-backed presentation/resource/upload/shader/residency-state
  soak runner. Advanced native pressure lanes remain missing evidence in the
  Period 44 parity report.

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
  Period 32+ driver parity plan.
- [ ] Native tessellation and mesh/task executable pipeline creation. Deferred
  to Period 32+ driver parity plan.

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
  deferred to Period 32+ driver parity plan.
- [x] Parity semantic decisions and stress planning. Period 44 adds the common
  GPU soak runner and records advanced native soak as missing evidence.

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
  records. First-triangle Metal driver AS work is Period 31, first-triangle
  Vulkan driver AS work is Period 32, full-scene mesh BLAS/TLAS work is
  Period33, and procedural AS geometry work is Period34.
- [x] Backend-private ray tracing pipeline handle metadata. First-triangle
  Metal driver pipeline work is Period 31, first-triangle Vulkan driver
  pipeline work is Period 32, full-scene pipeline work is Period33, and
  procedural/custom-intersection pipeline work is Period34.
- [x] Backend-private SBT record metadata and ray dispatch command records.
  First-triangle Metal dispatch is Period 31, first-triangle Vulkan dispatch is
  Period 32, full-scene dispatch is Period33, and procedural dispatch is
  Period34.
- [x] Backend-private Metal ray tracing table and acceleration-slot metadata.
  Direct Metal dispatch binding for the first triangle is Period 31.
- [x] Backend-private native advanced inventory with first-triangle routing to
  Period 31 and Period 32, full native RT scene routing to Period33, and
  procedural RT routing to Period34.
- [x] Backend-private parity validation plans and stability diagnostics.
  GPU-backed soak loops are Period32+ validation matrix work.
- [x] Backend-private native advanced example record checks. Pixel-producing
  ray traced scene examples are split across Period 31 and Period 32.

Expected result: supported Vulkan and Metal adapters can validate and record the
high-end paths that Period 29 made expressible through public runtime
contracts. Direct driver execution for those high-end paths is routed to
Period31, Period32, Period33, Period34, and later Period32+ work according to
backend and scope.

## Wave 12: Metal Ray Traced Triangle Driver Path

Tracked in `docs/develop/period31/`.

- [x] Metal ray traced scene example contract and feature gate.
- [x] Real Metal acceleration structure bridge and BLAS build.
- [x] Ray tracing shader path for the first triangle.
- [x] Metal ray dispatch to the drawable.
- [x] Present the ray tracing output in the window.
- [x] Local screenshot/manual validation on supported Metal hardware.
- [x] Documentation closeout and follow-up routing.

Expected result: `zig build run-ray-traced-scene` shows a visible ray traced
triangle on supported macOS Metal devices.

## Wave 13: Vulkan Ray Traced Triangle Driver Path

Tracked in `docs/develop/period32/`.

- [x] Vulkan ray tracing capability gate and loader contract.
- [x] Real Vulkan acceleration structure creation and BLAS build.
- [x] Vulkan ray tracing shader path through Slang/SPIR-V.
- [x] Vulkan ray tracing pipeline and SBT materialization.
- [x] `vkCmdTraceRaysKHR` dispatch to an output texture.
- [x] Present the Vulkan ray tracing output texture in the window.
- [x] Supported-hardware validation and visible-result documentation.
- [x] Documentation closeout and Period32+ routing.

Expected result: `zig build run-ray-traced-scene -Dvulkan` shows a visible
ray traced scene on supported Vulkan ray tracing devices.

Observed result: the current Period34-upgraded example was visibly validated
on Windows/NVIDIA Vulkan hardware. It reported built BLAS/TLAS objects,
driver-submitted trace work, runtime readiness, and
`driver_pixels=visible_vulkan_procedural_rt_scene`. This marker supersedes the
original Period32 `visible_vulkan_rt_output` marker and proves a superset of
the Wave 13 path.

## Wave 14: Native RT Mesh Scene

Tracked in `docs/develop/period33/`.

- [x] Freeze the full mesh RT scene acceptance contract.
- [x] Add public vertex/index-backed RT mesh geometry descriptors.
- [x] Lower mesh BLAS builds from user buffers on Vulkan.
- [x] Lower mesh BLAS builds from user buffers on Metal.
- [ ] Bind camera, material, light, and instance scene buffers instead of
  using fixed example-side scene constants.
- [x] Render the full `examples/ray_traced_scene` through native RT using mesh
  room and mesh sphere geometry.
- [ ] Validate visible output or exact unsupported reasons on supported Vulkan
  RT runtimes.
- [x] Validate visible output on supported local Metal RT hardware.

Expected result: `examples/ray_traced_scene` is no longer just a first-triangle
smoke path. It renders the reference-inspired room/sphere scene through native
RT using mesh geometry on supported backends.

## Wave 15: Procedural RT Geometry And Custom Intersection

Tracked in `docs/develop/period34/`.

- [x] Add procedural/custom-intersection feature gates and procedural hit-group
  descriptor validation.
- [x] Add procedural sphere API contract through AABB build input and
  procedural hit-group descriptors.
- [x] Add backend resource plumbing for Vulkan AABB build input.
- [x] Lower Vulkan intersection shader groups.
- [ ] Create and bind Metal intersection function tables for procedural
  sphere intersections. Deferred to Period39 Phase 2/4.
- [x] Share procedural sphere, material, and camera scene data between Vulkan
  and Metal paths through the Period35 scene-data payload.
- [x] Replace tessellated sphere meshes with procedural sphere geometry in the
  full native `ray_traced_scene` acceptance example.
- [x] Validate visible procedural output on supported Vulkan RT hardware.
  Observed on the Windows/NVIDIA Period32 validation host. Metal procedural
  validation remains Period39.

Expected result: the Vulkan full native ray traced scene uses procedural
sphere/custom-intersection geometry for spheres and prints
`driver_pixels=visible_vulkan_procedural_rt_scene`. Metal keeps the
pixel-producing scene path while driver-level procedural function-table parity
is tracked by Period39.

## Wave 16: RT Scene Data And Metal Procedural Parity

Tracked in `docs/develop/period35/`.

- [x] Move RT frame, camera, material, and primitive sphere data into shared
  scene payloads where practical.
- [ ] Keep mixed mesh room geometry and procedural sphere geometry in one scene
  assembly model. Deferred to Period39 Phase 2.
- [ ] Create and bind driver-level Metal procedural function tables. Deferred
  to Period39 Phase 2/4.
- [ ] Validate Vulkan/Metal visual parity for the reference-inspired scene on
  supported Vulkan RT hardware. Deferred to Period39 Phase 5.

Expected result: `examples/ray_traced_scene` uses the same logical scene data
on Vulkan and Metal, with remaining Metal procedural/custom-intersection parity
assigned to Period39 instead of hidden in the example.

## Wave 17: Sync And Queue Semantics

Tracked in `docs/develop/period36/`.

- [x] Portable timeline fence / shared event / fence semantics and feature gates.
- [x] Multi-queue roles for graphics, compute, transfer, and presentation.
- [x] Queue ownership and cross-queue hazard tracking.
- [x] Deterministic sync/queue validation coverage.
- [x] Record native timeline/shared-event submit and physical multi-queue
  validation as Period44 evidence work.

Expected result: vkmtl exposes portable synchronization and logical queue
planning, validates ownership hazards, and reports typed unsupported or
missing-transition errors. Driver-level native submit and physical multi-queue
claims require Period44 device-matrix evidence.

## Wave 18: Memory, Heaps, And Residency

Tracked in `docs/develop/period37/`.

- [x] Heap reservation and allocator ownership vocabulary.
- [x] Aliasing and transient allocation validation.
- [x] Memory budget and pressure reporting.
- [x] Sparse/tiled residency churn planning and deterministic map execution.
- [x] Record native heap-backed resources, native sparse/tiled page binding, and
  GPU memory-pressure soak as Period44 evidence work after backend lowering
  exists.

Expected result: vkmtl exposes portable heap, aliasing, memory-pressure, and
residency-churn diagnostics. Native heap and sparse/tiled execution claims
require backend lowering plus Period44 device-matrix evidence.

## Wave 19: Resource Tables And Pipeline Persistence

Tracked in `docs/develop/period38/`.

- [x] Descriptor indexing resource-table pressure planning.
- [x] Metal argument-buffer resource-table pressure planning.
- [x] Update-after-bind and partially-bound table semantics.
- [x] Native Metal argument-buffer and Vulkan descriptor-indexing table
  allocation, update, compatible-pipeline binding, and GPU execution.
- [x] Pipeline artifact compatibility planning for shader, entry point,
  reflection, backend, format, schema, and toolchain changes.
- [x] Native Vulkan pipeline-cache persistence.
- [x] Native Metal binary-archive persistence.

Expected result: large resource tables have deterministic pressure plans and
native execution, while pipeline artifacts have deterministic invalidation and
native driver-cache persistence. Metal physical evidence is recorded; Vulkan
physical pressure remains a useful follow-up beyond forced-build/unit evidence.

## Wave 20: Ray Tracing Completeness

Tracked in `docs/develop/period39/`.

- [x] AS update/refit/compaction planning.
- [x] Many-instance TLAS metadata planning.
- [x] Ray query where supported.
- [x] Complex SBT layouts and callable records.
- [x] Deterministic RT stress planning.

Expected result: RT moves beyond the reference scene into common engine-scale
maintenance and dispatch patterns. Native GPU stress evidence remains Period44
device-matrix work.

## Wave 21: Advanced Geometry Draw Paths

Tracked in `docs/develop/period40/`.

- [x] Tessellation draw planning contracts.
- [x] Vulkan mesh/task shader dispatch planning contracts.
- [x] Metal object/mesh equivalent planning contracts or precise unsupported contracts.
- [x] Advanced-geometry examples use public planning APIs.
- [ ] Visible native advanced-geometry examples after backend pipeline hooks.

Expected result: tessellation and mesh/task examples exercise public draw and
dispatch planning APIs instead of descriptor-only probes. Visible native output
remains part of the Period44 device-matrix evidence work after backend pipeline
hooks land.

## Wave 22: External Interop Matrix

Tracked in `docs/develop/period41/`.

- [ ] Vulkan external memory/image/semaphore import.
- [ ] Metal shared texture/event import.
- [ ] External texture sampling/presentation examples.
- [ ] Platform lifetime and safety docs.
- [x] External interop capability matrix.

Expected result: external interop has real platform-specific paths, not only
descriptor wrappers.

## Wave 23: Format, Copy, Layout, And Attachment Edge Semantics

Tracked in `docs/develop/period42/`.

- [x] Format capability matrix.
- [x] Copy/blit edge semantics.
- [x] Resource state/layout transition validation.
- [x] Depth-stencil and MSAA copy/resolve/readback behavior.

Expected result: vkmtl has tested edge semantics for formats, copies,
attachments, mips, layers, and slices across Vulkan and Metal.

## Wave 24: Profiling, Capture, And Debug Markers

Tracked in `docs/develop/period43/`.

- [x] Debug label lifetime/naming and command-marker scope contract.
- [x] Vulkan debug utils integration with validation-only command-buffer scope.
- [x] Metal debug groups and opt-in developer-tools capture integration.
- [x] Logical timestamp source reporting, typed GPU-time gate, and CPU/marker
  profiling fallback.
- [x] Issue-report snapshot and expanded capability dump.

Expected result: vkmtl objects and command streams are inspectable in native
debuggers; profiling reports distinguish logical ordering, CPU fallback, and
future native GPU timing without overstating support.

## Wave 25: CI, Device Matrix, And Soak Validation

Tracked in `docs/develop/period44/`.

- [x] CI job matrix and feature reporting.
- [x] Metal and Vulkan smoke host definitions and runners.
- [x] Deterministic transfer, compute, and render pixel regression harness.
- [x] GPU soak and resource churn runner.
- [x] Release readiness and parity report with missing evidence kept explicit.

Expected result: vkmtl can make evidence-backed parity claims against a
documented device matrix without treating configured but unobserved lanes as
proof. The hosted matrix and physical GPU evidence now satisfy all 9 explicit
release-readiness gates; deferred native feature lanes remain outside the claim.

## Wave 26: Native Semantic Coverage Audit

Tracked in `docs/develop/period45/`.

- [x] Correct false-positive usable capabilities, beginning with occlusion
  query placeholder results.
- [x] Expand the Metal source baseline into a stable semantic ledger.
- [x] Record Vulkan core/extension, composed, emulated, unsupported, or
  incomplete mappings for every ledger entry.
- [x] Link public ownership, implementation locations, and evidence.
- [x] Add deterministic inventory drift checks.
- [x] Route every incomplete semantic into a dependency-ordered implementation
  slice.

Expected result: backend completion is driven by source semantic coverage and
truthful executable evidence rather than by public API shape or roadmap
checkbox count.

## Wave 27: Native Queries, Counters, And Specialization

Tracked in `docs/develop/period46/`.

- [x] Replace occlusion placeholders with capability-gated zero/nonzero native
  visibility on Vulkan and Metal.
- [x] Lower timestamp writes, CPU readback, and GPU resolve while preserving
  truthful logical versus native result sources.
- [x] Keep pipeline statistics and device-specific counter breadth closed until
  their result shapes and sampling contracts are representable.
- [x] Specialize Metal vertex, fragment, and compute functions by stable
  numeric function-constant ID.
- [x] Bind deterministic tests and physical GPU evidence to the closeout.

Expected result: the portable query path returns real visibility or native GPU
ticks when the selected device supports them, never placeholder data, and both
backends execute shader specialization without expanding the flat API root.

## Wave 28: Core Resource, Format, Render, And Compute Breadth

Tracked in `docs/develop/period47/`.

- [x] Split the 15 routed broad Metal rows into precise portable and deferred
  semantics before changing capability claims.
- [x] Expand ordinary limits, formats, views, samplers, resource modes, and
  capability-gated buffer addresses.
- [x] Close common MRT, attachment, binding, and dynamic raster-state paths.
- [x] Close common compute dispatch, barrier, atomic, threadgroup-memory, and
  reflection paths.
- [x] Resolve managed synchronization and bind focused backend/physical
  evidence to the closeout.

Expected result: ordinary rendering and compute applications gain broader
native coverage without pulling heaps, function tables, advanced raster state,
native synchronization, or Metal 4 concepts into the common API prematurely.

## Wave 29: Native Synchronization, Queues, And Presentation Timing

Tracked in `docs/develop/period48/`. Complete: native timeline/shared-event
submission, physical queue selection, lifecycle callbacks, and capability-
gated Metal presentation timing have executable evidence.

## Wave 30: Native Heaps, Residency, Sparse Resources, And Memoryless

Tracked in `docs/develop/period49/`. Complete: native placement heaps,
memory-budget telemetry, and Metal memoryless attachments execute; sparse and
residency-set execution are precisely unsupported under the handle-free map.

## Wave 31: Binding Tables, Indirect Commands, And Pipeline Persistence

Tracked in `docs/develop/period50/`. Complete: resource tables, CPU-authored
reusable command lists, Metal binary archives, and Vulkan pipeline caches have
backend lowering and evidence.

## Wave 32: Advanced Rasterization And Geometry

Tracked in `docs/develop/period51/`. Complete: Vulkan tessellation and
Metal/Vulkan mesh-only paths execute; the remaining advanced raster contracts
are precisely unsupported.

## Wave 33: Ray Tracing Breadth

Tracked in `docs/develop/period52/`. Complete: ordinary AS maintenance, AABB
geometry, and multi-source TLAS execute; the unallocated function-table,
inline-query, callable, motion, and Metal 4 RT contracts are closed.

## Wave 34: External Interop, Metal I/O, And Device Topology

Tracked in `docs/develop/period53/`. Complete: same-device Metal resources and
IOSurface textures import into ordinary execution, and both backends report
device topology. The incomplete synchronization/I/O/insertion/cross-device
contracts are explicitly unsupported.

## Wave 35: Metal 4, Pipeline Datasets, Tensor/ML, And Counters

Tracked in `docs/develop/period54/`.

- [x] Compose admitted Metal 4 argument-table and explicit-barrier effects
  through existing portable owners.
- [x] Execute exact occlusion sample counts through Metal counting visibility
  and Vulkan precise occlusion.
- [x] Close allocator/reuse/feedback, flexible pipelines,
  compiler/archive/datasets, pools, tensor/ML, logs, calibration, and variable
  counter/statistic shapes precisely unsupported.
- [x] Reduce the Period 45 exactly-once gap routing to zero incomplete units.

Expected result: all 111 audited Metal semantic units have executable or
precise unsupported outcomes, without a broad Metal 4 feature flag.

## Wave 36: Explicit Ray-Tracing Texture Presentation

Tracked in `docs/develop/period55/`.

- [x] Allocate an additive caller-owned RT texture command without changing
  the root or context owners.
- [x] Lower Metal RT directly to the caller texture without drawable
  acquisition.
- [x] Lower Vulkan RT output to a sampled-image postcondition.
- [x] Present the caller-owned `rgba16_float` accumulation texture through one
  shared historical display-RGB clamp and sRGB-EOTF pass to
  `bgra8_unorm_srgb`, whose matching OETF restores reference bytes.
- [x] Lock deterministic color/resource validation and physical Metal
  evidence while keeping Vulkan physical execution and visual acceptance
  explicit.

Expected result: backend ray generation has one composable caller-owned output
contract with no implicit color-space conversion, and the example has one
shared reference transform. The golden scalar mapping is
`0.0/0.18/0.5/0.8/1.0 -> 0/46/128/204/255`. Metal has physical evidence;
that evidence validates command execution, not captured reference bytes.
Vulkan now submits and completes this route physically. Its first screenshot
exposed a vertical composition flip; the corrected fragment-position UV path
subsequently completed 3000 frames with the accepted top-left orientation.

## Wave 37: Observable Presentation Format Selection

Tracked in `docs/develop/period56/`.

- [x] Preserve `PresentationDescriptor.format` as the request and expose the
  concrete selection through `Swapchain.selectedFormat()`.
- [x] Select only the deterministic SDR BGRA8 pair on Metal and Vulkan, with
  exact explicit requests and typed unsupported outcomes.
- [x] Re-resolve selection after successful native resize and rebuild Vulkan
  format-dependent presentation resources when it changes.
- [x] Keep requested extent separate from actual native drawable extent.
- [x] Gate Vulkan resize before old-resource destruction and make destructive
  recreation failure terminal with `SurfaceLost`.
- [x] Reject current-drawable pipeline mismatches before native bind or draw.
- [x] Make legacy drawable RT dispatch honor the caller's linear BGRA8 output
  and copy bytes unchanged to the selected drawable on both backends, with one
  implicit present and typed duplicate-present rejection.
- [x] Record physical Metal automatic, sRGB, and linear deterministic offscreen
  pixels plus native selected-format readback and matching current-drawable
  pipeline bind/present smoke.
- [x] Record Metal legacy caller-output probes for sRGB and linear selected
  drawables under API Validation.
- [x] Keep Vulkan RT-machine evidence explicit rather than inferred from forced
  builds. Legacy raw copy and corrected canonical composition now both pass
  execution and visual orientation.

Expected result: callers can distinguish requested and selected presentation
formats and build pipelines against the concrete drawable. The presentation
layer performs no HDR, tone mapping, gamma, or gamut conversion, and the legacy
RT compatibility transfer performs only raw byte copying.

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
