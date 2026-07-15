# Period 19: Voxel World Pressure Test

Status: complete. Phases 1-7 closed on 2026-07-15.

Goal: build a Minecraft-like block world prototype under `examples/` as the
final pressure test for vkmtl's render, resource, shader, binding, transfer,
and presentation stack.

This is not a full game engine period. The target is a focused voxel renderer
prototype: fly a camera through a chunked block world, render visible faces with
a texture atlas, and use the result to expose remaining vkmtl bottlenecks.

Period 19 was reactivated after Periods 46-54 closed the original render,
binding, synchronization, resource, and semantic-routing blockers. New public
API is not assumed: the pressure test must first use the current canonical
surface and turn any real missing contract into an explicit allocation.

The completed example now renders deterministic chunk terrain with generated
atlas materials, a fly camera, conservative CPU frustum culling, bounded chunk
streaming, rebuild diagnostics, depth, and directional lighting. It uses only
the public vkmtl surface. No new public declaration was needed.

## Phase 1: Voxel Example Contract

- Define the exact scope and bounded workload profiles.
- Add a public-API-only `examples/voxel_world` window scaffold and run step.
- Keep gameplay out of scope and advanced optional capabilities off the
  correctness path.

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

## Closeout

The smoke, default, and stress profiles completed on physical Metal with Metal
API Validation enabled. The largest run reached the bounded 289-chunk resident
set, culled 168 chunks, drew 121 chunks, drained its rebuild queue, and emitted
the success marker after 160 frames.

The pressure test found one important production limitation rather than a
correctness gap: the physical Metal `CommandBuffer.commit()` path waits for GPU
completion, and the portable API does not expose application-owned in-flight
completion. A future asynchronous submission/in-flight resource period should
address that deliberately; Period 19 does not change command-buffer lifetime
semantics incidentally.

Metal API Validation also exposed and closed a default drawable-format bug by
aligning the Metal layer and capability report with the sRGB window-pipeline
convention. Explicit requested/selected presentation-format resolution remains
a separate maintenance item, especially for a Vulkan surface-format fallback.

See `pressure-test-report.md` for measurements and `closeout.md` for the final
scope and validation statement. Physical Vulkan execution is not claimed by
this period: Vulkan shader generation and forced Vulkan builds passed, but
those are not substitutes for a run on a Vulkan device.
