# Phase 4: Small Constants And Root Constants

Phase 4 makes low-latency constants available without creating tiny buffers.

## Scope

- Lower small constants to Vulkan push constants where supported.
- Lower root-constant-style values to Metal-compatible constant buffers or
  command encoder constants.
- Validate size, alignment, stage visibility, and pipeline layout compatibility.

## Validation

- Add tests for size/alignment limits.
- Add one render or compute example using constants.
