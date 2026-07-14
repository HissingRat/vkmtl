# Period 51 Closeout

Status: complete.

## Executable Outcomes

- Vulkan tessellation: schema-2 vertex/control/evaluation/fragment SPIR-V,
  native tessellation feature enablement, patch-list pipeline creation, and
  `vkCmdDraw` patch dispatch behind feature and control-point limits.
- Metal mesh: schema-2 mesh/fragment MSL, native
  `MTLMeshRenderPipelineDescriptor`, and render-encoder mesh-threadgroup
  dispatch. A physical Apple M4 Pro run reached the visible render loop.
- Vulkan mesh: `VK_EXT_mesh_shader` query/enablement, mesh/fragment pipeline,
  queried workgroup/grid limits, and `vkCmdDrawMeshTasksEXT` dispatch. This host
  provides forced-build and deterministic validation evidence, not a physical
  Vulkan claim.

## Precise Unsupported Outcomes

- Metal tessellation is closed because the pinned Slang Metal target rejects
  hull/domain stages under the source-only artifact contract.
- Vulkan task and Metal object/amplification execution are closed because the
  pinned compiler crashed during both target probes. Native feature bits stay
  visible only through `native_features`; usable `task_shaders` stays false.
- Advanced-stage resource binding is not claimed until `ShaderVisibility`,
  reflection, Metal slot binding, and Vulkan stage flags form one complete
  contract.
- Rate maps, tile/imageblock memory, raster-order/programmed blend, layered
  amplification, logical attachment remapping, depth clip control, and
  programmable sample positions are unsupported for the reasons recorded in
  `phase4.md` and the semantic ledger.

## Evidence

- Manifest parser tests cover schema 1 compatibility, schema 2 arrays, and
  schema-1 rejection of advanced arrays.
- Core/backend tests cover stage validation, tessellation patches, mesh/task
  limits, mesh grids, usable/native feature separation, and closed raster
  feature names.
- `zig build run-mesh-shader` on Apple M4 Pro created and ran the native Metal
  path and printed `native_mesh_frame_submitted=metal` after the first submitted
  frame.
  `zig build run-capability-dump -- --backend=metal` reported usable mesh
  support and native-only task support.
- The full validation commands and exact commit are recorded with the Period
  51 commit rather than inferred from uncommitted state.
