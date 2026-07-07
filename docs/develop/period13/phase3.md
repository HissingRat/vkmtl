# Phase 3: Resize, Minimize, And Surface-Lost Handling

Phase 3 hardens presentation lifecycle changes.

## Scope

- Recreate swapchain or drawable state after resize.
- Treat minimized or zero-sized surfaces as temporarily unavailable.
- Return typed surface-lost errors when native presentation resources fail.
- Keep lost surfaces removable through the registry while blocking accidental
  resize/reconfigure reuse.

## Validation

- Tests should cover zero extent, stale generation, and recreate sequencing.
- Examples should continue rendering after resize.
- Unit tests should distinguish suspended resize recovery from permanent
  surface-lost state.
