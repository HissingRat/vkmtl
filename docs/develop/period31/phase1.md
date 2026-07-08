# Phase 1: Example Contract And Capability Gate

Phase 1 turns `examples/ray_traced_triangle` into a hard visual contract instead
of a runtime-record smoke test.

## Scope

- Define the expected window result for supported Metal devices.
- Keep unsupported devices on clear feature-gated exits.
- Keep the example importing only public vkmtl modules and the external window
  helper.
- Preserve existing backend-private runtime record checks as diagnostics, not
  as the final success condition.

## Acceptance

- The example text and docs say that success means visible ray traced pixels in
  the window.
- The example still builds on machines without Metal ray tracing support.
- Unsupported devices do not panic and do not claim success.

## Non-Goals

- Do not add Vulkan ray tracing execution in this phase.
- Do not add broad ray tracing shader model parity in this phase.

