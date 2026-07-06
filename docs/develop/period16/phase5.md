# Phase 5: Slang Entry / Reflection Alignment

Phase 5 aligns shader compilation with advanced geometry stages.

## Scope

- Add Slang stage and entry metadata for tessellation, mesh, and task shaders.
- Include advanced geometry stages in shader and pipeline cache keys.
- Validate reflection output against pipeline descriptors.

## Validation

- Add reflection fixtures for tessellation and mesh shaders.
- Tests should reject mismatched shader stages.
