# Phase 4: Metal Mesh BLAS And TLAS

Phase 4 connects the public mesh geometry contract to Metal native ray tracing
builds.

## Checklist

- [x] Lower vertex/index-backed geometry to
  `MTLAccelerationStructureTriangleGeometryDescriptor`.
- [x] Replace the current backend-private built-in triangle buffer with
  user-provided buffers.
- [ ] Support multiple BLAS objects for the scene.
- [ ] Support a Metal TLAS or equivalent instance acceleration structure path
  for scene instances.
- [x] Keep Metal build sizes and scratch requirements queried from the driver.
- [ ] Add validation or example coverage for multiple instances.

## Acceptance

- Metal can build the room and tessellated sphere BLAS objects from public
  buffers.
- Metal can dispatch against the scene-level acceleration structure.
- The backend still keeps `MTLAccelerationStructure` handles private.
