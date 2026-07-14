# Period 51: Advanced Rasterization And Geometry

Status: complete.

Goal: execute the geometry paths that the pinned shader toolchain can lower
exactly, and close the remaining advanced raster semantics without upgrading a
native API or planning-only declaration into executable support.

Period 51 begins with the eight rows routed by the Period 45 audit. A row may
close through native execution, an exact composition, or a precise unsupported
decision tied to the current public shader and render-pass contracts.

## Phase Plan

### Phase 1: Contract Allocation And Compiler Audit

- Probe the pinned Slang compiler for tessellation, mesh, and amplification
  artifacts on both targets.
- Allocate advanced shader and pipeline creation below canonical domain
  facades, without growing the guarded root, `Device`, or `WindowContext`
  sets.
- Split native-device availability from complete shader-to-command execution.

See `phase1.md`.

### Phase 2: Executable Vulkan Tessellation

- Precompile vertex, hull, domain, and fragment SPIR-V artifacts.
- Enable native tessellation, create patch-list pipelines, and issue patch
  draws.
- Keep Metal tessellation closed until the Slang-only artifact contract can
  produce the required Metal stages.

See `phase2.md`.

### Phase 3: Executable Mesh Shading And Task/Object Decision

- Precompile mesh and fragment artifacts and audit optional amplification/task
  artifacts.
- Create native Metal mesh and Vulkan `VK_EXT_mesh_shader` pipelines.
- Dispatch native mesh threadgroup/task grids behind complete feature and limit
  gates.

See `phase3.md`.

### Phase 4: Advanced Raster Decisions

- Decide variable rasterization rate, tile/imageblock, raster ordering,
  layered/amplified rendering, logical attachment mapping, depth clip, sample
  positions, and related dynamic raster controls.
- Implement only cross-backend contracts whose observable meaning and shader,
  pass, and coordinate ownership are exact.
- Record precise unsupported outcomes for the remaining rows.

See `phase4.md`.

### Phase 5: Evidence And Semantic Closeout

- Add visible public examples and deterministic rejection/limit tests.
- Update both semantic inventories, routing, public API inventory,
  compatibility docs, matrices, roadmap, and checklist.
- Run API/backend validation and publish exact physical evidence only for paths
  exercised on suitable devices.

See `phase5.md`.

## Public API Allocation

- No new root declaration, public `Device` method, `WindowContext` method, or
  opaque runtime-handle name.
- Manifest schema 2 adds `tessellation_shaders` and `mesh_shaders`; schema 1
  remains accepted unchanged.
- `shader` owns compiled tessellation/mesh artifacts and free compile
  operations. `render` owns advanced pipeline descriptors and free pipeline
  creation operations.
- The existing `RenderPipelineState` remains the opaque pipeline handle.
  `RenderCommandEncoder` gains capability-gated patch and mesh dispatch
  methods.
- Additive descriptor, feature, limit, method, error, and manifest-schema
  declarations target `v0.2.0`. No `v0.1.x` declaration is removed or renamed.

## Explicit Boundaries

- Slang 2026.12.2 emits Vulkan hull/domain SPIR-V but rejects hull/domain for
  the Metal target. Metal's tessellation API surface exists, but vkmtl cannot
  execute it under the current Slang-only artifact contract.
- The same compiler emits both Vulkan mesh SPIR-V and Metal `[[mesh]]` source.
  Mesh execution may open independently on each backend after the complete
  pipeline and command path is present.
- Vulkan task support and Metal object/amplification support are separate
  gates. Slang 2026.12.2 crashed in both task-stage probes, so both usable gates
  remain false even when native device bits are true.
- The executable advanced geometry subset keeps tessellation-control,
  tessellation-evaluation, mesh, and task stages resource-free. The current
  `ShaderVisibility` contract does not claim bindings or root constants for
  those stages; fragment-stage resources retain the ordinary render path.
- Metal 4 render pipelines and encoders remain owned by Period 54.
- Tile/imageblock, raster-order/programmed blend, layered view amplification,
  logical attachment remapping, rasterization-rate coordinate transforms, and
  programmable sample locations are not approximated by unrelated subpasses,
  compute dispatches, multiview, or shading-rate extensions.

See `closeout.md` for exact executable, unsupported, and physical-evidence
outcomes.
