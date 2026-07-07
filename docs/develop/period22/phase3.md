# Phase 3: Dedicated Queues

Phase 3 makes non-graphics queues selectable.

## Scope

- Query Vulkan queue families for graphics, compute, and transfer support.
- Map Metal queue behavior to portable queue descriptors.
- Route command submission through selected queue views.
- Preserve graphics queue as the default path.

## Validation

- Add queue-selection tests using capability reports.
- Add docs for backend-specific queue limitations.
