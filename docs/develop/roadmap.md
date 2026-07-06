# Roadmap

This document is the route map for vkmtl. It describes the order and intent of
major work. Detailed phase notes live under `docs/develop/period*/`.

Use these companion documents for the other views:

- `docs/develop/checklist.md` tracks checkable work and phase gates.
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
- Phase 4: Slang runtime shader compile
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

Status: planned.

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

Status: planned.

Goal: lower the Period 10 bindless binding API to Vulkan descriptor indexing
and Metal argument buffers.

- Phase 1: advanced binding layout lowering contract
- Phase 2: Vulkan descriptor indexing lowering
- Phase 3: Metal argument buffer lowering
- Phase 4: Slang reflection bindless mapping
- Phase 5: bindless texture example
- Phase 6: bindless validation coverage

See `docs/develop/period12/`.

## Period 13: Multi-Surface / Presentation Backend

Status: planned.

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

Status: planned.

Goal: support explicit interop with platform APIs, engines, UI frameworks, and
media pipelines without leaking native handles into the portable path.

- Phase 1: native handle view stabilization
- Phase 2: Vulkan external memory / image / semaphore interop
- Phase 3: Metal texture / buffer / event interop
- Phase 4: external texture creation path
- Phase 5: native command insertion hooks
- Phase 6: external texture example

See `docs/develop/period14/`.

## Period 15: Sparse / Tiled Resources Backend

Status: planned.

Goal: lower sparse and tiled resource descriptors to backend-native residency
and page-commit mechanisms for large or streaming resources.

- Phase 1: sparse buffer backend
- Phase 2: sparse texture / tiled texture backend
- Phase 3: residency map and page commit API
- Phase 4: mip tail and alignment handling
- Phase 5: streaming texture example
- Phase 6: sparse validation coverage

See `docs/develop/period15/`.

## Period 16: Advanced Geometry Pipeline

Status: planned.

Goal: lower tessellation and mesh/task shader descriptors to real backend
pipelines where supported.

- Phase 1: Vulkan tessellation lowering
- Phase 2: Metal tessellation lowering
- Phase 3: Vulkan mesh/task shader lowering
- Phase 4: Metal object/mesh function path
- Phase 5: Slang entry/reflection alignment
- Phase 6: tessellation and mesh examples

See `docs/develop/period16/`.

## Period 17: Ray Tracing Backend

Status: planned.

Goal: lower acceleration structures, ray tracing pipelines, and shader binding
table descriptors to Vulkan and Metal ray tracing capabilities.

- Phase 1: acceleration structure backend API
- Phase 2: Vulkan ray tracing pipeline lowering
- Phase 3: Metal acceleration structure and intersection lowering
- Phase 4: shader binding table mapping
- Phase 5: basic ray traced triangle example
- Phase 6: ray tracing validation and matrix

See `docs/develop/period17/`.

## Period 18: Performance / Production Hardening

Status: planned.

Goal: turn the advanced backend slices from functional prototypes into
production-ready paths with cache persistence, diagnostics, and long-run
stability checks.

- Phase 1: driver pipeline cache persistence
- Phase 2: resource aliasing / transient allocator
- Phase 3: upload and readback queue optimization
- Phase 4: GPU timestamps and profiler markers
- Phase 5: debug labels and capture-friendly naming
- Phase 6: long-run stability tests

See `docs/develop/period18/`.

## Period 19: Voxel World Pressure Test

Status: planned.

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

## Priority Notes

- Period 11 is the next priority after the Period 10 API expansion.
- Feature gates must be truthful before advanced backend lowering begins.
- Periods 12 through 18 should prioritize backend implementation over new API
  surface unless a missing descriptor blocks lowering.
- Period 19 intentionally comes after production hardening. The voxel example is
  a pressure test, not the place to invent missing backend fundamentals.
- Each period should include tests or examples that prove the new capability.
