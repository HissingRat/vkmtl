# Phase 2: Native Ray Tracing Pipeline Handles

Phase 2 attaches `RayTracingPipelineState` to backend-private ray tracing
pipeline handle metadata.

Status: completed for vkmtl-owned backend-private pipeline state. Direct Vulkan
ray tracing pipeline creation and Metal executable pipeline/function-table
driver objects are deferred to the concrete Period 31+ backend-driver parity
plan.

## Scope

- Create vkmtl-owned backend-private pipeline handle metadata.
- Preserve shader-group counts, function-table entries, and recursion limits.
- Validate recursion depth, payload limits, and callable/hit group layout.

## Validation

- Add runtime pipeline metadata tests where native feature reports allow
  pipeline creation.
- Preserve typed unsupported behavior elsewhere.

## Deferred

- Direct Vulkan ray tracing pipeline creation is deferred to Period 31+ driver
  parity work.
- Direct Metal executable pipeline and function-table object creation is
  deferred to Period 31+ driver parity work.
