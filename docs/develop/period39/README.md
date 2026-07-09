# Period 39: Ray Tracing Completeness

Status: completed portable RT completeness contract.

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

- Done. `TopLevelAccelerationStructureInstanceDescriptor` and
  `TopLevelAccelerationStructureLayoutDescriptor` describe many-instance TLAS
  metadata without baking in any example scene.
- Done. Transforms, masks, custom indices, SBT record offsets, material
  metadata, and mixed triangle/procedural geometry are validated through
  backend-neutral plans.
- Done. Mixed mesh/procedural TLAS requirements are explicit:
  procedural AABB instances require procedural geometry and custom intersection
  feature gates. Driver-level Metal procedural sphere intersection function
  execution remains backend/device evidence work unless the selected adapter
  reports support and the backend path binds it.

### Phase 3: Ray Query Where Supported

- Done. `RayQueryDescriptor` defines shader-stage, traversal-depth,
  procedural, and candidate-intersection requirements.
- Done. `RayQueryPlan` lowers to Vulkan ray query when the selected native
  feature report exposes `ray_query`.
- Done. Metal ray query currently reports typed unsupported behavior because
  there is no direct portable equivalent in this abstraction layer.

### Phase 4: Complex SBT Layouts And Callable Records

- Done. `ComplexShaderBindingTableDescriptor` plans larger miss/hit/callable
  layouts on top of the existing SBT descriptor.
- Done. Callable records are gated by
  `DeviceFeatures.ray_tracing_callable_shaders`.
- Done. SBT alignment, stride, total record limits, hit group offsets, and
  procedural hit ranges are validated before native dispatch.

### Phase 5: RT Stress Examples And Validation

- Done. `RayTracingStressDescriptor` and `RayTracingStressPlan` combine AS
  maintenance, TLAS metadata, complex SBT layout, optional ray query, dispatch
  dimensions, and iteration count into deterministic validation data.
- Done. AS maintenance and SBT stress are covered by unit tests and device
  planning APIs. Native GPU stress evidence remains Period44 work on supported
  devices.
- Done. Device and validation matrices include Period39 RT coverage.

## Acceptance

- RT maintenance APIs are capability-gated and typed.
- Many-instance TLAS and complex SBT planning APIs are backend-neutral and
  tested.
- Unsupported RT features report actionable blockers.
- Mixed TLAS and procedural-table requirements are explicit public data; native
  driver evidence remains tied to feature reports and Period44 device runs.
