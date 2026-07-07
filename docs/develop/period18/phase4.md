# Phase 4: GPU Timestamps And Profiler Markers

Phase 4 adds portable timing and profiling hooks.

## Scope

- Add timestamp query support where available.
- Add profiler marker descriptors that map to native tooling.
- Keep unsupported timing features behind capability gates.
- Validate marker labels and timestamp begin/end requests.

## Validation

- Tests should cover timestamp descriptor validation.
- Backend smoke tests should record at least one GPU timing span where
  supported.
- Unit tests should reject timestamp markers when `timestamp_queries` is absent.
