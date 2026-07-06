# Period 10: Advanced / Backend-Gated

Goal: expose advanced Vulkan and Metal features without forcing them into the
portable core.

Every phase in this period is optional, capability-gated, and has no default
portable fallback unless a future design explicitly adds one.

## Phase 1: Descriptor Indexing / Argument Buffer

- Vulkan descriptor indexing.
- Metal argument buffers.
- Advanced API that does not pollute the base bind group model.

## Phase 2: Sparse / Tiled Resources

- Vulkan sparse resources.
- Metal sparse or tiled textures.
- Page size differences.
- Residency and mapping differences.
- Capability-gated API.

## Phase 3: External Texture / Platform Interop

- IOSurface.
- External memory.
- External semaphores.
- Platform handles.
- Integration with the native handle escape hatch.

## Phase 4: Tessellation Gated

- Vulkan tessellation.
- Metal tessellation.
- Shader model capability gate.
- Not part of the base render path.

## Phase 5: Mesh Shader Gated

- Vulkan mesh shader.
- Metal object shader or mesh-like paths if feasible.
- Clear documentation for non-portable differences.

## Phase 6: Ray Tracing Gated Module

- Acceleration structures.
- Ray tracing pipelines.
- Shader binding table and Metal intersection function differences.
- Backend-gated module, not a forced portable abstraction.

## Phase 7: Driver-Level Pipeline Cache / Binary Archive

- Vulkan pipeline cache.
- Metal binary archive.
- Disk cache.
- Version validation.
- Driver, device, and shader hash validation.
- Cache invalidation rules.
