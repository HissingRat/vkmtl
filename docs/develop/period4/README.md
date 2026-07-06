# Period 4: Shader And Binding

Goal: make Slang, reflection, and the binding model strong enough for real
projects.

Period 4 implements the binding model after Period 2 has defined the core
terminology. Cache key requirements can be defined here, but the shared object
cache is handled in Period 8.

## Phase 0: Shader And Binding Contract

- Keep Slang as the only source shader language.
- Keep shader compilation and reflection replaceable behind the shader module.
- Stabilize vkmtl reflection schema before adding more automatic derivation.
- Add advanced binding features as validation/API shape first, then lower them
  behind capability gates.

Decision notes: `phase0.md`.

## Phase 1: Binding Model Implementation

- Implement group, binding, visibility, and resource type mapping.
- Keep texture and sampler binding semantics explicit.
- Map bind groups to Vulkan descriptor sets.
- Map bind groups to Metal binding slots and future argument-buffer paths.
- Keep backend differences behind capability gates.

Decision notes: `phase1.md`.

## Phase 2: Shader Library / Module Manager

- Manage multiple shader modules.
- Manage multiple entry points.
- Support compile options.
- Support include paths.
- Support debug and release shader compile configuration.
- Define local cache key requirements for later Period 8 cache integration.

Decision notes: `phase2.md`.

## Phase 3: Reflection Schema Stabilization

- Stabilize the internal reflection model.
- Export reflection JSON.
- Version the reflection schema.
- Generate bind group layouts from Slang reflection.
- Allow manual reflection overrides where needed.

Decision notes: `phase3.md`.

## Phase 4: Bind Group Layout Completeness

- Uniform buffers.
- Storage buffers.
- Sampled textures.
- Storage textures.
- Samplers.
- Compare samplers.
- Resource arrays.
- Dynamic buffer bindings.
- Backend capability gates.

Decision notes: `phase4.md`.

## Phase 5: Dynamic Offsets / Small Constants

- Map Vulkan dynamic offsets and Metal buffer offsets into a portable API.
- Validate alignment.
- Support per-draw and per-dispatch small data updates.

Decision notes: `phase5.md`.

## Phase 6: Push Constants / Root Constants Equivalent

- Provide a capability-gated portable API.
- Use Vulkan push constants where available.
- Use Metal small buffers, `setBytes`, or inline constant equivalents.
- Expose size limits through `device.limits()`.

Decision notes: `phase6.md`.

## Phase 7: Shader Specialization

- Support specialization constants or Slang equivalent mechanisms.
- Include specialization data in pipeline cache keys.
- Gate backend differences through capabilities.

Decision notes: `phase7.md`.
