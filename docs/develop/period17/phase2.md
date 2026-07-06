# Phase 2: Vulkan Ray Tracing Pipeline Lowering

Phase 2 implements Vulkan ray tracing pipelines.

## Scope

- Enable required Vulkan ray tracing extensions.
- Create ray generation, miss, closest-hit, any-hit, and intersection stages.
- Create shader groups and pipeline layouts.
- Dispatch rays through command encoders.

## Validation

- Tests should validate recursion depth and group layout requirements.
- Vulkan smoke tests should trace a visible primitive.
