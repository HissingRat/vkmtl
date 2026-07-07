# Phase 6: Render Backend Validation

Phase 6 closes Period 20 by making the completed render backend slices
observable and hard to regress.

## Scope

- Update the backend test matrix for blend, raster, stencil, and MRT support.
- Add focused validation tests for feature-gated render states.
- Add example coverage only where it proves a real backend path.
- Document remaining backend-specific render limits.

## Status

Completed.

## Backend Matrix

| Capability | Vulkan | Metal | Notes |
| --- | --- | --- | --- |
| Color blend state | Native | Native | Independent blend follows backend capability. |
| Color write masks | Native | Native | Applies per color attachment. |
| Depth bias | Native | Native | Pipeline bind applies descriptor values; dynamic setter can override. |
| Wireframe / line fill | Native when `fillModeNonSolid` is available | Native | Current capability query reports support truthfully. |
| Vertex instance step rate | Native with vertex attribute divisor | Native | Non-default rates are valid for per-instance buffers. |
| Combined depth/stencil | Native | Native | `depth32_float_stencil8` is the first portable stencil format. |
| Texture-backed MRT | Native | Native | Current-drawable render passes remain single-color. |

## Remaining Limits

- Conservative rasterization remains feature-gated and unsupported.
- Separate stencil-only render pass attachments remain unsupported.
- Current-drawable MRT is deferred until presentation semantics are designed.
- This phase did not add a new visual example; validation is covered by focused
  descriptor and backend compile tests plus `zig build`.

## Validation

- `zig build test`
- `zig build`
- Backend matrix notes updated for Vulkan and Metal.
