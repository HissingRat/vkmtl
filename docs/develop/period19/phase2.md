# Phase 2: Chunk Mesh Data And CPU Meshing

Status: complete.

Phase 2 creates visible chunk geometry and proves the ordinary indexed-draw
path with application-owned mesh data.

## Implemented Scope

- `voxel.zig` owns the `16 x 64 x 16` chunk contract, air/grass/dirt/stone
  IDs, deterministic terrain sampler, allocator-owned mesh, and 32-byte
  position/UV/normal vertex ABI.
- Indices are `u32`. Each emitted quad has four vertices and six indices.
- The mesher samples neighbors in world coordinates, including coordinates
  outside the current chunk. Faces shared with adjacent chunks are therefore
  removed without backend knowledge.
- Each resident chunk owns one ordinary shared vertex buffer and one ordinary
  shared index buffer. Rendering binds them and calls the canonical
  `drawIndexedPrimitives(...)` path.
- `voxel_world.slang` is embedded and registered in the source-backed shader
  manifest. Runtime loading uses its precompiled backend artifacts and has no
  compiler fallback.
- Shader reflection derives the vertex descriptor and bind-group layout from
  the precompiled stages rather than duplicating shader ABI declarations.

## Evidence

- Focused tests cover the vertex ABI, an empty chunk, one block, two adjacent
  blocks, a finite solid chunk shell, deterministic terrain, and cross-chunk
  face removal.
- The smoke profile fills the bounded 3 x 3 resident grid and renders all nine
  chunks with depth testing and back-face culling.
- Physical Metal execution with API Validation enabled reached the success
  marker without shader, buffer, index, or render validation errors.

Relevant validation commands include:

```sh
zig test examples/voxel_world/voxel.zig
zig build test --summary all
zig build --summary all
zig build -Dvulkan --summary all
```

The forced Vulkan build proves that the source, precompiled SPIR-V, and Vulkan
lowering compile together. It is not physical Vulkan execution evidence.
