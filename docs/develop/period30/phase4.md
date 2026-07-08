# Phase 4: Native Metal Ray Tracing Dispatch

Phase 4 connects `MetalRayTracingExecutionMapping` to Metal acceleration and
function-table resources.

## Scope

- Bind Metal acceleration structures and intersection functions.
- Populate visible/intersection function tables.
- Lower ray dispatch resource binding while keeping Metal-only semantics
  explicit.

## Validation

- Add Metal capability tests where possible.
- Keep Vulkan paths unaffected by Metal-specific mapping.
