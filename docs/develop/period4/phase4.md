# Phase 4: Bind Group Layout Completeness

Phase 4 extends layout descriptors for advanced binding metadata.

## First Slice

- Add resource arrays.
- Add dynamic buffer binding flags.
- Add compare sampler resource kind.
- Validate arrays, dynamic buffers, and storage texture visibility.
- Keep unsupported backend lowering behind feature gates.

## Current Limits

- Runtime native lowering still supports the non-array first slice.
- Dynamic offsets are validated as public API shape before backend dynamic
  descriptor lowering.
