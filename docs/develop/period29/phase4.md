# Phase 4: Native Metal Ray Tracing Execution Mapping

Status: completed for the public runtime contract.

Phase 4 connects the Metal-specific ray tracing plan to native execution.

## Scope

- Added `MetalRayTracingExecutionMapping` runtime objects owned by `Device`.
- Added `Device.makeMetalRayTracingExecutionMapping(...)`, gated by the Metal
  backend and native ray tracing feature reports.
- Preserved Metal function-table entry counts, intersection-function counts,
  and intersection-function-table requirements in the runtime object.
- Kept Metal-specific execution metadata outside the portable
  `RayTracingPipelineState`.

## Validation

- Runtime tests cover Metal mapping creation and Vulkan typed unsupported
  behavior.

## Deferred Native Work

- Metal `MTLAccelerationStructure`, intersection function table, visible
  function table, and command encoding integration are deferred to Period 30
  Phase 4.
