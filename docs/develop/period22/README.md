# Period 22: Command, Sync, And Query Backend Completion

Status: planned after Period 21.

Goal: expose portable defaults and explicit escape hatches for synchronization,
multi-queue work, and query/profiling operations.

Expected result: vkmtl can support profiling, readback-heavy tools, async
compute/transfer experiments, and explicit synchronization without forcing
Vulkan details into ordinary user code.

## Phase 1: Explicit Resource Barriers

- Lower public barrier descriptors to backend commands.

See `phase1.md`.

## Phase 2: Fences And Events

- Add runtime fence, timeline fence, event, and shared-event objects.

See `phase2.md`.

## Phase 3: Dedicated Queues

- Lower dedicated compute and transfer queue selection.

See `phase3.md`.

## Phase 4: Queue Ownership And Hazards

- Define queue ownership transfer and Metal no-op/validation mapping.

See `phase4.md`.

## Phase 5: Query Pools And Encoder Commands

- Lower occlusion, timestamp, and pipeline statistics queries.

See `phase5.md`.

## Phase 6: Sync And Query Validation

- Add tests and examples for sync/query backend paths.

See `phase6.md`.
