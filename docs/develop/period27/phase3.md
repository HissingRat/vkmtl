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
