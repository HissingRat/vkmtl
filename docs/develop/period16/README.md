# Period 16: Advanced Geometry Pipeline

Status: completed.

Goal: lower tessellation and mesh/task shader descriptors to real backend
pipelines where supported.

These features remain outside the default render pipeline. Applications opt in
through capability-gated descriptors and shader entry points.

## Phase 1: Vulkan Tessellation Lowering

- Lower tessellation descriptors to Vulkan pipeline state.
- Add `VulkanTessellationLowering` metadata for patch control points, domain,
  and partition mode.

See `phase1.md`.

## Phase 2: Metal Tessellation Lowering

- Lower tessellation descriptors to Metal pipeline state and draw calls.
- Add `MetalTessellationLowering` metadata including factor-buffer requirement.

See `phase2.md`.

## Phase 3: Vulkan Mesh / Task Shader Lowering

- Lower mesh and task shader descriptors to Vulkan mesh shader pipelines.
- Add `VulkanMeshPipelineLowering` metadata for mesh/task entry points and
  threadgroup sizes.

See `phase3.md`.

## Phase 4: Metal Object / Mesh Function Path

- Use Metal object or mesh function paths where supported.
- Add `MetalMeshPipelineLowering` metadata for mesh/object function mapping.

See `phase4.md`.

## Phase 5: Slang Entry / Reflection Alignment

- Align Slang stages and reflection data for tessellation and mesh pipelines.
- Extend `ShaderStage` and Slang profile mapping for tessellation control,
  tessellation evaluation, mesh, and task stages.

See `phase5.md`.

## Phase 6: Tessellation And Mesh Examples

- Add examples that prove both advanced geometry paths.
- Add feature-gated `examples/tessellation` and `examples/mesh_shader`.

See `phase6.md`.
