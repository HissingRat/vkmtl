# Phase 2: Sparse / Tiled Resources

Phase 2 defines sparse/tiled resource metadata and validation.

## First Slice

- Add sparse buffer, sparse texture, and tiled texture feature gates.
- Add sparse page and residency descriptor shapes.
- Validate page size and mapping alignment.

## Current Limits

- `SparseBufferMappingDescriptor`, `SparseTextureMappingDescriptor`, and
  `SparseMappingCommitDescriptor` validate sparse/tiled mapping shape.
- `DeviceFeatures.sparse_buffers`, `sparse_textures`, and `tiled_textures`
  default to false.
- Native sparse/tiled allocation and residency management are not lowered yet.
