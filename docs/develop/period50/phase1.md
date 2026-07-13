# Period 50 Phase 1: Contract Allocation And Dependency Audit

Status: complete.

## Routed Rows

Period 50 begins with:

- `MTL-RES-012`
- `MTL-CMD-004`
- `MTL-SHD-004` through `MTL-SHD-007`
- `MTL-BND-001` and `MTL-BND-002`
- `MTL-IND-001` through `MTL-IND-003`
- `MTL-ARC-001` and `MTL-ARC-002`

## Decisions

1. `MTL-BND-001` is the executable scalable-table target. Classic Metal
   argument buffers and Vulkan descriptor indexing must allocate, update, and
   bind real native objects.
2. `MTL-BND-002` and `MTL-RES-012` depend on Metal 4 argument tables/resource
   IDs and Metal 4 encoders. They move together to Period 54 instead of being
   adapted to the current encoder model.
3. `MTL-SHD-005` is an RT callable/intersection-table semantic and moves to
   Period 52. Period 50 does not treat an entry-point string as a function
   handle.
4. CPU-authored reusable render/compute command slots receive a portable
   contract. GPU-authored command mutation is split out and closed as
   unsupported under the pinned Vulkan core/extension baseline.
5. Parallel child render encoders are not equivalent to reusable indirect
   command lists. With no thread-safe public child-encoder ownership contract,
   `MTL-CMD-004` closes as unsupported rather than becoming a hidden no-op.
6. Manifest schema 1 embeds complete stage artifacts and declares no link
   units, install names, stitching graphs, or runtime library compiler.
   Linked functions, stitching, and dynamic libraries therefore close as
   unsupported under the current shader contract.
7. Metal binary archives and Vulkan pipeline caches use the existing
   diagnostics-owned descriptor/identity contract and are consumed
   synchronously by pipeline creation.

## API Compatibility

The descriptor and handle additions are additive and target `v0.2.0`. The root
and common-owner allowlists stay fixed. The runtime handle-name allowlist is
updated intentionally for the new command-domain handle.
