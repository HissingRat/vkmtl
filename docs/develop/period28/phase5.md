# Phase 5: Native Advanced Escape Hatches

Phase 5 finishes explicit backend-specific advanced access.

## Scope

- Expose native handles only through intentional APIs.
- Add insertion or callback points for features that cannot be portable.
- Keep safety checks around encoder/queue state.
- Implement persistent native staging-buffer pools and reusable upload rings for
  backend paths that currently allocate temporary staging resources.
- Implement sparse buffer runtime objects and native sparse-memory page binding
  for backends that expose compatible residency APIs.
- Implement sparse/tiled texture runtime objects and native texture page
  binding for Vulkan sparse images and Metal sparse/tiled texture paths.

## Validation

- Add tests for invalid escape-hatch use.
- Add examples that clearly label backend-specific code.
