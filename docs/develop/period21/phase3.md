# Phase 3: Descriptor Indexing And Argument Buffers

Phase 3 lowers the advanced binding model.

## Scope

- Map vkmtl descriptor indexing ranges to Vulkan descriptor indexing.
- Map the same public model to Metal argument buffers.
- Define update frequency, residency, and bounds behavior.
- Keep the portable first-slice bind-group path unchanged.

## Validation

- Add backend capability checks.
- Add bindless texture or material-table example coverage.

## Result

- `AdvancedBindGroupLayout` exposes total descriptor count, per-resource descriptor count, partially-bound usage, and update-after-bind usage.
- Vulkan descriptor-indexing metadata and Metal argument-buffer metadata are created behind the backend boundary.
- Capability gates still control whether descriptor indexing or argument buffers can be requested.
- Bindless resource table allocation, resource updates, and command binding remain deferred to the next advanced-binding slice.
