# Phase 4: Small Constants And Root Constants

Phase 4 adds root-constant layout compatibility to pipeline descriptors. It
does not yet make command encoder writes executable; that lowering belongs to
Period 22.

## Scope

- Add root-constant layout metadata to render and compute pipeline descriptors.
- Validate that metadata against backend features, limits, and pipeline cache
  identity.
- Validate size, alignment, stage visibility, and pipeline layout compatibility.

## Validation

- Add tests for size/alignment limits.
- Keep examples deferred to Period 22, when command encoder writes become
  executable.

## Result

- Render and compute pipeline descriptors now carry optional `root_constant_layout`.
- Runtime pipeline creation validates root-constant layout compatibility against selected device features and limits.
- Pipeline fingerprints include root-constant layout metadata.
- Command encoder write methods and native Vulkan/Metal constant lowering
  remain deferred to Period 22, where the Metal slot/index model is finalized.
