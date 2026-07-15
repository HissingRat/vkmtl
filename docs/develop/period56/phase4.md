# Period 56 Phase 4: Legacy Ray Dispatch Compatibility

Status: complete.

## Compatibility-Only Drawable Method

`CommandBuffer.dispatchRaysToDrawable(...)` remains source-compatible and keeps
its presentation side effect, but it is not the canonical composition API.
Both backend implementations must use `resources.output` as the ray-generation
storage destination. Metal must no longer ignore that caller object and bind a
newly acquired drawable directly as shader output.

The combined legacy dispatch-and-present command is graphics-queue-only. A
compute or transfer queue returns `InvalidQueueCapability` before direct-command
state or native work is recorded.

After dispatch, the legacy method must copy the caller output into the current
drawable and present it. Presentation is therefore already recorded by this
command; a later explicit present on the same command buffer returns
`InvalidCommandBufferState`. The transfer itself is raw only:

- the source must have the required shader-write and copy-source usage;
- source and drawable must be single-sampled 2D images with a valid common
  copy region;
- the caller output format must be `bgra8_unorm`, whose byte layout is raw-copy
  compatible with either selected `bgra8_unorm` or `bgra8_unorm_srgb`;
- the transfer copies bytes unchanged and performs no sampling, filtering,
  transfer-function conversion, tone mapping, or gamut conversion.

An sRGB selected drawable is therefore valid for this compatibility copy. The
copy does not decode or encode sRGB; it preserves the caller's bytes and leaves
their interpretation to the selected presentation attachment.

An incompatible source fails with the typed presentation-format mismatch before
dispatch or drawable acquisition. The method must not substitute another
texture, format, shader, or conversion pass.

Metal additionally acquires the drawable, validates its selected format and
extent, and allocates the sRGB raw-copy staging buffer before creating the
compute encoder or dispatching rays. `NoDrawable`, drawable mismatch, and
staging-allocation failures therefore leave no partially encoded dispatch for
the portable runtime to account for. The linear drawable path allocates no
staging buffer, and every later error path releases an sRGB staging allocation.

## Canonical Texture Path

`CommandBuffer.dispatchRaysToTexture(...)` remains the canonical command for
new rendering, offscreen work, readback, headless execution, and explicit
presentation composition. Examples and user-facing docs must use the texture
path, then choose an application-owned render or transfer step whose pipeline
format exactly matches `Swapchain.selectedFormat()`.

The legacy method remains only so existing callers are not forced through an
incidental removal during backend maintenance. Runtime tests lock the caller
output usage, shape, extent, sample count, linear BGRA format, and compatibility
with either admitted selected drawable. The Metal bridge now receives that
caller texture, dispatches into it, and performs a byte-preserving blit; Vulkan
continues to dispatch into the caller image and copy it to the swapchain image.
The new physical Metal legacy-route probe and the Vulkan RT-machine rerun are
tracked in Phase 5 rather than inferred from unit or forced-build coverage.
`examples/ray_traced_scene` exposes the repeatable compatibility probe through
`VKMTL_RT_LEGACY_DRAWABLE=1`; its default route remains
`dispatchRaysToTexture(...)` plus the public fullscreen composition pass.
