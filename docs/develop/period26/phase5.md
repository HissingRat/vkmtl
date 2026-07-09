# Phase 5: Long-Run Stability

Phase 5 stress-tests completed backend paths.

## Scope

- Add resize/recreate loops.
- Add shader artifact warm/cold resolution loops.
- Add resource churn and upload/readback loops.
- Add staging-buffer reuse or pooling checks for unaligned Vulkan
  `fillBuffer(...)` fallback paths.
- Track leak reports and destruction-order issues.

## Validation

- Add opt-in long-run commands.
- Keep default test runs short and deterministic.

## Result

- Expanded `StabilityRunDescriptor` into a planning descriptor for resource
  churn, resize/recreate, shader-cache warm/cold, upload/readback, and Vulkan
  unaligned-fill fallback checks.
- Added `StabilityRunPlan` and expanded `StabilityRunDiagnostics` so future
  backend soak runners can consume the same counters that docs and tests
  describe.
- Added `zig build run-stability-plan -- --iterations <count>` as an opt-in
  diagnostic command; normal `zig build test` remains short and deterministic.
- Added Vulkan `fillBuffer(...)` fallback diagnostics that count native fills
  versus staging fallback fills.

## Deferred

- Persistent native staging-buffer pools and reusable upload rings remain
  deferred to Period 29 Phase 5.
- GPU-backed resize/resource/upload soak loops that open windows remain
  deferred to Period 29 Phase 6, after the native backend parity matrix is
  tighter.
