# Phase 1: Sparse And Tiled Buffers

Phase 1 starts advanced residency with buffers.

## Scope

- Lower sparse buffer descriptors to Vulkan where supported.
- Map Metal-compatible buffer residency behavior where available.
- Validate alignment, page size, and usage.

## Validation

- Add descriptor tests for alignment and residency errors.
- Document unsupported backend behavior.

## Result

- Added `SparseBufferLoweringMode` and `SparseBufferLowering` to describe the
  native sparse-buffer mapping selected for Vulkan or Metal.
- Added `SparseBufferDescriptor.resolvedPageSize(...)` and `pageCount(...)` so
  page math is shared by validation and lowering plans.
- Added `Device.planSparseBufferLowering(...)`, which uses native feature
  reports while keeping ordinary `validateSparseBufferDescriptor(...)` tied to
  usable public features.
- Added tests for page count, alignment, and native-feature planning when the
  public usable gate is still closed.

## Deferred

- Creating sparse buffer runtime objects and binding native memory pages remains
  deferred to Period 28 Phase 5.
