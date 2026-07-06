# Phase 2: Blit Encoder Completeness

Phase 2 expands the transfer descriptor surface while keeping unsupported native
lowering explicit.

## First Slice

- Keep buffer-to-buffer, buffer-to-texture, and texture-to-buffer copies working.
- Add texture-to-texture copy descriptors and validation.
- Add fill-buffer descriptors and validation.
- Record portable usage transitions for validated transfer commands.

## Current Limits

- Texture-to-texture, fill-buffer, clear-texture, and mipmap generation encoder
  commands are represented first and can return typed unsupported errors until
  native lowering lands.
- Copy alignment checks remain portable and conservative.
