# Period 30: Backend-Private Native Execution

Status: planned after Period 29.

Goal: connect the Period 29 runtime contracts to real Vulkan and Metal native
objects, command encoders, and GPU validation paths.

Expected result: supported adapters can execute the advanced paths that Period
29 can now describe and validate.

## Phase 1: Native Acceleration Structure Handles

- Create Vulkan `VkAccelerationStructureKHR` objects and Metal
  `MTLAccelerationStructure` objects.
- Encode native build/update commands from `AccelerationStructureBuildPlan`.
- Validate scratch/result resource usage against native alignment properties.

See `phase1.md`.

## Phase 2: Native Ray Tracing Pipeline Handles

- Create Vulkan ray tracing pipelines from shader groups.
- Create Metal executable ray tracing pipeline/function-table backend handles.
- Keep unsupported adapters typed and capability-gated.

See `phase2.md`.

## Phase 3: Native SBT Records And Dispatch

- Materialize SBT records from native shader group handles.
- Lower `CommandBuffer.dispatchRays(...)` to native dispatch commands.
- Validate device-address, stride, and range requirements.

See `phase3.md`.

## Phase 4: Native Metal Ray Tracing Dispatch

- Connect Metal acceleration structures, intersection functions, visible
  function tables, and dispatch resources.
- Keep Metal-specific semantics explicit behind public runtime contracts.

See `phase4.md`.

## Phase 5: Native Advanced Escape Hatches

- Implement native object pools, native driver caches, runtime cache I/O,
  persistent staging pools, heap-backed resources, sparse/tiled page binding,
  external imports/sync, command handle views, tessellation, and mesh/task
  execution.

See `phase5.md`.

## Phase 6: Native Parity And Soak Validation

- Add GPU-backed soak loops for ready backend paths.
- Revisit custom border colors and depth/stencil/MSAA copy expansion only where
  both Vulkan and Metal semantics can be kept clear.

See `phase6.md`.

## Phase 7: Pixel-Producing Native Advanced Examples

- Turn the ray tracing runtime-contract example into a pixel-producing sample
  on supported adapters.
- Add native advanced examples only when they prove backend execution paths.

See `phase7.md`.
