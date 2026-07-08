# Period 28: Ray Tracing And Native Advanced Parity

Status: completed as a planning, validation, and parity-routing slice. Native
execution is deferred to Period 29.

Goal: cover the highest-end Vulkan and Metal capabilities through explicit,
capability-gated APIs and a maintained parity matrix.

Expected result: vkmtl can describe, validate, and plan ray tracing, native
advanced pipeline paths, external/native escape hatches, and backend-specific
features without weakening the portable core. Period 29 owns executable native
backend work.

## Phase 1: Acceleration Structures

- Add acceleration-structure build descriptors and planning.

See `phase1.md`.

## Phase 2: Ray Tracing Pipelines

- Add ray tracing pipeline lowering plans.

See `phase2.md`.

## Phase 3: Shader Binding Tables And Dispatch

- Add SBT layout and ray dispatch planning.

See `phase3.md`.

## Phase 4: Metal Ray Tracing Mapping

- Add explicit Metal ray tracing mapping plans.

See `phase4.md`.

## Phase 5: Native Advanced Escape Hatches

- Add a native advanced closure inventory for escape hatches that cannot be made
  portable.

See `phase5.md`.

## Phase 6: Parity Matrix Closure

- Maintain the parity matrix and route executable native work to Period 29.

See `phase6.md`.

## Phase 7: Advanced Examples

- Keep advanced examples capability-gated and document native examples for
  Period 29.

See `phase7.md`.
