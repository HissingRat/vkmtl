# Phase 2: Ray Tracing Pipelines

Phase 2 lowers ray tracing pipeline descriptors.

## Scope

- Lower Vulkan ray tracing pipelines where available.
- Define Metal-compatible ray tracing pipeline mapping.
- Validate shader groups, recursion depth, and payload limits.

## Validation

- Add pipeline validation tests.
- Add capability matrix entries.

## Result

- Added backend-tagged `RayTracingPipelineLowering`.
- Preserved Vulkan ray-generation, miss, hit, and callable group counts.
- Extended Metal ray tracing lowering so it keeps shader-group counts alongside
  function-table and intersection-function metadata.
- Added `Device.planRayTracingPipelineLowering(...)`, which uses native feature
  reports while keeping ordinary public validation capability-gated.
- Added focused tests for native-feature planning and backend-tagged group
  counts.

## Deferred

- Executable Vulkan ray tracing pipeline creation and executable Metal ray
  tracing pipeline/function-table creation are deferred to Period 29 Phase 2.
