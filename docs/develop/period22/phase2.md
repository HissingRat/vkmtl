# Phase 2: Fences And Events

Phase 2 adds runtime synchronization objects.

## Scope

- Add binary fence runtime objects.
- Add timeline fence support where available.
- Add event/shared-event objects with explicit capability gates.
- Map Vulkan fences/semaphores/events and Metal events/shared events.

## Validation

- Add lifecycle tests for wait, signal, reset, and destroy ordering.
- Keep unsupported shared-event paths typed and discoverable.
