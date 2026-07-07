# Phase 6: Render Backend Validation

Phase 6 closes Period 20 by making the completed render backend slices
observable and hard to regress.

## Scope

- Update the backend test matrix for blend, raster, stencil, and MRT support.
- Add focused validation tests for feature-gated render states.
- Add example coverage only where it proves a real backend path.
- Document remaining backend-specific render limits.

## Validation

- `zig build test`
- `zig build`
- Backend matrix notes updated for Vulkan and Metal.
