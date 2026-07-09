# Phase 5: Scene Buffers And Binding

Phase 5 adds the resource binding shape needed by the full native RT scene.

## Checklist

- [x] Define camera scene-data layout through Period35.
- [x] Define material and light scene-data layout through Period35.
- [x] Define per-primitive sphere scene metadata through Period35.
- [x] Bind the scene data in Vulkan ray tracing shaders through Period35.
- [x] Bind the scene data in Metal native RT shaders through Period35.
- [x] Keep layouts documented and stable across both backends through Period35.
- [ ] Define full per-instance mixed TLAS metadata. Deferred to Period39
  Phase 2.

## Acceptance

- Period33 intentionally keeps scene constants in example shader code while
  removing hardcoded scene material/color data from backend bridge code.
- Shared RT scene data is handled by Period35 so Period33 can close as the
  mesh-geometry native RT slice. Full per-instance mixed TLAS metadata is
  owned by Period39.
