# Phase 1: Sparse Buffer Backend

Phase 1 implements sparse buffers where supported.

## Scope

- Query sparse buffer support and page size.
- Create sparse buffers without committing all memory up front.
- Commit and uncommit buffer pages through explicit descriptors.
- Preserve normal buffer APIs for non-sparse buffers.

## Validation

- Tests should cover page alignment and range bounds.
- Backend smoke tests should write and read a committed sparse buffer page.
