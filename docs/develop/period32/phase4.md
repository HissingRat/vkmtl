# Phase 4: Vulkan Ray Tracing Pipeline And SBT

Phase 4 creates the first real Vulkan ray tracing pipeline and shader binding
table.

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

## Deferred

- Large SBT stress tests and callable shader coverage are Period32+ work.

