# Phase 2: Sparse Texture / Tiled Texture Backend

Phase 2 implements sparse or tiled textures where supported.

## Scope

- Query sparse texture dimensions and page granularity.
- Create sparse or tiled textures through explicit descriptors.
- Commit and uncommit texture regions.
- Keep non-resident access behavior documented and validated.

## Validation

- Tests should cover page-aligned regions and unsupported texture shapes.
- Backend smoke tests should render from a committed tile.
