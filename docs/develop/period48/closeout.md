# Period 48 Closeout

Status: complete.

Implementation evidence commit:
`bbe40a6554c125d57945e2ad3ab276c0c52cae85`.

## Delivered

- Backed timeline fences with Vulkan timeline semaphores and Metal shared
  events, including native host query/wait/signal and GPU submission
  wait/signal.
- Backed Metal shared events with the same native object and command-buffer
  wait/signal path. Binary fences and ordinary events remain exact runtime
  fallbacks and are not reported as native synchronization.
- Created physical graphics/compute/transfer work queues. Metal uses
  independent command queues; Vulkan queries dedicated work families, creates
  unique queue/pool objects, and uses explicit graphics fallback.
- Preserved exclusive vkmtl resource ownership across physical queues. Vulkan
  uses concurrent resource sharing for the selected work families rather than
  exposing raw family release/acquire barriers.
- Added encoding/scheduled/completed/failed command lifecycle status and
  optional callback-once delivery. Metal uses native handlers; Vulkan composes
  milestones around submit and synchronous queue completion.
- Added immediate, scheduled-time, and minimum-duration drawable presentation
  descriptors. Metal lowers both timed modes natively; unsupported timing falls
  back only when the caller explicitly authorizes immediate presentation.
- Closed the six Period 48 Metal ledger rows and reduced exactly-once gap
  routing from 66 to 60 incomplete units assigned to Periods 49-54.

## Public Compatibility

The guarded root 68, `Device` 34, `WindowContext` 10, and 35 opaque runtime
handle baselines remain unchanged. The command and presentation facades each
gain two declarations. `CommandBufferDescriptor` gains nullable lifecycle
fields, `CommandBuffer` gains `lifecycleStatus()` and
`presentDrawableWithDescriptor(...)`, and `DeviceFeatures` reaches 90 fields.
The additions and new command errors target `v0.2.0`; all defaults preserve the
existing immediate, one-shot path.

## Validation

- `zig fmt build.zig src examples tools tests/package_consumer`
- `zig build run-api-guard`: root 68, `Device` 34, `WindowContext` 10, and 35
  runtime handles passed.
- `zig build run-semantic-inventory-check`: 90 feature fields, 57 compact
  inventory IDs, 107 Metal semantics, 78 protocols, and 60 routed gaps passed.
- `zig build test --summary all`: 603/603 tests passed.
- `zig build` passed.
- `zig build -Dvulkan` passed.
- `scripts/ci/run_package_smoke.sh` passed.
- `git diff --check` passed.

## Physical Metal Evidence

On 2026-07-13, implementation commit
`bbe40a6554c125d57945e2ad3ab276c0c52cae85` ran on macOS 15.7.3, arm64, and an
Apple M4 Pro:

- `VKMTL_BACKEND=metal zig build run-capability-dump` reported native and usable
  timeline fences, shared events, multi-queue execution, ownership transfer,
  lifecycle callbacks, and both timed-presentation modes. Dedicated hardware
  queue-class flags remained false, as intended for Metal's independent queue
  objects.
- `VKMTL_BACKEND=metal zig build run-transfer-readback` passed on the transfer
  queue with native timeline/shared-event synchronization and scheduled then
  completed callback delivery for both submissions.
- `VKMTL_BACKEND=metal VKMTL_PIXEL_REGRESSION=1 zig build run-offscreen-texture`
  passed exact render readback while exercising minimum-duration drawable
  presentation.

## Vulkan Evidence Boundary

Vulkan timeline object/submit lowering, queue-family allocation, concurrent
resource sharing, callbacks, and immediate-present fallback pass unit tests and
the complete forced-Vulkan build. No new physical Vulkan Period 48 run is
claimed. Usable timeline and multi-queue features remain closed unless the
selected device query and enabled dispatch path are complete; a physical
Vulkan rerun is the next evidence upgrade, not a prerequisite for the guarded
capability logic recorded here.

## Explicitly Unsupported Or Deferred

- Explicit untracked hazard ownership. The portable contract remains
  default/tracked hazards.
- Vulkan shared events and timed drawable presentation. Immediate presentation
  remains native, and timed descriptors may request explicit immediate
  fallback.
- External event/semaphore handle import/export and cross-process sharing;
  Period 53 later closed submission unsupported under the current descriptor.
- A Metal dedicated hardware compute/transfer queue-class guarantee. Separate
  command queue objects are executable but do not prove distinct hardware
  engines.
- Raw Vulkan queue-family release/acquire control, asynchronous `commit`
  return, callback thread identity, reentrant callback use, presentation
  observation, and calibrated display timestamps.

Period 49 is next: native heaps, residency, sparse resources, and hardware
memoryless behavior.
