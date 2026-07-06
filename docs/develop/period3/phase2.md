# Phase 2: Texture Shapes

Phase 2 makes texture shape classification explicit.

## First Slice

- Add helpers for 1D, 2D, 3D, array, cube, and multisample classification.
- Validate dimensional constraints before backend creation.
- Expose shape support through features and format capabilities.
- Keep cube and cube-array as 2D-array-compatible shapes until a dedicated view
  dimension is implemented.
- Implemented as `TextureDescriptor.shape()`, `isArray()`,
  `isCubeCompatible()`, `cubeCount()`, and `isMultisampled()`.

## Current Limits

- Cube textures are represented by 2D textures with six layers per cube.
- Cube-specific view dimensions are reserved for Phase 5 or later.
