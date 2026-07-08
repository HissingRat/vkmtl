# Phase 7: Native Advanced Examples

Status: completed for runtime-contract examples.

Phase 7 adds examples for executable advanced native paths.

## Scope

- Updated `examples/ray_traced_scene` from a planning-only sample to a public
  runtime-contract sample.
- The example now creates an `AccelerationStructure`, scratch buffer,
  `RayTracingPipelineState`, `ShaderBindingTable`, optional
  `MetalRayTracingExecutionMapping`, and records `CommandBuffer.dispatchRays`.
- Kept unsupported adapters reporting clear feature-gate messages.

## Validation

- Examples build by default.
- Runtime execution stays capability-gated.

## Deferred Native Work

- The example still does not render pixels. Backend-private native dispatch
  lowering and pixel-producing ray tracing examples are deferred to Period 30
  Phase 7 after native backend execution lands.
