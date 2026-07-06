# Phase 3: Vulkan Mesh / Task Shader Lowering

Phase 3 implements Vulkan mesh and task shader lowering.

## Scope

- Query and enable mesh shader features and limits.
- Create mesh pipelines with optional task stages.
- Dispatch mesh workloads through render command encoders.

## Validation

- Tests should cover threadgroup limits and required stages.
- A Vulkan smoke example should render via mesh shaders.
