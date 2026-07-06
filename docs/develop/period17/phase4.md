# Phase 4: Shader Binding Table Mapping

Phase 4 maps shader group descriptors to backend-specific ray binding data.

## Scope

- Build Vulkan shader binding tables with correct alignment.
- Map public shader groups to Metal function table or equivalent data.
- Include shader binding data in pipeline cache keys.

## Validation

- Tests should cover alignment, missing groups, and invalid group references.
- Docs should clearly explain portability limits.
