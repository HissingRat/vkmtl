# Phase 4: Atomics / Threadgroup Memory

Phase 4 documents and validates advanced compute shader requirements.

## First Slice

- Add descriptor shapes for compute atomic requirements.
- Add descriptor shapes for threadgroup/shared memory requirements.
- Gate those features behind device features and limits.

## Current Limits

- `ComputeAtomicDescriptor` declares storage-resource atomic requirements and
  is gated by `DeviceFeatures.compute_atomics`.
- `ThreadgroupMemoryDescriptor` declares shared/threadgroup memory requirements
  and is gated by `DeviceFeatures.compute_threadgroup_memory` plus
  `DeviceLimits.max_compute_threadgroup_memory_bytes`.
- Atomic and threadgroup-memory support is shader/backend dependent and not
  automatically inferred from Slang source yet.
