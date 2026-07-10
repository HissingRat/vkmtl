# Phase 6: Validation And Backend Matrix

Phase 6 closes Period34 with validation and docs.

## Checklist

- [x] Keep `zig build test` passing.
- [x] Keep `zig build` passing.
- [x] Run the Metal RT path on supported hardware to verify Period33 mesh path
  remains intact.
- [x] Run the procedural Vulkan path on supported hardware. Observed on Windows
  10 build 19045 with an NVIDIA GeForce RTX 5080 and the marker
  `driver_pixels=visible_vulkan_procedural_rt_scene`.
- [x] Capture or document visible procedural scene output markers.
- [x] Update backend completion and test matrices.
- [x] Update usage/API docs for procedural RT support.

## Acceptance

- Docs clearly separate mesh RT scene support from procedural/custom
  intersection support.
- Backend matrices show which native procedural RT path is implemented,
  unsupported, or unvalidated.
- Future work is routed to concrete later periods rather than vague parity
  notes.
