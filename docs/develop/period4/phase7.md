# Phase 7: Shader Specialization

Phase 7 defines shader specialization data and cache-key rules.

## First Slice

- Add `ShaderSpecializationValue`, `ShaderSpecializationConstant`, and
  `ShaderSpecializationDescriptor`.
- Attach specialization descriptors to `ProgrammableStageDescriptor`.
- Include specialization inputs in `ShaderLibraryCacheKeyDescriptor`.
- Validate duplicate IDs, duplicate names, empty names, and feature gates.
- Keep backend specialization lowering gated for later pipeline work.

## Current Limits

- Runtime shader compilation still compiles the source without specialization
  variants.
- Runtime pipeline creation rejects non-empty specialization descriptors with
  `UnsupportedShaderSpecialization` until Vulkan/Metal lowering is implemented.
