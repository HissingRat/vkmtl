# Phase 3: Render Breadth

Status: planned.

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
