# Phase 6: Long-Run Stability Tests

Phase 6 adds stress and soak coverage.

## Scope

- Add resource churn tests.
- Add presentation resize/recreate loops.
- Add shader/cache warm and cold loops.
- Track leaks, pending retirements, and backend errors over long runs.

## Validation

- Provide opt-in long-run commands so normal test runs stay fast.
- Record expected runtime and backend requirements in docs.
