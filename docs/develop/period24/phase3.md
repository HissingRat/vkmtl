# Phase 3: Broader Texture Copy Coverage

Phase 3 expands texture copy coverage.

## Scope

- Support array-layer copies.
- Support mip-level copies.
- Support more compatible color formats.
- Keep MSAA and depth/stencil copies capability-gated until semantics are clear.

## Validation

- Add descriptor tests for layers, mips, and format mismatch behavior.
- Add readback-backed tests where possible.

## Result

- Texture-to-texture copies now carry `slice_count` for multi-layer array
  copies.
- Vulkan lowers multi-layer copies through `VkImageCopy.layer_count`.
- Metal lowers multi-layer copies by looping native per-slice blit calls.
- Color copies now allow compatible unorm/sRGB pairs within the same channel
  order copy class.
- Depth/stencil and MSAA copy semantics remain deferred to Period 29 Phase 6,
  where the parity matrix will decide which cases become portable and which
  remain backend-specific.
