# Period 19 Voxel Pressure-Test Report

Status: complete on 2026-07-15.

## Workload

All measurements use the same deterministic terrain, `16 x 64 x 16` chunks,
ordinary per-chunk vertex/index buffers, one indexed draw per visible chunk,
the generated three-tile atlas, CPU frustum culling, and the public vkmtl
render path. The renderer limits rebuild work to two chunks and 8 MiB per
frame.

The measurements below came from an Apple M4 Pro Metal run with
`MTL_DEBUG_LAYER=1`. Validation mode and short finite runs make these
correctness and pressure observations, not release benchmark numbers.

## Results

| Metric | Smoke autopilot | Default | Stress |
| --- | ---: | ---: | ---: |
| Frames | 24 | 48 | 160 |
| Resident chunks | 9 | 81 | 289 |
| Visible chunks / draws | 9 | 49 | 121 |
| Culled chunks | 0 | 32 | 168 |
| Pending rebuilds at exit | 0 | 0 | 0 |
| Rebuilt chunks | 13 | 81 | 289 |
| Retired chunks | 4 | 0 | 0 |
| Uploaded bytes | 1,164,320 | 7,233,376 | 25,884,992 |
| Buffer allocations | 26 | 162 | 578 |
| Visible vertices | 21,712 | 115,808 | 284,768 |
| Visible indices | 32,568 | 173,712 | 427,152 |
| Total CPU mesh time (ms) | 27.317 | 169.620 | 597.104 |
| Encode time/frame (ms) | 0.158 | 0.162 | 0.209 |
| Commit time/frame (ms) | 0.734 | 0.943 | 1.068 |
| Frame p50 (ms) | 0.494 | 5.209 | 5.434 |
| Frame p95 (ms) | 5.900 | 5.938 | 6.036 |
| Frame max (ms) | 10.287 | 10.681 | 10.031 |

All runs emitted `voxel_world_pressure_test=ok`. Smoke used autopilot and
crossed a chunk boundary, accounting for four retirements and replacements.
Default and stress kept the fixed camera long enough to drain their full
initial grids. Resident and pending counts remained bounded in every run.

## Commands

```sh
MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal \
  VKMTL_VOXEL_PROFILE=smoke VKMTL_VOXEL_AUTOPILOT=1 \
  VKMTL_VOXEL_FRAME_LIMIT=24 zig build run-voxel-world

MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal \
  VKMTL_VOXEL_PROFILE=default VKMTL_VOXEL_FRAME_LIMIT=48 \
  zig build run-voxel-world

MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal \
  VKMTL_VOXEL_PROFILE=stress VKMTL_VOXEL_FRAME_LIMIT=160 \
  zig build run-voxel-world
```

## Findings

1. The existing public API is sufficient for the full portable correctness
   path. Period 19 did not need a root alias, owner method, feature flag, native
   handle, or backend branch.
2. Visible-face meshing and CPU frustum culling materially reduce geometry and
   draw work. At stress scale, 168 of 289 resident chunks were rejected before
   encoding.
3. The deliberately simple ownership model scales linearly: two buffers are
   allocated for every rebuilt chunk, and every visible chunk is one draw.
   Greedy meshing, mesh aggregation, and indirect submission may improve this,
   but none is a correctness dependency.
4. Submission is synchronous: Metal `commit()` waits for the command buffer to
   complete, and Vulkan `commit()` calls `queueWaitIdle` after either its
   presentation or non-presentation submission path. Metal's reported commit
   time therefore includes GPU completion waiting and prevents meaningful
   CPU/GPU overlap. No Vulkan timing conclusion is drawn without physical
   execution.
5. Metal API Validation exposed a current-drawable format mismatch: window
   pipelines use `bgra8_unorm_srgb`, while the Metal layer was linear
   `bgra8_unorm`. Period 19 aligned the Metal layer and format capability query
   with the sRGB convention and Vulkan's preferred surface format. Explicit
   `PresentationDescriptor.format` resolution and Vulkan's non-preferred
   fallback format remain outside the path proven here.

## Recommended Follow-Up

Allocate a separate asynchronous submission/in-flight resource period. It
should define completion ownership first, then add a bounded frame ring,
deferred resource retirement, and backend-native completion primitives. It
must preserve explicit backpressure and validate on physical Metal and Vulkan
before changing the public command lifetime contract.

Separately, presentation-format maintenance should make the existing
descriptor's requested/automatic format resolution observable and reject an
unavailable pipeline/drawable pairing before native render encoding. That work
must preserve the public API rules and update the semantic inventory with its
final Metal/Vulkan contract.

Do not infer physical Vulkan execution from this report. The Vulkan shader
artifact, forced Vulkan build, and backend lowering passed, but the closeout
host did not run the workload on a Vulkan device.
