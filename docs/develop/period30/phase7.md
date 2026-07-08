# Phase 7: Pixel-Producing Native Advanced Examples

Phase 7 adds examples that prove native advanced backend execution.

## Scope

- Turn `examples/ray_traced_triangle` into a pixel-producing ray tracing sample
  on supported adapters.
- Add sparse/tiled, tessellation, mesh/task, or native interop examples only
  when they prove real backend execution.
- Keep unsupported adapters reporting clear feature-gate messages.

## Validation

- Examples build by default.
- Native examples run on supported local or CI hosts.
