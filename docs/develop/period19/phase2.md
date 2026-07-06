# Phase 2: Chunk Mesh Data And CPU Meshing

Phase 2 creates visible chunk geometry.

## Scope

- Define block IDs, chunk dimensions, vertex format, and index format.
- Generate chunk meshes on the CPU.
- Emit only faces adjacent to empty blocks for the first slice.
- Upload vertex and index buffers through public vkmtl APIs.

## Validation

- Tests should cover simple chunk meshing cases.
- The example should render a static chunk field.
