# Phase 5: Texture View Completeness

Phase 5 makes texture view ranges inspectable and validates more view shapes.

## First Slice

- Expose resolved view format, dimension, mip range, and layer range on runtime
  `TextureView`.
- Keep format reinterpretation disabled until format families are defined.
- Keep cube view dimensions reserved until cube-specific backend lowering is
  complete.

## Current Limits

- Depth/stencil aspect-only views are not exposed yet because the current
  portable format set has no combined depth-stencil format.
