# Phase 3: Metal Ray Tracing Shader Path

Phase 3 adds the first shader path that can produce ray traced pixels for the
Metal example.

Status: completed for the current visual acceptance slice.

## Scope

- Add embedded shader source for `examples/ray_traced_scene`.
- Prefer Slang as the source path, consistent with vkmtl shader direction.
- Verify whether the pinned Slang toolchain can emit the required Metal ray
  tracing constructs.
- Keep shader diagnostics visible when compilation fails.

## Acceptance

- The example has a concrete shader artifact path for the ray tracing workload.
- Build/runtime errors name the shader entry point and backend.
- The shader computes a sphere-room ray traced scene per pixel and returns the
  visible color through the public render path.

## Contingency

The current shader does not use native Metal ray tracing constructs. It is a
Slang fragment shader that performs scene intersection, shadows, reflection, and
refraction directly so the example can prove visible ray traced pixels before
the native driver bridge lands.
