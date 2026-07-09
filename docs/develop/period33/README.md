# Period 33: Native RT Mesh Scene

Status: closed for the mesh-scene slice.

Goal: expand the Vulkan and Metal native ray tracing backends from first
triangle smoke paths into a full native RT mesh scene path that can render the
reference `ray_traced_scene` as triangle geometry.

Current implementation status:

- public mesh/AABB acceleration-structure geometry descriptors exist
- `examples/ray_traced_scene` now creates room and sphere triangle mesh input
  through the public runtime path
- Metal renders a visible full mesh room/sphere scene and prints
  `driver_pixels=visible_metal_full_mesh_rt_scene`
- Vulkan accepts user mesh build input and has been exercised on supported
  Vulkan RT hardware before the Period34 procedural replacement
- scene camera/material/light data is still fixed in the current example and
  example shader paths, not a shared public scene-buffer layout

This period is the first concrete Period32+ ray tracing period. It intentionally
uses mesh geometry first: Cornell-box walls and spheres are represented as
triangles, not procedural primitives. The reference fragment shader at
`examples/ray_traced_scene/shaders/ray_traced_scene.slang` remains the visual
and material target, but the acceptance path must use native RT driver work.

## Hard Acceptance Target

`examples/ray_traced_scene` should become a full native RT scene example, not a
simple triangle smoke test.

On supported Metal devices:

```sh
VKMTL_BACKEND=metal zig build run-ray-traced-scene
```

On supported Vulkan ray tracing devices:

```sh
zig build run-ray-traced-scene -Dvulkan
```

must:

- create the reference room and sphere scene as triangle mesh geometry
- create BLAS objects from user-provided vertex/index buffers
- create a scene-level acceleration structure or backend-equivalent scene
  object
- bind camera, material, light, and scene data
- dispatch native ray tracing work through the selected backend
- present the native RT output in the window
- print a success marker that distinguishes the full scene from the first
  triangle smoke paths

Unsupported runtimes must exit with typed capability messages instead of
falling back to the old fragment reference shader.

## Scope

In scope:

- public runtime descriptors for ray tracing mesh geometry input
- user-provided vertex/index buffer lowering for BLAS builds
- scene-level AS / instance support needed by the acceptance example
- camera, material, light, and per-instance scene data
- Vulkan and Metal native backend lowering for the mesh scene
- a full native RT `examples/ray_traced_scene` implementation using mesh
  spheres and room triangles
- validation that proves both supported backend paths render the scene or
  report precise unsupported reasons

Out of scope:

- procedural sphere geometry
- custom intersection shaders/functions
- ray query
- acceleration structure compaction/update/refit beyond what the mesh scene
  requires
- production denoising, temporal accumulation, and physically complete material
  models

Procedural geometry and custom intersection support are Period34.

## Phase Plan

### Phase 1: Scene Contract And Reference

- Freeze the mesh-first acceptance target.
- Keep the reference shader source as visual guidance only.
- Define success markers and unsupported-runtime behavior.

See `phase1.md`.

### Phase 2: Public RT Mesh Geometry API

- Add descriptors for vertex/index-backed RT mesh geometry.
- Define ownership and lifetime for buffers used by BLAS builds.
- Keep native handles hidden behind backend-private state.

See `phase2.md`.

### Phase 3: Vulkan Mesh BLAS And TLAS

- Lower public mesh geometry descriptors to Vulkan build geometry.
- Support multiple BLAS objects and a TLAS with multiple instances.
- Preserve typed unsupported behavior for missing native features.

See `phase3.md`.

### Phase 4: Metal Mesh BLAS And TLAS

- Lower public mesh geometry descriptors to Metal acceleration structure
  descriptors.
- Replace the current backend-private built-in triangle path with
  user-provided mesh buffers.
- Support a TLAS or equivalent instance path for the mesh scene.

See `phase4.md`.

### Phase 5: Scene Buffers And Binding

- Add camera, material, light, and instance data buffers.
- Define a shared scene data layout for the native RT shaders.
- Bind the same logical resources on Vulkan and Metal.

See `phase5.md`.

### Phase 6: Full Mesh Ray Traced Scene Example

- Build the room and tessellated sphere meshes.
- Render the full reference-inspired scene through native RT on supported
  backends.
- Remove the first-triangle output as the successful `ray_traced_scene` path.

See `phase6.md`.

### Phase 7: Validation And Documentation

- Keep `zig build test` and `zig build` passing.
- Capture or document Metal and Vulkan visible results where hardware is
  available.
- Update usage/API docs to describe the full native mesh RT scene and remaining
  procedural limitations.

See `phase7.md`.

## Deferred To Period 34

- procedural spheres
- custom intersection shaders/functions
- Vulkan intersection shader parity for AABB/procedural geometry
- exact Shadertoy-style procedural scene parity

## Deferred To Period 35

- Metal intersection function table execution for custom primitives
- shared camera/material/light/primitive scene buffers for RT scenes
