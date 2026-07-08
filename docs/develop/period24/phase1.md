# Phase 1: Automatic Mipmap Generation

Phase 1 lowers automatic mipmap generation.

## Scope

- Generate mip levels through Vulkan blits where valid.
- Generate mip levels through Metal blit commands.
- Validate format, usage, sample count, dimensions, and mip count.
- Keep unsupported formats behind typed texture errors.

## Validation

- Add tests for descriptor resolution and invalid formats.
- Add an example or smoke path that samples generated mip levels.

## Result

- `BlitCommandEncoder.generateMipmaps(...)` validates and records full-texture
  mipmap generation.
- Vulkan lowers full-texture generation through per-mip image blits.
- Metal lowers full-texture generation through `generateMipmapsForTexture`.
- Partial mip/layer generation is deferred to Period 28 Phase 6, where the
  parity matrix will decide whether it becomes a portable fallback or an
  explicit backend-specific escape hatch.
