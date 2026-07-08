# Phase 1: Native Acceleration Structure Handles

Phase 1 attaches `AccelerationStructure` runtime objects to backend-private
native acceleration-structure handle state and records build command metadata
through the command buffer path.

Status: completed for vkmtl-owned backend-private handle state. First-triangle
driver object creation is split into Period 31 for Metal
`MTLAccelerationStructure` and Period 32 for Vulkan `VkAccelerationStructureKHR`.
Broader acceleration-structure parity remains Period 32+ work because the
public/runtime boundary now exists but the low-level driver calls need
backend-specific extension enablement and hardware validation.

## Scope

- Create and destroy vkmtl-owned backend-private acceleration-structure handle
  state.
- Lower `CommandBuffer.encodeAccelerationStructureBuild(...)` to backend-private
  build/update command records.
- Validate scratch offset alignment and result-resource compatibility.
- Preserve typed unsupported behavior when native acceleration structures are
  unavailable.

## Validation

- Add runtime tests for invalid scratch alignment and missing result resources.
- Keep unsupported adapters returning `UnsupportedAccelerationStructures`.

## Deferred

- Direct Metal `MTLAccelerationStructure` allocation and encoder submission for
  the first triangle are deferred to Period 31.
- Direct Vulkan `VkAccelerationStructureKHR` allocation and
  `vkCmdBuildAccelerationStructuresKHR` submission for the first triangle are
  deferred to Period 32.
- Compaction, update/refit, larger scenes, and broader AS semantics are
  deferred to concrete Period32+ phases.
