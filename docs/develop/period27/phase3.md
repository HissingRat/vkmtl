# Phase 3: Residency And Page Commit API

Phase 3 makes sparse/tiled updates explicit.

## Scope

- Add page commit/update descriptors.
- Track committed regions for diagnostics.
- Validate unmap/remap rules.
- Integrate residency with resource lifetime.
- Connect runtime `Heap` reservations to native Vulkan `VkDeviceMemory`
  suballocation and Metal `MTLHeap`-backed resource creation where supported.

## Validation

- Add tests for overlapping, missing, and invalid page commits.
- Document backend page-size differences.

## Result

- Added `SparseMappingCommitPlan` to summarize commit batches before native page
  binding.
- Extended `SparseResidencyDiagnostics` with resident buffer bytes and resident
  texture pages.
- Added `SparseTextureMappingDescriptor.pageCount()` and
  `SparseMappingCommitDescriptor.plan(...)`.
- Added `Device.planSparseMappingCommit(...)`, which uses native feature
  reports while keeping ordinary public validation capability-gated.
- Added tests for overlap rejection, missing eviction rejection, commit/evict
  planning, and resident byte/page diagnostics.

## Deferred

- Native sparse page binding and native Vulkan `VkDeviceMemory` / Metal
  `MTLHeap` resource integration remain deferred to Period 28 Phase 5.
