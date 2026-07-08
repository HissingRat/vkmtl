# Phase 3: Native SBT Records And Dispatch

Phase 3 lowers `ShaderBindingTable` and `CommandBuffer.dispatchRays(...)` to
backend-private SBT record metadata and ray dispatch command records.

Status: completed for vkmtl-owned SBT record state and dispatch command
metadata. Direct Vulkan `cmdTraceRaysKHR` and equivalent Metal dispatch driver
calls are deferred to the concrete Period 31+ backend-driver parity plan.

## Scope

- Materialize backend-private SBT record metadata from the runtime descriptor.
- Track Vulkan device-address requirements in the backend-private record state.
- Record backend-private ray dispatch command metadata.

## Validation

- Add SBT record layout tests and dispatch command-record tests.
- Keep SBT range and stride validation deterministic.

## Deferred

- Copying Vulkan shader group handles into driver SBT buffers is deferred to
  Period 31+ driver parity work.
- Submitting Vulkan `cmdTraceRaysKHR` and Metal ray dispatch commands is
  deferred to Period 31+ driver parity work.
