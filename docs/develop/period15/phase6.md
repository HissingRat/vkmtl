# Phase 6: Sparse Validation Coverage

Phase 6 hardens sparse-resource validation.

## Scope

- Validate page alignment, residency state, and usage flags.
- Validate out-of-bounds sparse mapping descriptors.
- Validate non-resident access metadata where vkmtl can detect it.

## Validation

- Add unit tests for invalid mappings.
- Add backend smoke tests for commit/uncommit sequences where supported.
