# Period 26: Object Cache And Production Backend Hardening

Status: planned after Period 25.

Goal: make completed backend paths efficient, cacheable, diagnosable, and stable
under long-running applications.

Expected result: vkmtl behaves less like a prototype and more like a reusable
graphics runtime: repeated object creation is reduced, diagnostics explain
costs, and long-run stress tests catch resource churn.

## Phase 1: Native Object Reuse

- Implement reuse for shader modules, bind group layouts, pipelines, and
  samplers.

See `phase1.md`.

## Phase 2: Driver Pipeline Cache And Binary Archive

- Integrate Vulkan driver pipeline cache and Metal binary archives.

See `phase2.md`.

## Phase 3: Persistent Runtime Cache

- Persist selected cache artifacts across runs.

See `phase3.md`.

## Phase 4: Diagnostics And Capture Names

- Improve diagnostics for creation cost, cache misses, and native labels.

See `phase4.md`.

## Phase 5: Long-Run Stability

- Add stress loops for resize, resource churn, shader cache, and uploads.

See `phase5.md`.

## Phase 6: Production Readiness Matrix

- Add release-readiness checks for completed backend paths.

See `phase6.md`.
