# Period 35: RT Scene Data And Procedural Parity Boundary

Status: implemented as the shared-scene-data slice after Period34.

Goal: turn the Period33/34 ray traced scene from shader-local constants into
shared scene data, keep the native RT boundary backend-neutral, and record the
remaining driver-level procedural parity work without leaking Metal or Vulkan
handles into the public API.

## Completed Scope

- `examples/ray_traced_scene` now builds one backend-neutral `RtSceneData`
  payload with frame parameters, camera data, sphere primitive records, color
  records, and material records.
- The Vulkan Slang RT shader and the Metal MSL reference shader both read the
  same logical scene data layout through vkmtl ray-dispatch inline data.
- The Vulkan ray tracing inline-data buffer now has enough room for the shared
  scene payload instead of only a single float/time constant.
- The scene data remains example-owned. vkmtl provides the generic dispatch
  binding path; it does not contain reference-scene sphere, color, or material
  tables.
- The Metal path keeps backend-private mapping metadata for function-table
  planning while preserving the public/backend boundary.

## Remaining Ownership

- Full mixed mesh/procedural TLAS shading, including room walls as mesh
  geometry and spheres as procedural geometry in the same shader dispatch, moves
  to Period39 Phase 2 with many-instance TLAS and instance metadata.
- Driver-level Metal procedural intersection function table execution remains a
  Period39 RT-completeness item. Until then, Metal keeps the pixel-producing
  reference scene path and reports RT table metadata without exposing native
  handles through ordinary public API.
- Cross-device visual parity still needs supported-device Vulkan validation
  outside macOS. Period39 Phase 5 owns RT stress and visual validation beyond
  the Period35 smoke coverage.

## Phase Plan

### Phase 1: Shared RT Scene Data Layout

- Done for the reference-scene payload: frame params, camera, primitive sphere
  records, colors, and material data are provided by the example and consumed by
  both backend shader paths.
- The layout is backend-neutral plain data and is inspectable from the example.
- Shader-local hardcoded sphere, color, and material constants were removed from
  the active Vulkan/Metal scene shaders.

### Phase 2: Mixed Mesh And Procedural Scene Assembly

- Vulkan already supports procedural AABB BLAS/TLAS dispatch for the full
  reference scene.
- The runtime has multi-instance TLAS resource validation and Vulkan lowering,
  but the full mixed mesh/procedural material lookup path is deferred to
  Period39 Phase 2.

### Phase 3: Metal Procedural Function Tables

- The public API remains backend-neutral and Metal function-table details stay
  behind backend-private mapping objects.
- Driver-level Metal procedural function table binding is deferred to Period39
  RT completeness, where it can be implemented with the broader instance/SBT
  metadata work.

### Phase 4: Cross-Backend Scene Binding

- Done for the reference-scene payload: both Vulkan and Metal consume the same
  `RtSceneData` bytes through `RayDispatchDescriptor.inline_data`.
- Native AS and function-table handles remain hidden behind vkmtl objects.
- Primitive/object ids map to the shared sphere/color/material arrays for the
  current procedural scene. Full instance-id material lookup moves to Period39
  Phase 2.

### Phase 5: Visual Parity And Validation

- The Metal scene path was smoke-tested locally after the shared-data change.
- Vulkan cross-build validation passes; supported-device visual validation is
  tracked by Period39 Phase 5.
- Remaining quality gaps are assigned above instead of being left as vague
  deferred work.
