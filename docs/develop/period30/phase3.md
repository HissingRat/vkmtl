# Phase 3: Native SBT Records And Dispatch

Phase 3 lowers `ShaderBindingTable` and `CommandBuffer.dispatchRays(...)` to
backend-private SBT record metadata and ray dispatch command records.

Status: completed for vkmtl-owned SBT record state and dispatch command
metadata. First-triangle Metal dispatch is deferred to Period 31,
first-triangle Vulkan `cmdTraceRaysKHR` is deferred to Period 32, and broader
dispatch parity remains Period 32+ work.

## Scope

- Materialize backend-private SBT record metadata from the runtime descriptor.
- Track Vulkan device-address requirements in the backend-private record state.
- Record backend-private ray dispatch command metadata.

## Validation

- Add SBT record layout tests and dispatch command-record tests.
- Keep SBT range and stride validation deterministic.

## Deferred

- Copying Vulkan shader group handles into driver SBT buffers for the first
  triangle is deferred to Period 32.
- Submitting the first Metal ray dispatch command is deferred to Period 31.
- Submitting the first Vulkan `cmdTraceRaysKHR` command is deferred to Period
  32.
- Full-scene mesh RT dispatch is deferred to Period33.
- Procedural RT dispatch is deferred to Period34.
- Larger SBT layouts and remaining broader dispatch semantics are deferred to
  later Period32+ phases.
