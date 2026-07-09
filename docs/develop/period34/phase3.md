# Phase 3: Metal Intersection Function Table Path

Phase 3 implements the Metal custom intersection path for spheres.

## Checklist

- [ ] Add backend-private Metal intersection function table creation. Deferred
  to Period39 Phase 2/4.
- [ ] Add driver-level procedural sphere intersection functions. Deferred to
  Period39 Phase 2/4.
- [ ] Bind intersection function tables during native RT dispatch. Deferred to
  Period39 Phase 2/4.
- [x] Connect procedural sphere data to the Metal shader path through the
  Period35 scene-data payload.
- [x] Keep Metal-specific native handles behind backend-private state.
- [x] Report unsupported Metal procedural RT capability precisely.

## Acceptance

- Period34 does not claim Metal procedural execution.
- The Period33 Metal mesh RT path remains functional.
- Period39 owns Metal procedural function-table execution while preserving
  public/backend boundaries.
