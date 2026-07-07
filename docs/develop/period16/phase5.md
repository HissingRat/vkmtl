# Phase 5: Slang Entry / Reflection Alignment

Phase 5 aligns shader compilation with advanced geometry stages.

## Scope

- Add Slang stage and entry metadata for tessellation, mesh, and task shaders.
- Include advanced geometry stages in shader and pipeline cache keys.
- Validate reflection output against pipeline descriptors.
- Keep render and compute pipeline descriptors restricted to their existing
  stages while advanced geometry pipelines use explicit descriptors.

## Validation

- Add reflection fixtures for tessellation and mesh shaders.
- Tests should reject mismatched shader stages.
- Unit tests should classify advanced geometry stages and accept their
  reflection shape.
