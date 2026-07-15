# Period 55 Phase 3: Shared Display Transform

Status: complete.

## Linear Intermediate

`examples/ray_traced_scene` queries `getFormatCaps(.rgba16_float)` and proceeds
only when the selected device reports both sampled and storage support. It then
creates a private, single-sample texture with shader-read and shader-write usage
only. Ray generation writes scene-linear HDR values into that texture on both
backends. Callers that actually copy or read back the result add copy-source
usage and gate it separately.

The current drawable remains `bgra8_unorm_srgb`. The intermediate is recreated
when the framebuffer extent changes. Its bind group is destroyed before its
view, and the view before the texture, so resize never invalidates a live
borrow.

## One Shared Transform

The schema-2 render manifest owns `ray_traced_scene_present`, a Slang
fullscreen-triangle shader used by both backends. Its fragment stage:

1. sanitizes non-finite input and clamps negative scene values to zero;
2. multiplies by fixed exposure `1.0` in linear space;
3. applies the ACES-fitted curve
   `(x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14)`;
4. clamps the display-linear result to `[0, 1]`.

The shader returns display-linear RGB. It does not apply a gamma power or sRGB
OETF. The `bgra8_unorm_srgb` attachment performs exactly one hardware sRGB
encode.

## Public Presentation Path

Each frame uses one command buffer for texture RT dispatch and submission,
then a normal public render command buffer to sample the completed texture,
draw one fullscreen triangle, present the current drawable, and commit. Metal
no longer hides drawable acquisition inside the canonical texture dispatch,
and Vulkan uses the same display shader instead of a backend-specific color
conversion. The split also follows the current one-encoding-segment command
buffer contract; the synchronous first commit establishes the producer-to-
consumer lifetime boundary.
