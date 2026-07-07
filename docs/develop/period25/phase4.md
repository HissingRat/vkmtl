# Phase 4: External Semaphores And Shared Events

Phase 4 adds cross-system synchronization.

## Scope

- Lower Vulkan external semaphore import/export.
- Lower Metal shared event behavior.
- Integrate imported sync primitives with queue submission.
- Keep unsupported sharing modes behind precise typed errors.

## Validation

- Add lifecycle and invalid-handle tests where possible.
- Document platform-specific setup requirements.
