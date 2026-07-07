# Period 27+: Ray Tracing And Native Advanced Parity

Status: long-term planned.

Goal: cover the highest-end Vulkan and Metal capabilities through explicit,
capability-gated APIs and a maintained parity matrix.

Expected result: vkmtl can expose ray tracing, native advanced pipeline paths,
external/native escape hatches, and backend-specific features without weakening
the portable core.

The `+` means this period may split into more periods as implementation details
become concrete.

## Phase 1: Acceleration Structures

- Lower acceleration structure descriptors.

See `phase1.md`.

## Phase 2: Ray Tracing Pipelines

- Lower ray tracing pipeline descriptors.

See `phase2.md`.

## Phase 3: Shader Binding Tables And Dispatch

- Lower SBT layout and ray dispatch commands.

See `phase3.md`.

## Phase 4: Metal Ray Tracing Mapping

- Map Metal acceleration and intersection function paths.

See `phase4.md`.

## Phase 5: Native Advanced Escape Hatches

- Complete explicit backend-specific escape hatches that cannot be made
  portable.

See `phase5.md`.

## Phase 6: Parity Matrix Closure

- Maintain final feature matrix and decide what becomes future periods.

See `phase6.md`.

## Phase 7: Advanced Examples

- Add ray tracing and native-advanced examples where supported.

See `phase7.md`.
