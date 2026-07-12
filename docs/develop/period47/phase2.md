# Phase 2: Limits And Core Resources

Status: planned.

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

## Backend Boundary

- Metal maps to pixel/vertex formats, texture views, sampler descriptors,
  resource storage modes, and `MTLBuffer.gpuAddress` where supported.
- Vulkan maps to format properties, `VkImageView` component mapping,
  `VkSampler`, memory property selection, and buffer device address feature and
  usage flags.
- Unsupported combinations fail validation before native object creation.
