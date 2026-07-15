# Period 55: Explicit Ray-Tracing Texture Presentation

Status: complete.

Goal: separate native ray dispatch from presentation without assigning a color
space to caller-owned output. Native ray dispatch produces a caller-owned
`rgba16_float` accumulation texture. The example's normal public render pass
clamps its historical display-referred RGB, applies the sRGB EOTF, and writes
display-linear values to an sRGB drawable; the attachment OETF restores the
reference bytes.

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
- Keep `rgba16_float` as a caller-owned accumulation texture with no implicit
  color-space conversion in dispatch.
- Clamp the example's historical display-referred RGB and apply the sRGB EOTF.
- Return display-linear color to a `bgra8_unorm_srgb` attachment so its OETF
  reproduces the reference bytes.

See `phase3.md`.

### Phase 4: Evidence And Closeout

- Add deterministic color and resource-validation regressions.
- Update public and native semantic inventories plus user-facing docs.
- Run the full API/backend/package gates and physical Metal validation.

See `phase4.md` and `closeout.md`.

## Outcome

Both backend lowerings now write the caller's texture and the example presents
that texture through the same public render pipeline. The scalar golden
mapping is `0.0/0.18/0.5/0.8/1.0 -> 0/46/128/204/255`. Metal API Validation
completed a finite three-frame run for the command architecture. The Metal
pixel-regression lane also rendered the shared pass into an offscreen sRGB
attachment and read back black, `0.18`, `0.5`, yellow, and blue with a maximum
one-byte channel delta. Vulkan has implementation, unit, and forced-build
evidence for the new path; its physical RT-machine presentation rerun is still
explicit follow-up evidence rather than an inferred pass.

## Compatibility

The new resource alias and command method are additive and target `v0.2.0`.
No root declaration, `Device`, `WindowContext`, `HeadlessContext`, runtime
handle layout, existing field, enum tag, default, or existing method is removed
or renamed. `dispatchRaysToDrawable(...)` remains available for existing
callers; new code should prefer the composable texture command.
