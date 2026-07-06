# Phase 3: Format System

Phase 3 expands format classification and capability queries.

## First Slice

- Add color, depth, stencil, depth-stencil, sRGB, compressed, and byte-size
  helpers.
- Add format capability fields for mips, linear filtering, and blend/storage
  usage.
- Keep unsupported format use as typed validation errors.

## Current Limits

- The first expanded table still covers only formats implemented by both
  backends.
- Compressed formats are classified but not enabled until backend upload and
  copy rules are implemented.
