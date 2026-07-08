# Phase 6: Resource Utility Validation

Phase 6 closes Period 24 with coverage and docs.

## Scope

- Update resource utility docs.
- Update backend matrix entries for mipmaps, fills, copies, border colors, and
  heap allocation.
- Add tests for fallback selection and typed errors.

## Validation

- `zig build test`
- `zig build`
- Backend matrix updated for Vulkan and Metal.

## Result

- `src/development_matrix.zig` records the Period 24 resource utility matrix
  and `resource_utility_regression` row.
- `docs/develop/backend-test-matrix.md` separates native, fallback, portable
  runtime, and deferred resource utility paths.
- Deferred items are assigned to:
  - Period 28 Phase 5 for native heap-backed resource creation.
  - Period 28 Phase 6 for partial mipmap ranges, depth/stencil and MSAA copy
    semantics, and custom sampler border colors.
