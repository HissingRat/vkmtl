# Phase 6: Lighting And Visibility Polish

Status: complete.

Phase 6 improves visual readability without turning the example into an
engine.

## Implemented Scope

- Per-face normals from the mesher feed ambient plus directional lighting in
  the Slang fragment stage.
- The generated atlas gives the three opaque material classes distinct base
  colors and light texture variation.
- The render pipeline uses back-face culling, a `depth32_float` attachment,
  `less_equal` comparison, and depth writes.
- Transparent blocks and sorting remain out of scope. The reference block set
  is intentionally opaque, so no partial transparency rule is hidden behind
  backend-specific behavior.

## Evidence

- Face orientation produces visible directional contrast while the ambient
  term keeps unlit terrain readable.
- Smoke, default, and stress completed on physical Metal with Metal API
  Validation enabled and emitted the success marker.
- Meshing, camera math, atlas generation, world ownership, and metrics remain
  private example modules. No engine subsystem or public vkmtl declaration was
  added.
