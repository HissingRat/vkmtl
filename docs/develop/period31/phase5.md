# Phase 5: Present Ray Tracing Output

Phase 5 presents the ray tracing output texture to the example window.

## Scope

- Reuse existing vkmtl texture/render presentation paths where possible.
- Draw or copy the ray tracing output into the current drawable.
- Keep resize behavior predictable for the example.
- Make the triangle visible against a contrasting background.

## Acceptance

- `zig build run-ray-traced-triangle` opens a window and shows the ray traced
  triangle on supported Metal devices.
- The example output no longer reports `driver_pixels=deferred_period31_plus`
  on supported devices.
- Unsupported devices still report a clear feature-gate message.

## Deferred

- Advanced denoising, camera controls, materials, and scene complexity are
  outside this phase.

