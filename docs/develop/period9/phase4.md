# Phase 4: Native Interop Examples

Phase 4 defines explicit native interop examples without letting ordinary
examples depend on backend-private modules.

## First Slice

- Add planning metadata for Vulkan handles, Metal handles, external texture
  interop, and native command insertion.
- Keep native interop examples explicit and advanced.
- Document that ordinary examples should stay portable.

## Current Limits

- Planned native interop cases are recorded in `tools/development_matrix.zig`.
- Vulkan and Metal native-handle examples use `DeviceFeatures.native_handles`.
- External texture and native command insertion examples remain planned gates.
- Existing native handle access is borrowed and advanced; external texture and
  native command insertion are planned coverage.
