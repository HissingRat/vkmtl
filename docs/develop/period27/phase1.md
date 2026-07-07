# Phase 1: Sparse And Tiled Buffers

Phase 1 starts advanced residency with buffers.

## Scope

- Lower sparse buffer descriptors to Vulkan where supported.
- Map Metal-compatible buffer residency behavior where available.
- Validate alignment, page size, and usage.

## Validation

- Add descriptor tests for alignment and residency errors.
- Document unsupported backend behavior.
