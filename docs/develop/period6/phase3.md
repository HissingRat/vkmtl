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
- Explicit barriers are descriptor/validation first; Vulkan image barriers and
  Metal resource fences are later backend work.
