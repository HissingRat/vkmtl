# Phase 2: Sparse And Tiled Textures

Phase 2 lowers virtualized texture residency.

## Scope

- Lower Vulkan sparse texture residency.
- Lower Metal sparse/tiled texture behavior where supported.
- Handle mip tails, array layers, and format restrictions.

## Validation

- Add residency map tests.
- Add streaming texture smoke coverage where possible.
