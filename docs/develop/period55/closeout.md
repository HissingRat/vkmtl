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
- `ray_traced_scene` uses a capability-gated `rgba16_float` linear target and a
  shared exposure-1 ACES-fitted fullscreen pass to `bgra8_unorm_srgb`.

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

Ray generation produces scene-linear color. Presentation multiplies by fixed
exposure `1.0`, applies the documented ACES-fitted curve, clamps to display
linear, and relies on the final sRGB attachment for the only transfer encode.
The deterministic sRGB byte references for scene-linear
`0.0/0.18/0.5/1.0` are `0/141/206/232`.

## Evidence

- Focused runtime tests cover the valid resource contract, usage, shape, queue
  ownership, depth, dispatch extent, whole-texture subresource restriction,
  and single-encoding-segment rule. Command validation additionally owns the
  sample-count and storage-write-to-sampled postconditions.
- Vulkan dispatch descriptor sets and inline data are per-dispatch resources
  retained by the command buffer through synchronous completion.
- CPU tests lock the display transform, non-finite handling, and reference
  bytes.
- Finite-run tests prevent invalid limits, early-close false positives, and
  unbounded zero-sized-framebuffer waits.
- Metal API Validation completed a three-frame finite
  `run-ray-traced-scene` execution.
- Vulkan has implementation, unit, shader-artifact, and forced-build evidence.
  A physical run of the new color-managed path remains pending on a Vulkan RT
  machine and is not inferred from earlier Vulkan RT output.

The legacy drawable route is retained only for compatibility. New rendering,
offscreen, and future headless composition should use texture dispatch.
