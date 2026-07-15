# Period 55 Closeout

Status: complete.

## Executable Outcome

- `ray_tracing.RayTracingTextureResources` is the canonical exact alias for a
  dispatch resource bundle whose output is caller-owned.
- `CommandBuffer.dispatchRaysToTexture(...)` executes on Metal and Vulkan
  without presentation side effects and leaves the result ready for sampling.
- Direct RT/AS commands consume the command buffer's single native encoding
  segment; callers commit before starting the consumer command buffer.
- Metal binds the caller's output texture and does not acquire a drawable.
- Vulkan performs the RT write and ends in sampled-image layout for the public
  fragment consumer.
- `ray_traced_scene` uses a capability-gated, caller-owned `rgba16_float`
  accumulation texture and a shared fullscreen pass that clamps its historical
  display-referred RGB and applies the sRGB EOTF before
  `bgra8_unorm_srgb` performs the matching OETF.

## API And Compatibility

The `ray_tracing` facade grows from 54 to 55 declarations, and the actual
`CommandBuffer` surface grows from 21 to 22 methods. This also corrects the
inventory's stale 19-method count; only the texture-dispatch method is new in
Period 55. The top-level facade total grows from 534 to 535 declarations.
Root 69, `Device` 34,
`WindowContext` 10, `HeadlessContext` six, and the 37 runtime-handle names and
layouts do not change.

The alias and method are additive `v0.2.0` changes. The old
`RayTracingDrawableResources` name and `dispatchRaysToDrawable(...)` command
remain available with their existing legacy presentation behavior. No caller
is forced to migrate.

## Color Contract

Ray generation writes caller-defined numeric values to the accumulation
texture; dispatch does not assign them a color space. For the historical
`ray_traced_scene` output, presentation sanitizes and clamps display-referred
RGB, applies the standard sRGB EOTF, and relies on the final sRGB attachment's
matching OETF to restore the reference bytes. The deterministic scalar mapping
is `0.0/0.18/0.5/0.8/1.0 -> 0/46/128/204/255`.

## Evidence

- Focused runtime tests cover the valid resource contract, usage, shape, queue
  ownership, depth, dispatch extent, whole-texture subresource restriction,
  and single-encoding-segment rule. Command validation additionally owns the
  sample-count and storage-write-to-sampled postconditions.
- Vulkan dispatch descriptor sets and inline data are per-dispatch resources
  retained by the command buffer through synchronous completion.
- CPU tests lock the display transform, non-finite handling, and reference
  bytes.
- The Metal pixel-regression lane renders the shared transform to an offscreen
  `bgra8_unorm_srgb` attachment and reads back black, `0.18`, `0.5`, yellow,
  and blue with a maximum one-byte channel delta.
- Finite-run tests prevent invalid limits, early-close false positives, and
  unbounded zero-sized-framebuffer waits.
- Metal API Validation completed a three-frame finite
  `run-ray-traced-scene` execution, establishing command and architecture
  validity in addition to the separate byte-level display-pass regression.
- Vulkan has implementation, unit, shader-artifact, and forced-build evidence.
  A physical run of the new texture-presentation path remains pending on a
  Vulkan RT machine and is not inferred from earlier Vulkan RT output.

The legacy drawable route is retained only for compatibility. New rendering,
offscreen, and future headless composition should use texture dispatch.
