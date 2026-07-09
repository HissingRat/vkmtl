# Phase 5: Scene Buffers And Binding

Phase 5 adds the resource binding shape needed by the full native RT scene.

## Checklist

- [ ] Define camera buffer layout. Deferred to Period35 Phase 1.
- [ ] Define material and light buffer layouts. Deferred to Period35 Phase 1.
- [ ] Define per-instance or per-primitive scene metadata layout. Deferred to
  Period35 Phase 1.
- [ ] Bind the scene buffers in Vulkan ray tracing shaders. Deferred to
  Period35 Phase 2.
- [ ] Bind the scene buffers in Metal native RT shaders. Deferred to Period35
  Phase 3.
- [ ] Keep layouts documented and stable across both backends. Deferred to
  Period35 Phase 4.

## Acceptance

- Period33 intentionally keeps scene constants in example shader code while
  removing hardcoded scene material/color data from backend bridge code.
- Shared RT scene buffers are owned by Period35 so Period33 can close as the
  mesh-geometry native RT slice.
