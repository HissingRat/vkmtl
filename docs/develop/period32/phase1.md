# Phase 1: Vulkan Capability Gate And Loader Contract

Phase 1 makes Vulkan ray tracing availability explicit before driver work starts.

## Scope

- Confirm required Vulkan extensions and feature structs for the triangle path.
- Update capability reports to distinguish Vulkan ray tracing support from
  backend-private runtime record support.
- Print actionable unsupported messages for missing loader, ICD, extension, or
  feature requirements.
- Keep `examples/ray_traced_triangle` using public vkmtl APIs.

## Acceptance

- Supported Vulkan devices can pass the capability gate.
- Unsupported Vulkan runtimes identify the missing requirement.
- macOS Vulkan through MoltenVK may report unsupported if KHR ray tracing is not
  exposed.

