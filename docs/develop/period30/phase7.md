# Phase 7: Backend-Private Native Advanced Examples

Phase 7 updates examples so they prove the backend-private runtime records added
through Period 30.

Status: completed for backend-private runtime verification in
`examples/ray_traced_scene`. Pixel-producing first-triangle work is split:
Metal is deferred to Period31, Vulkan is deferred to Period32, and broader
examples remain Period32+ driver/example work.

## Scope

- Turn `examples/ray_traced_scene` into a sample that checks
  acceleration-structure, ray tracing pipeline, SBT, dispatch, and Metal mapping
  backend-private runtime records.
- Add sparse/tiled, tessellation, mesh/task, or native interop examples only
  when they prove real backend execution.
- Keep unsupported adapters reporting clear feature-gate messages.

## Validation

- Examples build by default.
- Native runtime-record examples run on supported local or CI hosts.

## Deferred

- Pixel-producing Metal ray traced scene execution is deferred to Period31.
- Pixel-producing Vulkan ray traced scene execution is deferred to Period32.
- Broader driver-executed native advanced examples are deferred to Period32+.
