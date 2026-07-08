# Phase 4: Metal Ray Tracing Mapping

Phase 4 handles Metal-specific ray tracing differences.

## Scope

- Map acceleration structures to Metal resource types.
- Map intersection functions and function tables.
- Document Vulkan/Metal semantic differences.

## Validation

- Add Metal capability tests where possible.
- Keep non-portable behavior explicit.

## Result

- Added `MetalRayTracingMappingDescriptor` and `MetalRayTracingMappingPlan`.
- The plan records function-table entries, intersection-function count, and
  whether intersection function tables and acceleration-structure resources are
  required.
- Added `Device.planMetalRayTracingMapping(...)`, which is explicit to the
  Metal backend and uses native feature reports.
- Added focused tests for mapping metadata and runtime planning.

## Deferred

- Executable Metal acceleration-structure resource creation, intersection
  function table binding, and Metal-specific ray tracing dispatch integration
  are deferred to Period 29 Phase 4.
