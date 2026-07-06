# Phase 7: Heaps / Memory Advanced

Phase 7 defines the advanced heap boundary without making default users manage
memory manually.

## First Slice

- Add heap feature gates and descriptor shapes.
- Document that default resource creation still owns memory internally.
- Keep heap allocation optional and advanced.
- Keep native heap handles out of default resource descriptors.
- Implemented as `DeviceFeatures.heaps`, `HeapStorageMode`,
  `HeapDescriptor`, and `HeapError`.

## Current Limits

- Vulkan memory heaps and Metal heaps are not allocated through public vkmtl
  yet.
- Explicit heap allocation should land as a separate backend-gated utility
  module.
