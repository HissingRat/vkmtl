# Phase 3: Shader Binding Tables And Dispatch

Phase 3 makes ray dispatch executable.

## Scope

- Lower shader binding table descriptors.
- Add ray dispatch command encoding.
- Validate SBT alignment and record ranges.

## Validation

- Add SBT layout tests.
- Add a minimal ray-dispatch smoke example where supported.

## Result

- Added `RayDispatchDescriptor` and `RayDispatchPlan`.
- `RayDispatchPlan` combines SBT layout, dispatch dimensions, total ray count,
  and total SBT size.
- Added `Device.planRayDispatch(...)`, which uses native feature reports while
  keeping ordinary public SBT validation capability-gated.
- Added focused tests for SBT offsets, dispatch dimension validation, and
  runtime native-feature planning.

## Deferred

- Native ray dispatch command encoding and executable ray-dispatch examples are
  deferred to Period 29 Phase 3.
