# Period 51 Phase 3: Executable Mesh And Object/Task Shading

Status: complete.

## Metal

- Compile Slang mesh entries to MSL.
- Create `MTLMeshRenderPipelineDescriptor` state.
- Dispatch mesh threadgroups on a render encoder.

## Vulkan

- Query and enable `VK_EXT_mesh_shader` mesh/task feature bits separately.
- Build graphics pipelines with mesh, optional task, and fragment stages.
- Dispatch `vkCmdDrawMeshTasksEXT` grids within queried limits.

## Validation

- Require complete shader artifacts and compatible entry stages.
- Validate per-axis and total workgroup limits.
- Reject task/object artifacts when the backend only exposes mesh execution.
- Add a visible public mesh example and deterministic unsupported-device tests.

## Task/Object Boundary

The pinned Slang 2026.12.2 task/amplification probes crashed with status 139
for both SPIR-V and Metal targets. Native task/object capability is still
reported in `native_features`, but `features.task_shaders` remains false and
schema-2 entries with `task_entry` are not advertised as executable. This is a
compiler/artifact blocker, not a claim that the native APIs lack the feature.

Advanced mesh-stage resource binding is also outside the current
`ShaderVisibility` shape. The executable slice is a resource-free mesh stage
plus an ordinary optional fragment stage.
