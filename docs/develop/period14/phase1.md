# Phase 1: Native Handle View Stabilization

Phase 1 clarifies native handle escape hatches.

## Scope

- Stabilize the names and payloads of native handle view structs.
- Document borrowed lifetime, thread-safety expectations, and invalidation.
- Keep native handles read-only unless a later phase explicitly allows mutation.

## Validation

- Tests should ensure native handle APIs are explicit and backend-tagged.
- Docs should warn that native handles are not portable.
