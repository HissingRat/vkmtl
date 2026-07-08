# Phase 3: Native SBT And Ray Dispatch Commands

Status: completed for the public runtime contract.

Phase 3 makes ray dispatch executable.

## Scope

- Added `ShaderBindingTable` runtime objects owned by `Device`.
- Added `Device.makeShaderBindingTable(...)`, gated by native ray tracing
  feature reports.
- Added SBT group-count validation against `RayTracingPipelineState`.
- Added `CommandBuffer.dispatchRays(...)` as the public runtime ray dispatch
  command contract.
- Preserved `RayDispatchPlan` as the inspectable validation result for dispatch
  dimensions, total rays, and SBT size.

## Validation

- Runtime tests cover invalid SBT hit/miss/ray-generation ranges and
  successful dispatch planning.

## Deferred Native Work

- Vulkan shader-group-handle copy into SBT records and `cmdTraceRaysKHR`
  lowering are deferred to Period 30 Phase 3.
- Metal function-table dispatch resource binding and native ray dispatch are
  deferred to Period 30 Phase 3.
