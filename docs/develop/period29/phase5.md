# Phase 5: Native Advanced Escape Hatch Execution

Status: completed for the public runtime contract.

Phase 5 closes the native advanced backlog.

## Scope

- Kept `Device.planNativeAdvancedClosure(...)` as the central inventory for
  native advanced backend work.
- Added `public_runtime_contract_features` to `NativeAdvancedClosurePlan` so the
  plan distinguishes API/runtime contracts from backend-private native lowering.
- Retargeted backend-private advanced native lowering to Period 31+ driver parity plan.
- Kept `deferred_native_features` as the count of native backend work that still
  needs private Vulkan/Metal implementation.

## Validation

- Core and runtime tests cover public contract counts, deferred native counts,
  and the updated Period 30 target.

## Deferred Native Work

- Lifetime-safe native object handle pools, persistent staging pools, reusable
  upload rings, Vulkan `VkPipelineCache` consumption, Metal binary archive
  consumption, automatic runtime cache manifest read/write, heap-backed native
  resources, sparse/tiled page binding, external imports/sync, native command
  handle lowering, tessellation execution, and mesh/task execution are deferred
  to Period 31+ driver parity plan.
