# Phase 1: Native Acceleration Structure Handles

Phase 1 attaches `AccelerationStructure` runtime objects to backend-private
native acceleration-structure handles.

## Scope

- Create and destroy Vulkan `VkAccelerationStructureKHR` handles.
- Create and destroy Metal `MTLAccelerationStructure` handles.
- Lower `CommandBuffer.encodeAccelerationStructureBuild(...)` to native
  build/update commands.
- Query and use native scratch alignment and build-size properties when
  available.

## Validation

- Add backend tests for invalid scratch alignment and missing result resources.
- Keep unsupported adapters returning `UnsupportedAccelerationStructures`.
