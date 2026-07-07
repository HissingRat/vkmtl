# Phase 1: Device-Owned Surface Registry

Phase 1 defines native ownership for multiple surfaces.

## Scope

- Decide whether `Device`, `Context`, or a presentation manager owns the
  surface registry.
- Track surface handles, labels, backend-native handles, and lifecycle state.
- Validate stale handles and duplicate destruction.
- Expose registry introspection without leaking backend swapchain internals.

## Validation

- Tests should cover create, lookup, remove, and stale-handle paths.
- Docs should show the expected multi-surface ownership model.
- `SurfaceCollection` is the current presentation registry shape; it can be
  owned by a future `Device` presentation manager without changing handle
  semantics.
