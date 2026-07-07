# Phase 3: Vertex Instance Step Rate

Phase 3 finishes vertex-layout lowering for non-default instance stepping.

## Scope

- Lower `VertexBufferLayout.instance_step_rate` to Vulkan vertex input binding
  divisors where available.
- Lower `instance_step_rate` to Metal vertex descriptor step rate.
- Keep missing backend support behind precise feature gates.

## Validation

- Add validation coverage for step-rate feature gates.
- Add or update an instancing example once the native path is available.
