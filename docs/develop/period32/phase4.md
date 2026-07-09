# Phase 4: Vulkan Ray Tracing Pipeline And SBT

Phase 4 creates the first real Vulkan ray tracing pipeline and shader binding
table.

Status: complete for the first-scene Vulkan path.

## Scope

- Create `VkRayTracingPipelineKHR` with the example shader groups.
- Query shader group handles.
- Allocate an SBT buffer with `VK_BUFFER_USAGE_SHADER_BINDING_TABLE_BIT_KHR`
  and device-address support.
- Materialize raygen, miss, and hit records with correct alignment and stride.

## Acceptance

- The Vulkan backend produces valid SBT device-address regions.
- Existing `ShaderBindingTable` diagnostics match the native SBT layout.
- Unsupported limits or alignment failures produce typed errors.

## Completed

- Added a Vulkan `ray_tracing_pipeline.zig` backend module.
- Created `VkRayTracingPipelineKHR` from raygen, miss, and closest-hit shader
  stages.
- Queried Vulkan shader group handles.
- Materialized a host-written SBT buffer with device-address allocation flags.
- Stored raygen, miss, hit, and callable SBT regions for command lowering.

## Deferred

- Large SBT stress tests and callable shader coverage are Period32+ work.
