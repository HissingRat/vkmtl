# Phase 7: Cache Diagnostics

Phase 7 adds object-cache diagnostics for repeated equivalent object creation.

## First Slice

- Add cache policy and diagnostic statistic shapes.
- Track repeated equivalent runtime object creation in the resource tracker.
- Expose diagnostics from runtime device/context views.

## Current Limits

- `ObjectCacheDiagnostics` reports hits, misses, creation attempts,
  equivalent recreation attempts, bypassed reuse, suppressed diagnostics, and
  total creation time.
- `Device.objectCacheDiagnostics()` and `WindowContext.objectCacheDiagnostics()`
  return runtime snapshots.
- Diagnostics count key-equivalent creation attempts; they do not yet prove
  native handle reuse.
