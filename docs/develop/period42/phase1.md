# Phase 1: Format Capability Matrix

Status: complete.

## Decisions

- `FormatCapabilities` remains the backend-neutral query result returned by
  `Device.getFormatCaps(format)`.
- The matrix distinguishes exact copy, scaled blit, presentation, and color,
  depth, or stencil resolve support. Native support is not reported as usable
  until vkmtl has the corresponding execution path.
- Vulkan derives format features from optimal-tiling format properties and
  derives presentation from the selected surface format list.
- Metal uses an explicit table for the small portable format set. Presentation
  is limited to the `CAMetalLayer` pixel format used by vkmtl.
- New API names are exposed through the relevant `vkmtl.resource`,
  `vkmtl.transfer`, `vkmtl.render`, `vkmtl.command`, `vkmtl.sync`,
  `vkmtl.presentation`, and `vkmtl.diagnostics` facades; no new flat type alias
  is added.

## Acceptance

- Sampling, storage, attachment, blend, exact copy, blit, resolve, and
  presentation are independently reportable.
- Capability dump output is suitable for backend issue reports.
- Tests cover color, depth, depth-stencil, presentable, and unsupported formats.
