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
- Runtime fence/event objects and native timeline/shared-event lowering are
  future backend work.
