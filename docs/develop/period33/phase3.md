# Phase 3: Vulkan Mesh BLAS And TLAS

Phase 3 connects the public mesh geometry contract to Vulkan native ray tracing
builds.

## Checklist

- [x] Lower vertex/index-backed geometry to
  `VkAccelerationStructureGeometryKHR`.
- [x] Use user-provided buffers with valid device addresses.
- [ ] Support multiple BLAS objects for the scene.
- [ ] Support TLAS instances with transform, mask, instance id, and hit-group
  offset.
- [x] Keep Vulkan build sizes and scratch alignment queried from the driver.
- [ ] Add validation or example coverage for multiple instances.

## Acceptance

- Vulkan can build the room and tessellated sphere BLAS objects from public
  buffers.
- Vulkan can build a TLAS that references the scene BLAS objects.
- Unsupported Vulkan runtimes still report precise missing requirements.
