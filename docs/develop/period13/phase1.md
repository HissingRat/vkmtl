# Phase 1: Device-Owned Surface Registry

Phase 1 defines native ownership for multiple surfaces.

## Scope

- Decide whether `Device`, `Context`, or a presentation manager owns the
  surface registry.
- Track surface handles, labels, backend-native handles, and lifecycle state.
- Validate stale handles and duplicate destruction.

## Validation

- Tests should cover create, lookup, remove, and stale-handle paths.
- Docs should show the expected multi-surface ownership model.
