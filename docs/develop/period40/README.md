# Period 40: Advanced Geometry Draw Paths

Status: complete for public contracts and planning examples.

Goal: turn tessellation and mesh/task shader support from descriptor/lowering
probes into public draw/dispatch planning contracts, with remaining native
backend hooks clearly tracked.

## Expected Result

After Period40, `examples/tessellation` and `examples/mesh_shader` are no
longer descriptor-only probes. They exercise public patch-draw and mesh-dispatch
planning APIs, report exact unsupported reasons on backends that cannot execute
the feature, and identify the remaining native backend hooks needed for visible
output.

## Phase Plan

### Phase 1: Tessellation Public Pipeline Contract

- Define public tessellation shader stage and pipeline descriptors.
- Define patch topology, factor buffers, and validation rules.
- Preserve existing non-tessellated render pipelines.

Phase 1 result:

- `TessellationShaderStageDescriptor` names control/evaluation entry points
  without exposing backend shader objects.
- `TessellationPatchDrawDescriptor` describes patch-list draws, instance
  counts, base patch/instance offsets, and optional factor-buffer metadata.
- `TessellationDrawPlan` validates the descriptor and records backend-neutral
  lowering metadata for later Vulkan/Metal command paths.
- Existing non-tessellated render pipelines and `drawPrimitives` APIs are
  unchanged.

### Phase 2: Vulkan Tessellation Draw Planning

- Lower tessellation stages to Vulkan draw metadata.
- Encode patch draw parameters through public planning APIs.
- Track visible tessellation output as native pipeline hook work.

Phase 2 result:

- `VulkanTessellationDrawLowering` converts a validated neutral patch draw
  plan into Vulkan-style patch-list draw metadata: patch control points,
  vertex count, instance count, first vertex, and first instance.
- `Device.planVulkanTessellationPatchDraw(...)` exposes this path without
  leaking Vulkan handles or `vulkan-zig` types into the public API.
- Visible Vulkan tessellation output still requires the native render pipeline
  hook that consumes tessellation shader artifacts and the draw lowering in the
  backend command encoder. That remains the executable rendering gap for
  Phase 6 / Period44 device-matrix validation.

### Phase 3: Metal Tessellation Draw Path Or Unsupported Contract

- Lower to Metal tessellation where supported.
- Define factor-buffer ownership and encoding.
- Report precise unsupported reasons where the backend cannot execute it.

Phase 3 result:

- `MetalTessellationDrawLowering` records patch metadata plus Metal-specific
  factor-buffer ownership.
- Factor buffers can be application-provided through
  `TessellationFactorBufferDescriptor` or represented as vkmtl-generated
  metadata when omitted.
- Backend mismatch and unavailable tessellation support use typed
  `UnsupportedTessellation`; invalid factor-buffer shape uses
  `InvalidTessellationFactorBuffer`.

### Phase 4: Vulkan Mesh/Task Shader Dispatch Planning

- Lower mesh/task shader descriptors to Vulkan mesh dispatch metadata.
- Encode mesh dispatch parameters through public planning APIs.
- Track visible mesh shader output as native pipeline hook work.

Phase 4 result:

- `MeshDispatchDescriptor` combines a mesh/task pipeline descriptor with
  backend-neutral threadgroup counts.
- `MeshDispatchPlan` validates mesh/task feature gates and records total
  threadgroups.
- `VulkanMeshDispatchLowering` exposes Vulkan-style draw-mesh-task command
  metadata while keeping raw Vulkan symbols out of the public API.
- Visible Vulkan mesh/task output still requires native mesh pipeline creation
  and backend command encoder hooks.

### Phase 5: Metal Object/Mesh Equivalent Path Or Unsupported Contract

- Map to Metal object/mesh style capabilities where available.
- Keep naming and public API backend-neutral.
- Report precise unsupported reasons where unavailable.

Phase 5 result:

- `MetalMeshDispatchLowering` maps the public mesh/task model to Metal
  mesh/object metadata.
- `Device.planMetalMeshDispatch(...)` keeps the entry point names, threadgroup
  counts, and object-stage metadata behind backend-neutral public descriptors.
- Backend mismatches and unavailable mesh support return typed
  `UnsupportedMeshShaders` / `UnsupportedTaskShaders` errors.

### Phase 6: Advanced Geometry Examples And Validation

- Convert advanced geometry examples from descriptor-only probes to public
  draw/dispatch planning examples.
- Add backend matrix entries for supported and unsupported paths.
- Keep examples using public vkmtl APIs only.

Phase 6 result:

- `examples/tessellation` now calls `Device.planTessellationPatchDraw(...)`
  and backend-specific public lowering helpers.
- `examples/mesh_shader` now calls `Device.planMeshDispatch(...)` and
  backend-specific public lowering helpers.
- `tools/development_matrix.zig` records the difference between portable
  planning contracts and deferred native executable pipeline hooks.

## Acceptance

- Advanced geometry examples use public draw/dispatch planning APIs and return
  typed feature-gate errors when unsupported.
- The public API remains backend-neutral.
- Visible advanced-geometry output is still blocked on native tessellation and
  mesh/task pipeline hooks in the backend command encoders.
