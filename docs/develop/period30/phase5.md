# Phase 5: Native Advanced Escape Hatches

Phase 5 closes the backend-private runtime inventory tracked by
`NativeAdvancedClosurePlan`.

Status: completed for vkmtl-owned inventory and routing. First-triangle driver
execution is split into Period 31 for Metal and Period 32 for Vulkan. Full
native RT scene work is Period33, procedural RT work is Period34, and the
remaining driver-level implementation stays in later Period32+ work because the
list spans multiple native API families and needs dedicated hardware
validation.

## Scope

- Count requested native advanced features.
- Count public runtime-contract features separately.
- Count backend-private runtime inventory separately.
- Route first-triangle driver work to Period 31 and Period 32, full native RT
  scene work to Period33, procedural RT work to Period34, and remaining
  driver-level native work to later Period32+ phases.
- Keep native object pools, driver caches, cache manifest I/O, staging pools,
  heaps, sparse/tiled binding, external interop, command handle views,
  tessellation, and mesh/task execution visible as explicit target items.

## Validation

- Add focused runtime tests for inventory counts and deferred driver targets.
- Update capability and backend matrices for every routed path.

## Deferred

- First-triangle driver-level execution is deferred to Period 31 for Metal and
  Period 32 for Vulkan.
- Full native RT scene execution is deferred to Period33.
- Procedural RT execution is deferred to Period34.
- Broader native advanced execution is deferred to later concrete Period32+
  periods and phases after Period 30 is complete.
