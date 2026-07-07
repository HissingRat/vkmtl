# Phase 1: Explicit Resource Barriers

Phase 1 makes explicit barrier descriptors executable.

## Scope

- Lower buffer barriers on Vulkan.
- Lower texture barriers on Vulkan.
- Define Metal mapping as validation/no-op or encoder-bound synchronization
  where appropriate.
- Keep automatic usage tracking available for the common path.

## Validation

- Add tests for invalid before/after usage transitions.
- Add backend notes that distinguish Vulkan commands from Metal no-op mapping.
