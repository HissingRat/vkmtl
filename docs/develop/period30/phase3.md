# Phase 3: Native SBT Records And Dispatch

Phase 3 lowers `ShaderBindingTable` and `CommandBuffer.dispatchRays(...)` to
native SBT records and ray dispatch commands.

## Scope

- Copy Vulkan shader group handles into SBT records.
- Allocate or bind SBT buffers with device-address requirements.
- Lower dispatch to Vulkan `cmdTraceRaysKHR` and equivalent Metal dispatch
  paths.

## Validation

- Add SBT record layout tests and native dispatch smoke tests.
- Keep SBT range and stride validation deterministic.
