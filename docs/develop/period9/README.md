# Period 9: Examples / Test Matrix / Documentation

Status: completed.

Goal: make the library maintainable and verifiable across examples, backends,
validation tests, and documentation.

Key examples should land with the period that introduces their feature. Period 9
organizes the gallery and matrix; it should not be the first proof that a
feature works.

## Phase 1: Example Gallery Cleanup

- Triangle.
- Textured quad.
- Uniform buffer.
- Storage buffer.
- Depth.
- Offscreen render.
- MSAA.
- Cube map.
- Mipmap.
- Review names, run commands, and expected output.

See `phase1.md`.

## Phase 2: Compute Example Gallery

- Image filter.
- Particle simulation.
- Prefix sum.
- Readback.
- Storage texture.

See `phase2.md`.

## Phase 3: Multi-Window Examples

- Single device with multiple surfaces.
- Multiple swapchains.
- Resize handling.
- Surface-lost handling.

See `phase3.md`.

## Phase 4: Native Interop Examples

- Vulkan native handle.
- Metal native handle.
- IOSurface or external texture as a gated feature.
- User-defined native command insertion where supported.

See `phase4.md`.

## Phase 5: Backend Test Matrix

- Vulkan Windows.
- Vulkan Linux.
- Metal macOS.
- Metal iOS if the project chooses to support it.
- MoltenVK macOS as an optional backend-test target.
- Headless or offscreen tests where practical.

See `phase5.md`.

## Phase 6: Validation Tests

- Invalid bind group.
- Invalid texture format.
- Invalid barrier.
- Resource destroyed while in use.
- Unsupported feature.
- Shader reflection mismatch.

See `phase6.md`.

## Phase 7: Documentation Completeness

- Getting started.
- `Device` / `Surface` / `Queue` architecture.
- Resource lifetime spec.
- Binding model spec.
- Command, sync, and usage tracking spec.
- Feature, limit, and capability gate docs.
- Backend difference notes.
- Performance guide.
- Compatibility table.

See `phase7.md`.
