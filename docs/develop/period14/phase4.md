# Phase 4: External Texture Creation Path

Phase 4 makes external textures usable through the normal texture APIs.

## Scope

- Create a vkmtl `Texture` wrapper from an external texture descriptor.
- Create views and sampler bindings for supported external textures.
- Validate format, usage, extent, and ownership compatibility.

## Validation

- Tests should cover invalid format, extent, usage, and backend-handle
  combinations.
- Rendering smoke tests should sample from an external texture.
