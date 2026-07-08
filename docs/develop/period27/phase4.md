# Phase 4: Tessellation Backend

Phase 4 lowers tessellation pipeline descriptors.

## Scope

- Lower Vulkan tessellation control/evaluation stages.
- Define Metal tessellation mapping or typed unsupported behavior.
- Validate patch size and control point limits.

## Validation

- Add pipeline validation tests.
- Add a simple tessellation example where supported.

## Result

- Added the backend-tagged `TessellationLowering` plan type.
- Added `Device.planTessellationLowering(...)`, which uses native feature
  reports while keeping ordinary public validation capability-gated.
- Preserved the existing Vulkan and Metal lowering metadata behind the unified
  plan.
- Added runtime tests that prove native tessellation planning can be inspected
  before the public feature is marked usable.

## Deferred

- Native tessellation pipeline creation, Slang tessellation stage attachment,
  and executable tessellation draw commands remain deferred to Period 28 Phase
  5.
