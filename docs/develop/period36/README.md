# Period 36: Sync And Queue Semantics

Status: implemented as the portable sync/queue contract after Period35.

Goal: make synchronization and multi-queue behavior explicit enough for real
async compute, async transfer, and cross-queue presentation workloads.

## Expected Result

After Period36, vkmtl exposes the public synchronization and logical queue
vocabulary needed by later native queue work:

- `SyncCapabilities` reports fence, timeline-fence, event, shared-event,
  host-wait, host-signal, queue-wait/signal, and native-support gates.
- `SynchronizationDescriptor` lets a command buffer validate fence/event waits
  and signals through `commitWithSynchronization(...)`.
- `QueueCapabilities`, `QueueSelectionPlan`, and `Device.planQueue(...)`
  describe whether a requested graphics/compute/transfer queue resolves to a
  dedicated logical queue or a graphics fallback.
- Logical queue ownership transfers remain validated for buffers and textures.

This period does not claim driver-level Vulkan timeline-semaphore submit
lowering, Metal shared-event submit lowering, or physical multi-queue scheduling
through separate native queues. Those native paths must still be implemented and
validated before vkmtl can make a production parity claim.

## Completed Scope

- Added backend-neutral sync capability reporting on `Device` and
  `WindowContext`.
- Added public synchronization operation descriptors for fence/event waits and
  signals.
- Added `CommandBuffer.commitWithSynchronization(...)` as the portable
  validation/runtime synchronization entry point.
- Added queue planning so callers can inspect requested queue kind, resolved
  queue kind, fallback behavior, dedicated logical queue selection, and
  ownership-transfer support before requesting a queue.
- Extended sync/queue tests to cover queue planning, fallback, and
  wait-before-submit / signal-after-submit semantics.

## Remaining Ownership

- Vulkan timeline semaphore waits/signals inside native queue submission remain
  native backend work. Period44 must validate them on real Vulkan smoke hosts
  before broad parity claims.
- Metal shared-event command-buffer integration remains native backend work.
  Period44 must validate same-device behavior and document unsupported
  cross-process behavior.
- Physical async compute/transfer scheduling through separate native queues
  remains backend work; Period44 owns device-matrix and soak validation once
  that lowering exists.

## Phase Plan

### Phase 1: Synchronization Object Contract

- Done. Public fence/timeline/shared-event concepts stay backend-neutral.
- Done. Host wait, signal, reset, and completion observation semantics are
  represented by `Fence`, `Event`, and synchronization operation descriptors.
- Done. Non-portable behavior is visible through `SyncCapabilities` and
  feature-gated descriptor validation.

### Phase 2: Vulkan Timeline Semaphore And Fence Lowering

- Done for the public contract and feature gate: timeline fences validate
  against `DeviceFeatures.timeline_fences` and report typed unsupported errors.
- Done for binary fallback semantics: binary fences remain distinct from
  timeline fences and reject invalid timeline values.
- Native `VkSemaphore` timeline submit lowering remains future backend work
  tracked under Period44 validation.

### Phase 3: Metal Shared Event And Fence Lowering

- Done for the public contract and feature gate: shared events validate against
  `DeviceFeatures.shared_events`.
- Done for boundary shape: Metal-only handles remain backend-private or behind
  explicit native escape hatches.
- Native `MTLSharedEvent` command-buffer integration and cross-process limits
  remain future backend work tracked under Period44 validation.

### Phase 4: Queue Families And Queue Roles

- Done. Graphics, compute, transfer, and presentation queue roles are described
  by `QueueKind`, `QueueCapabilities`, and `QueueDescriptor`.
- Done. `Device.queueCapabilities()` and `Device.planQueue(...)` expose the
  resolved logical queue plan.
- Done. Single-queue fallback is explicit in `QueueSelectionPlan`.

### Phase 5: Queue Ownership And Hazard Tracking

- Done. Buffer and texture owner queues are tracked.
- Done. Cross-queue resource usage is validated through ownership transfer
  state.
- Done. Missing transition paths return typed queue-ownership errors.

### Phase 6: Async Examples And Validation

- Done for deterministic public coverage: unit tests cover synchronization
  waits/signals, queue planning, fallback, and ownership validation.
- Existing transfer/readback and compute/readback examples remain the smoke
  coverage for deterministic command paths.
- Backend matrix entries now distinguish portable logical queue behavior from
  future native physical multi-queue lowering.

## Acceptance

- `zig build test` passes.
- Existing examples still run on the default backend.
- Sync/queue tests prove portable logical behavior and typed unsupported paths.
- Unsupported queue/sync features report typed errors instead of falling back
  silently.
