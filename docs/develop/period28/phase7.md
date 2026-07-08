# Phase 7: Advanced Examples

Phase 7 adds examples for completed advanced paths.

## Scope

- Add a minimal ray tracing example where supported.
- Add native-advanced examples only when they prove useful integration points.
- Keep examples separate from portable beginner examples.

## Validation

- Examples should build by default and run only when required capabilities are
  present.
- Unsupported backends should report clear feature-gate messages.

## Result

- Updated `examples/ray_traced_scene` to use Period 28 planning APIs:
  `Device.planAccelerationStructureBuild(...)`,
  `Device.planRayTracingPipelineLowering(...)`, `Device.planRayDispatch(...)`,
  and Metal mapping planning when Metal is selected.
- The example remains capability-gated through native feature reports and prints
  typed unsupported messages when the selected backend cannot plan ray tracing.
- Updated usage docs to describe the example as a planning/metadata sample.

## Deferred

- Executable native ray tracing and native advanced examples are deferred to
  Period 29 Phase 7.
