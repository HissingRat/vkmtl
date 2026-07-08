# Phase 5: Mesh And Task Shader Backend

Phase 5 lowers mesh/task shader pipeline descriptors.

## Scope

- Lower Vulkan mesh/task shader paths where extensions are available.
- Define Metal object/mesh function mapping where available.
- Keep classic vertex pipeline untouched.

## Validation

- Add feature-gated pipeline tests.
- Add a small mesh-shader example where supported.

## Result

- Added the backend-tagged `MeshPipelineLowering` plan type.
- Added `Device.planMeshPipelineLowering(...)`, which uses native feature
  reports while keeping ordinary public validation capability-gated.
- Preserved Vulkan task/mesh metadata and Metal object/mesh metadata behind the
  unified plan.
- Added runtime tests that prove native mesh/task planning can be inspected
  before the public feature is marked usable.

## Deferred

- Native mesh/task pipeline creation, shader stage attachment, and executable
  mesh draw/dispatch commands remain deferred to Period 29 Phase 5.
