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
| Pressure and presentation closure | 19, 55-56 and post-56 | Bounded voxel pressure, composable and material-bound hardware RT, one-sample temporal PTGI, deterministic SDR selection, corrected Vulkan orientation, and the example-private day/night/UI plus refractive-water composition |

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

### Post-Period 56 - Textured Hybrid Ray-Traced Voxel World

- **Goal:** turn the bounded voxel pressure example into a more representative
  textured scene that exercises the existing native triangle BLAS/TLAS and
  caller-owned texture-dispatch contracts without allocating public API.
- **Materials:** replaced the small three-material atlas with a deterministic
  476 x 68 sRGB atlas containing seven face-specific 64 x 64 tiles plus
  replicated two-texel borders: grass top/side, dirt, stone, sand, and snow
  top/side. Atlas alpha drives shader-side height-detail normals. No mip chain
  was added, so distant shimmer remains an explicit example limitation.
- **Hybrid path:** retained raster ownership of material/albedo shading and
  added a full-resolution `rgba8_unorm` sun-shadow/sky-visibility pass. Every
  resident chunk can own an indexed triangle BLAS; the per-frame TLAS is
  bounded to the nearest 7 x 7 chunks (49 instances), including under the
  289-resident stress profile.
- **Selection:** `VKMTL_VOXEL_RT=auto|off|required` defaults to capability-based
  automatic selection. `off` preserves the old raster pressure lane;
  `required` returns typed capability/format errors rather than falling back.
- **Backend correction:** Vulkan TLAS allocation now covers the complete
  instance count and maps one repeated or N exact BLAS sources. Metal queries
  the real indexed/AABB/instance descriptor sizes, rechecks final descriptors
  and scratch capacity, dynamically owns source arrays, and validates that the
  dispatched pipeline expects the actual BLAS/TLAS kind.
- **Metal evidence:** Metal API Validation completed hybrid smoke with nine
  traced chunks and default with 49. Deterministic default readback reported
  2445795 primary hits, 670298 shadowed pixels, and 1621736 sky-occluded
  pixels, with native driver submission and visibility validation true.
- **Vulkan boundary:** shaders, focused tests, and forced Vulkan builds pass.
  Physical Vulkan hybrid smoke/default evidence remains pending and must not be
  inferred from compilation or earlier raster-only voxel runs.
- **Non-goals:** this is not path tracing, global illumination, reflections,
  HDR, denoising, sparse residency, or a production streaming architecture.

### Post-Period 56 - Voxel Night Presentation And Example UI

- **Goal:** turn the hybrid voxel workload into an interactive night scene
  without adding engine policy or declarations to vkmtl's public API.
- **Sky and lighting:** added an ordinary fullscreen render pass with a
  world-space night gradient, visible moon, and direction-stable stars whose
  brightness varies with time. Raster and hybrid-RT lighting share the moon
  direction so the visible source and shadow query agree.
- **Terrain:** replaced the periodic height profile with platform-stable
  fixed-point continentalness, erosion, ridge, detail, temperature, and
  moisture fields. Grass, sand, and snow surfaces, a cached one-block mesh
  halo, and world-coordinate sampling keep positive and negative chunk
  boundaries continuous while preserving the existing streaming limits.
- **Example UI:** added a CPU 5x7 bitmap font, dynamic alpha-blended UI
  vertices, a right-aligned FPS counter, and a translucent ESC title overlay.
  The overlay displays `VKMTL VOXEL WORLD` and `Press ESC to continue`; Escape
  toggles input capture instead of closing the window.
- **Controls:** interactive flight now uses WASD, Space/Shift for vertical
  motion, Ctrl acceleration, and the existing mouse/arrow look and `R` rebuild.
- **Evidence:** `zig build test` passed with the semantic inventory check, and
  `zig build -Dvulkan` passed as compilation evidence only. Under Metal API
  Validation, the 48-frame default hybrid run reported native submission,
  validated visibility, 1846752 primary hits, 785967 shadowed pixels, and
  403844 sky-occluded pixels. A 160-frame raster stress run drained to 289
  resident chunks with zero pending work. Physical Metal visual checks accepted
  the night sky, moon/stars, FPS label, and both ESC overlay states.
- **Evidence boundary:** no physical Vulkan night-presentation or hybrid result
  is claimed; that exact-host lane remains pending.

### Post-Period 56 - Voxel 60-Second Day/Night Cycle

- **Goal:** extend the example-private night presentation into a complete
  time-varying sky and lighting loop without allocating public vkmtl API or
  changing the bounded voxel/RT workload contract.
- **Shared clock:** one 60-second phase maps 0/15/30/45/60 seconds to midnight,
  sunrise, noon, sunset, and wrapped midnight. The sky uniforms, raster
  terrain uniforms, and hybrid-RT visibility dispatch all consume the same
  per-frame celestial state.
- **Sky:** the sun and moon remain opposite, the appropriate body is shown
  above the horizon, night/twilight/day gradients blend continuously, and
  direction-stable stars twinkle while fading out with daylight.
- **Terrain and visibility:** ambient tint, direct color, strength, and
  direction follow the shared cycle. Direct strength reaches zero at the
  horizon transition, hiding the sun-to-moon direction handoff. The RT target
  remains binary directional-light/sky visibility owned by the existing
  hybrid composition rather than becoming a lighting or color buffer.
- **Determinism:** phase key points, wrap/continuity, normalized opposite
  directions, non-finite input handling, and the expanded sky/raster uniform
  ABI are covered by example-local tests. Representative night, twilight, and
  daytime frames were visually inspected on Metal.
- **Evidence:** that presentation-slice snapshot passed 730/730 tests, the ordinary build,
  and the forced Vulkan build. Under Metal API Validation, a 48-frame default
  hybrid run completed with 81 resident chunks, 49 visible chunks, zero
  pending work, native submission, validated visibility, 1846752 primary hits,
  553298 shadowed pixels, and 403844 sky-occluded pixels.
- **Evidence boundary:** backend shader/build checks are not physical Vulkan
  execution. The current Vulkan hybrid and presentation lane remains pending,
  and no Vulkan device result is inferred from compilation.

### Post-Period 56 - RT Resource Binding And Material-Bound Voxel PTGI

- **Goal:** extend the caller-owned RT texture route so ray shaders can consume
  ordinary application material resources, then use that contract to evolve
  the earlier binary-visibility voxel slice into a bounded hardware-RT PTGI
  workload. The earlier section records the intermediate state and its then-
  current non-goals; this later slice supersedes those example limitations.
- **Public allocation:** `ShaderVisibility` gained default-false
  `ray_tracing`; `RayTracingPipelineDescriptor` gained nullable
  `bind_group_layout`; and `RayTracingDrawableResources` plus its exact
  `RayTracingTextureResources` alias gained nullable `bind_group`. No root
  alias, facade declaration, owner method, runtime handle, or second resource
  union was added.
- **Binding contract:** fixed bindings 0, 1, and 2 own the acceleration
  structure, primary output, and inline data. One application group reuses
  ordinary buffers, textures, and samplers in bindings 3 through 14. Arrays
  occupy consecutive slots; dynamic offsets and multiple groups remain out of
  scope. The pipeline copies its layout and dispatch borrows the live matching
  group and resources through command-buffer completion.
- **Backend mapping:** Metal binds the application group through native
  compute-kernel buffer/texture/sampler slots. Vulkan maps the same group into
  its RT descriptor set. Both mappings retain `native-exact` status, but their
  evidence differs: Metal physically executes the material-bound path under
  API Validation, while Vulkan currently has focused tests, builds, and forced
  compile validation only. No physical Vulkan PTGI result is claimed.
- **Scene and material evidence:** a full-resolution G-buffer records geometric
  normal and ray distance. Exact secondary-hit material identity remains in a
  separate CPU-derived terrain-column volume and the same deterministic atlas
  used by rasterization; it is not guessed from height or packed into an
  approximate G-buffer material channel.
- **PTGI workload:** every covered full-resolution pixel keeps direct sun/moon
  visibility separate and takes one cosine-weighted hardware-RT indirect
  sample per frame. The one-bounce result is stored as scene-linear
  `rgba16_float` radiance, temporally reprojected with rejection and clamping,
  then reconstructed through four edge-aware a-trous passes before
  composition.
- **Bounds and discontinuities:** the TLAS covers the complete bounded 17 x 17
  resident neighborhood, up to 289 indexed chunk sources. The material-bound
  result fades toward the existing sky/ambient result at that source boundary.
  History resets after resize, camera cuts, discontinuous celestial-light
  changes, or source-signature/TLAS changes; these rules remain example policy,
  not vkmtl core semantics.
- **Presentation provenance:** the final pass uses independently authored fixed
  exposure, bloom, vignette, filmic shoulder, output gamma, sharpening, and
  dithering, with a subtle fixed saturation adjustment. Exposure and
  saturation are not adaptive. SEUS PTGI E12 supplied visual-strategy
  references only. No SEUS source, shader organization, constants, or assets
  were copied, and neither source equivalence nor pixel identity is claimed.
- **Evidence:** 780/780 tests, `run-api-guard`, the default build, package
  consumer smoke, and forced Vulkan compilation passed. Under Metal API
  Validation, smoke and default physically traversed all 9 and 81 resident
  chunk sources, and a 300-frame smoke soak retained native submission,
  finite nonzero direct, indirect, and reconstructed radiance, and zero invalid
  samples. The three current observation groups are recorded in
  `validation.md` rather than duplicated here.
- **Evidence boundary:** the Metal smoke/default/soak observations came from a
  dirty source snapshot. They establish physical implementation behavior, but
  they are not clean exact-commit or release-candidate evidence. Vulkan PTGI
  remains tests/build/forced-compile evidence only until the physical lane runs
  on a supported Vulkan RT host.
- **Compatibility:** the nullable fields preserve omitted-field source shapes,
  but the complete binding ABI targets `v0.2.0`: inline data moves from binding
  1 to 2, and `BindingError` gains reserved-slot and pipeline-layout mismatch
  cases. This slice is not a `v0.1.x` patch allocation.

### Post-Period 56 - Celestial-Disk Soft Visibility Refinement

- **Goal:** soften the voxel world's directional shadow edges while retaining
  the established E12-inspired presentation, full-resolution hardware-RT
  workload, and bounded one-bounce indirect path.
- **Source contract:** the sun and moon angular radii moved into the shared
  celestial state. The sky disk and RT shadow sampler now consume the same
  values, so the visible body size and emitted-direction cone cannot drift.
- **Sampling:** each covered pixel retains one direct hardware shadow ray per
  frame. A static per-pixel scramble plus an R2 temporal sequence selects a
  uniform tangent-disk sample within the active angular radius. Diffuse
  `NdotL` uses the center direction; only visibility uses the sampled
  direction. The indirect bounce keeps its independent cosine sample, and a
  secondary hit uses another independent disk sample.
- **Reconstruction:** direct visibility owns two `rgba16_float` history
  textures separate from indirect radiance. Temporal reprojection stores mean,
  second moment, validity, and history length; geometry rejects use the same
  depth/normal contract as indirect history. One 5 x 5 normal/depth-aware pass
  writes final visibility, while indirect radiance keeps its four a-trous
  passes. Existing scratch textures are reused after indirect reconstruction.
- **Scope:** this is example-private rendering policy. It adds no vkmtl public
  declaration, backend semantic row, source-compatibility promise, or generic
  denoiser API. It also does not copy the HRR half-resolution pipeline or claim
  SEUS source/pixel equivalence.
- **Evidence:** `zig build test`, `zig build`, `zig build -Dvulkan`, and
  `git diff --check` passed.
  Under Metal API Validation, fixed-midnight smoke completed 24 frames with
  86,867 reconstructed penumbra pixels, while fixed-noon default completed 48
  frames with 237,145. Both retained native RT submission, full PTGI
  validation, complete 9/81-source traversal, and zero invalid pixels.
  Interactive noon and lower-sun inspection retained geometry-aligned shadows
  with visibly softened transitions. Physical Vulkan execution remains a
  deferred evidence lane.

### Post-Period 56 - Voxel Biome And Daylight Balance Refinement

- **Goal:** retain the completed material-bound one-bounce PTGI path while
  darkening daytime occlusion correctly and adding deterministic vegetation and
  water without changing vkmtl's public surface or pressure bounds.
- **Lighting balance:** raster-only rendering retains its complete environment
  term. When PTGI is active, raster environment lighting becomes a small
  residual fill instead of adding a second full skylight contribution on top
  of reconstructed indirect radiance. Direct light remains gated by the
  independently reconstructed celestial-disk visibility signal.
- **Terrain features:** world-coordinate coarse-cell anchors place compact
  trunks and leaf crowns only when the complete footprint is ordinary grass,
  dry, and sufficiently level. Snow and water footprints reject trees. A
  separate low-frequency mask fills selected low sandy depressions to a fixed
  water level without replacing their underlying ground classification. The
  one-block chunk halo continues to sample the same global feature columns, so
  face culling remains deterministic across positive and negative boundaries.
- **Materials:** the deterministic atlas grew from seven to eleven tiles by
  appending wood top/side, leaves, and water. The RT material volume now stores
  one exact 16-byte column per world `(x,z)`: ground height, surface plus water
  level, a wood span, and a leaf span. Zig, Slang, and the direct Metal MSL path
  share the same packed byte-level contract, so secondary hits no longer infer
  above-ground vegetation or lake material from height alone.
- **Deliberate limit:** atlas alpha remains material height, chunk BLAS geometry
  remains opaque, and the raster terrain pass has no transparency stage.
  Consequently leaves and water are opaque voxel materials in this slice;
  cutout foliage, transmissive/refraction water, and RT any-hit transparency
  were not implied.
- **Bounds and scope:** chunks remain `16 x 64 x 16`, resident profiles remain
  9/81/289, and processing remains capped at two rebuilds and 8 MiB of uploads
  per frame. All feature generation, daylight balance, material packing, and
  presentation behavior remain example-private; no public API declaration or
  backend semantic claim changed.
- **Evidence:** `zig build test`, `zig build`, and `zig build -Dvulkan` passed.
  Under Metal API Validation, 24-frame smoke produced 19,180 visible vertices,
  88,473,600 primary rays, 118,340 reconstructed penumbra pixels, and zero
  invalid pixels. The 48-frame default lane drained at 81 resident chunks and
  produced 81,912 visible vertices, 176,947,200 rays, 258,864 penumbra pixels,
  and zero invalid pixels. The 160-frame raster stress lane drained at 289
  resident chunks with 242,336 visible vertices. Physical Vulkan execution of
  the updated material-bound route remains deferred.

### Post-Period 56 - Translucent Voxel Water Refinement

- **Goal and scope:** refine lake presentation inside `voxel_world` without
  changing vkmtl's public API, backend semantics, compatibility promises, or
  the established chunk-pressure bounds. Leaves remain opaque.
- **Geometry contract:** chunk meshing owns exact opaque and water index ranges
  while retaining faces at the solid-water interface. The opaque range feeds
  the terrain pass, G-buffer, and BLAS; water is excluded from G-buffer and
  acceleration-structure geometry.
- **Composition:** a second HDR pass draws water with premultiplied alpha,
  disabled depth writes, and far-to-near chunk ordering. Admission requires
  `DeviceFeatures.blend_state` and blendable `rgba16_float`; unsupported devices
  retain a precise capability gate instead of an approximate path.
- **Surface model:** four analytic waves use world coordinates and one
  continuous 64-second phase, avoiding per-chunk seams and discontinuous time
  resets. Fresnel response combines the water body with the current sky and
  active sun or moon highlight.
- **RT behavior:** because water is absent from the G-buffer and chunk BLASes,
  primary, visibility, and indirect rays treat it as optically thin and can
  reach the lake bed. The visible water surface remains raster composition;
  this is not RT transmission or a second transparent geometry layer.
- **Deliberate limits:** this slice adds no refraction, volumetric absorption,
  RT reflections, multilayer transparency, or order-independent transparency.
- **Evidence:** `zig build test`, `zig build`, and `zig build -Dvulkan` passed
  on the current source. Under Metal API Validation, the 24-frame smoke lane
  drained at 9 resident and zero pending chunks with 12 draws, 20,976 visible
  vertices, 31,464 visible indices, 1,095,464 uploaded bytes, 88,473,600
  primary rays, and zero invalid samples. The 48-frame default lane drained at
  81 resident and zero pending chunks with 44 draws, 84,224 visible vertices,
  126,336 visible indices, 7,080,312 uploaded bytes, 176,947,200 primary rays,
  and zero invalid samples. Both final-integration runs retained native RT
  submission and PTGI validation; physical Vulkan execution remains deferred.

### Post-Period 56 - Refractive And RT-Reflected Voxel Water

- **Goal and scope:** supersede the earlier alpha-composited lake model with
  depth-sensitive transmission and reflection while keeping all policy and
  resources private to `voxel_world`. No vkmtl public declaration, backend
  semantic, compatibility promise, or chunk-pressure bound changed.
- **Composition:** opaque sky and terrain render into a complete scene-linear
  HDR target. Water resolves into an independent full-coverage HDR overlay so
  its fragment shader can sample the opaque scene without a read/write feedback
  hazard. Overlay alpha records water coverage rather than material opacity;
  the presentation pass composites it before bloom and tone mapping.
- **Surface and transmission:** a dedicated water G-buffer stores the same
  world-continuous animated wave normal used for shading plus camera distance.
  The water shader projects a refracted camera segment into screen space,
  validates it against the opaque normal/distance G-buffer, and uses the
  water-to-opaque distance as a bounded thickness estimate. RGB Beer-Lambert
  transmittance attenuates the sampled opaque HDR radiance, and a water-colored
  in-scattering term replaces absorbed light.
- **Reflection:** the hybrid RT ray-generation pass clears the water reflection
  target, reconstructs visible water points from the water G-buffer, and traces
  one reflected ray against the opaque terrain TLAS. Opaque hits use the
  existing material and direct/environment lighting; misses use the current
  sky. Raster fallback leaves the target invalid, selecting the same sky
  fallback in the Fresnel composition. Water remains absent from the TLAS, so
  reflections do not contain another water layer and ordinary PTGI rays can
  still reach the retained lake bed.
- **Deliberate limits:** refraction can reuse only opaque data visible in the
  current frame; off-screen or occluded geometry is unavailable. Nested and
  underwater media, water-to-water reflection, caustics, multilayer
  transparency, and order-independent transparency remain out of scope. The
  reflection signal is one unfiltered ray per visible water pixel rather than
  a recursive or temporally reconstructed reflection system.
- **Validation contract:** finite RT runs read back reflection coverage,
  radiance, and validity. A fixed-camera lane requires nonzero covered and lit
  pixels plus zero invalid pixels and reports `rt_reflection_validated=true`;
  autopilot reports the same counts and marker without requiring visible water.
- **Evidence:** a fixed-camera 24-frame smoke run used `MTL_DEBUG_LAYER=1`, the
  Metal backend, and required native RT, with a positive `API Validation
  Enabled` marker. It submitted 24 RT dispatches and 88,473,600 primary rays,
  reported 1,017,402 primary-hit pixels, 438,485 reflection-covered pixels,
  438,485 lit reflection pixels, and zero invalid pixels, and ended with native
  submission, visibility/PTGI/reflection validation, and
  `voxel_world_pressure_test=ok`. The forced Vulkan build passes as compilation
  evidence only; physical Vulkan execution of this water path remains pending.

### Post-Period 56 - E12-Inspired Clean-Room Voxel Water Surface

- **Goal and provenance:** refine the completed transmission/reflection route
  toward the default SEUS PTGI E12 water character without changing its
  resource graph, public API, or backend semantics. E12 informed visual
  strategy only; its license precluded reuse, and no source, constants, shader
  organization, or assets were copied.
- **Surface:** six world-continuous analytic bands combine different scales,
  directions, and temporal harmonics. Raster shading and the water G-buffer
  share the same evaluated normal, with camera-distance and grazing-angle
  stabilization to restrain distant shimmer and preserve coherent reflection.
- **Transmission:** refraction displacement now scales with path thickness and
  distance and rejects invalid UV/depth candidates before direct-pixel
  fallback. A homogeneous single-scattering medium uses
  `sigma_a = (0.240, 0.062, 0.014)` and `sigma_s = 0.070`. It applies no
  painted blue body tint, leaving thin water predominantly transparent and
  letting blue-green character emerge with depth.
- **Reflection:** dielectric Fresnel uses `F0 = 0.02`, with a narrow
  approximately 420-exponent sun/moon glint. Water rays are capped at 96 world
  units while the opaque PTGI route retains 384. Misses evaluate a directional
  day/night/twilight sky with a restrained horizon and the active sun or moon
  disk and halo. The signal remains one unfiltered reflection sample per
  visible water pixel.
- **Deliberate limits:** foam, caustics, rain response, parallax water, TAA or
  reflection denoising, nested/underwater media, water-to-water reflection,
  off-screen refraction recovery, multilayer transparency, and OIT remain out
  of scope.
- **Evidence:** the refined source retained the strict fixed-noon Metal
  24-frame counts: 24 RT dispatches, 88,473,600 primary rays, 1,017,402 primary
  hits, 438,485 reflection-covered and lit pixels, and zero invalid pixels,
  with native submission plus visibility/PTGI/reflection validation true. A
  fixed-midnight 24-frame API Validation lane retained 438,485 covered pixels,
  reported 429,947 lit pixels, and kept the same rays, hits, zero-invalid
  result, and validation markers. The 24-frame Metal raster lane,
  `zig build test`, and `zig build -Dvulkan` passed. Physical Vulkan execution
  remains pending.

### Post-Period 56 - Five-Minute Atmosphere, Clouds, And Daylight Balance

- **Goal:** slow the example-private celestial presentation to a five-minute
  cycle, give the sky and every RT environment consumer one coherent analytic
  atmosphere/cloud model, and lower the daytime shadow floor without changing
  public vkmtl API or backend semantics. The earlier 60-second cycle section
  and its fixed-time commands remain historical evidence of that superseded
  snapshot rather than current probe values.
- **Clocks:** the 300-second celestial phase maps 0/75/150/225/300 seconds to
  midnight, sunrise, noon, sunset, and wrapped midnight. The validation
  override freezes only that celestial phase. World-anchored cloud wind uses
  real elapsed time, and the existing water-wave phase keeps its independent
  continuous 64-second loop.
- **Atmosphere and clouds:** a clean-room, E12-inspired analytic atmosphere
  responds to view and sun direction with a bright horizon, deep zenith, and
  warm low-sun glow while retaining the existing moon and stars. A lower
  self-shadowed cumulus layer and upper stretched cirrus layer appear in raster
  sky and, on the hybrid route, RT miss/PTGI environment and hardware-RT water
  reflection. Raster water fallback keeps the analytic current-sky tint and
  does not evaluate procedural clouds or celestial disks. A smooth ground-
  hemisphere fade prevents bright downward RT misses. RT cloud environment
  work is deferred to actual reflection/PTGI misses and the outer traced-edge
  blend. Dense cumulus gives full moving day/twilight shadows plus restrained
  moonlight shadows. Active-light strength gates that attenuation so the
  sun/moon switch happens at zero directional contribution. No E12 source,
  constants, shader organization, textures, or assets were copied.
- **Daylight balance:** daytime ambient changed from `0.52` to `0.44`; hybrid
  raster daylight safety changed from `0.20` to `0.14`; RT secondary-hit
  daylight environment changed from `0.18` to `0.13`; and traced-edge daylight
  environment changed from `0.72` to `0.56`. Night raster safety remains
  `0.20`, and direct sun, night ambient, water Fresnel, and celestial glint are
  unchanged.
- **Deliberate limits:** this remains a bounded analytic presentation. It does
  not implement weather or rain, volumetric cloud raymarching, cloud textures,
  cloud TAA, or a public atmospheric system.
- **Evidence:** `zig build`, `zig build test`, and `zig build -Dvulkan` passed.
  Under Metal API Validation, fixed-noon time `150` required-RT smoke completed
  24 frames with 88,473,600 rays, 1,017,402 primary hits, 438,485 reflection-
  covered and lit pixels, zero invalid pixels, every native/visibility/PTGI/
  reflection marker true, and `rt_ms=9.992`. Fixed-midnight time `0` retained
  the same ray, hit, and covered counts, reported 429,962 lit reflection pixels,
  zero invalid pixels, all markers true, and `rt_ms=9.547`. A fixed-noon
  24-frame Metal raster lane also passed. Default interactive required-RT noon
  stabilized around 65-68 FPS after warmup and raster sky around 120 FPS on
  the development machine; those frame rates are observations, not gates.

### Post-Period 56 - Wider View And Background Chunk Meshing

- **Goal and scope:** increase the ordinary interactive view from the former
  9 x 9 default neighborhood to 13 x 13 while removing CPU terrain meshing
  from the render thread. The current smoke/default/stress resident contract
  is 9/169/289 chunks. The old 9/81/289 records above remain valid only for
  their dated snapshots.
- **CPU scheduler:** `voxel_world` owns one example-private worker and permits
  one outstanding mesh ticket. Desired-set revisions issue a new ticket
  identity, so late completions are discarded instead of being uploaded into
  a newer world. If the worker cannot start, the same queue retains a
  synchronous fallback. Interactive execution admits one completed mesh per
  frame; finite validation admits two so bounded probes can drain without
  weakening the 8 MiB per-frame upload ceiling.
- **GPU boundary:** mesh completion does not make vkmtl command submission
  asynchronous. Vertex/index upload, per-chunk BLAS build, queue commit, and
  TLAS construction remain synchronous on the render thread. Normal TLAS
  publication batches source additions for up to four frames; bootstrap,
  queue drain, and source replacement rebuild immediately. Replaced BLAS
  owners remain deferred until the replacement TLAS has been published, so a
  live TLAS never references an already-retired source.
- **Contract boundary:** the worker, tickets, admission budgets, and batching
  policy are private to the example. They add no public API and no native-
  semantic inventory row, and they do not alter the synchronous
  `CommandBuffer.commit` or completion-handler contract.
- **Metal RT evidence:** under Metal API Validation, a fixed-noon `150`
  default run completed 96 frames without autopilot, drained 169 resident and
  traced chunks, and reported 169 submitted/169 completed/zero failed/zero
  stale CPU jobs. It built 169 BLAS objects and 22 TLAS versions, submitted 96
  RT dispatches and 353,894,400 rays, and observed 2,404,265 primary hits,
  862,626 direct-lit and 1,541,639 shadowed pixels, 2,403,729 indirect-lit and
  2,404,265 reconstructed-lit pixels, 632,564 reflection-covered and lit
  pixels, 298,276 reconstructed penumbra pixels, zero invalid pixels, and all
  native/visibility/PTGI/reflection markers true. Background CPU mesh time
  totaled 411.750 ms; synchronous upload and TLAS time totaled 179.797 ms and
  18.437 ms. Frame p50/p95/max were 19.919/23.364/401.845 ms, with the maximum
  including strict final readback.
- **Metal raster evidence:** the matching fixed-noon default run completed 96
  frames with 169 resident chunks, 81 visible and 88 culled, zero pending
  work, 104 draws, 180,132 vertices, 270,198 indices, and 14,111,376 uploaded
  bytes.
- **Evidence boundary:** these observations came from the current development
  snapshot and are not clean exact-release-commit evidence. The corresponding
  physical Vulkan default run at 169 resident/traced chunks remains pending;
  forced Vulkan compilation does not satisfy it.

### Post-Period 56 - Three-Bounce Experimental Voxel PTGI

- **Goal and provenance:** supersede the recorded one-bounce indirect shader
  with a bounded clean-room experiment while retaining its resource graph,
  temporal reconstruction, presentation, and public vkmtl surface. This is not
  a claim that default SEUS PTGI E12 uses three bounces; E12 remains only a
  visual-strategy reference under the earlier provenance limits.
- **Path estimator:** every covered opaque pixel launches one path per frame
  with at most three sequential cosine-weighted diffuse segments. Each hit
  performs an independent sun/moon next-event sample, material albedo
  propagates throughput, and terminal residual environment contributes at most
  once. The visible water surface keeps its independent one-segment specular
  reflection path.
- **Execution boundary:** ray generation issues each trace sequentially and
  the native pipeline keeps `max_recursion_depth=1`; no shader recursion,
  public API, command behavior, or native-semantic row changed. The established
  temporal and a-trous passes reconstruct the resulting radiance exactly as
  before. Frame data carries nonzero x/z chunk bounds only when the published
  TLAS contains the complete contiguous square for the active profile. Sparse
  initial or moving subsets publish zero extent, so their diffuse misses cannot
  sample environment. Once complete, residual environment and the older outer-
  edge blend are both admitted only when the path is confirmed to cross
  terrain top before a horizontal side. Side misses contribute nothing and
  cannot leak sky light into second or third bounces.
- **Diagnostics:** logs and the final pressure marker now report
  `ptgi_bounces=3`. The legacy `primary_rays` name counts dispatch threads only
  and does not include later diffuse or next-event segments.
- **Metal default evidence:** under Metal API Validation, fixed-noon default
  completed 96 frames with 169 resident chunks, zero pending work,
  169 submitted/169 completed/zero failed/zero stale jobs, 22 TLAS builds, 96
  dispatches, and `ptgi_bounces=3`. It reported 353,894,400 dispatch threads,
  `rt_ms_per_frame=16.327`, 2,404,265 primary hits, 863,410 direct-lit and
  1,540,855 shadowed pixels, 1,932,365 indirect-lit and 626,079 low-indirect
  pixels, 2,404,258 reconstructed-lit pixels, 632,564 reflection-covered and
  lit pixels, 297,535 reconstructed penumbra pixels, zero invalid pixels, and
  every native/visibility/PTGI/reflection marker true. Frame p50/p95/max were
  24.081/28.004/442.164 ms.
- **Metal smoke evidence:** final-boundary fixed-noon smoke completed 24 frames
  with nine resident chunks, zero pending work, `ptgi_bounces=3`,
  `rt_ms_per_frame=10.767`, 1,017,402 primary hits, 431,231 direct-lit,
  586,171 shadowed, 303,369 indirect-lit, 744,071 low-indirect, 1,017,398
  reconstructed-lit, 438,485 reflection-covered/lit, 45,238 penumbra, zero
  invalid pixels, and all markers true.
  Fixed-midnight smoke retained the same resident/pending and hit counts with
  `rt_ms_per_frame=11.248`, 431,228 direct-lit, 586,174 shadowed, 279,887
  indirect-lit, 839,646 low-indirect, 960,442 reconstructed-lit, 438,485
  reflection-covered, 429,973 reflection-lit, 53,592 penumbra, zero invalid
  pixels, and all markers true.
- **Performance and evidence boundary:** on the same fixed-noon default96
  command, host, and final boundary logic, a temporary A/B with only the bounce
  count set to one reported `rt_ms_per_frame=12.870`, p50/p95 20.960/23.583
  ms, 2,137,634
  indirect-lit, 507,522 low-indirect, and 2,404,265 reconstructed-lit pixels,
  with all validation markers true. Three bounces reported 16.327 RT ms and
  p50/p95 24.081/28.004 ms, about 26.9% more RT cost. The radiance-count
  difference is not an unbiased energy comparison because terminal residual is
  deferred until the final configured hit and side exits are conservative.
  Frame maximum and load transients are not performance gates. The corrected
  finite runs are dirty-source development observations, not clean release
  candidate evidence. Physical Vulkan execution of this exact three-bounce
  workload remains pending.

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
