# Phase 1: Vulkan Capability Query

Phase 1 makes Vulkan feature reporting backend-native instead of static.

## Scope

- Query core physical-device features and limits.
- Query required optional extensions for descriptor indexing, sparse resources,
  external memory/semaphores, mesh shaders, ray tracing, and pipeline cache.
- Map queue family capabilities into public queue feature data.
- Track MoltenVK extension gaps explicitly.

## Validation

- Unit tests should keep the mapping table complete.
- Backend smoke tests should print the queried features for the selected Vulkan
  adapter.
