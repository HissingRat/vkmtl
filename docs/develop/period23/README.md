# Period 23: Command, Sync, And Query Backend Completion

Status: completed portable sync/query validation slice.

Goal: expose portable defaults and explicit escape hatches for synchronization,
multi-queue work, and query/profiling operations.

Expected result: vkmtl can support profiling, readback-heavy tools, async
compute/transfer experiments, and explicit synchronization without forcing
Vulkan details into ordinary user code.

## Phase 1: Explicit Resource Barriers

- Lower public barrier descriptors to backend commands.

See `phase1.md`.

## Phase 2: Fences And Events

- Add runtime fence and event objects. Timeline fences and shared events remain
  capability-gated until native submit/shared-object integration lands.

See `phase2.md`.

## Phase 3: Dedicated Queues

- Add logical compute and transfer queue views with portable fallback. Native
  dedicated queue families remain a later backend step.

See `phase3.md`.

## Phase 4: Queue Ownership And Hazards

- Define queue ownership transfer and Metal no-op/validation mapping.

See `phase4.md`.

## Phase 5: Query Pools And Encoder Commands

- Add runtime occlusion and timestamp query sets with encoder commands and
  readback/resolve validation. Pipeline statistics remains capability-gated.

See `phase5.md`.

## Phase 6: Sync And Query Validation

- Add tests and backend-matrix entries for sync/query backend paths.

See `phase6.md`.
