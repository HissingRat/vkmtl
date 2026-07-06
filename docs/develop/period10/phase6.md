# Phase 6: Ray Tracing Gated Module

Phase 6 defines ray tracing descriptor shapes without forcing ray tracing into
the portable render path.

## First Slice

- Add ray tracing feature gates.
- Add acceleration structure, ray tracing pipeline, and shader table
  descriptors.
- Validate shape and capability requirements.

## Current Limits

- `AccelerationStructureDescriptor`, `RayTracingPipelineDescriptor`, and
  `ShaderBindingTableDescriptor` validate ray tracing shape.
- `DeviceFeatures.acceleration_structures` and `DeviceFeatures.ray_tracing`
  default to false.
- Vulkan and Metal ray tracing differ substantially; lowering remains isolated
  future backend work.
