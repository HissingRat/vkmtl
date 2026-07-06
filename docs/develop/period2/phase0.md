# Phase 0: Core Architecture Specs

Phase 0 defines the long-term runtime ownership model before broad API
expansion.

## Ownership Model

- `Device` owns backend device-level resource creation.
- `Queue` owns submission and queue-level synchronization.
- `Surface` / `Swapchain` own presentation acquisition, drawable state, resize,
  and present semantics.
- `WindowContext` remains as an early convenience owner while the public API is
  migrated. It should delegate to `Device` and `Queue` instead of being the
  permanent resource owner.
- Runtime resources are children of a `Device` unless a later spec explicitly
  assigns them to another owner.

## Lifetime Model

- Child resources must be released before the parent owner is destroyed.
- Debug builds should diagnose unreleased resources.
- Period 2 should add a deferred-destruction strategy before vkmtl allows
  resources to be destroyed while submitted GPU work may still reference them.
- Native-handle escape hatches must document lifetime and threading hazards.

## Binding Terminology

- A bind group is the portable unit of shader resource binding.
- A bind group layout describes resource type, visibility, binding index, and
  dynamic-offset behavior.
- Vulkan maps bind groups to descriptor sets.
- Metal maps bind groups to explicit slots first, with argument buffers reserved
  for a later advanced path.

## Command And Sync Principles

- The default API should track common resource usage automatically.
- Vulkan backends should derive required barriers from usage tracking.
- Metal backends should use encoder boundaries and usage hints where possible.
- Manual barriers are an advanced escape hatch, not the normal user path.

## Capability Gates

- Advanced behavior must be guarded by `features`, `limits`, and format
  capability queries.
- Unsupported features should fail early with clear errors.
- Backend-specific features belong in optional modules or explicit escape
  hatches.
