# Period 6: Command, Sync, Transfer

Status: in progress.

Goal: unify Vulkan's explicit synchronization needs with Metal's encoder model
through portable defaults and explicit advanced escape hatches.

Period 6 extends the Period 2 usage-tracking baseline. Manual barriers should
remain an advanced path rather than the normal way to use vkmtl.

## Phase 1: Command Lifecycle

- Command buffer pooling.
- Command buffer reset and reuse.
- Encoder state machines.
- Command recording error state.
- State transitions after submit.
- Debug checks for invalid call order.

See `phase1.md`.

## Phase 2: Blit Encoder Completeness

- Buffer-to-buffer copy.
- Buffer-to-texture copy.
- Texture-to-buffer copy.
- Texture-to-texture copy.
- Fill buffer.
- Clear texture as a gated feature.
- Generate mipmaps.
- Copy alignment checks.

See `phase2.md`.

## Phase 3: Resource Barrier Model

- Extend automatic usage tracking.
- Support explicit transition and barrier escape hatches.
- Validate resource usage in debug builds.
- Define read/write hazard behavior.

See `phase3.md`.

## Phase 4: Fences / Events

- CPU-GPU synchronization.
- GPU-GPU synchronization.
- Fence wait and signal.
- Timeline semaphore as a gated feature.
- Metal shared event as a gated feature.
- Portable fence API.

See `phase4.md`.

## Phase 5: Multi-Queue

- Graphics queues.
- Compute queues.
- Transfer queues.
- Queue capability gates.
- Queue ownership transfer where needed.
- Fallback to a single queue when multiple queues are not available.
- Cross-queue synchronization rules.

See `phase5.md`.

## Phase 6: Debug Markers Integration

- Integrate with Period 2 labels and debug markers.
- Ensure render, blit, and compute encoders can mark GPU capture scopes.

See `phase6.md`.
