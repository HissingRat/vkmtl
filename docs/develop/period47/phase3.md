# Phase 3: Render Breadth

Status: complete.

## Implemented Contract

- Runtime validation, debug state, usage tracking, ownership, extent, sample
  count, resolve, and backend lowering now consume every MRT color attachment.
- Texture-backed color and depth/stencil attachments lower load/store/clear
  actions on both backends. Combined depth/stencil is supported when both
  descriptors reference the same depth-stencil view.
- Current-drawable passes retain their exact prebuilt defaults; non-default
  load/store requests return `UnsupportedRenderPassAttachmentAction`.
- Depth/stencil resolve, separate stencil-only views, and current-drawable
  stencil remain typed unsupported and stay outside the portable promise.
- Existing render buffer/bind-group/root-constant paths and pipeline/dynamic
  raster state have complete backend mappings and focused validation coverage.

## Scope

- Validate every color attachment in MRT passes, including same-device
  ownership, extent, sample count, resolve target, format capability, load, and
  store behavior.
- Ensure runtime debug/usage tracking observes all attachments rather than only
  attachment zero.
- Close ordinary render binding through existing vertex/index buffers, bind
  groups, resource tables when usable, and root constants.
- Close viewport, scissor, winding/cull/fill, depth bias, blend color, stencil
  reference, and the pipeline states already exposed by vkmtl.
- Implement depth/stencil attachment resolve only where the public result is
  exact; retain the existing typed unsupported errors otherwise.

Heaps, function tables, sample-position programming, depth-clip variants,
layered/tile state, and other advanced raster semantics remain routed to later
periods.
