# Phase 2: Limits And Core Resources

Status: in progress.

## Implemented Slice: Limits And Samplers

- `DeviceLimits` now reports maximum buffer length, texture dimensions, array
  layers, and the queried Metal threadgroup-memory limit. Vulkan uses core 1.3
  maintenance-4 properties for maximum buffer size and core physical-device
  properties for texture limits.
- Buffer and texture factories validate those limits before native creation.
- `SamplerDescriptor.normalized_coordinates` lowers to
  `VkSamplerCreateInfo.unnormalizedCoordinates` and
  `MTLSamplerDescriptor.normalizedCoordinates`. A shared portable constraint
  set rejects combinations that one of the backends cannot represent.
- Focused descriptor and native-capability mapping tests cover the new limits
  and validation.
- Texture views now admit only the documented RGBA8 and BGRA8 linear/sRGB
  compatibility classes. Metal enables pixel-format views and lowers native
  swizzle channels; Vulkan creates mutable images and lowers component mapping
  through `VkImageView`.
- The documented finite texture/vertex format set now has core byte/aspect
  rules, shader reflection names, direct Metal/Vulkan mappings, and explicit
  capability reporting. Formats outside that set remain closed.
- Buffer-address and final storage-mode audit work remain in this phase.

## Scope

- Query real ordinary resource/compute limits used by validation; keep native
  memory-budget and recommended-working-set telemetry separate.
- Expand common color, integer, floating-point, depth, and stencil texture
  formats plus vertex formats only when both backend mappings and capability
  queries are explicit.
- Permit texture-view reinterpretation only inside documented compatible
  classes and add identity/default component mapping with explicit swizzles.
- Complete sampler normalized-coordinate validation alongside the existing
  filter, address, LOD, compare, anisotropy, and border-color fields.
- Define exact shared, managed, private, and automatic storage behavior per
  backend. Do not expose raw Metal resource-option bits.
- Add buffer GPU address behind a raw native fact and a complete usable path.

## Common Format Set

The portable expansion is intentionally finite. Texture formats add `r8_unorm`,
`rg8_unorm`, `rgba8_uint`, `rgba8_sint`, `r16_float`, `rg16_float`,
`rgba16_float`, `r32_float`, `rg32_float`, `rgba32_float`, `r32_uint`,
`r32_sint`, `depth16_unorm`, and `stencil8`. Vertex formats add float16 x2/x4,
normalized 8-bit x2/x4, and signed/unsigned 32-bit scalar/x2/x3/x4 inputs.
Formats outside this set remain unallocated rather than being accepted through
an untyped native value.

## Backend Boundary

- Metal maps to pixel/vertex formats, texture views, sampler descriptors,
  resource storage modes, and `MTLBuffer.gpuAddress` where supported.
- Vulkan maps to format properties, `VkImageView` component mapping,
  `VkSampler`, memory property selection, and buffer device address feature and
  usage flags.
- Unsupported combinations fail validation before native object creation.
