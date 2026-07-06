# Period 3: Resource Coverage

Goal: cover Metal and Vulkan buffer, texture, sampler, and memory fundamentals.

Period 3 should build on Period 2's ownership, lifetime, feature, limit, and
format-capability rules. Non-basic features should be guarded by capability
queries instead of silently falling back.

## Phase 1: Buffer Completeness

- Map and unmap buffers.
- Read and write CPU-visible buffers.
- Copy buffers.
- Provide staging upload helpers.
- Provide readback helpers.
- Cover storage mode and memory usage choices.
- Complete usage flags.
- Query alignment requirements.
- Expose dynamic uniform and storage buffer alignment limits.

## Phase 2: Texture Shapes

- 1D textures.
- 2D textures.
- 3D textures.
- Texture arrays.
- Cube textures.
- Cube arrays where supported.
- Multisampled textures.
- Check shape support through features and format capabilities.

## Phase 3: Format System

- Color formats.
- Depth formats.
- Stencil formats.
- Depth-stencil formats.
- sRGB formats.
- Compressed formats.
- Format capability queries for sampled, storage, attachment, filterable,
  blendable, and copy usage.

## Phase 4: Mipmap Support

- Create textures with mip levels.
- Upload specific mip levels.
- Copy mip-to-mip.
- Generate mipmaps.
- Check whether a format supports mipmap generation.
- Support texture views with explicit mip ranges.

## Phase 5: Texture View Completeness

- View dimension.
- Format reinterpretation where supported.
- Mip range.
- Layer range.
- Cube face view.
- Array slice view.
- Depth and stencil aspect view.

## Phase 6: Sampler Completeness

- Address modes.
- Minification and magnification filters.
- Mipmap filter.
- LOD min and max.
- Compare samplers.
- Anisotropy.
- Border color where supported.
- Capability gates for backend differences.

## Phase 7: Heaps / Memory Advanced

- Vulkan memory heaps.
- Metal heaps.
- Gated abstraction for explicit heap users.
- Default users should not need manual heap management.
- Define heap resource lifetime and ownership rules.
