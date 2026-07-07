# Phase 7: Draw Commands

Phase 7 rounds out direct and indirect draw command descriptor shapes.

## First Slice

- Keep direct draw and indexed draw working.
- Add base vertex and base instance descriptor fields.
- Add indirect draw descriptor shapes.
- Add multi-draw descriptor shapes behind feature gates.
- Lower base draw fields, indirect draw, and explicit multi-draw through the
  current backend command paths.

## Current Limits

- Existing command encoders lower direct draw and indexed draw.
- Indirect draw lowers to native backend commands; `draw_count > 1` expands by
  stride into repeated single indirect draw commands.
- Explicit multi-draw lowers by expanding to repeated direct draw calls.
- `base_instance` and `base_vertex` are represented on direct draw descriptors,
  and runtime lowering passes them to both native backends.
- `drawPrimitivesIndirect`, `drawIndexedPrimitivesIndirect`,
  `drawPrimitivesMulti`, and `drawIndexedPrimitivesMulti` exist on the runtime
  render encoder. True backend-native multi-draw is still future optimization.
