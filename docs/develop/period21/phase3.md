# Phase 3: Descriptor Indexing And Argument Buffers

Phase 3 records the advanced binding model in backend-aware layout metadata.
It deliberately does not create or bind resource tables yet; that executable
path belongs to Period 22.

## Scope

- Map vkmtl descriptor indexing ranges to Vulkan descriptor-indexing metadata.
- Map the same public model to Metal argument-buffer metadata.
- Define update frequency, residency, and bounds behavior.
- Keep the portable first-slice bind-group path unchanged.

## Validation

- Add backend capability checks.
- Keep bindless texture or material-table examples as capability/reporting
  smoke tests until Period 22 command binding lands.

## Result

- `AdvancedBindGroupLayout` exposes total descriptor count, per-resource descriptor count, partially-bound usage, and update-after-bind usage.
- Vulkan descriptor-indexing metadata and Metal argument-buffer metadata are created behind the backend boundary.
- Capability gates still control whether descriptor indexing or argument buffers can be requested.
- Bindless resource table allocation, resource updates, and command binding
  remain deferred to Period 22.
