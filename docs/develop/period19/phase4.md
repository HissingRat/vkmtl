# Phase 4: Camera, Input, And Culling

Phase 4 makes the voxel world navigable.

## Scope

- Add fly camera controls through the external windowing/input layer.
- Upload view/projection data through per-frame uniform buffers.
- Add simple distance or frustum culling for chunks.

## Validation

- The camera should move smoothly through the chunk field.
- Culling should not drop visible chunks in common camera positions.
