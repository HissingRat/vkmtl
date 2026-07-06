# Phase 6: Validation Tests

Phase 6 inventories validation cases and links them to existing focused tests.

## First Slice

- Add validation case metadata for invalid bind groups, texture formats,
  barriers, resource lifetime, unsupported features, and reflection mismatch.
- Link each case to current unit-test coverage where available.
- Document remaining integration-test gaps.

## Current Limits

- Validation cases are recorded in `src/development_matrix.zig`.
- Human-readable coverage lives in `docs/develop/validation-matrix.md`.
- Some cases remain unit-test only until native backend CI runners are wired.
