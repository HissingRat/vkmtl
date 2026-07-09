# Phase 5: Full Procedural Ray Traced Scene

Phase 5 upgrades the full scene from tessellated spheres to procedural sphere
intersections.

## Checklist

- [x] Replace tessellated sphere mesh BLAS objects with procedural sphere
  geometry where supported.
- [ ] Keep room walls as mesh geometry alongside procedural spheres. Deferred
  to Period39 Phase 2.
- [ ] Preserve reflection/refraction/material behavior from the reference
  visual target as closely as the current shaders allow. Ongoing RT stress and
  visual parity polish is Period39 Phase 5.
- [x] Present procedural native RT output in the window.
- [x] Print procedural-scene success markers.

## Acceptance

- `examples/ray_traced_scene` renders the full reference-inspired scene with
  procedural spheres on supported Vulkan RT backends.
- Successful output is neither the first triangle smoke scene nor the mesh-only
  Period33 scene.
- Unsupported procedural paths clearly explain the missing backend capability.
