# Phase 4: Unsupported Feature Validation

Phase 4 makes advanced API failures predictable.

## Scope

- Check advanced descriptors against selected-device features before creating
  backend-native objects.
- Check descriptor counts, alignments, page sizes, and stage visibility against
  selected-device limits.
- Return typed unsupported-feature errors for optional modules.

## Validation

- Tests should cover one unsupported path per advanced module.
- Error messages should identify the feature or limit that blocked creation.

## Current Status

- `Device` exposes validation helpers for descriptor indexing, sparse mapping,
  external textures/semaphores, tessellation, mesh pipelines, acceleration
  structures, ray tracing pipelines, shader binding tables, and driver pipeline
  caches.
- These helpers validate against the selected device's capability snapshot and
  return precise typed unsupported-feature errors before backend lowering.
