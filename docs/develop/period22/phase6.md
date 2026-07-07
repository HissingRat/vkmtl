# Phase 6: Binding And Variant Validation

Phase 6 closes Period 22 with coverage and documentation.

## Scope

- Update API docs for dynamic buffer arrays, resource tables, root constants,
  immutable/static samplers, and specialization variants.
- Update backend matrix entries for Vulkan descriptor indexing and Metal
  argument buffers.
- Update examples that were previously metadata-only smoke tests.
- Add regression tests for every deferred item closed by the period.

## Validation

- `zig build test`
- `zig build`
- Backend matrix updated for Vulkan and Metal.
- Examples that require optional features report clear feature-gate messages
  when unavailable.

## Result

- Period 21's deferred binding and shader items have either native backend
  lowering or explicit documented feature gates with tests.
