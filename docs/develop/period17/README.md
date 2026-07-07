# Period 17: Ray Tracing Backend

Status: in progress.

Goal: lower acceleration structures, ray tracing pipelines, and shader binding
table descriptors to Vulkan and Metal ray tracing capabilities.

Ray tracing remains an optional module. The portable render and compute paths
must not depend on ray tracing support.

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

See `phase5.md`.

## Phase 6: Ray Tracing Validation And Matrix

- Add validation and backend matrix coverage for ray tracing support.

See `phase6.md`.
