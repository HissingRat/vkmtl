# Phase 5: Bindless Texture Example

Phase 5 proves the advanced binding path with a visible example.

## Scope

- Add `examples/bindless_textures`.
- Load or generate multiple textures.
- Select textures per draw or per instance through bindless indices.
- Fall back to a clear unsupported-feature message when the backend lacks the
  required capability.

## Validation

- The example should use only public vkmtl APIs.
- The example should run on at least one Vulkan or Metal backend before the
  phase is considered complete.
