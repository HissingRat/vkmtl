# Phase 5: Shader Specialization Variants

Phase 5 turns specialization from cache identity into real pipeline variants.

## Scope

- Decide the Slang compile/runtime path for specialization values.
- Lower Vulkan specialization data into pipeline creation when the generated
  target supports it.
- Lower Metal specialization through Slang-generated variants, Metal function
  constants, or a documented capability-gated equivalent.
- Include specialization inputs in shader artifact hashes, pipeline
  fingerprints, and persistent cache metadata.
- Preserve typed errors for unsupported value kinds or backend paths.

## Validation

- Add tests proving distinct specialization values create distinct runtime
  variants.
- Add tests for unsupported specialization shapes and stale cache entries.
- Add a small example only if it proves backend-native variant behavior.

## Result

- `ProgrammableStageDescriptor.specialization` becomes an executable feature
  instead of a descriptor-only cache key.
