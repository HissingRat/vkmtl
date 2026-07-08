# Phase 2: Native Ray Tracing Pipeline Handles

Phase 2 attaches `RayTracingPipelineState` to backend-private executable ray
tracing pipeline handles.

## Scope

- Create Vulkan ray tracing pipelines and shader groups.
- Create Metal executable pipeline/function-table backing objects.
- Validate recursion depth, payload limits, and callable/hit group layout.

## Validation

- Add backend pipeline creation smoke tests where native support exists.
- Preserve typed unsupported behavior elsewhere.
