# Phase 5: Streaming Texture Example

Phase 5 proves sparse resources with a visible streaming example.

## Scope

- Add `examples/streaming_texture`.
- Stream visible tiles or mips into a sparse/tiled texture.
- Show missing tiles clearly during loading or unsupported-feature fallback.

## Validation

- The example should run on at least one backend with sparse/tiled support.
- Unsupported backends should exit with a clear feature-gate message.
