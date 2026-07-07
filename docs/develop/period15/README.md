# Period 15: Sparse / Tiled Resources Backend

Status: in progress.

Goal: lower sparse and tiled resource descriptors to backend-native residency
and page-commit mechanisms for large textures, virtual resources, and streaming
asset systems.

This period should remain optional and capability-gated. Portable applications
should not be forced to manage sparse residency.

## Phase 1: Sparse Buffer Backend

- Allocate sparse buffers.
- Commit and uncommit buffer pages.
- Add `SparseBufferDescriptor` validation for page-aligned virtual buffers.

See `phase1.md`.

## Phase 2: Sparse Texture / Tiled Texture Backend

- Allocate sparse or tiled textures.
- Commit texture regions by page.
- Add `SparseTextureDescriptor` validation for sparse/tiled texture shapes and
  page granularity.

See `phase2.md`.

## Phase 3: Residency Map And Page Commit API

- Track which regions are resident.
- Batch page commits and uncommits.
- Add `SparseResidencyMap` diagnostics for buffer and texture resident regions.

See `phase3.md`.

## Phase 4: Mip Tail And Alignment Handling

- Handle backend-specific mip tail and page alignment rules.
- Add `SparseMipTailDescriptor` for packed or strided small-mip metadata.

See `phase4.md`.

## Phase 5: Streaming Texture Example

- Add an example that streams texture tiles or mip levels.
- Provide a feature-gated `examples/streaming_texture` residency smoke path.

See `phase5.md`.

## Phase 6: Sparse Validation Coverage

- Validate page alignment, residency state, and unsupported access.

See `phase6.md`.
