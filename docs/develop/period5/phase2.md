# Phase 2: Raster State

Phase 2 extends render pipeline raster state without exposing backend-specific
pipeline structs.

## First Slice

- Keep cull mode and front face as portable state.
- Add fill mode.
- Add depth-bias descriptor shape.
- Add conservative rasterization feature gate.
- Reject unsupported advanced raster state with typed errors.

## Current Limits

- Fill mode, depth bias, and conservative rasterization are public validation
  shapes until backend lowering is implemented.
- Non-default fill mode, enabled depth bias, and conservative rasterization are
  rejected during runtime pipeline creation unless the matching feature gate is
  explicitly enabled by a future backend.
