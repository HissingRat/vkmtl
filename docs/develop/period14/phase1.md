# Phase 1: Native Handle View Stabilization

Phase 1 clarifies native handle escape hatches.

## Scope

- Stabilize the names and payloads of native handle view structs.
- Document borrowed lifetime, thread-safety expectations, and invalidation.
- Keep native handles read-only unless a later phase explicitly allows mutation.
- Keep `nativeHandles()` available while adding `nativeHandleView()` for the
  explicit borrowed/read-only contract.

## Validation

- Tests should ensure native handle APIs are explicit and backend-tagged.
- Docs should warn that native handles are not portable.
- Unit tests should assert borrowed lifetime and no mutation permission by
  default.
