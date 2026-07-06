# Period 19: Voxel World Pressure Test

Status: planned.

Goal: build a Minecraft-like block world prototype under `examples/` as the
final pressure test for vkmtl's render, resource, shader, binding, transfer,
and presentation stack.

This is not a full game engine period. The target is a focused voxel renderer
prototype: fly a camera through a chunked block world, render visible faces with
a texture atlas, and use the result to expose remaining vkmtl bottlenecks.

## Phase 1: Voxel Example Contract

- Define the exact scope of `examples/voxel_world`.
- Keep gameplay out of scope.

See `phase1.md`.

## Phase 2: Chunk Mesh Data And CPU Meshing

- Generate chunk geometry from block data.
- Emit only visible faces for the first slice.

See `phase2.md`.

## Phase 3: Texture Atlas And Material Binding

- Add a simple atlas and block-material mapping.
- Exercise texture upload, sampling, and bind groups.

See `phase3.md`.

## Phase 4: Camera, Input, And Culling

- Add fly camera controls and view/projection uniforms.
- Add basic frustum or distance culling.

See `phase4.md`.

## Phase 5: Chunk Streaming And Mesh Rebuild Loop

- Stream a small grid of chunks around the camera.
- Rebuild changed chunk meshes without stalling the whole frame.

See `phase5.md`.

## Phase 6: Lighting And Visibility Polish

- Add simple directional or ambient-occlusion-style lighting.
- Improve depth, face visibility, and transparent-block rules only where cheap.

See `phase6.md`.

## Phase 7: Pressure-Test Report

- Record what the example proves and what backend limits it exposes.
- Feed findings back into later production work.

See `phase7.md`.
