# Period 39: Ray Tracing Completeness

Status: planned after Period38.

Goal: move ray tracing beyond the Period35 scene into the broader feature set:
ray query, acceleration-structure updates, compaction, many-instance TLAS, and
complex shader binding table layouts.

## Expected Result

After Period39, vkmtl should support the common native RT maintenance and scale
paths needed by real engines: updating or refitting acceleration structures,
compacting them where supported, building many-instance TLAS layouts, using ray
query where available, and validating larger SBT layouts.

## Phase Plan

### Phase 1: AS Update, Refit, And Compaction Contract

- Define update, refit, and compaction descriptors.
- Map Vulkan and Metal support levels through feature gates.
- Preserve existing build-only AS paths.

### Phase 2: Many-Instance TLAS And Instance Metadata

- Add stress coverage for many TLAS instances.
- Validate transforms, masks, custom indices, and material lookup metadata.
- Keep instance buffer layout backend-neutral.

### Phase 3: Ray Query Where Supported

- Define shader and pipeline requirements for ray query.
- Lower to Vulkan ray query where supported.
- Document Metal support or unsupported behavior precisely.

### Phase 4: Complex SBT Layouts And Callable Records

- Support larger miss/hit group layouts.
- Add callable shader records where the backend supports them.
- Validate SBT alignment and stride limits under stress.

### Phase 5: RT Stress Examples And Validation

- Add deterministic RT stress cases beyond the reference scene.
- Validate AS update/compaction and SBT stress on supported devices.
- Update device matrix with RT feature coverage.

## Acceptance

- RT maintenance APIs are capability-gated and typed.
- Many-instance TLAS and complex SBT examples run where supported.
- Unsupported RT features report actionable blockers.
