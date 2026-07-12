# Phase 5: Managed Synchronization, Evidence, And Closeout

Status: planned.

## Decisions To Complete

- Decide whether existing map/read/write/copy boundaries automatically compose
  exact managed/host-visible synchronization. Add an explicit transfer command
  only if observable correctness requires caller control.
- Split and reroute every advanced remainder introduced while closing the 15
  P47 rows; preserve exactly-once gap routing.
- Update public API inventory, changelog, migration guide, English/Chinese user
  docs, semantic inventory, Metal ledger/protocol map, and backend matrices.

## Required Evidence

- Focused unit tests for every new format, descriptor field, capability gate,
  limit, same-device rule, and backend translation.
- API guard, semantic inventory check, all tests, default build, and forced
  Vulkan build.
- Physical Metal and Vulkan evidence for newly enabled GPU behavior before a
  row receives backend-specific physical evidence status.
- Exact-commit evidence and an explicit list of unsupported/deferred semantics
  in the closeout.
