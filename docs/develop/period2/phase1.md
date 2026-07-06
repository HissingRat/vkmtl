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
- Add runtime `Surface` and `Swapchain` view wrappers.
- Move example resize calls to `swapchain.resize(...)`.

## Non-Goals

- Do not remove `WindowContext.make*` yet.
- Do not require standalone multi-surface ownership in this slice.

## Later Work

- Keep `WindowContext.make*`, `compile*`, `resize(...)`, and `clear(...)` as
  compatibility forwards during Period 2.
- Decide when those forwards become deprecated after standalone `Device`,
  `Surface`, and `Swapchain` owners are no longer views.
