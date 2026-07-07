# Period 17: Ray Tracing Backend

Status: completed ray-tracing descriptor and lowering-metadata scaffold. Native
acceleration structure, pipeline, SBT, and dispatch lowering are tracked in
Period 28+.

Goal: define acceleration structure, ray tracing pipeline, and shader binding
table descriptors with backend-aware validation metadata.

Ray tracing remains an optional module. The portable render and compute paths
must not depend on ray tracing support.

Historical note: Period 28+ owns executable Vulkan and Metal ray-tracing
backend closure and the maintained advanced parity matrix.

## Phase 1: Acceleration Structure Backend API

- Create bottom-level and top-level acceleration structures.
- Define build, update, and scratch-buffer ownership.
- Add build-size and instance descriptor metadata.

See `phase1.md`.

## Phase 2: Vulkan Ray Tracing Pipeline Lowering

- Lower ray tracing descriptors to Vulkan KHR ray tracing pipelines.
- Add Vulkan ray tracing lowering metadata for shader group counts and recursion.

See `phase2.md`.

## Phase 3: Metal Acceleration Structure And Intersection Lowering

- Lower acceleration structures and intersection functions to Metal.
- Add Metal intersection function and function-table lowering metadata.

See `phase3.md`.

## Phase 4: Shader Binding Table Mapping

- Map public shader group descriptors to Vulkan SBT and Metal equivalents.
- Add `ShaderBindingTableLayout` offset/size mapping.

See `phase4.md`.

## Phase 5: Basic Ray Traced Triangle Example

- Add the smallest visible ray tracing example.
- Add feature-gated `examples/ray_traced_triangle` descriptor/SBT smoke path.

See `phase5.md`.

## Phase 6: Ray Tracing Validation And Matrix

- Add validation and backend matrix coverage for ray tracing support.
- Extend descriptor tests for invalid AS instances, missing raygen groups,
  recursion limits, and SBT alignment.

See `phase6.md`.
