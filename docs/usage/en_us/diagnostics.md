# Diagnostics And Issue Reports

Use the `vkmtl.diagnostics` namespace for capability truth, capture, profiling
plans, and issue-report snapshots. These APIs do not add flat root aliases.

## Native Debug Visibility

Query the selected device instead of assuming that a backend exposes every
debug operation natively:

```zig
const markers = vkmtl.diagnostics.debugMarkerCapabilities(device);
```

Each lane is `native`, `validation_only`, or `unavailable`. Vulkan object
labels and encoder markers are native when debug utils are enabled, while its
command-buffer-level groups/signposts remain validation-only. Metal object,
command-buffer, and encoder markers are native.

## Metal Capture

Metal capture is explicit and scoped:

```zig
var capture = try vkmtl.diagnostics.beginCaptureScope(&device, .{
    .label = "frame:main-pass",
});
defer capture.deinit();

// Encode and submit the work to capture.

try capture.end();
```

End the scope before destroying `WindowContext`. The label and the scope's
backend owner are borrowed. The current destination is Apple developer tools;
Vulkan returns `UnsupportedCapture`, and a capture-manager/tool failure returns
`CaptureFailed`.

## Profiling Semantics

Current timestamp query results are deterministic command-order sequence
values, not GPU clock ticks. Check `QuerySet.resultSource()` before interpreting
results. `logical_sequence` values cannot be used for GPU duration.

Resolve an honest profiling plan through:

```zig
const plan = try vkmtl.diagnostics.planProfiling(device, .{});
```

The current plan uses application-supplied CPU wall-clock measurement or marker
scopes. Setting `require_gpu_timestamps = true` returns
`UnsupportedGpuTimestamps` until a backend exposes real GPU timestamps.

The headless planner makes this visible:

```sh
zig build run-profiling-plan
zig build run-profiling-plan -- --markers-only
zig build run-profiling-plan -- --require-gpu
```

## Issue-Report Snapshot

Build a snapshot next to the failing operation:

```zig
const report = try vkmtl.diagnostics.issueReport(device, .{
    .operation = "blitTexture",
    .object_kind = "texture",
    .object_label = texture.label(),
    .failure = err,
});
```

The snapshot borrows device and descriptor strings. Consume or serialize it
before those owners are destroyed. It contains backend/adapter identity,
capability source, exact error and category, features, limits, marker/capture/
profiling support, resource counts, work serials, and object-cache diagnostics.

## Recommended Issue Bundle

Attach all of the following:

1. Exact vkmtl commit and Zig version.
2. Host OS/version, target, selected backend, adapter, and driver/runtime
   details.
3. Full output from `zig build run-capability-dump` on the failing setup.
4. Exact error name/category and the `IssueReportSnapshot` fields.
5. Operation and object labels, plus the smallest reproducible command
   sequence.
6. Shader source declarations and the relevant `zig-out/shaders/<name>/`
   inspection artifacts when shader or pipeline creation is involved.
7. Metal capture or Vulkan validation/debug output when available.
8. Whether the same workload fails on the other backend, and whether the
   failure is native, validation-only, or an expected unsupported gate.

Do not attach native handles as stable identifiers. Prefer deterministic labels
such as `scene:opaque-pass` or `upload:staging`.

## Device Evidence Commands

Period 44 keeps build, GPU, pixel, soak, and release evidence separate:

```sh
zig build run-validation-plan
zig build run-pixel-regression
zig build run-gpu-soak -- --iterations=120
zig build run-release-readiness
```

The readiness command defaults every evidence gate to missing. Pass a gate flag
only after reviewing the corresponding hosted/self-hosted artifact. The current
observed and missing lanes are recorded in
`docs/develop/period44/parity-report.md`.
