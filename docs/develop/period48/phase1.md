# Phase 1: Semantic Splits And Public Allocation

Status: complete.

## Decisions

- Keep binary fences and ordinary events as exact runtime synchronization
  objects. Their feature fields do not imply native GPU submission objects.
- `timeline_fences` means a native monotonic object supports host value query,
  host wait/signal, and GPU submission wait/signal. Vulkan uses a timeline
  semaphore; Metal uses `MTLSharedEvent`.
- `shared_events` means the selected backend executes the existing shared event
  path natively across vkmtl command queues. It does not promise external handle
  import/export; that remains `interop`/Period 53.
- Default/tracked resource hazards remain the only portable allocation.
  Explicit untracked hazard mode would transfer correctness responsibility to
  callers and is intentionally unsupported rather than approximated.
- Physical queues may use Vulkan concurrent resource sharing plus vkmtl's
  ownership state machine. The public contract is exclusive logical ownership,
  not exposure of raw queue-family release/acquire barriers.
- Lifecycle callbacks report scheduled and completed milestones truthfully but
  do not promise callback thread identity or that `commit` returns before
  completion.
- Scheduled/minimum-duration presentation is capability-gated. Unsupported
  backends return a typed result unless caller-authorized fallback selects
  immediate presentation.

## Public Allocation

- Reuse the existing `sync` fence/event/queue descriptors, operations, handles,
  and `SynchronizationDescriptor`.
- Lifecycle callback/status types belong to `command`; optional callback fields
  extend `CommandBufferDescriptor` with null defaults.
- Timed presentation descriptors and support diagnostics belong to
  `presentation`; the encoding operation belongs to `CommandBuffer` because it
  consumes that command buffer's drawable.
- New feature fields remain in `diagnostics.DeviceFeatures` and receive no root
  aliases.
- No new `Device`, `WindowContext`, `Queue`, `Fence`, or `Event` factory method
  is allocated.

All public additions target `v0.2.0`. The guarded root 68, `Device` 34,
`WindowContext` 10, and 35 opaque-handle baseline stays unchanged.
