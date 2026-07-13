# Phase 3: Native Memory Telemetry

Status: complete.

## Scope

- Query Metal recommended working set and current allocated size.
- Query Vulkan heap budget/usage through `VK_EXT_memory_budget` when available.
- Keep native and fallback report sources distinct.
- Report memory-budget/pressure features only when the complete query is usable.

## Result

Metal reports `recommendedMaxWorkingSetSize` and `currentAllocatedSize`.
Vulkan reports the sum of device-local `heapBudget`/`heapUsage` values only
when `VK_EXT_memory_budget` and the properties query are present. Runtime native
reports replace caller estimates; fallback reports ignore the caller's former
`native_budget_available` hint.
