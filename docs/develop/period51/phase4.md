# Period 51 Phase 4: Advanced Raster Decisions

Status: complete; all six families precisely unsupported.

## Required Decisions

- `MTL-REN-004`: compare Metal rasterization-rate coordinate transforms with
  Vulkan fragment shading-rate attachment semantics.
- `MTL-REN-013`: require an exact tile/imageblock memory and shader-stage
  contract before opening support.
- `MTL-REN-014`: require ordered per-pixel storage and shader-defined blend
  semantics rather than ordinary fixed-function blending.
- `MTL-REN-015`: distinguish shader layer routing, multiview, and vertex/view
  amplification.
- `MTL-REN-016`: require explicit logical-to-physical output mapping rather
  than silently rewriting attachment indices.
- `MTL-REN-020`: split depth clip, programmable sample positions, conservative
  rasterization, and other dynamic controls into independently gated rows.

## Rule

A native query or similar-looking extension is not executable support. Every
opened subset needs a public contract, native lowering on each claimed
backend, feature/limit gates, and command evidence. Remaining subsets close
with precise unsupported reasons in the semantic inventory.

## Decisions

- Variable rasterization-rate maps stay unsupported: Vulkan fragment-shading
  rate attachments do not provide Metal's public physical/logical coordinate
  transform contract.
- Tile shaders/imageblocks stay unsupported: subpasses, input attachments, and
  compute passes do not establish tile-local lifetime and imageblock layout.
- Raster-order groups/programmed blend stay unsupported: fixed-function blend,
  fragment interlock, and input attachments do not by themselves define the
  required ordered shader storage contract.
- Layered rendering/view amplification stays unsupported: shader layer output,
  multiview, and amplification have distinct invocation and view-selection
  behavior and no portable descriptor currently selects one.
- Logical attachment remapping stays unsupported: vkmtl has no explicit
  logical-to-physical output map, and silently rewriting shader locations is
  not exact.
- Depth clip control, programmable sample positions, and related advanced
  dynamic state stay unsupported as independent semantics. Existing depth
  bias and ordinary multisample counts do not stand in for them.

Focused compile-time tests keep the corresponding `DeviceFeatures` names
absent, preventing a native query from becoming an accidental usable claim.
