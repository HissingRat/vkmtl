# Period 55 Phase 1: Contract And API Allocation

Status: complete.

## Color Contract

Ray-generation shaders write numeric floating-point values to a caller-owned
`rgba16_float` accumulation texture. Dispatch does not assign those values a
color space or perform an implicit color conversion. The example's reference
display composition applies, in order:

1. sanitizing non-finite values and clamping the historical display-referred
   RGB to `[0, 1]`;
2. the standard sRGB EOTF, producing display-linear RGB;
3. the matching sRGB OETF in the final color attachment.

The shared pass performs no photographic or filmic remapping, generic gamma
power, or second OETF. The final attachment conversion therefore restores the
example's historical reference bytes. Scalar samples
`0.0/0.18/0.5/0.8/1.0` map to `0/46/128/204/255`.

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
