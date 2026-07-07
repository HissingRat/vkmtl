# Phase 5: Native Advanced Escape Hatches

Phase 5 finishes explicit backend-specific advanced access.

## Scope

- Expose native handles only through intentional APIs.
- Add insertion or callback points for features that cannot be portable.
- Keep safety checks around encoder/queue state.

## Validation

- Add tests for invalid escape-hatch use.
- Add examples that clearly label backend-specific code.
