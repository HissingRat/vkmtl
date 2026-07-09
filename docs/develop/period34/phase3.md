# Phase 3: Metal Intersection Function Table Path

Phase 3 implements the Metal custom intersection path for spheres.

## Checklist

- [ ] Add backend-private Metal intersection function table creation. Deferred
  to Period35 Phase 3.
- [ ] Add procedural sphere intersection functions. Deferred to Period35 Phase
  3.
- [ ] Bind intersection function tables during native RT dispatch. Deferred to
  Period35 Phase 3.
- [ ] Connect procedural sphere data to the Metal shader path. Deferred to
  Period35 Phase 4.
- [x] Keep Metal-specific native handles behind backend-private state.
- [x] Report unsupported Metal procedural RT capability precisely.

## Acceptance

- Period34 does not claim Metal procedural execution.
- The Period33 Metal mesh RT path remains functional.
- Period35 owns Metal procedural function-table execution while preserving
  public/backend boundaries.
