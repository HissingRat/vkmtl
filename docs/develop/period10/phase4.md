# Phase 4: Tessellation Gated

Phase 4 defines tessellation as an optional render pipeline extension.

## First Slice

- Add tessellation feature gates.
- Add tessellation descriptor shapes.
- Validate patch control points and shader stage requirements.

## Current Limits

- `TessellationDescriptor` validates control point count, domain/partition
  shape, and required stage presence.
- `DeviceFeatures.tessellation` defaults to false.
- Tessellation is not part of the base render path and is not lowered yet.
