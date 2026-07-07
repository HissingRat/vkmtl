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
