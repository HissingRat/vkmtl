# Phase 4: Native Metal Ray Tracing Execution Mapping

Phase 4 connects the Metal-specific ray tracing plan to native execution.

## Scope

- Connect Metal acceleration-structure resources.
- Bind intersection functions and function tables.
- Document any semantic difference that cannot be expressed portably.

## Validation

- Add Metal capability tests where possible.
- Keep Vulkan paths unaffected by Metal-only mapping.
