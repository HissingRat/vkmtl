# Phase 5: Heaps And Transient Allocation

Phase 5 gives applications explicit memory-control options.

## Scope

- Add heap-backed buffer and texture creation where supported.
- Add transient attachment allocation strategy.
- Keep default resource creation simple and internally managed.
- Validate heap compatibility and resource lifetime.

## Validation

- Add descriptor tests for heap compatibility.
- Add diagnostics for allocation mode and transient reuse.
