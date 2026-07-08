# Period 30: Backend-Private Runtime Records

Status: completed.

Goal: connect the Period 29 public runtime contracts to vkmtl-owned
backend-private record state without leaking Vulkan or Metal types through the
ordinary public API.

Expected result: supported adapters can create and validate the advanced
runtime objects, and examples can verify that vkmtl records backend-private
intent for acceleration structures, ray tracing pipelines, shader binding
tables, Metal ray tracing tables, advanced native inventory, and parity
diagnostics.

Direct driver execution for these high-end paths remains Period31+ work.

## Phase 1: Native Acceleration Structure Handles

- Added backend-private acceleration-structure handle state.
- Recorded backend-private build command metadata.
- Kept direct `VkAccelerationStructureKHR` / `MTLAccelerationStructure` driver
  calls deferred to Period31+.

See `phase1.md`.

## Phase 2: Native Ray Tracing Pipeline Handles

- Added backend-private ray tracing pipeline metadata.
- Preserved shader-group counts, function-table entries, and recursion limits.
- Kept direct Vulkan / Metal driver pipeline handles deferred to Period31+.

See `phase2.md`.

## Phase 3: Native SBT Records And Dispatch

- Added backend-private SBT record metadata.
- Recorded backend-private ray dispatch command metadata.
- Kept direct driver ray dispatch calls deferred to Period31+.

See `phase3.md`.

## Phase 4: Native Metal Ray Tracing Dispatch

- Added backend-private Metal function-table and intersection-table metadata.
- Tracked acceleration-structure slot requirements.
- Kept direct Metal table population and dispatch binding deferred to
  Period31+.

See `phase4.md`.

## Phase 5: Native Advanced Escape Hatches

- Added backend-private runtime inventory counts to
  `NativeAdvancedClosurePlan`.
- Routed driver-level native advanced work to Period31+.

See `phase5.md`.

## Phase 6: Native Parity And Soak Validation

- Added backend-private parity validation-plan status.
- Generated stability diagnostics from opt-in soak descriptors.
- Routed GPU-backed soak loops to the Period31+ validation matrix.

See `phase6.md`.

## Phase 7: Backend-Private Native Advanced Examples

- Updated `examples/ray_traced_triangle` to verify backend-private runtime
  records.
- Kept pixel-producing ray tracing examples deferred to Period31+.

See `phase7.md`.
