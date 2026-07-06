# Phase 7: Draw Commands

Phase 7 rounds out direct and indirect draw command descriptor shapes.

## First Slice

- Keep direct draw and indexed draw working.
- Add base vertex and base instance descriptor fields.
- Add indirect draw descriptor shapes.
- Add multi-draw descriptor shapes behind feature gates.
- Return typed unsupported errors for command forms that are not lowered yet.

## Current Limits

- Existing command encoders lower direct draw and indexed draw.
- Indirect and multi-draw are validation/API shape first in this period.
- `base_instance` and `base_vertex` are represented on direct draw descriptors,
  but runtime lowering rejects non-zero values until both backends support them.
- `drawPrimitivesIndirect`, `drawIndexedPrimitivesIndirect`,
  `drawPrimitivesMulti`, and `drawIndexedPrimitivesMulti` exist on the runtime
  render encoder and return typed unsupported errors after validation.
