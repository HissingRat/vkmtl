# Phase 6: Validation And Screenshot Gate

Phase 6 proves the Metal ray traced scene path is not just compiling.

Status: completed for the current visual acceptance slice.

## Scope

- Keep `zig build test` and `zig build` passing.
- Add focused tests for unsupported-device behavior and descriptor validation.
- Run `zig build run-ray-traced-scene` on supported local hardware.
- Capture or document the visible window result.

## Acceptance

- The example is visually verified on a supported Metal device.
- The validation notes include the command used and the observed result.
- The example remains buildable on hosts without Metal ray tracing support.
- Local screenshot: `/tmp/vkmtl-ray-scene-source-1to1-unorm.png`.
- Observed success text: `driver_pixels=visible_metal_ray_scene`.

## Deferred

- Automated CI GPU screenshots and broad device-matrix runs are Period32+
  validation work.
