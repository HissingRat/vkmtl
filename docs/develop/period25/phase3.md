# Phase 3: External Memory And Textures

Phase 3 imports resources owned by other systems.

## Scope

- Lower Vulkan external memory and image import.
- Lower Metal texture/buffer wrapping where supported.
- Validate format, usage, ownership, and lifetime.
- Keep portable resource creation unchanged.

## Validation

- Add external texture descriptor tests.
- Add an interop example or mock-backed path.

## Result

- `ExternalMemory`, `ExternalBuffer`, and `ExternalTexture` are runtime wrapper
  objects with backend, descriptor, ownership, and lifetime tracking.
- `Device.makeExternalMemory(...)`, `Device.makeExternalBuffer(...)`, and
  `Device.makeExternalTexture(...)` validate selected-backend compatibility and
  feature gates before creating wrappers.
- `WindowContext.makeExternalMemory(...)`,
  `WindowContext.makeExternalBuffer(...)`, and
  `WindowContext.makeExternalTexture(...)` remain compatibility forwards.
- `examples/external_texture` continues to exercise the explicit feature-gated
  texture path.
- Native Vulkan external memory/image import and Metal external
  buffer/texture wrapping are deferred to Period 28 Phase 5. Until that lands,
  these wrappers are explicit interop descriptors and lifetime guards, not
  proof that a backend-native import occurred.
