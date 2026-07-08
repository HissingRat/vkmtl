# Phase 4: Native Metal Ray Tracing Dispatch

Phase 4 connects `MetalRayTracingExecutionMapping` to backend-private Metal
function-table, intersection-table, and acceleration-structure slot metadata.

Status: completed for vkmtl-owned Metal-specific mapping state. Direct Metal
table population and dispatch binding remain deferred to the concrete Period
31+ backend-driver parity plan.

## Scope

- Track Metal acceleration-structure slot requirements.
- Track visible function table and intersection function table metadata.
- Keep Metal-only semantics explicit in `MetalRayTracingExecutionMapping`.

## Validation

- Add Metal mapping metadata tests where native feature reports allow creation.
- Keep Vulkan paths unaffected by Metal-specific mapping.

## Deferred

- Direct `MTLAccelerationStructure` binding, function-table population, and
  Metal ray dispatch resource binding are deferred to Period 31+ driver parity
  work.
