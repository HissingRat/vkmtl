# Phase 3: Metal Ray Tracing Shader Path

Phase 3 adds the first shader path that can produce ray traced pixels for the
Metal example.

## Scope

- Add embedded shader source for `examples/ray_traced_triangle`.
- Prefer Slang as the source path, consistent with vkmtl shader direction.
- Verify whether the pinned Slang toolchain can emit the required Metal ray
  tracing constructs.
- Keep shader diagnostics visible when compilation fails.

## Acceptance

- The example has a concrete shader artifact path for the ray tracing workload.
- Build/runtime errors name the shader entry point and backend.
- The shader can write a color result for the triangle path once dispatch lands.

## Contingency

If Slang cannot express or lower the required Metal ray tracing constructs yet,
this phase must document the exact blocker before adding a temporary
backend-private fallback. A fallback, if accepted later, must be isolated inside
the Metal backend and must not replace Slang as vkmtl's public shader language.

