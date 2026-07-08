# Period 29: Native Ray Tracing And Advanced Backend Execution

Status: planned after Period 28.

Goal: turn the Period 28 planning APIs into executable Vulkan and Metal backend
paths without weakening the portable core.

Expected result: ray tracing, native advanced escape hatches, and parity
semantics move from inspectable plans to backend-owned execution paths where the
selected adapter exposes the required native capabilities.

## Phase 1: Native Acceleration Structure Builds

- Allocate backend acceleration-structure resources.
- Encode build and update commands.
- Validate scratch/result resource usage and alignment.

See `phase1.md`.

## Phase 2: Native Ray Tracing Pipelines

- Create executable Vulkan ray tracing pipelines.
- Create executable Metal-compatible ray tracing pipeline state where
  available.
- Keep unsupported adapters typed and capability-gated.

See `phase2.md`.

## Phase 3: Native SBT And Ray Dispatch Commands

- Materialize shader binding table records.
- Add ray dispatch command encoding.
- Validate SBT ranges against dispatch plans.

See `phase3.md`.

## Phase 4: Native Metal Ray Tracing Execution Mapping

- Connect Metal acceleration-structure resources, intersection functions, and
  function tables.
- Keep Metal-specific semantics explicit.

See `phase4.md`.

## Phase 5: Native Advanced Escape Hatch Execution

- Complete native object pools, cache I/O, imports, synchronization, heaps,
  sparse binding, and advanced geometry execution.

See `phase5.md`.

## Phase 6: Parity Semantics And Stress Validation

- Decide remaining parity semantics for partial mipmaps, depth/stencil/MSAA
  copies, custom border colors, and GPU soak loops.

See `phase6.md`.

## Phase 7: Native Advanced Examples

- Add executable ray tracing and native advanced examples for supported
  adapters.

See `phase7.md`.
