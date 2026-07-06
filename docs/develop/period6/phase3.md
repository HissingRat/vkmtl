# Phase 3: Resource Barrier Model

Phase 3 defines explicit barriers as an advanced escape hatch over the automatic
usage tracker.

## First Slice

- Add public buffer and texture barrier descriptor shapes.
- Validate old/new usage transitions and redundant barriers.
- Keep automatic transitions as the default user path.
- Gate manual barrier lowering behind a feature flag.

## Current Limits

- Runtime backends continue to manage the currently lowered transitions
  internally.
- `BufferBarrierDescriptor` and `TextureBarrierDescriptor` are public
  validation shapes gated by `DeviceFeatures.explicit_resource_barriers`.
- `ResourceUsageState.applyExplicitBarrier(...)` validates the expected
  `before` usage against tracked state and records a manual barrier.
- Explicit barriers are descriptor/validation first; Vulkan image barriers and
  Metal resource fences are later backend work.
