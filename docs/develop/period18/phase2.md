# Phase 2: Resource Aliasing / Transient Allocator

Phase 2 reduces allocation churn for short-lived resources.

## Scope

- Define transient resource descriptors.
- Reuse compatible temporary buffers and textures when lifetimes do not
  overlap.
- Respect backend memory alignment and hazard constraints.
- Keep the first slice as deterministic aliasing eligibility metadata.

## Validation

- Tests should cover aliasing eligibility and rejected overlap.
- Diagnostics should report transient allocation reuse.
- Unit tests should reject overlapping lifetimes and incompatible resource
  kinds.
