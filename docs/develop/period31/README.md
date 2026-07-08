# Period 31: Metal Ray Traced Triangle Driver Path

Status: planned.

Goal: make `zig build run-ray-traced-triangle` produce visible ray-traced
pixels in a window on supported macOS Metal devices.

This period intentionally narrows the target. Periods 28 through 30 made ray
tracing expressible, validated, and recordable inside vkmtl. Period 31 must turn
that path into an actual Metal driver execution path for the first pixel
producing ray tracing example.

## Hard Acceptance Target

On a macOS device where Metal reports ray tracing support:

```sh
zig build run-ray-traced-triangle
```

must:

- create a window
- build a real Metal acceleration structure for a triangle
- dispatch a real Metal ray tracing workload
- write the ray traced result into a texture
- present that texture to the window
- show a visible triangle without importing backend-private modules from the
  example

On devices without Metal ray tracing support, the example must exit with a
clear unsupported-feature message instead of pretending to render.

## Scope

Period 31 is a productizing slice for the first ray tracing pixels. It is not a
general ray tracing parity period.

In scope:

- Metal-only driver path for `examples/ray_traced_triangle`
- real `MTLAccelerationStructure` creation and build
- real Metal command encoding for the ray tracing workload
- a ray tracing output texture presented in the existing vkmtl window path
- clear capability gates and failure messages
- screenshot/manual validation that proves pixels are visible

Out of scope:

- Vulkan `VkAccelerationStructureKHR` / `vkCmdTraceRaysKHR` parity, which is
  the explicit Period32 target
- full ray generation / miss / hit shader model parity
- acceleration structure compaction, update/refit, instances, procedural
  geometry, and ray query completeness
- broad native advanced parity unrelated to the first ray traced triangle

The first Vulkan triangle is Period32. The broader completeness items remain
Period32+ target work.

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
