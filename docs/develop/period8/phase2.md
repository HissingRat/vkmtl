# Phase 2: Bind Group Layout Cache

Phase 2 defines bind group layout object-cache identity.

## First Slice

- Add a bind group layout cache-key descriptor.
- Include binding number, resource type, visibility, dynamic offset, array
  count, and storage access.
- Reuse existing bind group layout validation.

## Current Limits

- `BindGroupLayoutCacheKeyDescriptor` is label-free and can be converted back
  to a `BindGroupLayoutDescriptor` for validation.
- Native descriptor-set layout / argument metadata reuse is future backend work.
