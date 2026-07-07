# Period 18: Performance / Production Hardening

Status: in progress.

Goal: turn backend features from functional slices into production-ready paths
with persistent caches, diagnostics, profiling, and long-run stability checks.

This period should reduce surprise for real applications: fewer redundant
native objects, clearer captures, better upload paths, and confidence that
long-running render loops stay stable.

## Phase 1: Driver Pipeline Cache Persistence

- Persist Vulkan pipeline caches and Metal binary archives where supported.
- Add driver cache load/store planning metadata.

See `phase1.md`.

## Phase 2: Resource Aliasing / Transient Allocator

- Add transient resource reuse for short-lived render and transfer resources.
- Add transient resource descriptors and aliasing eligibility checks.

See `phase2.md`.

## Phase 3: Upload And Readback Queue Optimization

- Improve staging, transfer, and readback scheduling.
- Add transfer batch plans that choose graphics versus transfer queues.

See `phase3.md`.

## Phase 4: GPU Timestamps And Profiler Markers

- Add portable timing and profiling markers.
- Add `ProfilerMarkerDescriptor` with timestamp feature gating.

See `phase4.md`.

## Phase 5: Debug Labels And Capture-Friendly Naming

- Lower labels and debug groups to native backends consistently.
- Add unified debug label descriptor validation for capture-friendly names.

See `phase5.md`.

## Phase 6: Long-Run Stability Tests

- Add stress and soak tests for resource churn and presentation loops.

See `phase6.md`.
