# Phase 2: Sparse And Tiled Textures

Phase 2 lowers virtualized texture residency.

## Scope

- Lower Vulkan sparse texture residency.
- Lower Metal sparse/tiled texture behavior where supported.
- Handle mip tails, array layers, and format restrictions.

## Validation

- Add residency map tests.
- Add streaming texture smoke coverage where possible.

## Result

- Added `SparseTextureLoweringMode` and `SparseTextureLowering` to describe
  Vulkan sparse-image, Metal sparse-texture, and Metal tiled-texture planning.
- Added `SparseTextureDescriptor.pageGrid()` so texture residency planning can
  compute edge pages with ceil division.
- Added `Device.planSparseTextureLowering(...)`, which uses native feature
  reports while keeping ordinary sparse/tiled texture validation tied to usable
  public features.
- Added focused tests for page-grid planning and native-feature planning when
  the public usable gate is still closed.

## Deferred

- Creating sparse/tiled texture runtime objects and binding native texture
  pages remains deferred to Period 29 Phase 5.
