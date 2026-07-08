# Phase 1: Acceleration Structures

Phase 1 lowers acceleration structure descriptors.

## Scope

- Lower bottom-level and top-level acceleration structures.
- Define geometry, instance, scratch, and build/update descriptors.
- Validate memory, alignment, and build flags.

## Validation

- Add descriptor tests for invalid geometry and build flags.
- Add backend capability gates.

## Result

- Added `AccelerationStructureGeometryDescriptor`,
  `AccelerationStructureBuildDescriptor`, and `AccelerationStructureBuildPlan`.
- Added build/update mode, build flags, geometry count, scratch alignment, and
  build-size planning.
- Added `Device.planAccelerationStructureBuild(...)`, which uses native feature
  reports while keeping ordinary public validation capability-gated.
- Added focused tests for geometry validation, scratch alignment, update
  planning, and native-feature planning through `Device`.

## Deferred

- Native acceleration-structure object allocation and backend build/update
  command lowering are deferred to Period 29 Phase 1.
