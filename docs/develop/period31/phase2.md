# Phase 2: Metal Acceleration Structure Driver Bridge

Phase 2 adds the first real Metal acceleration-structure backend path.

Status: remaining native hardening. The current visible example keeps
Period30 backend-private acceleration-structure records but does not allocate a
real `MTLAccelerationStructure` yet.

## Scope

- Extend the Metal bridge with backend-private acceleration-structure types.
- Allocate real `MTLAccelerationStructure` objects for the example.
- Query or compute Metal build sizes and scratch requirements.
- Encode the triangle bottom-level acceleration structure build through Metal.
- Connect the runtime `AccelerationStructure` object to the real backend handle
  while keeping the handle backend-private.

## Acceptance

- The ray traced triangle example can build a real Metal bottom-level
  acceleration structure for one triangle.
- Existing runtime validation still rejects invalid scratch/result resources.
- Non-Metal or unsupported Metal devices keep typed unsupported behavior.

## Deferred

- TLAS/instance builds are deferred to Period32+.
- Acceleration structure update/refit/compaction is deferred to Period32+.
