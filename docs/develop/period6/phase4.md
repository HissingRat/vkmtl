# Phase 4: Fences / Events

Phase 4 introduces portable synchronization descriptor shapes.

## First Slice

- Add fence and event descriptors.
- Add wait/signal validation structures.
- Represent binary and timeline-style synchronization while keeping optional
  timeline behavior gated.
- Keep CPU/GPU and GPU/GPU synchronization semantics explicit in docs.

## Current Limits

- The current backends still complete submitted work synchronously.
- `FenceDescriptor`, `FenceSignalDescriptor`, and `FenceWaitDescriptor` are
  public validation shapes gated by `DeviceFeatures.fences` and
  `DeviceFeatures.timeline_fences`.
- `EventDescriptor`, `EventSignalDescriptor`, and `EventWaitDescriptor` are
  public validation shapes gated by `DeviceFeatures.events` and
  `DeviceFeatures.shared_events`.
- Runtime fence/event objects and native timeline/shared-event lowering are
  future backend work.
