# Phase 1: Dynamic Buffer Offsets

Phase 1 makes dynamic buffer offsets a real command-encoding feature.

## Scope

- Preserve `BindGroupLayoutEntry.dynamic_offset` as the public declaration.
- Add dynamic-offset lists to render and compute `setBindGroup(...)` calls.
- Lower offsets to Vulkan dynamic descriptor offsets.
- Lower offsets to Metal buffer offsets.
- Validate count, alignment, and buffer binding class before backend calls.

## Validation

- Add tests for missing, extra, unaligned, and valid dynamic offsets.
- Keep non-buffer dynamic offsets rejected.

## Result

- `BindGroupBinding.dynamic_offsets` carries per-bind dynamic buffer offsets.
- Runtime validation rejects missing, extra, misaligned, and out-of-range dynamic offsets before backend calls.
- Vulkan uses dynamic buffer descriptor types and passes dynamic offsets to `cmdBindDescriptorSets`.
- Metal adds dynamic offsets to buffer base offsets when binding render or compute resources.
