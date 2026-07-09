# Phase 4: Ray Dispatch To Output Texture

Phase 4 turns the runtime ray dispatch command into a real Metal command path
for the example.

Status: completed for the first native Metal RT visible slice.

## Scope

- Create an output texture/view resource for the public dispatch contract.
- Bind the Metal acceleration structure and shader resources needed by the ray
  tracing workload.
- Encode the ray tracing dispatch on a Metal command buffer.
- Preserve `CommandBuffer.dispatchRaysToDrawable(...)` as the public visible
  dispatch path.

## Acceptance

- Dispatch writes deterministic non-clear pixels to the current drawable on
  supported Metal devices.
- The command path is feature gated and reports unsupported Metal ray tracing
  clearly.
- Runtime record diagnostics still reflect the dispatched ray count.
- The current visible slice reports rendered frame rays from the drawable
  extent and keeps backend-private dispatch diagnostics intact.

## Deferred

- Vulkan SBT buffer materialization and `vkCmdTraceRaysKHR` for the first
  triangle are Period32 work.
- Full miss/hit/callable shader table parity remains Period32+ work.
