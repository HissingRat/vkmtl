# Period 27: Advanced Resource And Geometry Backend Completion

Status: planned after Period 26.

Goal: lower advanced resource residency and geometry pipeline features where
Vulkan and Metal expose compatible or explicitly capability-gated paths.

Expected result: vkmtl can support streaming-heavy renderers, large virtualized
resources, tessellated geometry, and mesh/task-shader-style pipelines where the
backend supports them.

## Phase 1: Sparse And Tiled Buffers

- Lower sparse buffer or equivalent tiled buffer behavior.

See `phase1.md`.

## Phase 2: Sparse And Tiled Textures

- Lower sparse/tiled texture descriptors and residency updates.

See `phase2.md`.

## Phase 3: Residency And Page Commit API

- Add explicit residency maps and page commit/update behavior.

See `phase3.md`.

## Phase 4: Tessellation Backend

- Lower tessellation descriptors to supported backend pipeline paths.

See `phase4.md`.

## Phase 5: Mesh And Task Shader Backend

- Lower mesh/task shader descriptors where available.

See `phase5.md`.

## Phase 6: Advanced Geometry Examples

- Add examples and validation for completed advanced geometry/resource paths.

See `phase6.md`.
