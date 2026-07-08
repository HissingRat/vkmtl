# Phase 4: Ray Dispatch To Output Texture

Phase 4 turns the runtime ray dispatch command into a real Metal command path
for the example.

## Scope

- Create an output texture suitable for ray tracing writes and later
  presentation.
- Bind the Metal acceleration structure and shader resources needed by the ray
  tracing workload.
- Encode the ray tracing dispatch on a Metal command buffer.
- Preserve `CommandBuffer.dispatchRays(...)` as the public intent API where
  practical.

## Acceptance

- Dispatch writes deterministic non-clear pixels into the output texture on
  supported Metal devices.
- The command path is feature gated and reports unsupported Metal ray tracing
  clearly.
- Runtime record diagnostics still reflect the dispatched ray count.

## Deferred

- Vulkan SBT buffer materialization and `vkCmdTraceRaysKHR` for the first
  triangle are Period32 work.
- Full miss/hit/callable shader table parity remains Period32+ work.
