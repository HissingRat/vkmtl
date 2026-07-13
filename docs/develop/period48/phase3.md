# Phase 3: Physical Queues And Ownership

Status: complete.

## Scope

- Query Vulkan graphics/compute/transfer queue families and create only the
  unique requested queues; create independent Metal command queues.
- Route command buffers to the resolved physical queue and keep render/present
  graphics-only.
- Make resources safely usable across selected physical queues while retaining
  the existing exclusive logical ownership checks.
- Lower cross-queue dependencies through Phase 2 native synchronization.
- Report dedicated queue and ownership features only for executable paths.

## Result

Metal owns independent graphics, compute, and transfer command queues. Vulkan
selects graphics plus dedicated compute/transfer families when present and
creates only unique family queues and command pools. Vulkan resources use
concurrent sharing across selected work families while vkmtl retains exclusive
logical ownership. Cross-queue dependencies use Phase 2 native monotonic
synchronization. Metal separate queue objects do not claim dedicated hardware
queue classes.
