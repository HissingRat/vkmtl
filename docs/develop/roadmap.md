# Roadmap

This document is the route map for vkmtl. It describes the order and intent of
major work. Detailed phase notes live under `docs/develop/period*/`.

Use these companion documents for the other views:

- `docs/develop/checklist.md` tracks checkable work and phase gates.
- `docs/develop/backend-completion-roadmap.md` tracks native Vulkan / Metal
  backend catch-up work after API shapes exist.
- `docs/api/zh_cn/core.md` and `docs/api/en_us/core.md` describe the public API.
- `docs/usage/zh_cn/quick-start.md` and `docs/usage/en_us/quick-start.md` show
  how to use the current API.
- `docs/develop/period1/` preserves the first core slice.
- `docs/develop/period2/` and later directories track long-term coverage.

## Direction

vkmtl is a Vulkan + Metal graphics abstraction library. The long-term goal is
practical parity: if Metal and Vulkan can support a graphics or compute
workload, vkmtl should either expose a backend-neutral path for it or clearly
document why that feature is backend-specific.

The API should describe graphics work in backend-neutral terms:

- choose adapters, devices, queues, and features
- describe presentation surfaces and drawables
- create buffers, textures, views, samplers, shaders, pipelines, and bind groups
- encode render, transfer, and compute commands
- synchronize GPU work and present frames

Backend details stay behind `src/backend/vulkan` and `src/backend/metal`.
Windowing stays outside vkmtl core and enters through public surface descriptors
and provider callbacks.

## Capability Strategy

vkmtl should not become a lowest-common-denominator wrapper. The API grows in
three layers:

- Portable core: default APIs that map cleanly to both Vulkan and Metal.
- Capability-gated APIs: optional features guarded by `features`, `limits`, and
  format capability queries.
- Backend-specific escape hatches: explicit advanced APIs for native handles,
  manual barriers, and features that cannot be made portable.

Advanced or backend-specific features must not pollute the default portable API.

## Checklist Discipline

Before starting any phase, update `docs/develop/checklist.md` or the relevant
period notes with the phase checklist. Each phase should identify:

- design decisions that must be settled first
- public API surface being added or changed
- Vulkan and Metal backend mapping
- validation, tests, or examples that prove the slice works
- documentation that must change with the implementation

## Period 1: Core Library Slice

Status: current core slice, with remaining polish tracked in the checklist.

Goal: preserve the historical minimum vertical slice that proved vkmtl can route
the same public examples through Vulkan and Metal.

- Phase 0: Vulkan / Metal binding
- Phase 1: public API shape / backend selection
- Phase 2: surface / presentation
- Phase 3: buffer / texture / sampler
- Phase 4: Slang shader declaration and precompiled artifact cache
- Phase 5: command buffer / render encoder
- Phase 6: bind group / reflection
- Phase 7: depth / offscreen / MSAA / cube
- Phase 8: transfer / compute / readback
- Phase 9: docs / polish / distribution cleanup

See `docs/develop/period1/`.

## Period 2: Runtime Architecture And Specs

Status: planned next major period.

Goal: turn the working vertical slice into the long-term API foundation before
expanding broad resource and pipeline coverage.

- Phase 0: core architecture specs
- Phase 1: `Device` / `Queue` / `Surface` split
- Phase 2: adapter selection and capabilities
- Phase 3: resource lifetime and deferred destruction
- Phase 4: basic usage tracking and sync baseline
- Phase 5: error model and validation layer
- Phase 6: multi-surface / multi-window
- Phase 7: native handle escape hatch
- Phase 8: debug labels / markers / diagnostics

See `docs/develop/period2/`.

## Period 3: Resource Coverage

Status: completed validation/API expansion, with advanced backend lowering
gated behind typed unsupported errors.

Goal: cover Metal and Vulkan buffer, texture, sampler, and memory fundamentals.

- Phase 1: buffer completeness
- Phase 2: texture shapes
- Phase 3: format system
- Phase 4: mipmap support
- Phase 5: texture view completeness
- Phase 6: sampler completeness
- Phase 7: heaps / memory advanced

See `docs/develop/period3/`.

## Period 4: Shader And Binding

Status: completed validation/API expansion, with advanced shader and binding
features gated behind typed unsupported errors until lowering lands.

Goal: make Slang, reflection, and the binding model strong enough for real
projects.

- Phase 1: binding model implementation
- Phase 2: shader library / module manager
- Phase 3: reflection schema stabilization
- Phase 4: bind group layout completeness
- Phase 5: dynamic offsets / small constants
- Phase 6: push constants / root constants equivalent
- Phase 7: shader specialization

See `docs/develop/period4/`.

## Period 5: Render Pipeline

Status: completed validation/API expansion, with advanced render pipeline
features gated behind typed unsupported errors until lowering lands.

Goal: cover common graphics rendering features without baking backend-specific
state into user code.

- Phase 1: render pass / attachment model
- Phase 2: raster state
- Phase 3: dynamic render state
- Phase 4: blend state
- Phase 5: depth / stencil state
- Phase 6: vertex layout completeness
- Phase 7: draw commands
- Phase 8: query support

See `docs/develop/period5/`.

## Period 6: Command, Sync, Transfer

Status: completed validation/API expansion, with advanced synchronization and
multi-queue features gated until native lowering lands.

Goal: unify Vulkan's explicit synchronization needs with Metal's encoder model
through portable defaults and explicit advanced escape hatches.

- Phase 1: command lifecycle
- Phase 2: blit encoder completeness
- Phase 3: resource barrier model
- Phase 4: fences / events
- Phase 5: multi-queue
- Phase 6: debug markers integration

See `docs/develop/period6/`.

## Period 7: Compute

Status: completed validation/API expansion, with advanced compute features and
example gallery growth gated for later backend/example work.

Goal: make compute capable of supporting real workflows independently of render
examples.

- Phase 1: compute dispatch completeness
- Phase 2: dispatch indirect
- Phase 3: storage resource rules
- Phase 4: atomics / threadgroup memory
- Phase 5: compute pipeline cache requirements
- Phase 6: compute examples

See `docs/develop/period7/`.

## Period 8: Pipeline / Object Cache

Status: completed validation/API expansion, with native object reuse still
planned as backend work.

Goal: manage expensive native objects so real applications do not repeatedly
create equivalent shader modules, layouts, pipelines, and samplers.

- Phase 1: shader module cache
- Phase 2: bind group layout cache
- Phase 3: pipeline layout cache
- Phase 4: render pipeline cache
- Phase 5: compute pipeline cache
- Phase 6: sampler cache
- Phase 7: cache diagnostics

See `docs/develop/period8/`.

## Period 9: Examples / Test Matrix / Documentation

Status: completed.

Goal: make the library maintainable and verifiable across examples, backends,
validation tests, and documentation.

- Phase 1: example gallery cleanup
- Phase 2: compute example gallery
- Phase 3: multi-window examples
- Phase 4: native interop examples
- Phase 5: backend test matrix
- Phase 6: validation tests
- Phase 7: documentation completeness

See `docs/develop/period9/`.

## Period 10: Advanced / Backend-Gated

Status: completed validation/API expansion for optional modules.

Goal: expose advanced Vulkan and Metal features without forcing them into the
portable core. Every phase here is optional, capability-gated, and has no
default portable fallback unless explicitly designed.

- Phase 1: descriptor indexing / argument buffer
- Phase 2: sparse / tiled resources
- Phase 3: external texture / platform interop
- Phase 4: tessellation gated
- Phase 5: mesh shader gated
- Phase 6: ray tracing gated module
- Phase 7: driver-level pipeline cache / binary archive

See `docs/develop/period10/`.

## Period 11: Backend Capability Reality

Status: completed backend capability baseline.

Goal: make feature and limit reports come from real Vulkan and Metal backend
queries, then route unsupported advanced APIs through precise typed errors.

- Phase 1: Vulkan capability query
- Phase 2: Metal capability query
- Phase 3: unified feature / limit fill path
- Phase 4: unsupported feature validation
- Phase 5: capability dump example
- Phase 6: backend capability tests

See `docs/develop/period11/`.

## Period 12: Bindless / Argument Buffer Backend

Status: completed API, validation, reflection, and layout-metadata scaffold.

Goal: define the Period 10 bindless binding API, validate it, derive it from
Slang reflection, and record backend-aware descriptor-indexing / argument-buffer
metadata. Executable resource tables are tracked in Period 22.

- Phase 1: advanced binding layout lowering contract
- Phase 2: Vulkan descriptor indexing lowering
- Phase 3: Metal argument buffer lowering
- Phase 4: Slang reflection bindless mapping
- Phase 5: bindless texture example
- Phase 6: bindless validation coverage

See `docs/develop/period12/`.

## Period 13: Multi-Surface / Presentation Backend

Status: completed presentation architecture baseline.

Goal: make one device manage multiple presentation surfaces reliably across
Vulkan swapchains and Metal drawable layers.

- Phase 1: device-owned surface registry
- Phase 2: multiple swapchain / drawable state
- Phase 3: resize, minimize, and surface-lost handling
- Phase 4: present mode and vsync configuration
- Phase 5: frame pacing baseline
- Phase 6: multi-window example

See `docs/develop/period13/`.

## Period 14: Native Interop / External Resources

Status: completed native-handle, descriptor, validation, and feature-gate
scaffold.

Goal: define explicit interop shapes for platform APIs, engines, UI frameworks,
and media pipelines without leaking native handles into the portable path.
Executable external interop is tracked in Period 25.

- Phase 1: native handle view stabilization
- Phase 2: Vulkan external memory / image / semaphore interop
- Phase 3: Metal texture / buffer / event interop
- Phase 4: external texture creation path
- Phase 5: native command insertion hooks
- Phase 6: external texture example

See `docs/develop/period14/`.

## Period 15: Sparse / Tiled Resources Backend

Status: completed sparse/tiled descriptor and residency-validation scaffold.

Goal: define sparse and tiled resource descriptors, residency maps, and
page-commit validation for large or streaming resources. Native sparse/tiled
backend closure is tracked in Period 27.

- Phase 1: sparse buffer backend
- Phase 2: sparse texture / tiled texture backend
- Phase 3: residency map and page commit API
- Phase 4: mip tail and alignment handling
- Phase 5: streaming texture example
- Phase 6: sparse validation coverage

See `docs/develop/period15/`.

## Period 16: Advanced Geometry Pipeline

Status: completed descriptor and lowering-metadata scaffold.

Goal: define tessellation and mesh/task shader descriptors, feature gates, and
backend lowering metadata where supported. Executable pipelines are tracked in
Period 27.

- Phase 1: Vulkan tessellation lowering
- Phase 2: Metal tessellation lowering
- Phase 3: Vulkan mesh/task shader lowering
- Phase 4: Metal object/mesh function path
- Phase 5: Slang entry/reflection alignment
- Phase 6: tessellation and mesh examples

See `docs/develop/period16/`.

## Period 17: Ray Tracing Backend

Status: completed ray-tracing descriptor and lowering-metadata scaffold.

Goal: define acceleration structure, ray tracing pipeline, and shader binding
table descriptors with backend-aware validation metadata. Executable ray
tracing is tracked in Period 29 after Period 28 planning.

- Phase 1: acceleration structure backend API
- Phase 2: Vulkan ray tracing pipeline lowering
- Phase 3: Metal acceleration structure and intersection lowering
- Phase 4: shader binding table mapping
- Phase 5: basic ray traced scene example
- Phase 6: ray tracing validation and matrix

See `docs/develop/period17/`.

## Period 18: Performance / Production Hardening

Status: completed production-hardening descriptor, diagnostic, and planning
scaffold.

Goal: define production-hardening shapes for cache persistence, diagnostics,
profiling, and long-run stability checks. Executable hardening work is tracked
in Period 26.

- Phase 1: driver pipeline cache persistence
- Phase 2: resource aliasing / transient allocator
- Phase 3: upload and readback queue optimization
- Phase 4: GPU timestamps and profiler markers
- Phase 5: debug labels and capture-friendly naming
- Phase 6: long-run stability tests

See `docs/develop/period18/`.

## Period 19: Voxel World Pressure Test

Status: deferred until the backend completion periods make the render and
binding stack less experimental.

Goal: build a Minecraft-like block world prototype under `examples/` as the
final pressure test for the core render, resource, shader, binding, transfer,
and presentation stack.

- Phase 1: voxel example contract
- Phase 2: chunk mesh data and CPU meshing
- Phase 3: texture atlas and material binding
- Phase 4: camera, input, and culling
- Phase 5: chunk streaming and mesh rebuild loop
- Phase 6: lighting and visibility polish
- Phase 7: pressure-test report

See `docs/develop/period19/`.

## Period 20: Common Render Backend Completion

Status: completed.

Goal: finish native Vulkan / Metal lowering for common render pass and render
pipeline features that already have public API shapes.

- Phase 1: blend state lowering
- Phase 2: raster and depth-bias backend state
- Phase 3: vertex instance step rate
- Phase 4: stencil backend state
- Phase 5: multiple render targets
- Phase 6: render backend validation

See `docs/develop/period20/`.

## Period 21: Binding And Shader Backend Completion

Status: completed as a binding backend validation slice.

Goal: finish backend lowering for dynamic offsets, resource arrays, advanced
binding models, constants, and shader specialization.

- Phase 1: dynamic buffer offsets
- Phase 2: resource arrays
- Phase 3: descriptor indexing and argument buffers
- Phase 4: small constants and root constants
- Phase 5: shader specialization
- Phase 6: binding backend validation

See `docs/develop/period21/`.

## Period 22: Binding ABI And Shader Variant Closure

Status: planned after Period 21.

Goal: close the binding and shader backend items that Period 21 intentionally
left as explicit follow-up work.

- Phase 1: binding ABI cleanup
- Phase 2: bindless resource table objects
- Phase 3: descriptor table command binding
- Phase 4: root constants command writes
- Phase 5: shader specialization variants
- Phase 6: binding and variant validation

See `docs/develop/period22/`.

## Period 23: Command, Sync, And Query Backend Completion

Status: completed portable sync/query validation slice.

Goal: lower explicit barriers, synchronization objects, dedicated queues, queue
ownership transfers, and query commands.

- Phase 1: explicit resource barriers
- Phase 2: fences and events
- Phase 3: dedicated queues
- Phase 4: queue ownership and hazards
- Phase 5: query pools and encoder commands
- Phase 6: sync and query validation

See `docs/develop/period23/`.

## Period 24: Resource And Transfer Utility Completion

Status: completed resource utility validation slice.

Goal: complete practical texture, buffer, mipmap, sampler, heap, and transient
allocation utilities.

- Phase 1: automatic mipmap generation
- Phase 2: fill buffer fallbacks
- Phase 3: broader texture copy coverage
- Phase 4: sampler border color
- Phase 5: heaps and transient allocation
- Phase 6: resource utility validation

See `docs/develop/period24/`.

## Period 25: Platform, Surface, And Interop Completion

Status: completed platform/interop validation slice.

Goal: support multi-surface applications and explicit native interop with
external resources and synchronization primitives.

- Phase 1: multi-surface runtime
- Phase 2: present modes and frame pacing
- Phase 3: external memory and textures
- Phase 4: external semaphores and shared events
- Phase 5: native command insertion
- Phase 6: interop examples and matrix

See `docs/develop/period25/`.

## Period 26: Object Cache And Production Backend Hardening

Status: completed production-hardening planning and diagnostics slice, with
native cache/object reuse and GPU soak execution deferred to Period 30.

Goal: make native backend paths cacheable, diagnosable, persistent where useful,
and stable under long-running workloads. Period 26 closed the portable planning,
diagnostics, and regression-command layer; native cache consumption and
long-running GPU execution are tracked in Period 28.

- Phase 1: native object reuse
- Phase 2: driver pipeline cache and binary archive
- Phase 3: persistent runtime cache
- Phase 4: diagnostics and capture names
- Phase 5: long-run stability
- Phase 6: production readiness matrix

See `docs/develop/period26/`.

## Period 27: Advanced Resource And Geometry Backend Completion

Status: completed as a planning and validation slice. Native executable backend
closure is deferred to Period 32+ driver parity plan.

Goal: lower sparse/tiled resources, residency updates, tessellation, and
mesh/task shader paths where the backend supports them.

- Phase 1: sparse and tiled buffers
- Phase 2: sparse and tiled textures
- Phase 3: residency and page commit API
- Phase 4: tessellation backend
- Phase 5: mesh and task shader backend
- Phase 6: advanced geometry examples

See `docs/develop/period27/`.

## Period 28: Ray Tracing And Native Advanced Parity

Status: completed as a planning, validation, and parity-routing slice. Native
execution is deferred to Period 30.

Goal: expose ray tracing and other high-end backend-specific capabilities
through explicit capability-gated APIs and a maintained parity matrix.

- Phase 1: acceleration structures
- Phase 2: ray tracing pipelines
- Phase 3: shader binding tables and dispatch
- Phase 4: Metal ray tracing mapping
- Phase 5: native advanced escape hatches
- Phase 6: parity matrix closure
- Phase 7: advanced examples

See `docs/develop/period28/`.

## Period 29: Native Ray Tracing And Advanced Backend Execution

Status: completed for public runtime contracts.

Goal: turn Period 28 planning APIs into public runtime contracts that can own
objects, validate resources, record command intent, and preserve backend
metadata without exposing Vulkan or Metal private handles.

- Phase 1: native acceleration structure builds
- Phase 2: native ray tracing pipelines
- Phase 3: native SBT and ray dispatch commands
- Phase 4: native Metal ray tracing execution mapping
- Phase 5: native advanced escape hatch execution
- Phase 6: parity semantics and stress validation
- Phase 7: native advanced examples

See `docs/develop/period29/`.

## Period 30: Backend-Private Runtime Records

Status: completed.

Goal: attach the Period 29 runtime contracts to vkmtl-owned backend-private
record state while preserving public/backend boundaries.

- Phase 1: backend-private acceleration structure handle/build records
- Phase 2: backend-private ray tracing pipeline metadata
- Phase 3: backend-private SBT records and ray dispatch records
- Phase 4: backend-private Metal ray tracing table metadata
- Phase 5: advanced native inventory and Period31/32/32+ driver routing
- Phase 6: parity validation diagnostics and Period32+ soak routing
- Phase 7: backend-private advanced example record checks

See `docs/develop/period30/`.

## Period 31: Metal Ray Traced Triangle Driver Path

Status: completed for the first native Metal RT visible slice.

Goal: make `zig build run-ray-traced-scene` produce visible native Metal
ray-traced pixels in a window on supported macOS Metal devices.

- Phase 1: example contract and capability gate
- Phase 2: Metal acceleration structure driver bridge
- Phase 3: Metal ray tracing shader path
- Phase 4: ray dispatch to output texture
- Phase 5: present ray tracing output
- Phase 6: validation and screenshot gate
- Phase 7: documentation and follow-up routing

See `docs/develop/period31/`.

## Period 32: Vulkan Ray Traced Scene Driver Path

Status: in progress; Phases 1-5 implement the first direct Vulkan ray tracing
output path. Phases 6-7 own supported-hardware validation and docs closure.

Goal: make `zig build run-ray-traced-scene -Dvulkan` pass Vulkan capability
gates, create real Vulkan AS/pipeline/SBT objects, submit `vkCmdTraceRaysKHR`,
and present ray-traced pixels in the window on supported Vulkan ray tracing
devices.

- Phase 1: Vulkan capability gate and loader contract
- Phase 2: Vulkan acceleration structure build
- Phase 3: Vulkan ray tracing shader path
- Phase 4: Vulkan ray tracing pipeline and SBT
- Phase 5: Vulkan trace rays and direct output presentation
- Phase 6: validation on supported Vulkan hardware
- Phase 7: documentation and follow-up routing

See `docs/develop/period32/`.

## Period 33: Native RT Mesh Scene

Status: planned after Period 32 validation/docs closure.

Goal: expand the first native Metal and Vulkan RT smoke paths into a full
native RT mesh scene. The reference `examples/ray_traced_scene` visual target
should be rendered through native acceleration structures, native RT pipelines,
native dispatch, and native presentation on supported backends.

This period keeps spheres as triangle meshes. Procedural spheres and custom
intersection are explicitly Period 34.

- Phase 1: scene contract and reference target
- Phase 2: public RT mesh geometry API
- Phase 3: Vulkan mesh BLAS and TLAS
- Phase 4: Metal mesh BLAS and TLAS
- Phase 5: scene buffers and binding
- Phase 6: full mesh ray traced scene example
- Phase 7: validation and documentation

See `docs/develop/period33/`.

## Period 34: Procedural RT Geometry And Custom Intersection

Status: Vulkan procedural path implemented; supported-hardware validation
pending.

Goal: replace the Vulkan mesh-sphere approximation from Period 33 with native
procedural sphere/custom intersection support. The full `ray_traced_scene`
example remains the acceptance example, and successful Vulkan output must use
procedural/AABB/custom-intersection geometry for spheres rather than
tessellated sphere meshes. Metal procedural function-table parity is routed to
Period39.

- Phase 1: procedural geometry contract
- Phase 2: Vulkan AABB geometry and intersection shader
- Phase 3: Metal intersection function table path
- Phase 4: shared procedural scene data
- Phase 5: full procedural ray traced scene
- Phase 6: validation and backend matrix

See `docs/develop/period34/`.

## Period 35: RT Scene Data And Procedural Parity Boundary

Status: implemented as the shared scene-data slice after Period34.

Goal: replace example-local RT scene constants with shared scene data, keep
backend-specific procedural RT machinery behind vkmtl abstractions, and assign
the remaining driver-level mixed TLAS / Metal procedural-table work to the RT
completeness period.

- Phase 1: shared RT scene data layout
- Phase 2: mixed mesh and procedural scene assembly ownership
- Phase 3: Metal procedural function table ownership
- Phase 4: cross-backend scene binding
- Phase 5: visual parity and validation

See `docs/develop/period35/`.

## Period 36: Sync And Queue Semantics

Status: implemented portable sync/queue contract after Period35.

Goal: make synchronization and multi-queue behavior explicit enough for real
async compute, async transfer, and cross-queue presentation workloads.

- Phase 1: synchronization object contract
- Phase 2: timeline fence gates and typed fallback behavior
- Phase 3: shared-event gates and native-handle boundary
- Phase 4: queue families, queue roles, and queue planning
- Phase 5: queue ownership and hazard tracking
- Phase 6: deterministic sync/queue validation

See `docs/develop/period36/`.

## Period 37: Memory, Heaps, And Residency

Status: implemented portable memory/residency contract after Period36.

Goal: add production memory behavior at the public contract layer:
heap-reservation and aliasing plans, memory-budget reporting, pressure
diagnostics, and deterministic sparse/tiled residency churn planning.

- Phase 1: heap and allocator contract
- Phase 2: aliasing and transient resource validation
- Phase 3: memory budget and pressure reporting
- Phase 4: sparse/tiled residency churn planning
- Phase 5: deterministic residency and allocation churn validation

See `docs/develop/period37/`.

## Period 38: Resource Tables And Pipeline Persistence

Status: planned after Period37.

Goal: prove large resource tables and persistent pipeline caches under scale
instead of only descriptor-shape validation.

- Phase 1: descriptor indexing pressure tests
- Phase 2: Metal argument buffer pressure tests
- Phase 3: update-after-bind and dynamic binding semantics
- Phase 4: Vulkan pipeline cache/library persistence
- Phase 5: Metal binary archive persistence
- Phase 6: cache invalidation and artifact compatibility validation

See `docs/develop/period38/`.

## Period 39: Ray Tracing Completeness

Status: planned after Period38.

Goal: move ray tracing beyond the Period35 scene into the broader feature set:
ray query, acceleration-structure updates, compaction, many-instance TLAS, and
complex shader binding table layouts.

- Phase 1: AS update, refit, and compaction contract
- Phase 2: many-instance TLAS and instance metadata
- Phase 3: ray query where supported
- Phase 4: complex SBT layouts and callable shader records
- Phase 5: RT stress examples and multi-device validation

See `docs/develop/period39/`.

## Period 40: Advanced Geometry Draw Paths

Status: planned after Period39.

Goal: turn tessellation and mesh/task shader support from descriptor/lowering
probes into real draw paths with backend-native execution where supported.

- Phase 1: tessellation public pipeline contract
- Phase 2: Vulkan tessellation draw path
- Phase 3: Metal tessellation draw path or precise unsupported contract
- Phase 4: Vulkan mesh/task shader draw path
- Phase 5: Metal object/mesh equivalent path or precise unsupported contract
- Phase 6: advanced geometry examples and validation

See `docs/develop/period40/`.

## Period 41: External Interop Matrix

Status: planned after Period40.

Goal: make external memory, external textures, and external synchronization
usable through an explicit platform matrix instead of descriptor-only probes.

- Phase 1: interop capability matrix
- Phase 2: Vulkan external memory/image/semaphore import
- Phase 3: Metal shared texture/event import
- Phase 4: external texture presentation and sampling examples
- Phase 5: external synchronization validation
- Phase 6: safety, lifetime, and platform documentation

See `docs/develop/period41/`.

## Period 42: Format, Copy, Layout, And Attachment Edge Semantics

Status: planned after Period41.

Goal: close the edge cases that decide whether vkmtl behaves like a serious
graphics abstraction: format capabilities, layout/state transitions,
depth-stencil behavior, MSAA resolve/copy, mips, layers, and slices.

- Phase 1: format capability matrix
- Phase 2: copy and blit edge semantics
- Phase 3: resource state/layout transition validation
- Phase 4: depth-stencil copy, resolve, and readback semantics
- Phase 5: MSAA, mip, layer, and slice regression coverage

See `docs/develop/period42/`.

## Period 43: Profiling, Capture, And Debug Markers

Status: planned after Period42.

Goal: make vkmtl debuggable in native tools by providing stable labels,
markers, capture scopes, timestamps, and issue-report diagnostics.

- Phase 1: debug label and marker contract
- Phase 2: Vulkan debug utils integration
- Phase 3: Metal debug groups and capture integration
- Phase 4: timestamp/query/profiling support
- Phase 5: diagnostics output for issue reports

See `docs/develop/period43/`.

## Period 44: CI, Device Matrix, And Soak Validation

Status: planned after Period43.

Goal: turn the parity work into something trustworthy by validating examples,
feature gates, screenshots, readbacks, and long-running workloads across a
documented backend/device matrix.

- Phase 1: CI job matrix and feature reporting
- Phase 2: Metal and Vulkan smoke hosts
- Phase 3: screenshot/pixel regression harness
- Phase 4: GPU soak and resource churn tests
- Phase 5: release readiness and parity report

See `docs/develop/period44/`.

## Period 32+: Full Parity And Production Coverage

Status: long-tail target. Period 33 through Period 44 split the broad target
into concrete follow-up periods.

Goal: complete the long-tail parity, platform, diagnostics, validation,
interop, and pressure-test work required before vkmtl can reasonably claim broad
Vulkan / Metal workload coverage.

See `docs/develop/period32+/target.md`.

## Priority Notes

- Period 30 is complete as backend-private runtime record work. It does not
  claim driver-level ray tracing pixels or full native parity.
- Period 31 has made the Metal ray traced scene visibly render in the window
  through a first native Metal RT command path.
- Period 32 follows Period31 and must present pixels produced by the Vulkan ray
  tracing shader on supported Vulkan ray tracing devices.
- Period 33 turns the first Metal/Vulkan RT paths into a full native mesh RT
  scene.
- Period 34 adds Vulkan procedural sphere/custom intersection support and
  validates it through the full native `ray_traced_scene` example.
- Period 35 owns shared RT scene data and precise ownership for the remaining
  procedural parity work; Period39 owns driver-level mixed TLAS and Metal
  procedural/custom-intersection completion.
- Period 36 owns the portable synchronization and logical queue API contract.
  Driver-level Vulkan timeline submit, Metal shared-event submit, and physical
  multi-queue validation remain Period44 evidence requirements before broad
  parity claims.
- Period 37 owns the portable memory, heap aliasing, budget/pressure, and
  sparse residency churn contracts. Native heap-backed resources and native
  sparse/tiled page binding remain Period44 evidence requirements after backend
  lowering exists.
- Periods 36 through 44 own the remaining production parity buckets: sync,
  queues, memory, residency, resource-table scale, pipeline persistence, ray
  tracing completeness, advanced geometry, external interop, edge semantics,
  profiling, capture, debug markers, CI, and device-matrix validation.
- Period 19 remains the voxel pressure-test target, but it is deferred until the
  backend completion work removes the obvious render and binding blockers.
- Period 11 remains the long-term capability-query baseline for advanced
  backend work.
- Periods 20 through 30 are backend completion and parity periods, not a
  request to reshape already-completed historical API-shape periods.
- Periods 12 through 18 are historical API, validation, and capability-scaffold
  periods. When they describe advanced lowering, treat Period 20+ as the
  current source of truth for executable native backend closure.
- Feature gates must be truthful before advanced backend lowering begins.
- Period 19 intentionally comes after production hardening. The voxel example is
  a pressure test, not the place to invent missing backend fundamentals.
- Each period should include tests or examples that prove the new capability.
