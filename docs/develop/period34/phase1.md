# Phase 1: Procedural Geometry Contract

Phase 1 defines how procedural spheres enter vkmtl without destabilizing the
mesh scene from Period33.

## Checklist

- [x] Define the procedural sphere descriptor shape as AABB build input plus
  primitive-id sphere lookup in the example shader.
- [x] Define feature gates for procedural RT geometry and custom intersection.
- [x] Decide fallback behavior when a backend lacks procedural support.
- [x] Keep mesh geometry support from Period33 unchanged.
- [x] Define success markers for procedural native RT output.

## Acceptance

- vkmtl can distinguish mesh scene success from procedural scene success.
- Unsupported procedural paths return typed errors before command submission.
- Docs say that Period34 closes Vulkan procedural sphere parity and routes
  Metal procedural parity to Period35.
