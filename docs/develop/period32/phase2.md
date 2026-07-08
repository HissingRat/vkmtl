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

## Deferred

- TLAS and multi-instance scene layouts are Period32+ work unless required for
  the first triangle implementation.
- Compaction, update, and refit are Period32+ work.

