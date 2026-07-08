# Phase 2: Native Ray Tracing Pipeline Handles

Phase 2 attaches `RayTracingPipelineState` to backend-private ray tracing
pipeline handle metadata.

Status: completed for vkmtl-owned backend-private pipeline state. First-triangle
Metal executable pipeline/function-table driver objects are deferred to Period
31, first-triangle Vulkan ray tracing pipeline creation is deferred to Period
32, and broader pipeline parity remains Period 32+ work.

## Scope

- Create vkmtl-owned backend-private pipeline handle metadata.
- Preserve shader-group counts, function-table entries, and recursion limits.
- Validate recursion depth, payload limits, and callable/hit group layout.

## Validation

- Add runtime pipeline metadata tests where native feature reports allow
  pipeline creation.
- Preserve typed unsupported behavior elsewhere.

## Deferred

- Direct Metal executable pipeline and function-table object creation for the
  first triangle is deferred to Period 31.
- Direct Vulkan ray tracing pipeline creation for the first triangle is
  deferred to Period 32.
- Larger shader groups, callable shaders, and broader pipeline parity are
  deferred to Period32+.
