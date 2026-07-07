# Phase 4: Small Constants And Root Constants

Phase 4 makes low-latency constants available without creating tiny buffers.

## Scope

- Lower small constants to Vulkan push constants where supported.
- Lower root-constant-style values to Metal-compatible constant buffers or
  command encoder constants.
- Validate size, alignment, stage visibility, and pipeline layout compatibility.

## Validation

- Add tests for size/alignment limits.
- Add one render or compute example using constants.

## Result

- Render and compute pipeline descriptors now carry optional `root_constant_layout`.
- Runtime pipeline creation validates root-constant layout compatibility against selected device features and limits.
- Pipeline fingerprints include root-constant layout metadata.
- Command encoder write methods and native Vulkan/Metal constant lowering remain deferred until the Metal slot/index model is finalized.
