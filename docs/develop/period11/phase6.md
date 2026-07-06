# Phase 6: Backend Capability Tests

Phase 6 locks capability reporting into the test matrix.

## Scope

- Add tests for conservative defaults.
- Add tests for backend query mapping completeness.
- Add backend matrix notes for device-dependent capabilities that cannot be
  asserted on every machine.

## Validation

- `zig build test` should cover mapping and validation helpers.
- Backend smoke runs should record capability-dump output in release notes or
  test logs when possible.
