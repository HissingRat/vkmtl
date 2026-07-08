# Period 29: Native Ray Tracing And Advanced Backend Execution

Status: completed for public runtime contracts.

Goal: turn the Period 28 planning APIs into public runtime contracts without
weakening the portable core.

Expected result: ray tracing, native advanced escape hatches, and parity
semantics move from inspectable plans to runtime-owned objects, resource
validation, command intent, examples, and capability-gated metadata. Backend
private native handles and pixel-producing execution continue in Period 30.

## Phase 1: Native Acceleration Structure Builds

- Create runtime acceleration-structure objects.
- Encode build/update command intent.
- Validate scratch/result resource usage and alignment.

See `phase1.md`.

## Phase 2: Native Ray Tracing Pipelines

- Create runtime ray tracing pipeline state objects.
- Preserve Vulkan and Metal lowering metadata.
- Keep unsupported adapters typed and capability-gated.

See `phase2.md`.

## Phase 3: Native SBT And Ray Dispatch Commands

- Create runtime shader binding table objects.
- Add ray dispatch command intent.
- Validate SBT ranges against dispatch plans.

See `phase3.md`.

## Phase 4: Native Metal Ray Tracing Execution Mapping

- Preserve Metal acceleration-structure, intersection-function, and function
  table mapping metadata.
- Keep Metal-specific semantics explicit.

See `phase4.md`.

## Phase 5: Native Advanced Escape Hatch Execution

- Distinguish public runtime contracts from backend-private native lowering and
  retarget remaining native escape-hatch work to Period 30.

See `phase5.md`.

## Phase 6: Parity Semantics And Stress Validation

- Decide remaining parity semantics for partial mipmaps, depth/stencil/MSAA
  copies, custom border colors, and GPU soak loops.

See `phase6.md`.

## Phase 7: Native Advanced Examples

- Upgrade ray tracing examples from planning-only to public runtime-contract
  APIs while keeping unsupported adapters capability-gated.

See `phase7.md`.
