# Phase 5: Depth / Stencil State

Phase 5 completes the public depth/stencil descriptor model.

## First Slice

- Keep depth compare and depth write controls.
- Add stencil operation descriptors.
- Add stencil read/write masks.
- Add stencil reference validation shape.
- Reject unsupported stencil lowering with typed errors.

## Current Limits

- Depth state already lowers for the first slice.
- Stencil state is public validation/API shape first in this period.
- `StencilDescriptor` includes front/back face operations and read/write masks.
- Current texture formats do not include a stencil-capable format yet, so
  stencil-enabled depth/stencil descriptors are rejected by validation until the
  format system grows a stencil format.
