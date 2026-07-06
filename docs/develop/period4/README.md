# Period 4: Shader And Binding

Goal: make Slang, reflection, and the binding model strong enough for real
projects.

Period 4 implements the binding model after Period 2 has defined the core
terminology. Cache key requirements can be defined here, but the shared object
cache is handled in Period 8.

## Phase 1: Binding Model Implementation

- Implement group, binding, visibility, and resource type mapping.
- Keep texture and sampler binding semantics explicit.
- Map bind groups to Vulkan descriptor sets.
- Map bind groups to Metal binding slots and future argument-buffer paths.
- Keep backend differences behind capability gates.

## Phase 2: Shader Library / Module Manager

- Manage multiple shader modules.
- Manage multiple entry points.
- Support compile options.
- Support include paths.
- Support debug and release shader compile configuration.
- Define local cache key requirements for later Period 8 cache integration.

## Phase 3: Reflection Schema Stabilization

- Stabilize the internal reflection model.
- Export reflection JSON.
- Version the reflection schema.
- Generate bind group layouts from Slang reflection.
- Allow manual reflection overrides where needed.

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

## Phase 5: Dynamic Offsets / Small Constants

- Map Vulkan dynamic offsets and Metal buffer offsets into a portable API.
- Validate alignment.
- Support per-draw and per-dispatch small data updates.

## Phase 6: Push Constants / Root Constants Equivalent

- Provide a capability-gated portable API.
- Use Vulkan push constants where available.
- Use Metal small buffers, `setBytes`, or inline constant equivalents.
- Expose size limits through `device.limits()`.

## Phase 7: Shader Specialization

- Support specialization constants or Slang equivalent mechanisms.
- Include specialization data in pipeline cache keys.
- Gate backend differences through capabilities.
