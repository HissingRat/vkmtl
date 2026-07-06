# Phase 4: Render Pipeline Cache

Phase 4 defines render pipeline cache identity.

## First Slice

- Add a render pipeline cache-key descriptor.
- Include shader identity, render target formats, raster state, blend state,
  depth/stencil state, vertex layout, and specialization data.
- Validate through existing render pipeline validation.

## Current Limits

- Native render pipeline state reuse remains future runtime/backend work.
