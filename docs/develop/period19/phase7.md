# Phase 7: Pressure-Test Report

Status: complete.

Phase 7 turns the voxel example into concrete feedback for vkmtl.

## Outcome

- The example records CPU mesh time, upload bytes, buffer allocations, visible
  vertices/indices, draw counts, encode and commit time, and frame p50/p95/max.
- All three bounded workload profiles completed on physical Metal with API
  Validation enabled.
- The public API covered the complete correctness path: precompiled Slang,
  reflection, texture upload and sampling, bind groups, uniform updates,
  vertex/index buffers, indexed draws, depth, commands, and presentation.
- No new public API or semantic-inventory row was required. The existing
  `RES-06` evidence was updated after Metal API Validation exposed and the
  implementation fixed a linear-versus-sRGB current-drawable mismatch.
- Per-chunk buffers and one draw per visible chunk intentionally expose linear
  resource/draw pressure; greedy meshing, batching, and indirect draws are
  optimizations, not missing correctness contracts.
- Synchronous `commit()` is the one material production bottleneck. The next
  related work should be an explicitly designed asynchronous submission and
  in-flight ownership period, not an incidental example-only workaround.
- Existing presentation-format maintenance should also make requested versus
  selected surface format resolution explicit, especially when Vulkan cannot
  provide the preferred sRGB surface format.

## Evidence Boundary

The complete measurements and run commands are recorded in
`pressure-test-report.md`. `closeout.md` records the finished period boundary.

Metal observations are physical execution evidence. The Vulkan shader
artifacts, implementation, tests, and forced Vulkan build pass, but no physical
Vulkan device ran this example in the closeout environment. Period 19 therefore
does not claim Vulkan runtime parity from build success alone.
