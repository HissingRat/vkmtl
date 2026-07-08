# Phase 4: Diagnostics And Capture Names

Phase 4 makes backend work visible to developers.

## Scope

- Report object creation cost and cache reuse.
- Improve capture-friendly native labels.
- Add optional diagnostics for resource churn and submission cost.
- Keep diagnostics low overhead when disabled.

## Validation

- Add diagnostics tests for counters and suppression policy.
- Document capture setup for Vulkan and Metal.

## Result

- Added `RuntimeDiagnosticsSnapshot` for live resource count, deferred
  retirement count, submitted/completed work serials, and object-cache
  diagnostics.
- Exposed `Device.runtimeDiagnostics()` and
  `WindowContext.runtimeDiagnostics()`.
- Added `CaptureNameDescriptor` plus `Device.writeCaptureName(...)` and
  `WindowContext.writeCaptureName(...)`; runtime helpers fill the selected
  backend when the descriptor omits it.
- Added focused tests for capture-name formatting, resource churn counters,
  pending-retirement counters, and object-cache diagnostics in the runtime
  snapshot.

## Deferred

- Native capture/profiler enrichment beyond labels and marker lowering remains
  deferred to Period 28 Phase 6.
