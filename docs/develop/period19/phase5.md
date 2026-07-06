# Phase 5: Chunk Streaming And Mesh Rebuild Loop

Phase 5 turns the static field into a small streaming world.

## Scope

- Maintain a chunk grid around the camera.
- Generate new chunks as the camera moves.
- Rebuild changed chunk meshes without blocking unrelated draw work more than
  necessary.
- Track upload and buffer churn for diagnostics.

## Validation

- The example should keep rendering while chunks enter and leave the view area.
- Diagnostics should show mesh rebuild and upload counts.
