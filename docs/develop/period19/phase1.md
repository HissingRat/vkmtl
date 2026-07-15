# Phase 1: Voxel Example Contract

Status: complete.

Phase 1 defines the pressure-test target before chunk rendering starts. The
contract is deliberately bounded and uses the existing canonical API. A real
workload finding may justify a later API allocation; the example itself must
not bypass vkmtl or invent backend-private dependencies.

## Example Boundary

- The example lives at `examples/voxel_world` and runs through
  `zig build run-voxel-world`.
- One Zig implementation, one eventual Slang render shader, and one resource
  layout must serve Metal and Vulkan.
- Window creation and input use the external GLFW adapter. Rendering uses only
  the public `vkmtl` module and `WindowContext`.
- Backend-private imports, raw native handles, and new `WindowContext`
  compatibility forwards are forbidden.
- The renderer owns deterministic block data only to exercise rendering. It is
  not a world-generation, gameplay, physics, networking, inventory, save-file,
  editor, or general engine project.

## Reference Workload

The implementation phases use these fixed profiles so observations are
comparable and resource growth stays bounded:

| Profile | Horizontal radius | Resident grid | Maximum chunks | Purpose |
| --- | ---: | ---: | ---: | --- |
| smoke | 1 | 3 x 3 | 9 | Build/runtime correctness and deterministic checks. |
| default | 4 | 9 x 9 | 81 | Interactive example and ordinary pressure evidence. |
| stress | 8 | 17 x 17 | 289 | Opt-in upload, draw-count, and frame-pacing pressure. |

- A chunk is `16 x 64 x 16` blocks.
- The first block set is `air`, `grass`, `dirt`, and `stone`. A fixed
  deterministic height function supplies test data; terrain quality is out of
  scope.
- The first mesher emits only faces adjacent to air, including neighbor checks
  across chunk boundaries. Greedy meshing and transparent sorting are not part
  of the baseline.
- Each non-empty chunk owns one vertex buffer and one 32-bit index buffer.
  Ordinary non-sparse buffers are the required portable streaming path.
- The vertex ABI is an `extern struct` with world position `[3]f32`, atlas UV
  `[2]f32`, and face normal `[3]f32`, for a 32-byte stride. Indices are `u32`;
  the worst-case visible-face mesh is not safe in a `u16` index domain.

## Required Portable Path

The completed renderer must exercise these canonical contracts on both
backends:

| Work | Required vkmtl surface |
| --- | --- |
| Window, resize, present | `WindowContext`, `Swapchain`, public presentation descriptors |
| Geometry | vertex/index buffers and `drawIndexedPrimitives(...)` |
| Camera | a per-frame uniform buffer updated through public buffer methods |
| Materials | one generated RGBA atlas, texture view, sampler, and ordinary bind group |
| Shader/pipeline | embedded manifest-backed Slang, reflection, render pipeline state |
| Visibility | depth attachment, back-face culling, and CPU chunk frustum/distance culling |
| Streaming | bounded CPU meshing plus public buffer upload/copy paths |
| Commands | public command buffer and render/blit encoder objects |

Heap placement, resource tables, reusable command lists, timestamps, and exact
occlusion queries may become capability-gated pressure modes. None may be
required for correct baseline rendering. Sparse/tiled residency remains
outside the portable path because its native execution contract is explicitly
unsupported. Pipeline-statistics and device-counter result shapes are also not
required; the report uses CPU timings and portable resource/command counts,
plus native timestamps only when available.

## Budgets And Diagnostics

- Phase 5 processes at most two rebuilt chunks and 8 MiB of mesh uploads per
  frame by default. Excess work remains in a bounded queue for later frames.
- Resident chunks, pending rebuilds, and retired GPU resources must never grow
  without the selected profile's bound.
- Once streaming exists, the example reports resident/visible/culled chunks,
  draw calls, vertices, indices, rebuilt chunks, uploaded bytes, buffer
  reallocations, rebuild queue depth, CPU meshing/commit time, and CPU frame
  p50/p95/max at least on exit.
- There is no hardware-independent 60 FPS gate. Phase 7 records observed
  numbers for named hardware and treats correctness, bounded growth, and
  stable frame delivery as the portable requirements.

The initial API audit found no correctness blocker for Phases 2-5. It did find
one deliberate pressure hypothesis: command submission may serialize GPU work
and make dynamic rebuild uploads stall rendering. Period 19 must measure that
behavior instead of pre-allocating an asynchronous submission or upload-ring
API. Only observed, cross-backend workload evidence may open such a contract.

## Expected Output And Controls

Phase 1 shows a resizable sky-colored scaffold and prints the selected backend
and default workload dimensions. Later phases must produce a readable
grass/dirt/stone chunk field with stable depth and no internal faces.

The Phase 4 control contract is:

- `W/A/S/D`: horizontal movement.
- `Q/E`: descend/ascend.
- mouse or arrow keys: yaw and pitch.
- Shift: faster movement.
- `R`: request a nearby deterministic chunk rebuild.
- Escape or window close: exit.

## Phase 1 Deliverables

- `examples/voxel_world/main.zig` initializes the public window/presentation
  path and clears the drawable without importing a backend.
- `build.zig` installs `vkmtl-voxel-world` and exposes
  `run-voxel-world`.
- `VKMTL_BACKEND=metal|vulkan` selects a debug backend override.
- `VKMTL_VOXEL_FRAME_LIMIT=N` makes the scaffold exit after `N` presented
  frames and print `voxel_world_phase1_scaffold=ok`, providing an automated
  smoke path.
- No placeholder shader is registered in Phase 1. Phase 2 adds the real
  manifest-backed chunk shader together with the first geometry.
- No public API declaration or allowlist changes in this phase.

## Observed Evidence

On an Apple M4 Pro, the finite-frame command ran with Metal API Validation
enabled and reported:

```text
Using backend: .metal
voxel workload contract: chunk=16x64x16, default_grid=9x9, max_resident=81
voxel_world_phase1_scaffold=ok frames=2
```

The default and forced Vulkan build configurations both include the new target
and pass 60/60 build steps. Physical Vulkan voxel execution is not claimed by
Phase 1.

## Validation

- `zig fmt --check build.zig src examples tools tests/package_consumer`
- `zig build test --summary all`
- `zig build run-api-guard`
- `zig build --summary all`
- `zig build -Dvulkan --summary all`
- `VKMTL_VOXEL_FRAME_LIMIT=2 VKMTL_BACKEND=metal zig build run-voxel-world`
- `git diff --check`
