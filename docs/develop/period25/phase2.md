# Phase 2: Present Modes And Frame Pacing

Phase 2 exposes presentation behavior explicitly.

## Scope

- Add present mode / vsync configuration.
- Map Vulkan present modes.
- Map Metal display-sync behavior.
- Add frame pacing diagnostics.

## Validation

- Add docs for backend-specific present-mode availability.
- Add example output that reports selected mode.

## Result

- `PresentModeSupport.resolveWithDiagnostics(...)` returns the requested mode,
  selected fallback mode, support table, vsync intent, and fallback status.
- `Device.presentModeSupport()`, `Device.resolvePresentMode(...)`,
  `WindowContext.presentModeSupport()`, and
  `WindowContext.resolvePresentMode(...)` expose conservative runtime support.
- `FramePacingDiagnostics` records configured state, extent, selected present
  mode, vsync intent, generation, frame-in-flight state, and submitted /
  completed frame serials.
- `SurfaceCollection.framePacingDiagnostics(...)` reports diagnostics per
  surface handle, keeping multi-surface counters independent.
- Native Vulkan present-mode enumeration per surface and Metal display-sync
  mapping remain deferred to Period 29 Phase 5, where platform-specific native
  escape hatches and surface ownership are finalized.
