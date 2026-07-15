# Period 55 Phase 1: Contract And API Allocation

Status: complete.

## Color Contract

Ray-generation shaders write scene-linear floating-point color to a
caller-owned texture. The portable display composition applies, in order:

1. exposure multiplication in linear space;
2. the documented ACES-fitted tone map per RGB channel;
3. clamping to the display-linear `[0, 1]` range;
4. one hardware sRGB encode by the final color attachment.

The display shader must not apply an sRGB OETF or a `1 / 2.2` power. Doing so
would double-encode Metal and Vulkan sRGB drawables. Negative and non-finite
scene values are sanitized before tone mapping.

## API Allocation

`ray_tracing.RayTracingTextureResources` is the canonical resource name for a
ray dispatch that consumes an acceleration structure and writes a texture
view. It preserves exact type identity with the existing
`RayTracingDrawableResources` name. The additive
`CommandBuffer.dispatchRaysToTexture(...)` method owns executable dispatch;
the caller independently chooses whether to sample, copy, read back, or present
the result.

The existing `dispatchRays(...)` cannot be repurposed because it has no
acceleration-structure or output-resource arguments. The existing
`dispatchRaysToDrawable(...)` cannot be changed into a texture-only command
because callers rely on its presentation behavior. Both remain intact.

## Capability And Validation Contract

The output view must be alive, owned by the selected backend, two-dimensional,
single-sampled, storage-writable, sample-readable, and at least as large as the
dispatch extent. Until Vulkan gains per-subresource native layout tracking, the
view must cover mip zero and array layer zero of a texture that has exactly one
mip and one layer. The texture command leaves the output ready for the
canonical sampling consumer; readback callers may additionally request
copy-source usage. The example uses `rgba16_float` only when the selected
device reports both storage and sampled support and requires
`bgra8_unorm_srgb` presentation support before it creates the display pipeline.
