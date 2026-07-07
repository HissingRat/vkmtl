# Phase 5: Streaming Texture Example

Phase 5 proves sparse resources with a visible streaming example.

## Scope

- Add `examples/streaming_texture`.
- Stream visible tiles or mips into a sparse/tiled texture.
- Show missing tiles clearly during loading or unsupported-feature fallback.
- Current implementation validates sparse/tiled texture descriptors and commits
  one tile in `SparseResidencyMap`; visible rendering waits for backend sparse
  lowering.

## Validation

- The example should run on at least one backend with sparse/tiled support.
- Unsupported backends should exit with a clear feature-gate message.
- The example should compile with the normal example build.
