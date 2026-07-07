# Phase 6: Ray Tracing Validation And Matrix

Phase 6 hardens ray tracing support.

## Scope

- Add validation cases for invalid acceleration structures, shader groups,
  recursion depth, and shader binding tables.
- Extend the backend test matrix with ray tracing expectations.
- Document optional support per backend and host.
- Keep smoke rows feature-gated because not every local backend exposes ray
  tracing.

## Validation

- `zig build test` should cover descriptor validation.
- Backend matrix notes should identify which devices were smoke-tested.
- Example smoke target: `zig build run-ray-traced-triangle`.
