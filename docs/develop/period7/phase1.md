# Phase 1: Compute Dispatch Completeness

Phase 1 expands dispatch validation and keeps the existing compute backend path
intact.

## First Slice

- Validate dispatch grid and threadgroup dimensions against device limits.
- Add a descriptor that resolves total thread counts into threadgroup counts.
- Preserve `dispatchThreadgroups(...)` as the direct lowered path.

## Current Limits

- Backends still lower threadgroup dispatch directly.
- `DispatchThreadgroupsDescriptor.validateForLimits(...)` validates grid and
  threadgroup dimensions against `DeviceLimits`.
- `DispatchThreadsDescriptor` resolves total thread counts into threadgroup
  counts and then uses the same limit checks.
- Limit values are conservative until backend-native compute limits are queried.
