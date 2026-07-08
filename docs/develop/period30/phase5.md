# Phase 5: Native Advanced Escape Hatches

Phase 5 closes the backend-private runtime inventory tracked by
`NativeAdvancedClosurePlan`.

Status: completed for vkmtl-owned inventory and routing. Direct driver-level
implementation for these features is intentionally moved to the concrete
Period 31+ backend-driver parity plan because the list spans multiple native API
families and needs dedicated hardware validation.

## Scope

- Count requested native advanced features.
- Count public runtime-contract features separately.
- Count backend-private runtime inventory separately.
- Route remaining driver-level native work to Period 31+.
- Keep native object pools, driver caches, cache manifest I/O, staging pools,
  heaps, sparse/tiled binding, external interop, command handle views,
  tessellation, and mesh/task execution visible as explicit target items.

## Validation

- Add focused runtime tests for inventory counts and deferred driver targets.
- Update capability and backend matrices for every routed path.

## Deferred

- Driver-level native advanced execution is deferred to Period 31+ concrete
  periods and phases after Period 30 is complete.
