# Period 55: Color-Managed Ray-Tracing Presentation

Status: complete.

Goal: make ray-traced scene color mean the same thing on Metal and Vulkan.
Native ray dispatch produces a caller-owned linear texture. A normal public
render pass applies the documented display transform and writes linear values
to an sRGB drawable, so the attachment performs exactly one sRGB encode.

## Phase Plan

### Phase 1: Contract And API Allocation

- Add `ray_tracing.RayTracingTextureResources` as the canonical resource name.
- Add `CommandBuffer.dispatchRaysToTexture(...)` as an additive command.
- Preserve the existing drawable resource name and supported presentation
  behavior; reject unsafe extra encoding segments with the existing typed
  state error.
- Gate the intermediate texture through selected-device format capabilities.

See `phase1.md`.

### Phase 2: Native Texture Dispatch

- Pass the caller's Metal texture view into the native RT compute encoder.
- End Vulkan RT output in shader-read layout with an RT-stage source barrier.
- Reject invalid usage, shape, backend, and dispatch extents before encoding.

See `phase2.md`.

### Phase 3: Shared Display Transform

- Use a manifest-backed fullscreen Slang shader on both backends.
- Store scene-linear HDR in `rgba16_float`.
- Apply fixed exposure and an ACES-fitted tone map.
- Return display-linear color to a `bgra8_unorm_srgb` attachment without a
  shader-side gamma transform.

See `phase3.md`.

### Phase 4: Evidence And Closeout

- Add deterministic color and resource-validation regressions.
- Update public and native semantic inventories plus user-facing docs.
- Run the full API/backend/package gates and physical Metal validation.

See `phase4.md` and `closeout.md`.

## Outcome

Both backend lowerings now write the caller's texture and the example presents
that texture through the same public render pipeline. Metal API Validation
completed a finite three-frame run. Vulkan has implementation, unit, and
forced-build evidence for the new path; its physical RT-machine color rerun is
still explicit follow-up evidence rather than an inferred pass.

## Compatibility

The new resource alias and command method are additive and target `v0.2.0`.
No root declaration, `Device`, `WindowContext`, `HeadlessContext`, runtime
handle layout, existing field, enum tag, default, or existing method is removed
or renamed. `dispatchRaysToDrawable(...)` remains available for existing
callers; new code should prefer the composable texture command.
