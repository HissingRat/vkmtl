# Period 40: Advanced Geometry Draw Paths

Status: planned after Period39.

Goal: turn tessellation and mesh/task shader support from descriptor/lowering
probes into real draw paths with backend-native execution where supported.

## Expected Result

After Period40, `examples/tessellation` and `examples/mesh_shader` should no
longer be descriptor-only probes. They should render visible output on
supported backends, or report exact unsupported reasons on backends that cannot
execute the feature.

## Phase Plan

### Phase 1: Tessellation Public Pipeline Contract

- Define public tessellation shader stage and pipeline descriptors.
- Define patch topology, factor buffers, and validation rules.
- Preserve existing non-tessellated render pipelines.

### Phase 2: Vulkan Tessellation Draw Path

- Lower tessellation stages to Vulkan pipeline state.
- Encode patch draws through public command APIs.
- Add visible tessellation example output.

### Phase 3: Metal Tessellation Draw Path Or Unsupported Contract

- Lower to Metal tessellation where supported.
- Define factor-buffer ownership and encoding.
- Report precise unsupported reasons where the backend cannot execute it.

### Phase 4: Vulkan Mesh/Task Shader Draw Path

- Lower mesh/task shader descriptors to Vulkan mesh shader pipelines.
- Encode mesh dispatch/draw commands.
- Add visible mesh shader example output.

### Phase 5: Metal Object/Mesh Equivalent Path Or Unsupported Contract

- Map to Metal object/mesh style capabilities where available.
- Keep naming and public API backend-neutral.
- Report precise unsupported reasons where unavailable.

### Phase 6: Advanced Geometry Examples And Validation

- Convert advanced geometry examples from probes to visible output.
- Add backend matrix entries for supported and unsupported paths.
- Keep examples using public vkmtl APIs only.

## Acceptance

- Advanced geometry examples render visible output on at least one supported
  backend path.
- Unsupported backends return typed feature-gate errors.
- The public API remains backend-neutral.
