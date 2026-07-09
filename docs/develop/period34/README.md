# Period 34: Procedural RT Geometry And Custom Intersection

Status: Vulkan procedural path implemented; Metal procedural parity deferred to
Period35.

Goal: extend the native ray tracing backends from mesh-only scene rendering to
procedural sphere/custom intersection support, then use the full native
`examples/ray_traced_scene` as the acceptance example.

Period33 renders the reference scene with triangle meshes. Period34 replaces
the Vulkan tessellated sphere approximation with procedural geometry:

- Vulkan: AABB geometry plus intersection shaders.
- Metal: keeps the Period33 native mesh/intersector path for now; procedural
  primitive support plus intersection function tables are Period35.

The goal is not just to expose descriptors. The goal is to make the reference
scene render through native procedural/custom-intersection paths.

Current implementation status:

- public AABB geometry descriptor fields and build-input buffer validation are
  in place
- public ray tracing pipeline descriptors can mark procedural hit groups and
  intersection shader stages
- `DeviceFeatures.ray_tracing_procedural_geometry` and
  `DeviceFeatures.ray_tracing_custom_intersection` gate procedural/custom
  intersection descriptors with typed unsupported errors
- Vulkan backend plumbing can lower AABB geometry input into AS build records
- Slang ray tracing precompile emits intersection SPIR-V and reflection
  artifacts
- Vulkan ray tracing pipelines can create procedural hit groups with
  intersection shader stages and SBT records
- the Vulkan `ray_traced_scene` path now builds procedural sphere AABBs and
  prints `driver_pixels=visible_vulkan_procedural_rt_scene`
- Metal intersection function tables and procedural primitive execution are
  not implemented yet and are routed to Period35

## Hard Acceptance Target

After Period34, `examples/ray_traced_scene` should have a Vulkan native RT mode
that uses procedural spheres/custom intersections instead of tessellated sphere
meshes. Metal remains on the Period33 native mesh path until Period35.

Supported backends must:

- build procedural sphere acceleration-structure geometry
- bind custom intersection shader/function resources
- model the reference room and visible spheres as procedural/AABB/custom-
  intersection primitives on Vulkan
- leave mixed mesh-room plus procedural-sphere assembly to Period35
- shade the same camera/material/light scene data from Period33
- present the full scene in the window
- print a success marker that identifies procedural native RT output

Unsupported backends or runtimes must report the missing procedural/custom
intersection capability precisely.

## Scope

In scope:

- public or capability-gated descriptors for procedural RT primitives
- procedural/custom-intersection feature gates
- Vulkan AABB geometry lowering and intersection shader dispatch
- Vulkan intersection shader stage integration
- example validation using the full native RT scene on Vulkan

Out of scope:

- Metal intersection function table execution
- Metal procedural primitive lowering
- shared camera/material/light/primitive buffers
- denoising or temporal accumulation
- ray query examples unless directly required by the procedural scene
- arbitrary user-defined procedural primitive libraries
- production material completeness beyond the reference scene needs

## Phase Plan

### Phase 1: Procedural Geometry Contract

- Define the procedural sphere acceptance target.
- Decide public descriptors and feature gates.
- Preserve mesh scene behavior from Period33.

See `phase1.md`.

### Phase 2: Vulkan AABB Geometry And Intersection Shader

- Add Vulkan AABB geometry lowering.
- Compile and bind intersection shader stages.
- Wire procedural hit data into closest-hit shading.

See `phase2.md`.

### Phase 3: Metal Intersection Function Table Path

- Add Metal intersection function table execution.
- Bind procedural intersection functions for sphere geometry.
- Keep Metal RT constructs backend-private until the portable shader model is
  ready.

Deferred to Period35 Phase 3. See `phase3.md`.

### Phase 4: Shared Procedural Scene Data

- Add sphere procedural descriptors and material linkage.
- Keep camera/material/light buffers compatible with Period33.
- Validate procedural geometry ranges and primitive ids.

See `phase4.md`.

### Phase 5: Full Procedural Ray Traced Scene

- Replace tessellated sphere meshes with procedural sphere primitives.
- Render the reference-style room with procedural primitives on Vulkan.
- Route mixed mesh-room plus procedural-sphere assembly to Period35.
- Render the full reference scene using native custom intersections.

See `phase5.md`.

### Phase 6: Validation And Backend Matrix

- Validate supported Metal and Vulkan procedural paths where hardware permits.
- Document unsupported runtime gaps precisely.
- Update backend matrices and examples docs.

See `phase6.md`.

## Deferred Beyond Period 34

- Metal intersection function table execution: Period35 Phase 3.
- shared RT scene data buffers: Period35 Phases 1-4.
- arbitrary procedural primitive authoring API: Period35+.
- ray query examples: Period35+.
- compaction/update/refit stress tests: Period35+.
- large SBT and function-table pressure tests: Period35+.
- long-running GPU soak coverage: Period35+.
