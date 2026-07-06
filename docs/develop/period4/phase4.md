# Phase 4: Bind Group Layout Completeness

Phase 4 extends layout descriptors for advanced binding metadata.

## First Slice

- Add `BindGroupLayoutEntry.array_count`.
- Add `BindGroupLayoutEntry.dynamic_offset`.
- Add `BindingResourceKind.compare_sampler` and matching bind group resource
  descriptors.
- Validate array count, dynamic-offset resource kinds, duplicate bindings, and
  storage-texture visibility in the shared descriptor layer.
- Keep unsupported backend lowering behind explicit runtime errors until the
  matching backend work lands.

## Current Limits

- Runtime native lowering supports only `array_count = 1`.
- Runtime native lowering rejects `dynamic_offset = true` with
  `UnsupportedDynamicBinding`; Phase 5 adds the public dynamic-offset list shape
  before backend dynamic descriptor lowering.
- Compare samplers lower through the same backend sampler path as regular
  samplers; compare behavior is still controlled by sampler descriptor feature
  gates.
