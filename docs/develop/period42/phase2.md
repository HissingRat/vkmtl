# Phase 2: Copy And Blit Edge Semantics

Status: complete.

## Decisions

- Buffer/texture copies validate buffer offset, row pitch, image pitch, mip,
  slice, and region bounds before backend encoding.
- Backend alignment requirements are represented explicitly and applied by the
  runtime encoder rather than hidden in backend code.
- Buffer offsets must also align to the selected aspect's texel size; row pitch
  must be a multiple of that texel size even when the backend limit is 1.
- Exact texture copies require compatible copy classes and matching aspects.
- Scaled blits are described separately from exact copies. Vulkan lowers
  supported blits to `vkCmdBlitImage`; Metal reports a typed unsupported error
  until a shader-backed scaling path exists.
- Linear filtering requires both source format linear-filter support and blit
  support. Depth and stencil blits are not part of the portable path.

## Acceptance

- Misaligned buffer offsets and row pitches fail deterministically.
- Partial mip, array-layer, and 3D-slice copies are validated.
- Nearest and linear blit behavior is explicit and capability-gated.
