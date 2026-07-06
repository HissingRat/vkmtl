# Phase 2: Multiple Swapchain / Drawable State

Phase 2 creates separate presentation resources for each surface.

## Scope

- Support multiple Vulkan swapchains for one device.
- Support multiple Metal layers or drawable streams for one device.
- Keep per-surface extent, format, present mode, and frame-in-flight state.

## Validation

- Smoke tests should create two surfaces where the host windowing layer allows
  it.
- Unit tests should cover per-surface state isolation.
