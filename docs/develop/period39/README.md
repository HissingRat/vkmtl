# Period 39: Ray Tracing Completeness

Status: in progress.

Goal: move ray tracing beyond the Period35 shared-scene-data slice into the
broader feature set: mixed mesh/procedural TLAS dispatch, Metal procedural
intersection tables, ray query, acceleration-structure updates, compaction,
many-instance TLAS, and complex shader binding table layouts.

## Expected Result

After Period39, vkmtl should support the common native RT maintenance, parity,
and scale paths needed by real engines: mixed triangle/procedural scenes,
driver-level Metal procedural intersection functions, updating or refitting
acceleration structures, compacting them where supported, building
many-instance TLAS layouts, using ray query where available, and validating
larger SBT layouts.

## Phase Plan

### Phase 1: AS Update, Refit, And Compaction Contract

- Done. `AccelerationStructureMaintenanceDescriptor` and
  `AccelerationStructureMaintenancePlan` define update, refit, and compaction
  planning.
- Done. Vulkan and Metal native feature reports expose fine-grained gates for
  update, refit, and compaction while usable features remain conservative.
- Done. Existing build-only AS paths are unchanged.

### Phase 2: Many-Instance TLAS And Instance Metadata

- Add stress coverage for many TLAS instances.
- Validate transforms, masks, custom indices, and material lookup metadata.
- Keep instance buffer layout backend-neutral.
- Close the Period35 deferred mixed mesh/procedural scene path: room mesh
  geometry and procedural sphere geometry in one logical dispatch.
- Bind driver-level Metal procedural sphere intersection functions where
  supported, and report typed unsupported reasons where unavailable.

### Phase 3: Ray Query Where Supported

- Define shader and pipeline requirements for ray query.
- Lower to Vulkan ray query where supported.
- Document Metal support or unsupported behavior precisely.

### Phase 4: Complex SBT Layouts And Callable Records

- Support larger miss/hit group layouts.
- Add callable shader records where the backend supports them.
- Validate SBT alignment and stride limits under stress.
- Validate hit group offsets for mixed triangle/procedural geometry, including
  the Metal procedural function-table lowering path.

### Phase 5: RT Stress Examples And Validation

- Add deterministic RT stress cases beyond the reference scene.
- Validate AS update/compaction and SBT stress on supported devices.
- Update device matrix with RT feature coverage.

## Acceptance

- RT maintenance APIs are capability-gated and typed.
- Many-instance TLAS and complex SBT examples run where supported.
- Unsupported RT features report actionable blockers.
- The Period35 deferred mixed TLAS / Metal procedural table work is either
  driver-backed on supported devices or blocked by precise capability reports.
