# Phase 1: Device / Queue / Surface Split

Phase 1 introduces the long-term owner names without breaking existing
examples.

## First Slice

- Add runtime `Device` and `Queue` wrappers.
- Let `WindowContext.device()` return a device view.
- Let `WindowContext.queue()` return a queue view.
- Keep existing `WindowContext.make*` methods as compatibility forwards.
- Move implementation of resource creation methods behind `Device`.
- Move command-buffer creation behind `Queue`.
- Migrate examples to `device.make*` and `queue.makeCommandBuffer()` so the
  public sample code uses the new entry points.

## Non-Goals

- Do not remove `WindowContext.make*` yet.
- Do not split presentation into a separate public swapchain owner yet.

## Later Work

- Add explicit `Surface` / `Swapchain` runtime wrappers.
- Decide which `WindowContext` APIs stay as convenience helpers.
