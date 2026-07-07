# Phase 2: Raster And Depth-Bias Backend State

Phase 2 lowers remaining common raster state that already exists in the public
pipeline descriptor.

## Scope

- Lower `TriangleFillMode.line` / wireframe where the backend supports it.
- Lower pipeline `DepthBiasDescriptor` instead of only dynamic depth-bias
  commands.
- Keep conservative rasterization behind feature gates until both backend
  mappings are explicit.

## Validation

- Add focused descriptor tests for feature gates.
- Keep at least one render example building with default fill mode.
- Add backend mapping notes for unsupported conservative rasterization.
