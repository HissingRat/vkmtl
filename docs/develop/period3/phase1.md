# Phase 1: Buffer Completeness

Phase 1 makes buffer CPU visibility and range validation explicit.

## First Slice

- Add descriptor helpers for resolved storage mode and CPU visibility.
- Add buffer mapping descriptors for explicit read/write ranges.
- Add runtime map/unmap wrappers where the backend can expose CPU-visible
  memory.
- Keep `replaceBytes(...)` and `readBytes(...)` as convenience helpers.
- Document that private buffers require transfer/staging paths instead of CPU
  mapping.

## Current Limits

- Mapping is for CPU-visible buffers only.
- Persistent coherent mapping policy remains backend-owned.
- Explicit staging allocators and ring uploaders are future utility layers.
