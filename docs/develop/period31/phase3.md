# Phase 3: Metal Ray Tracing Shader Path

Phase 3 adds the first shader path that can produce native Metal ray traced
pixels for the Metal example.

Status: completed for the current visual acceptance slice.

## Scope

- Add the backend-private Metal ray tracing kernel needed for the first native
  visible slice.
- Keep Slang as the project shader language for portable render, compute, and
  Vulkan ray tracing shaders.
- Document that the first Metal native RT kernel is bridge-private until the
  Slang-to-Metal ray tracing model is made portable.
- Keep shader diagnostics visible when compilation fails.

## Acceptance

- The example has a concrete native Metal shader path for the ray tracing
  workload.
- Build/runtime errors name the shader entry point and backend.
- The shader uses Metal ray tracing constructs and returns visible pixels
  through the native Metal dispatch path.

## Contingency

The current Metal native RT kernel is backend-private bridge source. It is not
the final portable Slang ray tracing shader model, which remains Period32+
parity work.
