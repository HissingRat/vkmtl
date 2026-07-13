# Period 48: Native Synchronization, Queues, And Presentation Timing

Status: complete.

Progress: Phases 1-5 complete.

Goal: replace runtime-only cross-submit synchronization and logical queue views
with truthful native execution where both the selected backend and vkmtl path
can preserve the contract. Portable fallbacks remain explicit and must not be
reported as native queue synchronization.

## Routed Rows

| Row | Period 48 target | Explicit boundary |
| --- | --- | --- |
| `MTL-RES-018` | Default/tracked hazard ownership composed with vkmtl resource state | Explicit untracked hazard ownership is intentionally unsupported. |
| `MTL-CMD-005` | Immediate plus capability-gated scheduled/minimum-duration presentation | Vulkan timing extensions remain device-gated; ordinary present is unchanged. |
| `MTL-CMD-006` | Exact encoder/resource ordering through portable barriers and backend hazard mechanisms | A distinct public native-fence object is not required for the observable contract. |
| `MTL-CMD-007` | Native GPU timeline wait/signal and Metal shared-event execution | External event/semaphore handle import/export remains Period 53. |
| `MTL-CMD-008` | Truthful scheduled/completed lifecycle status and callbacks | Callbacks never imply a caller thread or asynchronous return guarantee. |
| `MTL-CMD-009` | Physical compute/transfer queues, cross-queue dependencies, and exact portable ownership | Vulkan may use concurrent sharing plus vkmtl ownership state; raw family-transfer control is not promised. |

## Phase Plan

1. Semantic splits and public allocation decisions.
2. Native timeline/shared-event objects and submission wait/signal lowering.
3. Physical queue selection, resource sharing, and ownership enforcement.
4. Command lifecycle callbacks and capability-gated presentation timing.
5. Evidence, inventory updates, and closeout.

See `phase1.md` through `phase5.md`.
The final implementation and evidence boundary is recorded in `closeout.md`.

## Compatibility Boundary

No root alias, `Device` method, or `WindowContext` method is added. Existing
sync and queue descriptors remain in `sync`. Any lifecycle fields added to the
root-aliased `CommandBufferDescriptor`, presentation descriptor/method, feature
field, enum tag, or typed error targets `v0.2.0` and requires inventory,
changelog, migration-guide, and API-guard coverage.

## Acceptance

- Native and runtime-emulated synchronization are separately observable.
- A usable native feature opens only when object creation, host operations,
  submit encoding, lifetime, and deterministic evidence all exist.
- Cross-queue resource use is rejected until the documented ownership contract
  is satisfied.
- Timed presentation falls back only when the descriptor explicitly permits it.
- Full tests, API/semantic guards, default/forced-Vulkan builds, and appropriate
  physical evidence pass.
