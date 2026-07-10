# Phase 5: MSAA, Mip, Layer, And Slice Regression Coverage

Status: complete.

## Decisions

- Ordinary copy/readback of multisampled textures remains unsupported; resolve
  is the explicit conversion to a single-sample target.
- Color resolve requires matching formats/extents, multisampled source, and
  single-sample destination.
- Texture views and copies validate mip and array-layer ranges independently.
- Format reinterpretation is limited to existing compatible unorm/sRGB copy
  classes. Texture views do not reinterpret formats until backend view-format
  compatibility is queried explicitly.
- Regression tests cover MSAA rejection/resolve validation, partial mip/layer
  copies, 3D slices, and allowed/disallowed reinterpretation.

## Acceptance

- Edge cases are covered by executable tests or typed unsupported errors.
- Vulkan and Metal differences remain behind capability and validation models.
- Period 42 docs and backend matrix describe the remaining limits.
