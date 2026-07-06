# Phase 3: Multi-Window Examples

Phase 3 defines multi-window example coverage and keeps it gated behind the
runtime multi-surface capability.

## First Slice

- Add planning metadata for single-device multi-surface, multiple swapchain,
  resize, and surface-lost examples.
- Keep native execution gated by `DeviceFeatures.multi_surface`.
- Document the current `SurfaceCollection` limit.

## Current Limits

- Planned multi-window cases are recorded in `src/development_matrix.zig`.
- Every case is gated by `DeviceFeatures.multi_surface`.
- Native multiple swapchain creation remains future backend work.
