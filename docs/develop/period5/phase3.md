# Phase 3: Dynamic Render State

Phase 3 adds Metal-like encoder methods for state that should not require
pipeline recreation.

## First Slice

- Add viewport and scissor descriptor shapes.
- Add blend constants, stencil reference, and dynamic depth-bias shapes.
- Add render encoder entry points for dynamic state.
- Return clear unsupported errors until native backend lowering is wired.

## Current Limits

- Dynamic render state methods validate input and then return typed unsupported
  errors for states that are not lowered yet.
- Public methods are available on `RenderCommandEncoder`: `setViewport`,
  `setScissorRect`, `setBlendColor`, `setStencilReference`, and `setDepthBias`.
