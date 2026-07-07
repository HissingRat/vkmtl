# Phase 5: Query Pools And Encoder Commands

Phase 5 lowers query descriptors into real backend query commands.

## Scope

- Add runtime query set objects.
- Lower occlusion queries.
- Lower timestamp writes and resolves.
- Lower pipeline statistics where Vulkan supports them and gate Metal behavior
  precisely.
- Add readback helpers for query results.

## Validation

- Add deterministic query validation where possible.
- Add profiler marker and timestamp example coverage.
