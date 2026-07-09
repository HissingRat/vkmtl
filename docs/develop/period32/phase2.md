# Phase 2: Vulkan Acceleration Structure Build

Phase 2 creates and builds the first real Vulkan acceleration structure.

## Scope

- Allocate triangle geometry buffers with device-address support.
- Allocate acceleration-structure storage buffers.
- Create `VkAccelerationStructureKHR`.
- Build a bottom-level acceleration structure for one triangle.
- Keep native handles backend-private.

## Acceptance

- The Vulkan backend can build a BLAS for the example triangle.
- Invalid scratch/result resources still fail through typed validation.
- Driver handles are destroyed safely with the owning runtime object.

## Result

Implemented.

- Added a backend-private Vulkan acceleration structure object.
- Vulkan now queries build sizes through `vkGetAccelerationStructureBuildSizesKHR`.
- The backend allocates private acceleration-structure storage and an internal
  host-visible triangle geometry buffer with device-address usage.
- `CommandBuffer.encodeAccelerationStructureBuild(...)` records
  `vkCmdBuildAccelerationStructuresKHR` on the Vulkan command buffer for the
  first-scene BLAS path.
- `examples/ray_traced_scene` now reports whether the acceleration-structure
  build reached the driver path through `as_driver_submitted`.

## Deferred

- TLAS and multi-instance scene layouts are Period32+ work unless required for
  the first triangle implementation.
- Compaction, update, and refit are Period32+ work.
