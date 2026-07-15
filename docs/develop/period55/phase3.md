# Period 55 Phase 3: Shared Display Transform

Status: complete.

## Caller-Owned Accumulation Intermediate

`examples/ray_traced_scene` queries `getFormatCaps(.rgba16_float)` and proceeds
only when the selected device reports both sampled and storage support. It then
creates a private, single-sample texture with shader-read and shader-write usage
only. Ray generation writes caller-defined numeric values into that texture on
both backends; neither the format nor dispatch assigns those values a color
space. Callers that actually copy or read back the result add copy-source usage
and gate it separately.

The current drawable remains `bgra8_unorm_srgb`. The intermediate is recreated
when the framebuffer extent changes. Its bind group is destroyed before its
view, and the view before the texture, so resize never invalidates a live
borrow.

## Shared Reference Transform

The schema-2 render manifest owns `ray_traced_scene_present`, a Slang
fullscreen-triangle shader used by both backends. Its fragment stage:

1. sanitizes non-finite input and clamps the example's historical
   display-referred RGB to `[0, 1]`;
2. applies the standard sRGB EOTF to produce display-linear RGB.

The shader performs no photographic or filmic remapping, generic gamma power,
or sRGB OETF. The `bgra8_unorm_srgb` attachment applies the matching OETF and
therefore restores the historical display bytes. Scalar samples
`0.0/0.18/0.5/0.8/1.0` produce `0/46/128/204/255`.

## Public Presentation Path

Each frame uses one command buffer for texture RT dispatch and submission,
then a normal public render command buffer to sample the completed texture,
draw one fullscreen triangle, present the current drawable, and commit. Metal
no longer hides drawable acquisition inside the canonical texture dispatch,
and Vulkan uses the same display shader instead of a backend-specific color
conversion. The split also follows the current one-encoding-segment command
buffer contract; the synchronous first commit establishes the producer-to-
consumer lifetime boundary.
