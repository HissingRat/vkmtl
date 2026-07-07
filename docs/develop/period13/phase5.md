# Phase 5: Frame Pacing Baseline

Phase 5 adds basic per-surface pacing.

## Scope

- Track frame serials per surface.
- Avoid one blocked surface stalling unrelated surfaces when possible.
- Keep the first implementation simple and debuggable.
- Validate begin/complete pairing so pacing state cannot silently drift.

## Validation

- Tests should cover per-surface frame counters.
- Multi-window smoke runs should show both windows updating.
- Unit tests should show one in-flight surface does not advance or block the
  counters of another registered surface.
