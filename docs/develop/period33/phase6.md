# Phase 6: Full Mesh Ray Traced Scene Example

Phase 6 upgrades `examples/ray_traced_scene` from first-triangle output to a
full native RT mesh scene.

## Checklist

- [x] Generate Cornell-box style room mesh data.
- [x] Generate tessellated sphere mesh data for the visible spheres.
- [x] Create BLAS/TLAS objects through public vkmtl APIs.
- [x] Dispatch native RT on Vulkan and Metal where supported.
- [x] Present the full scene output in the window.
- [x] Print full-scene success markers distinct from first-triangle markers.

## Acceptance

- `examples/ray_traced_scene` shows a reference-inspired room-and-spheres scene
  through native RT on supported Metal devices.
- The Vulkan path shows the same logical scene on supported Vulkan RT devices,
  or reports a precise unsupported-runtime reason. Period34 replaces the
  Vulkan sphere geometry with procedural AABB/custom-intersection primitives.
- Successful output is no longer a single triangle.
