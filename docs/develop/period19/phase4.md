# Phase 4: Camera, Input, And Culling

Status: complete.

Phase 4 makes the voxel world navigable and keeps draw work bounded to a
conservative visible set.

## Implemented Scope

- `W/A/S/D` move horizontally, `Q/E` move vertically, Shift increases speed,
  mouse or arrow keys control yaw/pitch, `R` requests a deterministic rebuild,
  and Escape exits.
- GLFW remains an example-only input and window adapter. Rendering and resource
  work remain on the public vkmtl surface.
- A 96-byte uniform contains four view-projection rows plus directional-light
  parameters. The shared uniform buffer is updated once per frame.
- Camera math uses a right-handed zero-to-one depth projection and floor-based
  chunk coordinates, including correct negative-world movement.
- CPU culling uses a conservative chunk bounding sphere against the camera
  frustum and 640-unit far distance. False positives are accepted; the test is
  biased against dropping visible chunks.

## Evidence

- Focused tests cover bounded workload profiles, negative chunk coordinates,
  horizontal/vertical movement, and representative front/behind culling.
- At the final fixed default camera, 49 of 81 chunks were visible and 32 were
  culled. At stress scale, 121 of 289 were visible and 168 were culled.
- The renderer emits one indexed draw per visible chunk, so the same runs
  issued 49 and 121 draw calls respectively.
- Smoke autopilot crossed a chunk boundary and exercised camera-driven
  streaming while Metal API Validation remained clean.
