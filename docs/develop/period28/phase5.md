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
- Connect runtime `Heap` reservations to native Vulkan memory suballocation and
  Metal `MTLHeap`-backed buffer/texture creation where supported.
- Connect tessellation lowering plans to native Vulkan/Metal render pipeline
  creation, shader stage attachment, and executable draw commands.
- Connect mesh/task lowering plans to native Vulkan task/mesh pipeline creation,
  Metal object/mesh pipeline creation, and executable mesh draw/dispatch
  commands.

## Validation

- Add tests for invalid escape-hatch use.
- Add examples that clearly label backend-specific code.

## Result

- Added `NativeAdvancedClosureFeature`, `NativeAdvancedClosureDescriptor`, and
  `NativeAdvancedClosurePlan`.
- Added `nativeAdvancedClosureTarget(...)` so deferred native backend work has a
  concrete future period/phase target.
- Added `Device.planNativeAdvancedClosure(...)` for apps and tools that want to
  inspect which advanced native paths are still implementation work.
- Added focused tests for the default closure inventory and `Device` planning.

## Deferred

- Native object pooling, driver cache consumption, runtime cache manifest I/O,
  persistent staging pools, native heaps, sparse page binding, native external
  imports/synchronization, command handle views, native multi-surface
  presentation, tessellation execution, and mesh/task execution are deferred to
  Period 29 Phase 5.
