# Phase 2: Driver Pipeline Cache And Binary Archive

Phase 2 connects backend-native pipeline caches.

## Scope

- Integrate Vulkan pipeline cache creation, serialization, and reuse.
- Integrate Metal binary archives where available.
- Include shader, specialization, layout, and render target identity in cache
  compatibility.

## Validation

- Add cache identity tests.
- Add docs for portable and backend-specific cache behavior.

## Result

- `Device.validateNativeDriverPipelineCacheDescriptor(...)` validates driver
  cache descriptors against native feature reports.
- `Device.planDriverPipelineCache(...)` and
  `WindowContext.planDriverPipelineCache(...)` return a
  `DriverPipelineCachePlan` with `load_existing` and `store_on_shutdown` set
  from the descriptor and path existence.
- Usable feature gates remain conservative; native feature reports can plan a
  cache without claiming vkmtl has already wired it into pipeline creation.
- Actual Vulkan `VkPipelineCache` creation/serialization and Metal
  `MTLBinaryArchive` integration are deferred to Period 28 Phase 5.
