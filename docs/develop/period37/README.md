# Period 37: Memory, Heaps, And Residency

Status: implemented as the portable memory/residency contract after Period36.

Goal: add production memory behavior at the public contract layer:
heap-reservation and aliasing plans, memory-budget reporting, pressure
diagnostics, and deterministic sparse/tiled residency churn planning.

## Expected Result

After Period37, vkmtl exposes the public memory and residency vocabulary needed
by later native heap and sparse/tiled backend work:

- `Heap` tracks aligned reservations and `HeapAliasingDescriptor` validates
  whether overlapping heap ranges can be reused across non-overlapping
  lifetimes.
- `TransientAllocationDiagnostics` reports requested units, peak live units,
  aliasable pairs, aliasing savings, and max alignment.
- `MemoryBudgetDescriptor` and `Device.memoryBudgetReport(...)` provide native
  or fallback memory-pressure diagnostics.
- `SparseResidencyChurnDescriptor`, `SparseResidencyMap.runChurn(...)`, and
  `Device.planSparseResidencyChurn(...)` summarize deterministic repeated
  commit/evict pressure.

This period does not claim native Vulkan `VkDeviceMemory` suballocation, Metal
`MTLHeap`-backed resource creation, or driver-level sparse/tiled page binding.
Those native paths still need backend lowering and device-matrix evidence before
vkmtl can claim production memory parity.

## Completed Scope

- Added heap aliasing plans for placed allocations.
- Extended transient allocation diagnostics with peak live pressure and
  aliasing savings.
- Added memory budget/pressure reports with native/fallback source metadata.
- Added sparse residency churn planning and deterministic map execution.
- Added runtime tests for heap aliasing, memory budget reports, transient
  pressure, sparse mapping plans, and sparse churn plans.

## Remaining Ownership

- Native heap-backed buffer/texture creation remains future backend work.
- Vulkan sparse binding and Metal tiled/sparse page binding remain future
  backend work.
- Long-running GPU-backed residency and memory-pressure soak runs remain
  Period44 device-matrix work once native lowering exists.

## Phase Plan

### Phase 1: Heap And Allocator Contract

- Done for the portable contract: heap descriptors, aligned reservations, and
  placed allocation aliasing plans are public.
- Done for capability gates: explicit heaps remain behind `DeviceFeatures.heaps`.
- Done. Ordinary resource creation still works without explicit heaps.

### Phase 2: Aliasing And Transient Resource Validation

- Done. Heap aliasing eligibility is based on overlapping memory ranges with
  non-overlapping lifetimes.
- Done. Invalid heap lifetimes, alignment, and out-of-heap ranges are typed.
- Done. Transient diagnostics now include peak live pressure and aliasing
  savings.

### Phase 3: Memory Budget And Pressure Reporting

- Done for public reports. `MemoryBudgetDescriptor` can classify fallback or
  native-source pressure reports.
- Done. Unknown native budget data produces fallback/unknown reports instead of
  platform assumptions.
- Done. Reports include used bytes, available bytes, usage basis points, and
  pressure status.

### Phase 4: Native Sparse/Tiled Residency Updates

- Done for portable planning and map execution: sparse/tiled mapping
  descriptors validate page shape, and churn plans summarize repeated
  commit/evict pressure.
- Native Vulkan sparse binding remains future backend work.
- Native Metal tiled/sparse page binding remains future backend work.

### Phase 5: Long-Running Residency And Churn Tests

- Done for deterministic tests: residency churn is tested through
  `SparseResidencyMap.runChurn(...)` and `Device.planSparseResidencyChurn(...)`.
- Done. Heap aliasing and transient pressure diagnostics are covered by tests.
- Done. Backend matrices now record memory-pressure and residency-churn
  expectations.

## Acceptance

- Heap reservation and aliasing plans work through the public runtime API.
- Aliasing validation catches invalid reuse.
- Sparse/tiled residency churn produces deterministic pressure diagnostics.
- Unsupported native heap/sparse behavior remains typed and capability-gated.
