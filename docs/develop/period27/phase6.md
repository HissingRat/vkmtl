# Phase 6: Advanced Geometry Examples

Phase 6 closes Period 27 with examples and matrix coverage.

## Scope

- Add examples only for backend-supported advanced paths.
- Update backend matrix for sparse/tiled, tessellation, mesh, and task support.
- Document fallback expectations.

## Validation

- `zig build test`
- `zig build`
- Backend matrix updated for Vulkan and Metal.

## Result

- Added `advanced_resource_geometry_regression` to the backend test matrix.
- Added an authoritative advanced resource/geometry matrix in
  `src/development_matrix.zig`.
- Added validation inventory coverage for sparse/tiled planning, residency
  planning, tessellation lowering, and mesh/task lowering.
- Marked Period 27 as complete as a planning and validation slice.
- Kept the existing tessellation and mesh-shader examples as public API
  feature-gate examples.

## Deferred

- Native sparse/tiled resource objects and page binding remain deferred to
  Period 28 Phase 5.
- Native tessellation and mesh/task executable pipeline creation remain
  deferred to Period 28 Phase 5.
