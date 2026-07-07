# Phase 5: Debug Labels And Capture-Friendly Naming

Phase 5 improves graphics-debugger captures.

## Scope

- Lower resource labels to Vulkan debug utils and Metal labels.
- Lower command debug groups and signposts consistently.
- Preserve readable names in examples and diagnostics.
- Keep labels validated before native debug-utils or Metal label lowering.

## Validation

- Tests should cover label validation and lifetime rules.
- Manual capture notes should explain how to inspect labels per backend.
- Unit tests should reject empty capture labels.
