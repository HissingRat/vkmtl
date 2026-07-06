# Phase 3: Resize, Minimize, And Surface-Lost Handling

Phase 3 hardens presentation lifecycle changes.

## Scope

- Recreate swapchain or drawable state after resize.
- Treat minimized or zero-sized surfaces as temporarily unavailable.
- Return typed surface-lost errors when native presentation resources fail.

## Validation

- Tests should cover zero extent, stale generation, and recreate sequencing.
- Examples should continue rendering after resize.
