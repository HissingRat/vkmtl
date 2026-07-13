# Phase 2: Native Timeline And Shared-Event Submission

Status: complete.

## Scope

- Create/destroy/query/signal/wait native timeline objects behind existing
  timeline fences.
- Create/destroy/query/signal/wait native shared-event objects where supported.
- Lower `SynchronizationDescriptor` waits and signals into the native command
  submission instead of host-side pre/post composition for native objects.
- Preserve runtime binary fence/event fallback without reporting it as native.
- Validate monotonic values, same-device ownership, pending command borrows,
  timeout behavior, and object destruction order.

## Result

Vulkan timeline semaphores and Metal shared events now back timeline fences.
Metal shared events also back the capability-gated shared-event path. Native
objects lower wait/signal values into command submission; binary fences and
ordinary events keep the exact host-side fallback. Factories require an actual
native capability source before constructing native state.
