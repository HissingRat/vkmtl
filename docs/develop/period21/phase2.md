# Phase 2: Resource Arrays

Phase 2 supports array bindings for common resources.

## Scope

- Lower sampled texture arrays.
- Lower sampler arrays.
- Lower uniform and storage buffer arrays where both backends can represent
  them cleanly.
- Keep storage texture arrays capability-gated if backend support diverges.
- Preserve clear binding-count validation.

## Validation

- Add layout/resource-count mismatch tests.
- Add shader reflection tests for array resources.
