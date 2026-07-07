# Phase 6: Sparse Validation Coverage

Phase 6 hardens sparse-resource validation.

## Scope

- Validate page alignment, residency state, and usage flags.
- Validate out-of-bounds sparse mapping descriptors.
- Validate non-resident access metadata where vkmtl can detect it.
- Validate missing uncommit, empty commit, and independent mip-level residency.

## Validation

- Add unit tests for invalid mappings.
- Add backend smoke tests for commit/uncommit sequences where supported.
- Backend smoke tests remain capability-gated until native sparse/tiled lowering
  is enabled.
