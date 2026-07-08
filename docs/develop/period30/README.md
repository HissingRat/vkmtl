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

Direct driver execution for these high-end paths is split after Period30:
Period31 owns the first Metal ray traced triangle, Period32 owns the first
Vulkan ray traced triangle, and Period32+ owns broader parity.

## Phase 1: Native Acceleration Structure Handles

- Added backend-private acceleration-structure handle state.
- Recorded backend-private build command metadata.
- Routed first-triangle Metal AS driver calls to Period31, first-triangle
  Vulkan AS driver calls to Period32, and broader AS parity to Period32+.

See `phase1.md`.

## Phase 2: Native Ray Tracing Pipeline Handles

- Added backend-private ray tracing pipeline metadata.
- Preserved shader-group counts, function-table entries, and recursion limits.
- Routed first-triangle Metal pipeline work to Period31, first-triangle Vulkan
  pipeline work to Period32, and broader pipeline parity to Period32+.

See `phase2.md`.

## Phase 3: Native SBT Records And Dispatch

- Added backend-private SBT record metadata.
- Recorded backend-private ray dispatch command metadata.
- Routed first-triangle Metal dispatch to Period31, first-triangle Vulkan
  dispatch to Period32, and broader dispatch parity to Period32+.

See `phase3.md`.

## Phase 4: Native Metal Ray Tracing Dispatch

- Added backend-private Metal function-table and intersection-table metadata.
- Tracked acceleration-structure slot requirements.
- Routed direct Metal table population and first-triangle dispatch binding to
  Period31.

See `phase4.md`.

## Phase 5: Native Advanced Escape Hatches

- Added backend-private runtime inventory counts to
  `NativeAdvancedClosurePlan`.
- Routed first-triangle driver work to Period31 and Period32, with broader
  native advanced work left for Period32+.

See `phase5.md`.

## Phase 6: Native Parity And Soak Validation

- Added backend-private parity validation-plan status.
- Generated stability diagnostics from opt-in soak descriptors.
- Routed GPU-backed soak loops to the Period32+ validation matrix.

See `phase6.md`.

## Phase 7: Backend-Private Native Advanced Examples

- Updated `examples/ray_traced_triangle` to verify backend-private runtime
  records.
- Kept pixel-producing ray tracing examples deferred to Period31 for Metal and
  Period32 for Vulkan.

See `phase7.md`.
