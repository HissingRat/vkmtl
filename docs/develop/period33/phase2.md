# Phase 2: Public RT Mesh Geometry API

Phase 2 adds the public runtime shape needed to build acceleration structures
from user-provided mesh buffers.

## Checklist

- [x] Add or extend RT geometry descriptors for vertex/index buffers.
- [x] Define vertex format, stride, index type, range, and primitive count.
- [ ] Define optional geometry/material identifiers without leaking backend
  native types.
- [x] Validate buffer ownership, usage flags, ranges, and lifetime.
- [x] Keep backend-private acceleration structure handles hidden from ordinary
  public API.
- [x] Add focused validation tests for invalid ranges and missing usage flags.

## Acceptance

- User code can describe mesh geometry for BLAS builds through public vkmtl
  descriptors.
- Vulkan and Metal backends receive the same logical mesh geometry contract.
- Existing triangle smoke paths still build while the new API lands.
