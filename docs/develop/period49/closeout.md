# Period 49 Closeout

Status: complete.

Implementation evidence commit:
`79d61964aa0a2aeb8a10312bb0b18267fffd8273`.

## Delivered

- Replaced planning-only heaps with native placement storage. Metal uses
  `MTLHeapTypePlacement`; Vulkan allocates one compatible `VkDeviceMemory`
  block.
- Added exact buffer/texture allocation-requirement queries, validated reserved
  offsets, and heap-backed resource creation.
- Made heap-child lifetime executable. Heap-backed resources do not free the
  shared native allocation and decrement `liveResourceCount()` when destroyed;
  they must be destroyed before the heap.
- Added native memory telemetry. Metal reports recommended working set/current
  allocation; Vulkan reports device-local `heapBudget`/`heapUsage` through
  `VK_EXT_memory_budget` when the complete query path exists.
- Added a separately probed hardware-memoryless attachment feature and
  `.memoryless` storage mode on Metal. Memoryless attachments reject persistent
  load/store behavior and support MSAA resolve into persistent storage.
- Closed explicit residency sets, sparse resource/page execution, explicit CPU
  cache policy, and resource-content optimization hints as unsupported under
  their current contracts. Planning records remain distinct and usable feature
  fields stay false.
- Closed all eight Period 49 Metal ledger rows and reduced exactly-once gap
  routing from 60 to 52 incomplete units assigned to Periods 50-54.

## Public Compatibility

The guarded root 68, `Device` 34, `WindowContext` 10, and 35 runtime-handle
name baselines remain unchanged. No facade declaration or operation is added.
The existing `Heap` handle gains five methods and now has 16 public methods;
its private `_state` becomes pointer-backed without creating a layout promise.

`ResourceStorageMode` gains `.memoryless`; `DeviceFeatures` reaches 91 fields
with `memoryless_attachments`. Buffer, texture, and heap error sets gain typed
memoryless/allocation failures. These enum, feature, method, lifetime, and
error-set additions target `v0.2.0`; existing `.automatic` defaults remain
unchanged.

## Validation

- `zig fmt build.zig src examples tools tests/package_consumer`
- `zig build run-api-guard`: root 68, `Device` 34, `WindowContext` 10, and 35
  runtime handles passed.
- `zig build run-semantic-inventory-check`: 91 feature fields, 57 compact
  inventory IDs, 107 Metal semantics, 78 protocols, and 52 routed gaps passed.
- `zig build test --summary all`: 607/607 tests passed.
- `zig build` passed.
- `zig build -Dvulkan` passed.
- `scripts/ci/run_package_smoke.sh` passed.
- `git diff --check` passed.

## Physical Metal Evidence

On 2026-07-13, implementation commit
`79d61964aa0a2aeb8a10312bb0b18267fffd8273` ran on macOS 15.7.3, arm64, and an
Apple M4 Pro:

- `VKMTL_BACKEND=metal zig build run-capability-dump` reported native/usable
  heaps, memory budget/pressure, and memoryless attachments. The memory report
  source was native with a nonzero recommended working-set budget and current
  allocation.
- `VKMTL_BACKEND=metal zig build run-transfer-readback` created its source
  buffer and private texture from placement heaps, then passed transfer-queue
  buffer/texture readback together with the native memory-report check.
- `VKMTL_BACKEND=metal VKMTL_PIXEL_REGRESSION=1 zig build run-msaa-triangle`
  rendered through a memoryless four-sample attachment and resolved into the
  persistent sampled texture successfully.

## Vulkan Evidence Boundary

Vulkan placement memory, exact requirements, offset binding, shared-memory
ownership, and `VK_EXT_memory_budget` query code pass focused tests, the default
build, and the complete forced-Vulkan build. No new physical Vulkan Period 49
run is claimed. Memory-budget features remain closed without both the extension
and properties dispatch; individual heap descriptors still depend on a
compatible selected memory type.

## Explicitly Unsupported Or Deferred

- Vulkan hardware-memoryless guarantees. Lazily allocated/transient memory is
  not presented as proof that no backing allocation exists.
- Native sparse/tiled buffer or texture creation, page commit/decommit, and
  explicit residency sets. Current region-only descriptors do not bind actual
  resources; planning and churn maps remain non-executable.
- Explicit write-combined/default CPU cache selection and Metal content
  optimization hints. Default backend cache/coherency behavior remains the
  portable path.
- Heap purgeability, automatic alias synchronization, and overlapping live
  resource safety. Offset reuse requires the caller's validated disjoint
  lifetime and resource destruction before reuse.
- A physical Vulkan heap/budget rerun and broad adapter coverage beyond queried
  capability gates.

Period 50 is next: scalable binding tables, indirect/generated commands,
linked functions, native object pooling, and persistent driver artifacts.
