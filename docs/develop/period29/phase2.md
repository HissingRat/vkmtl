# Phase 2: Native Ray Tracing Pipelines

Phase 2 turns ray tracing pipeline plans into executable backend pipelines.

## Scope

- Lower Vulkan ray-generation, miss, hit, and callable groups.
- Lower Metal-compatible ray tracing pipeline state where available.
- Keep recursion-depth and payload limits capability-gated.

## Validation

- Add pipeline creation tests where native support is available.
- Preserve typed unsupported behavior on unsupported adapters.
