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

Status: planned optional modules.

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

## Priority Notes

- Period 2 is the next priority.
- Period 2 must settle owner, lifetime, binding, sync, and capability-gate
  rules before broad resource or pipeline expansion.
- `features`, `limits`, and format capabilities should arrive early.
- Binding and sync are the largest long-term risks; define specs before
  expanding their implementations.
- Advanced features should stay in optional, capability-gated modules.
- Each period should include tests or examples that prove the new capability.
  Period 9 organizes the matrix; it should not be the first proof that a
  feature exists.
