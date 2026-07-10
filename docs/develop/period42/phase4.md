# Phase 4: Depth-Stencil Copy, Resolve, And Readback

Status: complete.

## Decisions

- Copy descriptors carry a `TextureAspect` so depth and stencil behavior is
  explicit.
- `depth32_float` supports depth texture copies and buffer readback when the
  selected backend reports the required copy features.
- Combined depth-stencil copies require an explicit depth or stencil aspect.
  Portable combined-aspect buffer layout is unsupported.
- Color resolve remains executable. Depth and stencil resolve are represented
  in the capability matrix and return typed unsupported errors until both
  backends expose a validated lowering.
- Stencil buffer readback remains unsupported on Metal in the current portable
  path and must not silently copy an implementation-defined packed texel.

## Acceptance

- Depth copy/readback layout uses the selected aspect byte size.
- Mismatched or unavailable aspects return precise errors.
- Depth/stencil resolve support is truthful in capability reports.
