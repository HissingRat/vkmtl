# Phase 2: Native Ray Tracing Pipelines

Status: completed for the public runtime contract.

Phase 2 turns ray tracing pipeline plans into executable backend pipelines.

## Scope

- Added `RayTracingPipelineState` runtime objects owned by `Device`.
- Added `Device.makeRayTracingPipelineState(...)`, gated by native ray tracing
  feature reports.
- Preserved shader-group metadata and backend lowering metadata in the runtime
  object so later native backend lowering has stable inputs.
- Kept portable `Device.validateRayTracingPipelineDescriptor(...)` gated by
  usable features while native pipeline-state creation uses native feature
  reports.

## Validation

- Runtime tests cover typed unsupported portable validation and successful
  native-gated pipeline-state creation.

## Deferred Native Work

- Vulkan `VkPipeline` creation with ray-generation, miss, hit, and callable
  shader groups is deferred to Period 30 Phase 2.
- Metal executable ray tracing pipeline/function-table backend handles are
  deferred to Period 30 Phase 2.
