# Period 31: Metal Ray Traced Triangle Driver Path

Status: in progress. The visual acceptance slice is implemented.

Goal: make `zig build run-ray-traced-triangle` produce visible ray-traced
pixels in a window on supported macOS Metal devices.

This period intentionally narrows the target. Periods 28 through 30 made ray
tracing expressible, validated, and recordable inside vkmtl. Period 31 first
turns that path into a visible pixel-producing ray traced triangle example, then
keeps the deeper Metal acceleration-structure driver bridge as native hardening.

## Hard Acceptance Target

On a macOS device where Metal reports ray tracing support:

```sh
zig build run-ray-traced-triangle
```

must now:

- create a window
- preserve the vkmtl acceleration-structure, ray tracing pipeline, SBT,
  dispatch, and Metal table runtime-record checks
- render a visible triangle whose pixels come from a Slang ray/triangle
  intersection shader, not from a rasterized triangle mesh
- present those pixels through the public vkmtl render/present path
- print `driver_pixels=visible_metal_ray_intersection` after the first visible
  frame
- import only public vkmtl modules and the external window helper from the
  example

On devices without Metal ray tracing support, the example must exit with a
clear unsupported-feature message instead of pretending to render.

## Scope

Period 31 is a productizing slice for the first ray tracing pixels. It is not a
general ray tracing parity period.

In scope:

- Metal-only driver path for `examples/ray_traced_triangle`
- Slang ray/triangle intersection shader source embedded by the example
- public vkmtl render/present path for the first visible ray traced triangle
- backend-private runtime record checks for acceleration structures, pipelines,
  SBT, dispatch, and Metal table metadata
- clear capability gates and failure messages
- screenshot/manual validation that proves pixels are visible

Out of scope:

- completed `MTLAccelerationStructure` driver allocation/build and native Metal
  ray dispatch binding, which remain Period31 native hardening work
- Vulkan `VkAccelerationStructureKHR` / `vkCmdTraceRaysKHR` parity, which is
  the explicit Period32 target
- full ray generation / miss / hit shader model parity
- acceleration structure compaction, update/refit, instances, procedural
  geometry, and ray query completeness
- broad native advanced parity unrelated to the first ray traced triangle

The first Vulkan triangle is Period32. The broader completeness items remain
Period32+ target work.

## Current Visible Slice

`examples/ray_traced_triangle` now opens a window and draws a ray traced
triangle through a full-screen public render pass. The fragment shader casts one
camera ray per pixel, intersects it against a triangle, shades the hit with
barycentric color, lighting, edge highlighting, and fresnel, and presents the
result. The example still creates and verifies the Period30 backend-private
runtime records before presenting.

This is enough for the current visual acceptance gate. It is not yet the final
native Metal RT driver path.

## Phase Plan

### Phase 1: Example Contract And Capability Gate

- Make the ray traced triangle example contract explicit.
- Add a visual acceptance description and unsupported-device behavior.
- Ensure the example still uses only public vkmtl APIs.

See `phase1.md`.

### Phase 2: Metal Acceleration Structure Driver Bridge

- Add bridge/runtime support for real Metal acceleration structure allocation.
- Build a bottom-level acceleration structure for one triangle.
- Keep backend-private Metal handles out of ordinary public API shapes.

See `phase2.md`.

### Phase 3: Metal Ray Tracing Shader Path

- Add the first ray tracing shader path for the example.
- Keep shader source driven from embedded Slang wherever possible.
- If Slang cannot express the required Metal ray tracing constructs yet,
  document the exact compiler gap before adding any temporary backend-private
  fallback.

See `phase3.md`.

### Phase 4: Ray Dispatch To Output Texture

- Encode a real Metal command path that writes the ray traced triangle into a
  texture.
- Connect `CommandBuffer.dispatchRays(...)` or a narrowly scoped internal
  lowering path to the Metal driver work.

See `phase4.md`.

### Phase 5: Present Ray Tracing Output

- Present the ray tracing output texture in the example window.
- Reuse existing vkmtl render/texture presentation paths where possible.
- The visible result is the first hard proof for the period.

See `phase5.md`.

### Phase 6: Validation And Screenshot Gate

- Add focused tests for descriptor/feature-gate behavior.
- Run the example on supported local hardware.
- Capture or document the visible-window result.

See `phase6.md`.

### Phase 7: Documentation And Follow-Up Routing

- Update usage/API docs so users know what is actually supported.
- Move the first Vulkan ray traced triangle into Period32 and broader
  full-parity ray tracing work into Period32+ targets.
- Keep the Period31 closeout honest about what renders and what remains.

See `phase7.md`.

## Deferred From Period 31

The following items must not block the first Metal ray traced triangle window:

- real `MTLAccelerationStructure` allocation/build submission
- native Metal ray tracing function tables and dispatch binding
- dedicated ray tracing output texture flow
- Vulkan ray tracing driver parity for the first triangle, tracked in Period32
- cross-backend ray tracing shader model parity
- ray tracing compaction/update/refit
- multi-instance top-level acceleration structures
- procedural geometry and custom intersection examples
- large SBT stress tests
- long-run GPU soak and CI device matrix coverage

The first Vulkan triangle should be handled by Period32. The remaining items
should be planned as concrete Period32+ phases after both first-triangle paths
are visible or explicitly unsupported on a runtime.
