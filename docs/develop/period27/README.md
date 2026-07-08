# Period 27: Advanced Resource And Geometry Backend Completion

Status: completed as a planning and validation slice. Native executable backend
closure is deferred to Period 28 Phase 5.

Goal: lower advanced resource residency and geometry pipeline features where
Vulkan and Metal expose compatible or explicitly capability-gated paths.

Expected result: vkmtl can describe and validate streaming-heavy renderer
requirements, large virtualized resources, tessellated geometry, and
mesh/task-shader-style pipelines through backend-neutral planning APIs. Period
28 owns native sparse page binding and executable advanced geometry pipelines.

## Phase 1: Sparse And Tiled Buffers

- Add sparse buffer lowering plans.

See `phase1.md`.

## Phase 2: Sparse And Tiled Textures

- Add sparse/tiled texture lowering plans and page-grid metadata.

See `phase2.md`.

## Phase 3: Residency And Page Commit API

- Add explicit residency maps and page commit/update planning.

See `phase3.md`.

## Phase 4: Tessellation Backend

- Add tessellation lowering plans for supported backend paths.

See `phase4.md`.

## Phase 5: Mesh And Task Shader Backend

- Add mesh/task shader lowering plans where available.

See `phase5.md`.

## Phase 6: Advanced Geometry Examples

- Add examples and validation for completed advanced geometry/resource paths.

See `phase6.md`.
