# Phase 4: External Texture Creation Path

Phase 4 makes external textures usable through the normal texture APIs.

## Scope

- Create a vkmtl `Texture` wrapper from an external texture descriptor.
- Create views and sampler bindings for supported external textures.
- Validate format, usage, extent, and ownership compatibility.
- Keep the first runtime object named `ExternalTexture` so it is clear when a
  handle is externally owned and backend lowering is still feature-gated.

## Validation

- Tests should cover invalid format, extent, usage, and backend-handle
  combinations.
- Rendering smoke tests should sample from an external texture.
- Runtime tests should cover wrapper lifetime tracking even when native import
  lowering is not active on the test host.
