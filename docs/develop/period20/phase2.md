# Phase 2: Raster And Depth-Bias Backend State

Phase 2 lowers remaining common raster state that already exists in the public
pipeline descriptor.

## Scope

- Lower `TriangleFillMode.lines` / wireframe where the backend supports it.
- Lower pipeline `DepthBiasDescriptor` instead of only dynamic depth-bias
  commands.
- Keep conservative rasterization behind feature gates until both backend
  mappings are explicit.

## Status

Completed.

## Backend Notes

- Vulkan enables `fillModeNonSolid` when the native device exposes it, maps
  `TriangleFillMode.lines` to `VK_POLYGON_MODE_LINE`, and applies pipeline
  depth-bias values on bind so later dynamic depth-bias calls can override them.
- Metal maps `TriangleFillMode.lines` to `MTLTriangleFillModeLines` on encoder
  bind and applies pipeline depth-bias values through the existing encoder
  command.
- Conservative rasterization remains unsupported unless a future backend pass
  adds explicit native mappings.

## Validation

- Add focused descriptor tests for feature gates.
- Keep at least one render example building with default fill mode.
- Add backend mapping notes for unsupported conservative rasterization.
