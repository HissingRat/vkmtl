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

## Result

- `ExternalSemaphore` and `ExternalEvent` are runtime wrappers around explicit
  backend/platform handles.
- `Device.makeExternalSemaphore(...)`, `Device.makeExternalEvent(...)`,
  `WindowContext.makeExternalSemaphore(...)`, and
  `WindowContext.makeExternalEvent(...)` validate feature gates and selected
  backend compatibility.
- `ExternalSynchronizationDescriptor` groups wait/signal semaphores and events.
- `CommandBuffer.commitWithExternalSynchronization(...)` validates wrapper
  lifetime and backend ownership before committing portable work.
- Native Vulkan external semaphore wait/signal and Metal shared-event command
  integration are deferred to Period 29 Phase 5.
