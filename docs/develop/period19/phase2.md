# Phase 2: Chunk Mesh Data And CPU Meshing

Status: next.

Phase 2 creates visible chunk geometry.

## Scope

- Use the Phase 1 contract: `16 x 64 x 16` chunks; air/grass/dirt/stone block
  IDs; a 32-byte position/UV/normal vertex; and `u32` indices.
- Generate chunk meshes on the CPU.
- Emit only faces adjacent to empty blocks, including cross-chunk neighbor
  checks.
- Upload vertex and index buffers through public vkmtl APIs.
- Add the real embedded Slang chunk shader and register it in
  `shaders/manifest.json`; do not add a runtime compiler fallback.

## Validation

- Tests cover an empty chunk, one block, two adjacent blocks, a solid chunk,
  and a cross-chunk boundary.
- The smoke profile renders a deterministic static 3 x 3 chunk field with
  depth testing and back-face culling.
