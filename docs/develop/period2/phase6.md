# Phase 6: Multi-Surface / Multi-Window

Phase 6 adds the backend-neutral management shape for multiple surfaces before
the native runtime owns multiple swapchains from one long-lived device.

## First Slice

- Add `SurfaceHandle`.
- Add `SurfaceCollection`.
- Allow one selected backend to track multiple neutral surfaces.
- Let each tracked surface own its own `PresentationDescriptor` state.
- Support resize and remove through handles.

## Current Limits

- `SurfaceCollection` is descriptor/runtime-state management, not native
  multi-swapchain creation yet.
- `WindowContext` still owns one native presentation chain.
- `DeviceFeatures.multi_surface` remains the feature gate for complete native
  support.

## Rules

- `WindowContext` is a convenience owner, not the long-term `Device`.
- Multi-window applications should be modeled as one `Device` with many
  surfaces/swapchains once native support lands.
- Handles include a generation so stale removed-surface handles fail
  validation.
