# Period 36: Sync And Queue Semantics

Status: planned after Period35.

Goal: make synchronization and multi-queue behavior explicit enough for real
async compute, async transfer, and cross-queue presentation workloads.

## Expected Result

After Period36, vkmtl should expose a portable synchronization model backed by
Vulkan timeline semaphores/fences and Metal shared events where available. The
runtime should be able to submit graphics, compute, and transfer work to
separate queues when the backend supports them, with queue ownership and hazard
transitions validated instead of implicit.

## Phase Plan

### Phase 1: Synchronization Object Contract

- Define public fence/timeline/shared-event concepts without leaking native
  handles through normal API shapes.
- Define host wait, signal, reset, and completion observation semantics.
- Decide which operations are portable and which require feature gates.

### Phase 2: Vulkan Timeline Semaphore And Fence Lowering

- Lower timeline operations to `VkSemaphore` timeline behavior where supported.
- Keep binary semaphore/fence fallback behavior explicit.
- Report typed unsupported reasons when timeline semantics are unavailable.

### Phase 3: Metal Shared Event And Fence Lowering

- Lower shared-event style operations to `MTLSharedEvent` where supported.
- Define same-device and cross-process limitations.
- Keep Metal-only details behind backend-private state or native escape hatches.

### Phase 4: Queue Families And Queue Roles

- Describe graphics, compute, transfer, and presentation queue roles.
- Query backend queue capabilities and limits.
- Keep single-queue fallback behavior clear.

### Phase 5: Queue Ownership And Hazard Tracking

- Track queue ownership transitions for buffers and textures.
- Validate cross-queue resource usage and barriers.
- Add errors that name the resource, queue role, and missing transition.

### Phase 6: Async Examples And Validation

- Add deterministic async transfer/readback coverage.
- Add async compute plus graphics synchronization coverage.
- Update backend test matrix with supported/unsupported queue combinations.

## Acceptance

- `zig build test` passes.
- Existing examples still run on the default backend.
- New async examples prove cross-queue scheduling where supported.
- Unsupported queue/sync features report typed errors instead of falling back
  silently.
