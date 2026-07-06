# Phase 7: Cache Diagnostics

Phase 7 adds object-cache diagnostics for repeated equivalent object creation.

## First Slice

- Add cache policy and diagnostic statistic shapes.
- Track repeated equivalent runtime object creation in the resource tracker.
- Expose diagnostics from runtime device/context views.

## Current Limits

- Diagnostics count key-equivalent creation attempts; they do not yet prove
  native handle reuse.
