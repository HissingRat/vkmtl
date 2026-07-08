# Period 26: Object Cache And Production Backend Hardening

Status: completed production-hardening planning and diagnostics slice. Native
cache object consumption, native object pooling, persistent staging pools, and
GPU-backed soak loops are deferred to Period 28.

Goal: make completed backend paths efficient, cacheable, diagnosable, and stable
under long-running applications.

Expected result: vkmtl behaves less like a prototype and more like a reusable
graphics runtime: repeated object creation is visible, cache and stability plans
are deterministic, diagnostics explain costs, and the remaining native
hardening work is assigned to explicit later phases.

## Phase 1: Native Object Reuse

- Add lookup diagnostics and reuse candidates for shader modules, bind group
  layouts, pipelines, and samplers. Lifetime-safe native handle pooling is
  deferred to Period 28 Phase 5.

See `phase1.md`.

## Phase 2: Driver Pipeline Cache And Binary Archive

- Add driver cache / binary archive planning. Native `VkPipelineCache` and
  `MTLBinaryArchive` consumption is deferred to Period 28 Phase 5.

See `phase2.md`.

## Phase 3: Persistent Runtime Cache

- Add runtime cache manifest planning and compatibility checks. Automatic
  manifest read/write is deferred to Period 28 Phase 5.

See `phase3.md`.

## Phase 4: Diagnostics And Capture Names

- Improve diagnostics for creation cost, cache misses, and native labels.

See `phase4.md`.

## Phase 5: Long-Run Stability

- Add deterministic stability plans and an opt-in planning command. GPU-backed
  soak loops are deferred to Period 28 Phase 6.

See `phase5.md`.

## Phase 6: Production Readiness Matrix

- Add release-readiness checks for completed backend paths.

See `phase6.md`.
