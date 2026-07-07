# Phase 4: Stencil Backend State

Phase 4 turns stencil descriptors into real render-pass and pipeline state.

## Scope

- Add stencil-capable texture formats when the format model is ready.
- Lower stencil attachments in Vulkan render passes and Metal render pass
  descriptors.
- Lower stencil compare, read/write masks, and front/back operations to
  pipeline state.
- Keep dynamic stencil reference commands connected to the active stencil
  pipeline state.

## Validation

- Add descriptor tests for stencil format and mask rules.
- Add a small stencil render example or deterministic test path.
