# Phase 1: Multi-Surface Runtime

Phase 1 lets one device manage more than one presentation target.

## Scope

- Add device-owned surface registry.
- Support multiple Vulkan swapchains.
- Support multiple Metal drawable/layer states.
- Handle independent resize/minimize/surface-loss events.

## Validation

- Add a multi-window example.
- Add resize and close-order tests where possible.

## Result

- `Device.makeSurfaceCollection()` and `WindowContext.makeSurfaceCollection()`
  create backend-tagged `SurfaceCollection` registries.
- `SurfaceCollection` tracks independent presentation descriptors, resize
  state, frame state, generation handles, removal, and surface loss.
- `examples/multi_window` uses the public registry as a multi-surface smoke
  path.
- Native multiple-swapchain / multiple-`CAMetalLayer` execution remains
  capability-gated by `DeviceFeatures.multi_surface` and is deferred to Period
  28 Phase 5, where native advanced escape hatches and platform-specific
  surface ownership are closed.
