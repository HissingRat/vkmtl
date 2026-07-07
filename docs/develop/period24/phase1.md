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
