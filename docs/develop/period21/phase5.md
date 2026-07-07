# Phase 5: Shader Specialization

Phase 5 verifies that shader specialization metadata participates in runtime
identity. It deliberately keeps native variant creation for Period 22.

## Scope

- Preserve specialization descriptors as validated pipeline inputs.
- Keep non-empty specialization rejected until native variants land.
- Ensure specialization data participates in pipeline cache identity.
- Keep unsupported specialization forms behind typed shader errors.

## Validation

- Add descriptor validation tests for typed constants.
- Add cache-key tests for specialization identity.

## Result

- Runtime pipeline fingerprints include shader specialization constants.
- Descriptor validation continues to reject duplicate IDs, duplicate names, and empty names.
- Runtime pipeline creation still rejects non-empty specialization with `UnsupportedShaderSpecialization`.
- Native Vulkan specialization info and Metal/Slang variant lowering remain
  deferred to Period 22.
