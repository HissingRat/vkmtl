# Phase 5: Bindless Texture Example

Phase 5 proves the advanced binding path with a public example that creates a
bindless-style texture table layout and reports capability-gated fallback
output when the selected backend cannot support it yet.

## Scope

- Add `examples/bindless_textures`.
- Create a sampled-texture descriptor array layout through the public vkmtl API.
- Fall back to a clear unsupported-feature message when the backend lacks the
  required capability.

## Validation

- The example should use only public vkmtl APIs.
- The example should compile with the normal example build.
- Runtime texture sampling remains a later rendering/material milestone.
