# Period 52: Ray Tracing Breadth

Status: complete.

Goal: extend the existing native ray-tracing vertical slice through executable
ordinary acceleration-structure maintenance and geometry breadth, while
closing shader-table, inline-query, motion, and Metal 4 contracts that the
current shader/build/runtime model cannot execute exactly.

## Phase Plan

### Phase 1: Contract And Capability Allocation

- Audit every Period 52 route against executable backend code.
- Allocate maintenance resources under `ray_tracing` without adding root,
  `Device`, or `WindowContext` names.
- Separate usable capabilities from native API availability and planning.

See `phase1.md`.

### Phase 2: Native AS Maintenance

- Execute build-update, update/refit, and compact commands on both backends.
- Preserve allow-update/allow-compaction native build flags and exact build
  and update scratch sizes.
- Validate source, destination, scratch, backend, alignment, and lifetime.

See `phase2.md`.

### Phase 3: Ordinary Geometry And Instance Breadth

- Execute Metal AABB BLAS input in addition to triangle input.
- Size Metal BLAS allocation/scratch for the maximum ordinary triangle/AABB
  form admitted by the descriptor.
- Build Metal TLAS objects from multiple distinct BLAS sources.

See `phase3.md`.

### Phase 4: Advanced RT Closure Decisions

- Close Metal function/intersection tables, Vulkan inline ray query, callable
  and complex SBT execution, motion/curve geometry, and Metal 4 descriptors.
- Preserve planning records as diagnostics only and keep usable feature bits
  false for every closed path.
- Query Vulkan ray-query native availability independently from the RT
  pipeline extension.

See `phase4.md`.

### Phase 5: Evidence And Inventory Closeout

- Add a headless public maintenance/geometry stress example.
- Record physical Metal evidence and a Vulkan rerun command without upgrading
  the latter to physical evidence on this host.
- Update public and semantic inventories, routing, checklist, roadmap, and
  validation matrix.

See `phase5.md` and `closeout.md`.

## Public API Allocation

- `ray_tracing.AccelerationStructureMaintenanceResources` owns maintenance
  source/destination/scratch resources.
- `CommandBuffer.encodeAccelerationStructureMaintenance(...)` owns command
  encoding, next to the existing build and ray-dispatch commands.
- `AccelerationStructure` exposes maintenance count and recorded/submitted
  evidence in the same diagnostic style as its existing build evidence.
- `AccelerationStructureBuildPlan.allow_update` and
  `AccelerationStructureMaintenancePlan.scratch_alignment` make native
  lowering and resource validation explicit.
- No root declaration, `Device` method, `WindowContext` method, handle name, or
  shader-manifest schema changes.

All additions are source-compatible and target the additive `v0.2.0` surface.

## Exact Boundaries

- Compact copy is executable, but vkmtl has no post-build compacted-size query
  result object. Destination allocation therefore uses an explicit safe upper
  bound; compacted-size query is a separate unsupported semantic.
- Metal AABB creation is executable. Metal custom intersection dispatch is
  not: schema 2 embeds Metal ray-generation MSL but no linked intersection
  function artifact or table binding layout.
- Vulkan ray-query availability is diagnostic only. The current ordinary
  render/compute binding contract cannot bind an acceleration structure, so
  `features().ray_query` remains false.
- Callable and complex SBT plans do not create callable artifacts, multiple
  native group programs, record payloads, or a nonzero callable region. They
  remain planning-only and are not executable support.
- Motion, curves, row-major advanced geometry, and Metal 4 AS descriptors have
  no admitted cross-backend resource/layout contract and are rejected rather
  than approximated.
