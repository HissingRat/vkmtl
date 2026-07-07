# Phase 2: Vulkan External Memory / Image / Semaphore Interop

Phase 2 implements Vulkan external interop where supported.

## Scope

- Detect external memory and semaphore handle types.
- Import or export buffers and images through explicit descriptors.
- Map external semaphore waits and signals into queue submission.
- Keep platform-specific handle kinds gated by features.
- Add an explicit `ExternalMemoryDescriptor` for Vulkan external memory handles.

## Validation

- Tests should validate descriptor compatibility and unsupported handle kinds.
- Backend smoke tests should cover at least one supported handle path when
  practical.
- Backend import/export lowering remains behind `DeviceFeatures.external_memory`,
  `external_textures`, and `external_semaphores`.
