# Phase 6: Tessellation And Mesh Examples

Phase 6 proves advanced geometry paths visually.

## Scope

- Add `examples/tessellation`.
- Add `examples/mesh_shader` or a combined advanced geometry example.
- Print clear unsupported-feature messages on devices without support.
- Current examples validate descriptors and backend lowering metadata; visible
  advanced-geometry rendering waits for native backend pipeline lowering.

## Validation

- Each example should use public vkmtl APIs.
- At least one backend path should run before the phase is considered complete.
- The examples should compile with the normal build and stay feature-gated at
  runtime.
