# Phase 3: Texture Atlas And Material Binding

Status: complete.

Phase 3 adds block materials through ordinary texture and bind-group APIs.

## Implemented Scope

- The example generates a deterministic `48 x 16` RGBA atlas at startup. Its
  three `16 x 16` tiles are green grass, brown dirt, and gray stone with a
  small deterministic per-pixel variation.
- Mesh UVs select the tile for each `BlockId` and use a half-texel inset to
  keep nearest sampling inside the intended tile.
- The atlas is an `rgba8_unorm_srgb` shader-readable texture populated through
  `replaceAll2D(...)`.
- One texture view and nearest-filter sampler are bound beside the camera
  uniform in a reflection-derived bind group.
- The Slang fragment stage samples the atlas normally. There is no
  backend-specific material path and no native handle escape.

## Evidence

- Grass, dirt, and stone occupy distinct atlas regions and remain visibly
  distinguishable after lighting.
- Metal API Validation initially caught a linear-layer versus sRGB-pipeline
  mismatch. The Metal layer now uses `bgra8_unorm_srgb`, and its presentation
  capability query reports that actual format.
- All three Metal API Validation profile runs completed without texture,
  sampler, shader-binding, or color-format diagnostics.
- Shader precompilation and the forced Vulkan build passed for the same Slang
  source and binding layout. Physical Vulkan sampling is not claimed.
