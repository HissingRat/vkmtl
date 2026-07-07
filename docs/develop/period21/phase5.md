# Phase 5: Shader Specialization

Phase 5 lowers shader specialization metadata into native pipeline creation.

## Scope

- Lower specialization constants to Vulkan specialization info.
- Define Metal lowering through Slang-generated variants or pipeline constants.
- Ensure specialization data participates in pipeline cache identity.
- Keep unsupported specialization forms behind typed shader errors.

## Validation

- Add reflection and pipeline-creation tests for typed constants.
- Add cache-key tests for specialization identity.

## Result

- Runtime pipeline fingerprints include shader specialization constants.
- Descriptor validation continues to reject duplicate IDs, duplicate names, and empty names.
- Runtime pipeline creation still rejects non-empty specialization with `UnsupportedShaderSpecialization`.
- Native Vulkan specialization info and Metal/Slang variant lowering remain deferred to the shader variant slice.
