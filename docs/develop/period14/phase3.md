# Phase 3: Metal Texture / Buffer / Event Interop

Phase 3 implements Metal interop where supported.

## Scope

- Wrap existing Metal textures or buffers through explicit descriptors.
- Support Metal shared events or equivalent synchronization objects where
  available.
- Preserve ownership boundaries between vkmtl and external owners.
- Default external resources to borrowed ownership so vkmtl does not destroy
  objects it did not create.

## Validation

- Tests should cover borrowed versus owned external resource descriptors.
- macOS smoke tests should validate a wrapped texture or buffer path.
- Backend wrapping remains gated by `DeviceFeatures.external_memory` and
  `external_semaphores`.
