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
