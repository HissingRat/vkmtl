# Phase 1: Vulkan Capability Gate And Loader Contract

Phase 1 makes Vulkan ray tracing availability explicit before driver work starts.

## Scope

- Confirm required Vulkan extensions and feature structs for the triangle path.
- Update capability reports to distinguish Vulkan ray tracing support from
  backend-private runtime record support.
- Print actionable unsupported messages for missing loader, ICD, extension, or
  feature requirements.
- Keep `examples/ray_traced_scene` using public vkmtl APIs.

## Acceptance

- Supported Vulkan devices can pass the capability gate.
- Unsupported Vulkan runtimes identify the missing requirement.
- macOS Vulkan through MoltenVK may report unsupported if KHR ray tracing is not
  exposed.

## Result

Implemented.

- Confirmed the Period32 Vulkan ray tracing gate requires
  `VK_KHR_acceleration_structure`, `VK_KHR_ray_tracing_pipeline`,
  `VK_KHR_deferred_host_operations`, `VK_KHR_buffer_device_address`,
  `VK_KHR_spirv_1_4`, and `VK_KHR_shader_float_controls`.
- Added `RayTracingCapabilityDiagnostics` to public capability reports.
- Vulkan now checks required extension presence, feature bits, RT/SBT limits,
  and required device commands.
- `examples/ray_traced_scene` prints the first missing Vulkan ray tracing
  blocker before attempting backend-private runtime setup.
