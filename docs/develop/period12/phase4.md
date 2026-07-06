# Phase 4: Slang Reflection Bindless Mapping

Phase 4 connects Slang reflection to the advanced binding path.

## Scope

- Parse resource-array metadata from reflection.
- Derive advanced layout ranges when shaders declare bindless resources.
- Include advanced layout details in shader and pipeline cache keys.

## Validation

- Add reflection fixture tests for bindless declarations.
- Ensure explicit descriptors can override derived layout data.
