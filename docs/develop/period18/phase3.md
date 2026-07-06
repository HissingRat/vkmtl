# Phase 3: Upload And Readback Queue Optimization

Phase 3 improves data movement.

## Scope

- Batch uploads through reusable staging resources.
- Prefer transfer or blit queues where available and beneficial.
- Improve readback scheduling without blocking unrelated render work.

## Validation

- Tests should preserve deterministic readback results.
- Examples should keep simple upload helpers working.
