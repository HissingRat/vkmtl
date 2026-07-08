# Phase 1: Native Acceleration Structure Builds

Status: completed for the public runtime contract.

Phase 1 turns acceleration-structure build plans into backend resources and
commands.

## Scope

- Added `AccelerationStructure` runtime objects owned by `Device`.
- Added `Device.makeAccelerationStructure(...)`, gated by native feature
  reports.
- Added `AccelerationStructureBuildResources` validation for result object,
  scratch buffer usage, scratch offset alignment, backend matching, update
  source state, and lifetime.
- Added `CommandBuffer.encodeAccelerationStructureBuild(...)` as the public
  runtime command contract. It records scratch usage and marks the result object
  built.

## Validation

- Runtime tests cover invalid scratch usage and successful build encoding.
- Unsupported adapters still return `UnsupportedAccelerationStructures`.

## Deferred Native Work

- Backend-private Vulkan `VkAccelerationStructureKHR` allocation/build command
  lowering and Metal `MTLAccelerationStructure` lowering are deferred to Period
  30 Phase 1.
