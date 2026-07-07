# Phase 4: Stencil Backend State

Phase 4 turns stencil descriptors into real render-pass and pipeline state.

## Scope

- Add stencil-capable texture formats when the format model is ready.
- Lower combined depth/stencil attachments in Vulkan render passes and Metal
  render pass descriptors.
- Lower stencil compare, read/write masks, and front/back operations to
  pipeline state.
- Keep dynamic stencil reference commands connected to the active stencil
  pipeline state.

## Status

Completed for the combined depth/stencil path.

## Backend Notes

- `depth32_float_stencil8` is the first portable stencil-capable format.
- Vulkan maps it to `VK_FORMAT_D32_SFLOAT_S8_UINT`, clears stencil to 0 for the
  combined depth/stencil attachment, and lowers front/back `VkStencilOpState`.
- Metal maps it to `MTLPixelFormatDepth32Float_Stencil8`, binds the same
  texture as depth and stencil attachment, and lowers front/back
  `MTLStencilDescriptor` state.
- Separate stencil-only render pass attachments remain unsupported until a later
  attachment-model pass.

## Validation

- Add descriptor tests for stencil format and mask rules.
- Add a small stencil render example or deterministic test path.
