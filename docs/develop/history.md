# vkmtl Development History

This ledger compresses the repository's Period 1-56 development notes into a
historical record. It describes what each period set out to do, what actually
landed, and which limitations were deliberately preserved.

## Authority And Snapshot

This file is history, not the current API or support contract.

- Current public API policy belongs in `public-api.md`.
- The current exported surface belongs in `public-api-inventory.md`.
- Current executable backend claims belong in
  `native-semantic-coverage-inventory.md`.
- Current work and validation requirements belong in `roadmap.md` and
  `validation.md`.
- Git remains the source for implementation detail and superseded phase notes.

The pre-consolidation documentation snapshot is
`4ac780fced49d89ecfd4c09d519ac8dcd5fba07c`.

That commit contains the former `docs/develop/period1/` through
`docs/develop/period56/` trees, the detailed phase notes, closeouts, evidence
records, and the old checklist. For example:

```sh
git show 4ac780f:docs/develop/period52/closeout.md
```

Historical words such as "supported", "complete", and "native" below apply to
the bounded period outcome at that snapshot. They must not override a later
capability query, inventory row, typed error, or release policy.

## Evidence Vocabulary

The periods gradually tightened these evidence distinctions:

- **Shape or planning** means a descriptor, validation rule, lowering plan, or
  diagnostic existed. It does not mean a driver command executed.
- **Unit/build** means deterministic tests or a backend-forced build passed. It
  does not prove the feature ran on a suitable GPU.
- **Physical** means the documented command executed on the named or otherwise
  described physical host.
- **Visual** means a submitted path also produced an inspected image or
  deterministic pixel/readback result.
- **Unsupported** means the period intentionally kept usable capability false
  or returned a typed error. It is a result, not an unfinished checkbox.

## Major Eras

| Era | Periods | Historical result |
| --- | --- | --- |
| Core vertical slice | 1-10 | Vulkan and Metal public slices, resources, rendering, compute, Slang, examples, and advanced descriptor gates |
| Capability and API breadth | 11-18 | Truthful device queries plus broad validation/planning contracts for bindless, interop, sparse, geometry, RT, and production diagnostics |
| Backend catch-up | 20-30 | Common native lowering, runtime objects, backend-private records, and explicit routing from plans toward execution |
| Native pixels and production matrix | 31-44 | First Metal/Vulkan RT pixels, full procedural scene, production contracts, edge semantics, diagnostics, CI, and device evidence |
| Tagged baseline | v0.1.0 | First documented compatibility release at `96c5b08c` |
| Source-driven semantic closure | 45-54 | Metal SDK semantic audit, exact executable slices, and precise unsupported decisions with zero unrouted gaps |
| Pressure and presentation closure | 19, 55-56 | Voxel pressure test, composable RT texture output, deterministic SDR presentation selection, and corrected Vulkan visual evidence |

Period numbers express ownership, not strict completion order. Period 19 was
reactivated and completed after Period 54, once the backend blockers discovered
by the original pressure-test plan had been closed.

## Release Milestone: v0.1.0

The annotated `v0.1.0` tag points to
`96c5b08c34163a148f9811efff04a6f78936778a`.

The release was prepared by the Phase 9 API migration (`73caa9c`), release
baseline work (`f57c9ca`), and the Windows shader-dependency portability fixes
ending at the tagged commit.

The release promised the documented portable Zig source API throughout the
`v0.1.x` line. It did not promise a stable binary ABI, opaque `_state` layout,
raw native-handle values, or stability of backend-native escape hatches.
Intentional portable source breaks were reserved for `v0.2.0` or later.

The release package exported only `vkmtl`. Consumer shaders used a
source-backed `shader_manifest`; the build tracked manifest, source, and Slang
include dependencies, embedded precompiled SPIR-V/MSL/reflection, and never
spawned `slangc` or wrote runtime shader caches.

The exact-tag review recorded:

- API guard baselines of root 68, `Device` 34, `WindowContext` 10, and 35
  opaque runtime handles;
- external package consumption with a consumer-owned shader manifest;
- formatting, tests, default and Vulkan builds, and package fetch/smoke;
- hosted macOS, Linux, and Windows jobs;
- reviewed physical Metal and Vulkan smoke, pixel, and soak evidence;
- readiness 9/9 and `release ready: true` before tag publication.

## Period Ledger

### Period 1 - Core Library Slice And Polish

- **Goal:** replace the Vulkan triangle prototype with a small Metal-inspired,
  backend-neutral library and a working Vulkan/Metal vertical slice.
- **Outcome:** added explicit backend selection, surface/presentation
  boundaries, buffers, textures, views, samplers, build-time Slang artifacts,
  render/compute pipelines, command encoders, bind groups, depth, offscreen
  rendering, MSAA resolve, transfer, compute, and readback examples.
- **Durable decision:** ordinary API types remain backend-neutral; native
  Vulkan and Metal objects stay behind backend modules and explicit escape
  hatches. Surface providers keep GLFW and platform details outside the core.
- **Durable decision:** shader declarations resolve embedded build-time
  artifacts. Runtime compilation and runtime shader-cache writes are not part
  of the contract.
- **Boundary:** early `WindowContext` creation methods were transitional; later
  periods moved canonical ownership toward `Device` and domain facades.
- **Evidence:** the initial integrated slice is commit `0f529f7`; the later
  Phase 9 pre-tag API migration is `73caa9c` and feeds the `v0.1.0` baseline.

### Period 2 - Runtime Architecture And Specs

- **Goal:** settle ownership, lifetime, capability, synchronization, and
  presentation concepts before broadening the surface.
- **Outcome:** established device/queue/surface foundations, adapter selection,
  resource retirement tracking, resource usage tracking, typed error classes,
  multi-surface state, native handle views, and debug diagnostics.
- **Durable decision:** capabilities and limits come from the selected adapter;
  optional paths fail before backend work when their contract is unavailable.
- **Durable decision:** resources are children of runtime owners, and deferred
  retirement or equivalent tracking protects GPU-referenced lifetimes.
- **Boundary:** the period created the architecture baseline; later periods
  supplied broader and more exact native execution.
- **Commits:** `d6b35ad` documents the model; implementation spans
  `a724bda` through `dcbd774`.

### Period 3 - Resource Coverage

- **Goal:** cover buffer, texture, sampler, format, mip, view, and heap
  fundamentals without exposing backend memory objects.
- **Outcome:** added buffer mapping and alignment foundations, texture shape
  and format helpers, mip/view ranges, sampler completeness, and heap feature
  gates.
- **Durable decision:** ordinary users create resources through descriptors;
  explicit heaps remain an optional, capability-gated lane.
- **Boundary:** several advanced resource features were initially descriptor or
  validation coverage. Native heaps arrived in Period 49; sparse page execution
  remained unsupported at the snapshot.
- **Commits:** definition and implementation span `b8b1b3d` through
  `a980b59`.

### Period 4 - Shader And Binding

- **Goal:** make Slang, reflection, and bind-group terminology suitable for
  real applications.
- **Outcome:** added binding helpers, shader library descriptors, a versioned
  reflection schema, bind-group layout metadata, dynamic-offset and small/root
  constant shapes, and specialization descriptors.
- **Durable decision:** Slang is the source language; reflection may derive
  layouts, while explicit descriptors remain available.
- **Durable decision:** Vulkan descriptor sets and Metal binding slots are
  backend mappings of one public group/binding model.
- **Boundary:** scalable tables, command-written root constants, and native
  variants were completed in later binding periods.
- **Commits:** `02892dc` through `15ceb22`.

### Period 5 - Render Pipeline Surface

- **Goal:** describe common render passes and graphics state without exposing
  Vulkan pipeline complexity.
- **Outcome:** added attachment, raster, dynamic state, blend, depth/stencil,
  vertex-layout, draw, indirect-draw, and query descriptor/validation coverage.
- **Durable decision:** viewport and scissor are encoder state rather than
  baked pipeline state.
- **Boundary:** the first slice retained typed unsupported results for advanced
  state. Common blend, stencil, MRT, fill, and instance-rate lowering followed
  in Period 20; advanced geometry/raster decisions followed in Period 51.
- **Commits:** `b3b49c2` through `7bc4380`.

### Period 6 - Command, Synchronization, And Transfer Surface

- **Goal:** unify Vulkan's explicit ordering with Metal's encoder model through
  portable defaults and advanced escape hatches.
- **Outcome:** added command lifecycle validation, broader blit descriptors,
  explicit barrier shapes, fence/event gates, logical multi-queue descriptors,
  and debug signposts.
- **Durable decision:** tracked resource usage is the ordinary path; explicit
  barriers remain an advanced option.
- **Boundary:** native timeline/shared-event submit and physical queues were
  not claimed here; they arrived in Period 48.
- **Commits:** `d0a241a` through `bb7d704`.

### Period 7 - Compute

- **Goal:** make compute independently useful and share binding, sync, and
  cache rules with rendering.
- **Outcome:** completed dispatch validation, indirect-dispatch gates, storage
  access rules, atomic/threadgroup requirement descriptors, cache identity, and
  deterministic compute/readback coverage.
- **Durable decision:** compute-only work must be verifiable through GPU
  readback rather than a window image.
- **Boundary:** advanced atomic families and broader native scheduling remained
  capability-gated; the common executable subset was tightened in Period 47.
- **Commits:** `1858947` through `afaa641`.

### Period 8 - Pipeline And Object Cache Contracts

- **Goal:** define stable identity for expensive shader, layout, pipeline, and
  sampler objects.
- **Outcome:** added cache keys for shader modules, bind-group and pipeline
  layouts, render/compute pipelines, sampler policy, and cache diagnostics.
- **Durable decision:** keys include shader identity, layouts, formats,
  specialization, and relevant toolchain/configuration state.
- **Boundary:** this was identity and diagnostics, not lifetime-safe native
  handle pooling. Driver artifact persistence arrived in Period 50; broad
  native object pooling remained outside the snapshot.
- **Commits:** `a5e8f66` through `e790458`.

### Period 9 - Examples, Test Matrix, And Documentation

- **Goal:** organize the gallery, backend matrix, validation cases, and user
  documentation around the public API.
- **Outcome:** catalogued render/compute/multi-window/interop examples, added
  backend and validation matrices, and completed the first documentation pass.
- **Durable decision:** examples are API consumers, not privileged users of
  backend-private modules.
- **Boundary:** matrix entries distinguish expected unsupported outcomes from
  executable GPU evidence.
- **Commits:** planning begins at `7b8660a`; the period closes through
  `8bce6f6` to `11b6b5d`.

### Period 10 - Advanced Backend-Gated Surface

- **Goal:** expose optional bindless, sparse, external, tessellation, mesh, RT,
  and driver-cache concepts without contaminating the portable core.
- **Outcome:** added capability-gated descriptor families for each area.
- **Durable decision:** an advanced native feature has no implicit portable
  fallback unless the abstraction defines an equivalent observable result.
- **Boundary:** this period was API/validation expansion, not broad native
  execution. Subsequent periods either implemented exact slices or recorded
  typed unsupported outcomes.
- **Commits:** `72b5f0f` through `6f90bf1`.

### Period 11 - Backend Capability Reality

- **Goal:** replace assumed feature/limit values with selected-device queries.
- **Outcome:** queried Vulkan and Metal features, limits, extensions, families,
  and format facts; unified reports; added pre-lowering gates, a capability
  dump, and conservative tests.
- **Durable decision:** unknown facts default false or conservative. Native API
  availability is not the same as an executable vkmtl path.
- **Evidence:** the capability dump became the standard issue/smoke artifact.
- **Commits:** `cb95d95` through `33f645d`.

### Period 12 - Bindless And Argument-Buffer Metadata

- **Goal:** define scalable binding layouts while preserving ordinary bind
  groups.
- **Outcome:** added advanced layout contracts, Vulkan descriptor-indexing and
  Metal argument-buffer metadata, reflection derivation, an example, and
  validation coverage.
- **Durable decision:** advanced tables are a separate capability-gated lane.
- **Boundary:** the period did not claim executable table allocation/update/
  binding. Runtime tables followed in Period 22 and production native scalable
  execution in Period 50.
- **Commits:** `66280c5` through `e6a4443`.

### Period 13 - Multi-Surface And Presentation State

- **Goal:** let one selected device track multiple independent surfaces.
- **Outcome:** added surface registries, per-surface presentation state,
  suspended-versus-lost lifecycle, present-mode fallback, and independent frame
  serials, plus a multi-window capability example.
- **Durable decision:** a window context is not the device; each surface owns
  its presentation lifecycle.
- **Boundary:** later presentation periods made native format selection and
  failure/recovery semantics exact.
- **Commits:** `1c8b292` through `a977481`.

### Period 14 - Native Interop Shapes

- **Goal:** define intentional native handle, external resource, and command
  insertion ownership without leaking native types into ordinary APIs.
- **Outcome:** stabilized borrowed handle views and added Vulkan/Metal external
  resource descriptors, external texture wrappers, insertion descriptors, and
  a gated example.
- **Durable decision:** borrowed/transferred ownership and lifetime are explicit
  parts of every interop path.
- **Boundary:** these were validation/wrapper contracts. Exact Metal imports
  arrived in Period 53; incomplete Vulkan import descriptors and command
  insertion remained unsupported.
- **Commits:** `5a2258c` through `0a2b401`.

### Period 15 - Sparse And Tiled Resource Shapes

- **Goal:** describe optional sparse buffers/textures, residency maps, page
  commits, and mip tails.
- **Outcome:** added descriptors, deterministic residency maps, mip-tail
  metadata, a streaming probe, and validation tests.
- **Durable decision:** sparse residency is optional and must identify exact
  resources/pages before it can count as command execution.
- **Boundary:** no native sparse/tiled allocation or page bind was claimed.
  Period 49 explicitly kept usable sparse/residency capabilities false.
- **Commits:** `4b184fe` through `ecbc595`.

### Period 16 - Advanced Geometry Metadata

- **Goal:** define tessellation and mesh/task shader stages and backend
  lowering metadata.
- **Outcome:** added Vulkan and Metal tessellation/mesh plans, advanced shader
  stages, reflection alignment, feature gates, and examples.
- **Boundary:** metadata was not a visible pipeline. Executable Vulkan
  tessellation and Metal/Vulkan mesh slices were decided in Period 51.
- **Durable limitation:** native support alone never opened a usable feature
  without stable compiler artifacts and command lowering.
- **Commits:** `198cb71` through `1c7cd66`.

### Period 17 - Ray Tracing Metadata

- **Goal:** define acceleration structures, RT pipelines, shader binding
  tables, Metal mapping, and validation.
- **Outcome:** added build and pipeline lowering metadata, SBT layout, gated
  example shapes, and tests.
- **Boundary:** this did not allocate driver AS/pipeline objects or dispatch
  rays. Planning, runtime records, and visible execution were separated across
  Periods 28-34.
- **Durable decision:** RT remains optional and cannot become a dependency of
  ordinary render/compute paths.
- **Commits:** `43d841a` through `c6b0ea9`.

### Period 18 - Production Hardening Shapes

- **Goal:** describe persistent caches, transient aliasing, transfer planning,
  profiling, labels, and stability runs.
- **Outcome:** added driver-cache plans, transient allocation metadata,
  transfer-batch plans, profiler/label descriptors, and soak descriptors.
- **Boundary:** this was planning and diagnostics. Native cache consumption
  landed in Period 50 and physical soak evidence in Period 44.
- **Durable decision:** cache misses and unavailable persistence are performance
  outcomes, not correctness failures.
- **Commits:** `fa08ef8` through `533dfd4`.

### Period 19 - Voxel World Pressure Test

- **Goal:** pressure-test the public API with a bounded Minecraft-like chunked
  renderer, not build a game engine.
- **Outcome:** delivered deterministic terrain, visible-face meshing, atlas
  materials, fly camera, culling, bounded streaming/rebuilds, depth, and
  lighting without adding public API.
- **Physical evidence:** Metal API Validation passed smoke/default/stress. The
  160-frame run reached 289 resident chunks, drew 121, culled 168, rebuilt all
  289, and exited with `voxel_world_pressure_test=ok` and no pending work.
- **Finding:** synchronous `CommandBuffer.commit()` prevented useful CPU/GPU
  overlap; a future in-flight completion contract must own any behavior change.
- **Finding:** a Metal drawable-format mismatch was corrected; explicit
  request/selected semantics were routed to Period 56.
- **Boundary:** forced Vulkan build and SPIR-V artifacts were not physical
  Vulkan execution.
- **Commits:** phase activation `ab1c06b`; completed pressure test `4a93d57`.

### Period 20 - Common Render Backend Completion

- **Goal:** lower existing common render descriptors to both native backends.
- **Outcome:** implemented blend and independent attachment blend, depth bias,
  wireframe/line fill where available, instance step rate, combined
  depth/stencil, and texture-backed MRT.
- **Durable decision:** backend catch-up should not rewrite the public shape.
- **Boundary:** conservative rasterization, stencil-only attachments, and
  current-drawable MRT remained outside the slice.
- **Commits:** `84c7317` through `a36e651`.

### Period 21 - Binding And Shader Backend Completion

- **Goal:** execute the common binding features already represented publicly.
- **Outcome:** lowered dynamic offsets and first-slice resource arrays, exposed
  advanced layout summaries, validated root-constant compatibility, and locked
  specialization cache identity.
- **Boundary:** scalable table objects, command root writes, dynamic buffer
  array ABI, static sampler policy, and native variants were routed to Period
  22 rather than overstated.
- **Commits:** `bed5441` through `5fcc9b0`.

### Period 22 - Binding ABI And Shader Variants

- **Goal:** close the binding-table, root-constant, and variant gaps left by
  Period 21.
- **Outcome:** added per-array-element dynamic offsets, static sampler policy,
  `ResourceTable` state/update/binding, encoder root writes, Vulkan push
  constants, Metal bytes, and Vulkan specialization lowering.
- **Durable decision:** table state and ordinary bind groups remain separate;
  layouts and lifetimes are validated before command binding.
- **Boundary:** Metal function-constant execution remained gated until Period
  46; production scalable native tables were completed in Period 50.
- **Commits:** `9506d62` through `50f83b9`.

### Period 23 - Command, Sync, And Query Runtime Contracts

- **Goal:** expose portable barriers, synchronization objects, logical queues,
  ownership, and query sets.
- **Outcome:** lowered explicit barriers; added fence/event objects, logical
  compute/transfer queues, ownership validation, and logical occlusion/timestamp
  query commands and resolves.
- **Boundary:** timeline/shared-event native submit, physical queues, and real
  GPU query storage were deliberately left for Periods 46 and 48.
- **Durable decision:** a logical fallback must be observable and cannot be
  reported as native execution.
- **Commits:** `e92f51e` through `65a0dd6`.

### Period 24 - Resource And Transfer Utilities

- **Goal:** remove application workarounds for common mip, fill, copy, sampler,
  and allocation tasks.
- **Outcome:** implemented full-texture mip generation, unaligned Vulkan fill
  fallback, broader texture copies, fixed border colors, heap reservation
  planning, and utility validation.
- **Boundary:** partial mip generation, custom border colors, heap-backed
  resources, packed depth/stencil, and ordinary MSAA copy were not implied.
- **Commits:** `a3c05a9` through `4677653`.

### Period 25 - Platform, Surface, And Interop Completion

- **Goal:** make the runtime composable inside multi-window and native-hosted
  applications.
- **Outcome:** added surface registries, pacing diagnostics, external resource
  and sync wrappers, command-insertion hooks, examples, and matrix coverage.
- **Boundary:** wrapper creation was not native OS/API import or native sync
  submission. Those incomplete contracts were revisited in Period 53.
- **Durable decision:** native access remains explicit and capability-gated.
- **Commits:** `d20e79a` through `cfcc6fb`.

### Period 26 - Cache And Production Diagnostics

- **Goal:** make cost, reuse opportunities, persistence compatibility, and
  long-run plans observable.
- **Outcome:** added object-cache lookup diagnostics, driver-cache planning,
  runtime manifest compatibility, creation/churn diagnostics, stability plans,
  and a readiness matrix.
- **Boundary:** lookup diagnostics did not pool native handles; plans did not
  consume driver archives. Persistence landed in Period 50, while advanced
  physical pressure lanes remained evidence work.
- **Commits:** `7f5f69c` through `240608e`.

### Period 27 - Advanced Resource And Geometry Planning

- **Goal:** define backend-neutral plans for sparse/tiled resources,
  residency, tessellation, and mesh/task dispatch.
- **Outcome:** added sparse buffer/texture/page plans and advanced geometry
  lowering plans with examples and validation.
- **Boundary:** the period was explicitly planning/validation. Native sparse
  page binding remained unsupported; executable geometry was decided later.
- **Commits:** `c67af02` through `6841ab4`.

### Period 28 - RT And Native Advanced Parity Planning

- **Goal:** route acceleration structures, RT pipelines, SBT dispatch, Metal
  mapping, and native-only gaps without weakening the portable core.
- **Outcome:** produced build/pipeline/dispatch plans, a native closure
  inventory, parity matrix, and exact routing into runtime work.
- **Boundary:** no driver object or ray dispatch was claimed. Period 29 owned
  public runtime objects, Period 30 private records, and Periods 31-34 pixels.
- **Commits:** `f24a1b7` through `ba718c8`.

### Period 29 - Native Advanced Public Runtime Contracts

- **Goal:** turn Period 28 plans into runtime-owned public objects and commands.
- **Outcome:** added acceleration-structure, RT pipeline, SBT, dispatch, Metal
  mapping, parity, and stress runtime contracts plus examples.
- **Durable decision:** public handles may own backend-neutral runtime state
  while native handles remain private.
- **Boundary:** recorded command intent was not native driver execution; that
  distinction was assigned to Period 30 and later visible slices.
- **Commits:** `237c6bd` through closeout `266cfb2`.

### Period 30 - Backend-Private Runtime Records

- **Goal:** connect public RT/advanced objects to private backend records
  without exposing native types.
- **Outcome:** added private AS handles/build records, RT pipeline metadata, SBT
  and dispatch records, Metal table metadata, native closure counts, and
  stability diagnostics.
- **Boundary:** the records still did not prove driver AS builds, pipeline
  creation, trace dispatch, or pixels. Those were split by backend and scene
  complexity into Periods 31-34.
- **Commits:** `ec1346a` through closeout `d4d4e46`.

### Period 31 - First Visible Metal Ray Tracing

- **Goal:** turn the recorded Metal RT path into native ray-traced pixels.
- **Outcome:** created a real Metal acceleration structure, native RT compute
  path, command dispatch, drawable presentation, capability gate, and a visible
  first-triangle result.
- **Durable decision:** unsupported devices exit with a typed capability
  message; no raster fallback may masquerade as RT success.
- **Boundary:** the first triangle did not claim mesh/procedural parity,
  maintenance breadth, or Vulkan support.
- **Commits:** first visible slice `7e90032`; later native path consolidation
  `49ce699`.

### Period 32 - First Visible Vulkan Ray Tracing

- **Goal:** create a real Vulkan KHR AS/pipeline/SBT/trace/present path on a
  device exposing the required extensions and features.
- **Outcome:** added capability diagnostics, BLAS/TLAS builds, precompiled RT
  SPIR-V, a KHR RT pipeline, aligned SBT storage, `vkCmdTraceRaysKHR`, output
  image binding, and presentation.
- **Physical evidence:** Windows 10 on an NVIDIA GeForce RTX 5080 visibly
  executed the path; the later procedural marker
  `visible_vulkan_procedural_rt_scene` superseded the original triangle marker.
- **Boundary:** MoltenVK and other runtimes without the complete KHR set report
  actionable unsupported reasons.
- **Commits:** implementation `2ddff49`; supported-hardware/CI evidence
  consolidation `e303a61`.

### Period 33 - Native RT Mesh Scene

- **Goal:** replace first-triangle smoke paths with a room/sphere mesh scene
  built from caller-provided triangle data.
- **Outcome:** added mesh geometry descriptors, buffer validation,
  multi-BLAS/TLAS scene inputs, and native full-scene dispatch/presentation.
- **Evidence:** Metal produced `visible_metal_full_mesh_rt_scene`; Vulkan mesh
  input executed on supported RT hardware before the procedural replacement.
- **Boundary:** camera/material/light data remained example-scoped, and custom
  procedural intersection belonged to Period 34.
- **Commit:** the integrated native RT artifact/scene work is `690922e`.

### Period 34 - Procedural RT Geometry

- **Goal:** replace Vulkan tessellated sphere approximations with AABB geometry
  and a custom intersection shader.
- **Outcome:** added procedural/custom-intersection feature gates, AABB build
  input, intersection SPIR-V, procedural hit groups/SBT records, and the
  `visible_vulkan_procedural_rt_scene` acceptance path.
- **Boundary:** Metal procedural intersection-function-table execution did not
  land; Metal retained its pixel-producing reference path. Mixed mesh and
  procedural scene ownership moved forward.
- **Durable decision:** native Metal table metadata was not reported as
  executable custom intersection.
- **Commit:** integrated scene/artifact implementation `690922e`.

### Period 35 - Shared RT Scene Data Boundary

- **Goal:** remove active shader-local scene constants while keeping scene data
  and native handles on the correct side of the abstraction.
- **Outcome:** one example-owned `RtSceneData` payload supplied frame, camera,
  sphere, color, and material bytes to both Vulkan Slang and Metal MSL paths.
- **Durable decision:** vkmtl owns generic inline dispatch data, not a built-in
  Cornell-box scene schema.
- **Boundary:** full Metal procedural tables and broader mixed-instance
  material lookup were not inferred from shared payload compatibility.
- **Commit:** `cc3db60`.

### Period 36 - Portable Sync And Queue Semantics

- **Goal:** make sync objects, logical queue selection, fallback, and ownership
  explicit enough for future native async work.
- **Outcome:** added sync capability reports, commit synchronization
  descriptors, queue planning, fallback diagnostics, and ownership tests.
- **Boundary:** this was the portable contract. Native Vulkan timeline submit,
  Metal shared events, and physical work queues were completed in Period 48.
- **Durable decision:** queue fallback is inspectable and cannot be called a
  dedicated native queue.
- **Commit:** `0a5ddc3`.

### Period 37 - Portable Memory, Heaps, And Residency

- **Goal:** define heap reservations/aliasing, budget reports, transient
  pressure, and deterministic sparse churn.
- **Outcome:** added heap aliasing validation, peak/savings diagnostics,
  native-or-fallback budget classification, and residency churn plans/tests.
- **Boundary:** no native placed resource or sparse page command was claimed.
  Native heaps followed in Period 49; sparse execution remained unsupported.
- **Durable decision:** fallback estimates are labeled and never upgraded to
  native telemetry.
- **Commit:** `41fb2de`.

### Period 38 - Resource-Table Pressure And Artifact Compatibility

- **Goal:** make large-table requirements and pipeline-cache compatibility
  deterministic before native pressure work.
- **Outcome:** added resource-table pressure plans, partially-bound and
  update-after-bind requirements, and artifact manifests keyed by backend,
  shader, reflection, formats, schema, and toolchain.
- **Boundary:** plans did not consume `VkPipelineCache` or `MTLBinaryArchive`
  and did not prove large tables on a GPU; Period 50 supplied that execution.
- **Commit:** `45d31cc`.

### Period 39 - RT Completeness Contracts

- **Goal:** model AS maintenance, many-instance/mixed TLAS layouts, ray query,
  complex SBTs, callable records, and stress workloads.
- **Outcome:** added capability-gated plans for update/refit/compaction,
  transforms/masks/material metadata, ray query, complex SBT layout, and
  deterministic stress composition.
- **Boundary:** these were portable contracts and diagnostics, not blanket
  native execution. Period 52 later implemented the admitted ordinary
  maintenance subset and rejected the still-incomplete paths precisely.
- **Commits:** `916182d`, `ebfcb83`, `2b952e2`, `bdc2d44`, and `4aea64c`.

### Period 40 - Advanced Geometry Draw Plans

- **Goal:** move tessellation and mesh/task examples from descriptor probes to
  public draw/dispatch plans.
- **Outcome:** added tessellation patch descriptors, Vulkan/Metal lowering
  metadata, factor-buffer ownership, mesh dispatch plans, and typed feature
  failures.
- **Boundary:** visible native pipelines and encoder hooks still did not exist.
  Period 51 performed the compiler audit and executable subset.
- **Commits:** `2c17e3c` through closeout `6a6cd8a`.

### Period 41 - External Interop Matrix

- **Goal:** make external resource/sync contracts explicit across platform,
  backend, handle type, process scope, and device scope.
- **Outcome:** added capability/import/usage/synchronization plans, ownership
  rules, failure diagnostics, and public examples.
- **Boundary:** a native-required plan did not prove an OS/API import call.
  Executable Metal imports and precise rejected routes arrived in Period 53.
- **Durable decision:** borrowed and transferred handles have distinct lifetime
  responsibility.
- **Commits:** `90ce219` through `a98aaf0`.

### Period 42 - Format, Copy, Layout, And Attachment Edges

- **Goal:** close common format/copy/subresource/depth-stencil/MSAA semantics.
- **Outcome:** implemented exact capability matrices, row/alignment validation,
  mip/layer/slice copies, shared subresource state, Vulkan scaled blit, depth
  copy subsets, and color resolve.
- **Unsupported outcomes:** Metal scaled blit, packed depth/stencil copy,
  ordinary MSAA copy/readback, depth/stencil resolve, and non-exact view
  reinterpretation remained typed unsupported.
- **Durable decision:** backend layouts and encoder state stay private behind
  the public subresource state model.
- **Commit:** `1873e31`.

### Period 43 - Profiling, Capture, And Diagnostics

- **Goal:** make native command streams identifiable in captures and issue
  reports.
- **Outcome:** established label lifetime/naming, marker nesting, Vulkan debug
  utils, Metal debug/capture scopes, timestamp/query profiling plans, and
  issue-snapshot bundles.
- **Boundary:** logical/CPU timestamp fallback was labeled; unsupported native
  counters were not converted into fake GPU durations.
- **Commits:** `d9be332`, with release-matrix integration in `e2a7362`.

### Period 44 - CI, Device Matrix, And Soak Validation

- **Goal:** replace broad parity statements with a repeatable evidence matrix.
- **Outcome:** defined hosted/self-hosted boundaries, smoke hosts, pixel and
  screenshot regressions, bounded soak workloads, and a release evaluator.
- **Evidence:** all nine gates were observed; hosted macOS/Linux/Windows
  artifacts and reviewed physical Metal plus Windows/NVIDIA Vulkan evidence
  produced `release ready: true`.
- **Boundary:** an unexecuted Linux self-hosted GPU lane was not inferred from
  hosted builds. Advanced pressure lanes remained missing evidence unless a
  suitable backend path and device run both existed.
- **Commits:** infrastructure `e2a7362`, portability/device evidence `e303a61`,
  hosted release evidence `04bc370`.

### Period 45 - Native Semantic Coverage Audit

- **Goal:** replace feature-family optimism with a source-driven Metal semantic
  ledger and exact Vulkan/compatibility mapping.
- **Outcome:** audited 99 stable Metal semantic units against the macOS 26.2
  SDK, mapped all 78 concrete Metal protocols and all 86 then-current feature
  fields, and routed 77 incomplete units exactly once to Periods 46-54.
- **Truthfulness correction:** usable occlusion queries were turned off until
  real result storage/readback existed; native query API availability remained
  a separate fact.
- **Durable decision:** planning, native-query availability, and executable
  support use different statuses and evidence classes.
- **Evidence:** `run-semantic-inventory-check`; 583/583 tests at closeout.
- **Commit:** audit implementation `f482e3c`.

### Period 46 - Native Queries, Counters, And Specialization

- **Goal:** replace query placeholders with real results and implement Metal
  function constants.
- **Outcome:** added Vulkan query pools, Metal visibility storage, native
  timestamp paths where fully gated, resolve/readback lifetime rules, and Metal
  vertex/fragment/compute constants by numeric ID.
- **Physical evidence:** Apple M4 Pro returned occlusion visible=1/empty=0,
  reset/reuse, CPU/GPU resolve agreement, and exact specialization pixels.
- **Boundary:** native timestamp duration was not claimed without calibration;
  pipeline statistics and multi-counter shapes remained closed.
- **Vulkan evidence:** focused tests and forced build, not a new physical run.
- **Commit:** `8023539` (full `8023539505ecc47f21ce0dc271d924459ece166e`).

### Period 47 - Core Resource, Render, And Compute Breadth

- **Goal:** close common-workload parts of broad Metal rows without hiding
  advanced remainders.
- **Outcome:** expanded limits, storage modes, formats, views/swizzles,
  samplers, MRT, attachments, ordinary bindings, dynamic raster state,
  direct/indirect compute, 32-bit atomic/threadgroup memory, reflection, and
  managed synchronization.
- **Physical evidence:** Apple M4 Pro capability, compute readback, atomics,
  groupshared memory, transfer, and managed synchronization passed.
- **Unsupported boundary:** incompatible views, advanced atomics, native
  fences/heaps/function tables, tile attachments, sample positions, and the
  unbounded native format universes were not absorbed into the claim.
- **Vulkan evidence:** tests/forced build; no new atomic physical rerun.
- **Commit:** `7d791d0`.

### Period 48 - Native Synchronization, Queues, And Timing

- **Goal:** replace logical sync/queue views with truthful native execution
  where the portable contract was exact.
- **Outcome:** implemented Vulkan timeline semaphores, Metal shared events,
  host/GPU wait/signal, physical work queues, ownership enforcement, lifecycle
  callbacks/status, and capability-gated timed presentation.
- **Physical evidence:** Apple M4 Pro native timeline/shared-event transfer,
  lifecycle delivery, and minimum-duration presentation pixel regression.
- **Unsupported boundary:** Vulkan shared events/timed presentation, explicit
  untracked hazards, raw family control, async-return guarantee, callback
  thread identity, and calibrated display timestamps.
- **Vulkan evidence:** tests and complete forced build, not a physical P48 run.
- **Commit:** `bbe40a6`.

### Period 49 - Native Heaps, Telemetry, And Memoryless Attachments

- **Goal:** execute exact heap/telemetry contracts and decide residency and
  memoryless semantics truthfully.
- **Outcome:** implemented Metal placement heaps, Vulkan shared
  `VkDeviceMemory`, exact requirements/offset binding, heap-child lifetime,
  native memory telemetry, and Metal hardware-memoryless attachments.
- **Physical evidence:** Apple M4 Pro heap-backed transfer/readback, native
  memory report, and 4x memoryless MSAA resolve passed.
- **Unsupported outcomes:** Vulkan memoryless guarantee, native sparse/tiled
  page execution, explicit residency sets, explicit CPU cache policy, and
  content optimization hints.
- **Durable decision:** Vulkan lazily allocated memory is not presented as a
  no-physical-backing guarantee.
- **Commit:** `79d6196`.

### Period 50 - Binding Tables, Indirect Commands, And Persistence

- **Goal:** execute scalable tables, reusable command lists, and driver cache
  artifacts while rejecting unrepresentable dynamic-link/generated-command
  claims.
- **Outcome:** implemented native Metal argument buffers, Vulkan indexed
  descriptor sets, pipeline layout fingerprints, CPU-authored reusable render/
  compute command lists, Metal ICB or exact direct expansion, `VkPipelineCache`,
  and `MTLBinaryArchive` persistence.
- **Physical evidence:** Apple M4 Pro bound 64 textures plus one sampler,
  executed a native inherited ICB draw, and reused a persisted binary archive.
- **Unsupported outcomes:** GPU-authored command mutation, parallel child
  render encoders, schema-1 dynamic libraries/linked functions/stitching,
  lifetime-safe general native object pooling, and Vulkan pipeline libraries.
- **Vulkan evidence:** tests and forced build, not a new physical large-table
  run.
- **Commit:** `25da0d1`.

### Period 51 - Advanced Rasterization And Geometry Execution

- **Goal:** execute advanced geometry stages that the pinned toolchain could
  lower exactly and close the rest precisely.
- **Executable outcomes:** Vulkan hull/domain tessellation and patch draw;
  Metal mesh pipeline/threadgroup dispatch; Vulkan `VK_EXT_mesh_shader`
  pipeline and draw-mesh-tasks path behind queried limits.
- **Physical evidence:** Apple M4 Pro reached the visible Metal mesh loop.
  Vulkan geometry had deterministic/forced-build evidence, not a physical run.
- **Unsupported outcomes:** Metal tessellation because Slang rejected Metal
  hull/domain; Vulkan task and Metal object/amplification because compiler
  probes crashed; advanced-stage resources until visibility/binding is exact.
- **Unsupported outcomes:** rate maps, tile/imageblock, raster-order/programmed
  blend, layered amplification, logical attachment remapping, depth clip, and
  programmable sample positions.
- **Commit:** `a199528`.

### Period 52 - Ray Tracing Breadth

- **Goal:** execute the ordinary AS maintenance/geometry subset and close
  advanced RT shapes that the shader/runtime contracts could not represent.
- **Foundation:** `ac19b33` introduced a true `HeadlessContext`, separating
  windowless GPU ownership from `WindowContext` before this stress slice.
- **Executable outcomes:** native Metal/Vulkan update/refit/compact copy,
  Metal triangle and AABB BLAS, multi-source Metal TLAS, validation, and a
  headless stress example.
- **Physical evidence:** Metal completed 32 alternating update/refit commands,
  compact copy, AABB BLAS, and two-source TLAS through `HeadlessContext`.
- **Unsupported outcomes:** compacted-size result ownership, Metal visible/
  intersection function tables, executable Vulkan inline ray query, callable
  artifacts, complex SBT payload/program breadth, motion/curve/row-major
  geometry, and Metal 4 AS descriptors.
- **Boundary:** planning structures for those paths remained diagnostic-only;
  usable capabilities stayed false. Vulkan had tests/forced build only here.
- **Commits:** implementation `ef06da9`; later Metal AS sizing correction
  `221c5b9`.

### Period 53 - External Interop, Metal I/O, And Topology

- **Goal:** execute external imports whose descriptors were complete, expose
  selected-device identity, and reject incomplete I/O/sync/insertion shapes.
- **Executable outcomes:** Metal same-device `MTLBuffer`/`MTLTexture` import,
  single-plane IOSurface texture import, ordinary vkmtl accessors/readback, and
  backend-neutral Metal registry/peer plus Vulkan UUID/group diagnostics.
- **Physical evidence:** Metal API Validation passed raw buffer, raw texture,
  and IOSurface GPU readback; topology reported Metal registry identity.
- **Unsupported outcomes:** Vulkan external imports without memory/allocation/
  tiling/ownership data; value-free external sync submission; callbacks without
  active encoder handles; Metal I/O/compression without async lifecycle; and
  cross-device execution. Topology remained diagnostic-only.
- **Commit:** `073d96c`.

### Period 54 - Metal 4, Counters, Tensor, And ML Closure

- **Goal:** close the final 20 audit routes by exact composition, one portable
  query addition, or precise unsupported decisions.
- **Executable outcomes:** Boolean versus exact-count occlusion mode; Metal
  counting visibility; Vulkan precise occlusion; Metal 4 argument-table effects
  composed through `ResourceTable`; ordering composed through the sync/hazard
  contract.
- **Physical evidence:** Apple M4 Pro returned exact counts
  `visible=61170, empty=0` before/after reset with zero pixel delta.
- **Unsupported outcomes:** Metal 4 pools/allocators/reusable buffers/feedback,
  flexible pipeline/compiler/archive/dataset objects, tensor/ML resources and
  encoders, function logs, advanced reflection, counter heaps/device counters,
  calibration, pass-boundary sampling, and multi-counter/statistics shapes.
- **Audit result:** 111 Metal semantic units, 78 protocols, 93 feature fields,
  and zero routed gaps; unsupported families received no placeholder bit.
- **Commit:** `398fa23`.

### Period 55 - Explicit RT Texture Presentation

- **Goal:** separate ray dispatch from presentation while leaving color-space
  meaning with the caller/application.
- **Outcome:** added caller-owned `RayTracingTextureResources` and
  `dispatchRaysToTexture(...)`; Metal writes the supplied texture, Vulkan ends
  in sampled layout, and the example composes `rgba16_float` through one shared
  fullscreen pass.
- **Color contract:** dispatch stores caller-defined numbers and assigns no
  color space. The example alone clamps its historical display-referred RGB,
  applies the sRGB EOTF, and relies on the sRGB attachment OETF to reproduce
  bytes `0/46/128/204/255` for `0/0.18/0.5/0.8/1`.
- **Evidence:** deterministic transform/resource tests; Metal offscreen pixel
  regression within one byte; Metal API Validation finite RT run; Vulkan
  implementation/build and later physical submission/presentation evidence.
- **Compatibility:** the old drawable alias/method remained as a legacy path;
  new code was directed to composable texture dispatch.
- **Follow-up correction:** `8c75c45` preserved the reference display values
  after the initial implementation `32a293f`.

### Period 56 - Presentation Request And Selection

- **Goal:** make requested versus native-selected presentation format and
  extent observable and deterministic.
- **Outcome:** added `Swapchain.selectedFormat()`. Automatic SDR selection is
  `bgra8_unorm_srgb` then `bgra8_unorm`; explicit requests succeed exactly or
  return `UnsupportedPresentationFormat`. Requested extent stays in the
  descriptor; `Swapchain.extent()` reports actual native extent.
- **Outcome:** tightened resize/recovery, terminal `SurfaceLost`, active-command
  gates, present-queue retirement, failed-commit cleanup, and exact pipeline/
  drawable format validation.
- **Legacy boundary:** `dispatchRaysToDrawable(...)` remains compatibility-only
  and performs a raw BGRA8 copy with no EOTF/OETF, tone mapping, HDR, gamma, or
  gamut conversion. Canonical code dispatches to texture and composes using the
  selected pipeline format.
- **Physical Metal:** sRGB/linear/automatic request pixel and drawable smokes,
  selected-format capability dump, and both legacy RT formats passed with Metal
  API Validation.
- **Physical Vulkan:** after the Windows loader fix (`c747dcb`) and AS size
  variant reservation fix (`ee720dc`), canonical and compatibility RT routes
  built BLAS/TLAS, submitted 518400 rays, and completed finite runs.
- **Vulkan visual correction:** the first canonical image was vertically
  flipped while raw-copy compatibility was correct. Fragment-position UV
  composition (`f92b6b6`) restored top-left orientation; the corrected
  canonical path completed 3000 frames. Evidence closeout is `4ac780f`.
- **Evidence boundary:** supplied Vulkan logs did not positively identify the
  device/driver or prove Khronos validation-layer enablement, so neither claim
  was made. The asymmetric 5x2 Vulkan pixel regression remained separate
  release-matrix evidence at the snapshot.
- **Non-goal:** no HDR formats, metadata, exposure, tone mapping, gamut policy,
  or general color-management pipeline was added.

### Post-Period 56 - Raster Coordinate Parity Correction

- **Problem:** ordinary Vulkan geometry used a positive native viewport height,
  so Metal-like clip-space Y appeared vertically inverted even though the
  separate fullscreen texture-composition regression was top-left.
- **Outcome:** `dd40422` lowers public positive, top-left viewports to adjusted
  negative-height Vulkan viewports, preserves direct winding names, and applies
  the existing winding/cull descriptors through native Metal encoder state.
- **Regression:** the pixel lane now renders a counter-clockwise asymmetric
  triangle with back-face culling and samples distinct top/bottom pixels. Both
  Metal and Vulkan report `raster_orientation=top_left`; Vulkan returned zero
  raster and composition channel delta.
- **Physical Vulkan:** smoke/default/stress voxel runs completed 24/48/160
  frames at 9/81/289 resident chunks, drained pending work, and emitted
  `voxel_world_pressure_test=ok`. The corrected stress run observed 121 visible
  and 168 culled chunks.
- **Evidence boundary:** the corrected-path log did not repeat the commit hash
  or clean-worktree command, so it proves the physical behavior but does not
  replace a future exact-release-commit matrix refresh.

## Durable Historical Decisions

Several decisions survived many periods and explain why some advanced native
APIs are absent from the portable surface:

1. A usable feature requires a complete public owner, descriptor/result shape,
   lifetime model, backend lowering, and suitable evidence. A native feature
   bit or planning object is insufficient.
2. Exact composition is acceptable: one vkmtl operation may lower to multiple
   Vulkan/Metal operations plus internal state, provided the observable result
   is preserved.
3. A backend-only semantic with no exact portable contract is explicitly
   unsupported rather than approximated by an unrelated feature.
4. Native handles and command insertion are intentional escape hatches. They
   do not define ordinary vkmtl API shapes or compatibility promises.
5. Examples use canonical public APIs and can own scene/color policy. vkmtl
   owns resource, command, synchronization, and presentation contracts, not an
   engine's rendering model.
6. Build coverage, source inspection, and unit tests never substitute for
   physical GPU evidence; a screenshot never substitutes for deterministic
   bytes when exact pixel semantics are the acceptance target.
7. Unsupported decisions are stable historical outcomes until a later period
   adds the missing contract and executable evidence. They are not silently
   reopened by SDK growth.

At snapshot `4ac780f`, Periods 1-56 were historically closed and `v0.1.0`
remained the published baseline. Zero audit routing gaps meant every audited
row had an executable/composed or explicit unsupported outcome, not that every
Metal or Vulkan API was implemented. Use current inventories and capability
queries for present-day claims; use this ledger to understand their history.
