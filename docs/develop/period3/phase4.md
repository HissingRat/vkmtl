# Phase 4: Mipmap Support

Phase 4 completes public mipmap validation and range helpers.

## First Slice

- Add `maxMipLevelCount(...)` helper.
- Validate requested mip counts against texture extent.
- Expose resolved mip dimensions.
- Keep explicit upload/copy-to-mip paths.
- Add a future-facing generate-mipmaps descriptor shape behind capability
  checks.
- Implemented as `mipDimension(...)`, `maxMipLevelCountForExtent(...)`,
  `TextureDescriptor.maxMipLevelCount()`, `TextureDescriptor.mipExtent(...)`,
  and `GenerateMipmapsDescriptor`.

## Current Limits

- Automatic mipmap generation is not lowered to native commands yet.
- Applications can upload or copy individual mip levels explicitly.
