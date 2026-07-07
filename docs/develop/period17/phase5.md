# Phase 5: Basic Ray Traced Triangle Example

Phase 5 proves the ray tracing module with the smallest visible example.

## Scope

- Add `examples/ray_traced_triangle`.
- Build one acceleration structure.
- Dispatch one ray generation shader and present the result.
- Print a clear unsupported-feature message on unsupported devices.
- Current example validates AS metadata, ray tracing pipeline groups, and SBT
  layout. Visible ray dispatch waits for backend-native lowering.

## Validation

- The example should use public vkmtl APIs.
- At least one backend path should run before the phase is considered complete.
- The example should compile with the normal build and stay feature-gated at
  runtime.
