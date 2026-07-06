# Phase 3: Pipeline Layout Cache

Phase 3 defines pipeline layout cache identity.

## First Slice

- Add a pipeline layout cache-key descriptor.
- Include bind group layout list.
- Include small-constant and root-constant layout inputs.

## Current Limits

- `PipelineLayoutCacheKeyDescriptor` validates bind group layout keys,
  small-constant descriptors, and root-constant layout descriptors together.
- Empty pipeline layouts are valid cache keys.
- Native Vulkan pipeline layouts and Metal equivalent binding metadata are not
  reused across objects yet.
