# Phase 5: Compute Pipeline Cache

Phase 5 unifies compute pipeline cache identity with the Period 7 compute key.

## First Slice

- Keep `ComputePipelineCacheKeyDescriptor` as the public compute key.
- Include compute shader identity, entry point, bind group layouts, backend,
  compile profile, and specialization data.

## Current Limits

- `ComputePipelineCacheKeyDescriptor` keeps the Period 7 `bind_group_layouts`
  field for compatibility and adds `pipeline_layout` for the unified Period 8
  layout key.
- `validateForDevice(...)` should be used when the key includes small/root
  constant layout inputs.
- Native compute pipeline state reuse remains future runtime/backend work.
