# Phase 1: Scene Contract And Reference

Phase 1 defines the full native RT mesh scene contract before backend work
starts.

## Checklist

- [x] Define the target image as the reference-room scene, not the old triangle
  smoke test.
- [x] Keep `examples/ray_traced_scene/shaders/ray_traced_scene.slang` as
  reference-only source.
- [x] Decide the success markers for Metal and Vulkan full-scene runs.
- [x] Decide unsupported-runtime output for missing mesh RT requirements.
- [x] Document that procedural sphere parity belongs to Period34.

## Acceptance

- Period33 docs make mesh-first scope explicit.
- The reference shader is not added back to the active runtime/precompile path.
- The example acceptance text distinguishes full native RT scene output from
  first-triangle output.
