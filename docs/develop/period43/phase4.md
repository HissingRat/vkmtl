# Phase 4: Timestamp, Query, And Profiling Support

Status: complete for the current truthful fallback slice.

## Timestamp Meaning

The existing portable timestamp `QuerySet` records deterministic command-order
sequence values. These values are not GPU clock ticks and cannot be subtracted
to obtain a GPU duration. `QuerySet.resultSource()` therefore reports
`logical_sequence` for timestamp sets and `unavailable` for other query types.

## Profiling Plan

`vkmtl.diagnostics.ProfilingCapabilities` and `ProfilingPlanDescriptor` choose
one of three modes:

- `native_gpu_timestamps` only when a future backend exposes real GPU time;
- `cpu_fallback` for application-owned wall-clock instrumentation around
  submitted work;
- `markers_only` when the caller disables CPU fallback.

Requesting `require_gpu_timestamps = true` on the current backends returns
`UnsupportedGpuTimestamps`. The capability report never upgrades logical
sequence values into native GPU timestamps.

The opt-in command below prints the resolved plan without opening a window:

```sh
zig build run-profiling-plan
zig build run-profiling-plan -- --backend=vulkan --markers-only
zig build run-profiling-plan -- --require-gpu
```

Core and runtime tests cover logical query sources, fallback selection,
markers-only mode, and the typed native-GPU requirement failure.
