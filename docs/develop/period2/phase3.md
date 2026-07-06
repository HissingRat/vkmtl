# Phase 3: Resource Lifetime And Deferred Destruction

Phase 3 defines the runtime lifetime baseline used before vkmtl removes the
current wait-idle behavior from command submission.

## First Slice

- Runtime resources are owned by `Device` and tracked by `ResourceTracker`.
- `Surface` and `Swapchain` are runtime views owned by the current
  `WindowContext` convenience owner.
- `CommandBuffer` advances a submitted-work serial on `commit()`.
- Completed work advances a completed-work serial.
- Resource `deinit()` retires the resource from the live-resource tracker.
- If a resource is retired while submitted work is still incomplete, the
  tracker records a pending deferred retirement.

## Current Backend Behavior

The current Vulkan and Metal command paths both wait for submitted work to
complete before `commit()` returns. Because of that, Phase 3 can mark the
submitted serial complete immediately after a successful backend commit.

This is intentionally a baseline. Later work can attach backend-native destroy
closures or handles to the same serial model once command submission stops
waiting for idle.

## Rules

- User code must still call `deinit()` on resources before destroying the
  context.
- Debug builds still report leaked live resources at context destruction.
- Debug builds also report pending deferred retirements if work has not been
  completed before context destruction.
- `WindowContext.deinit()` drains completed work before checking leaks because
  the current backend paths are synchronous.
