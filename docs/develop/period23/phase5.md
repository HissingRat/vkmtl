# Phase 5: Query Pools And Encoder Commands

Historical status: completed for query descriptors, validation, logical
timestamp sequencing, and runtime query objects. The original occlusion
lowering claim was corrected by Period 45: occlusion query creation is typed
unsupported until native GPU visibility results replace the logical placeholder.

## Scope

- Add runtime query set objects.
- Define occlusion query commands and keep native lowering capability-gated.
- Lower timestamp writes and resolves.
- Lower pipeline statistics where Vulkan supports them and gate Metal behavior
  precisely.
- Add readback helpers for query results.

## Validation

- Add deterministic query validation where possible.
- Add profiler marker and timestamp example coverage.
