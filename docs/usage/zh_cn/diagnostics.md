# Diagnostics 与 Issue Report

Capability 真值、capture、profiling plan 和 issue-report snapshot 都使用
`vkmtl.diagnostics` namespace；这些 API 不会继续扩张 flat root alias。

## Native Debug 可见性

不要按平台猜测 debug API，直接查询所选 device：

```zig
const markers = vkmtl.diagnostics.debugMarkerCapabilities(device);
```

每条能力都会报告为 `native`、`validation_only` 或 `unavailable`。Vulkan 在 debug utils
启用时会原生下沉 object label 和 encoder marker，但 command-buffer-level group/signpost
仍是 validation-only。Metal 的 object、command-buffer 和 encoder marker 都会原生下沉。

## Metal Capture

Metal capture 是显式 scope：

```zig
var capture = try vkmtl.diagnostics.beginCaptureScope(&device, .{
    .label = "frame:main-pass",
});
defer capture.deinit();

// Encode and submit the work to capture.

try capture.end();
```

必须在销毁 `WindowContext` 前结束 scope。Label 和 scope 持有的 backend owner 都是 borrowed。
当前 destination 是 Apple developer tools；Vulkan 返回 `UnsupportedCapture`，capture manager
或工具启动失败返回 `CaptureFailed`。

## Profiling 语义

当前 timestamp query result 是确定性的 command-order sequence，不是 GPU clock tick。
解释结果前先检查 `QuerySet.resultSource()`；`logical_sequence` 不能计算 GPU duration。

通过下面的 API 解析不会夸大能力的 profiling plan：

```zig
const plan = try vkmtl.diagnostics.planProfiling(device, .{});
```

当前 plan 使用应用自己提供的 CPU wall-clock measurement 或 marker scope。设置
`require_gpu_timestamps = true` 会返回 `UnsupportedGpuTimestamps`，直到 backend 真正暴露
GPU timestamp。

Headless planner 可以直接查看结果：

```sh
zig build run-profiling-plan
zig build run-profiling-plan -- --markers-only
zig build run-profiling-plan -- --require-gpu
```

## Issue-Report Snapshot

在失败操作旁创建 snapshot：

```zig
const report = try vkmtl.diagnostics.issueReport(device, .{
    .operation = "blitTexture",
    .object_kind = "texture",
    .object_label = texture.label(),
    .failure = err,
});
```

Snapshot 会 borrow device 和 descriptor string，必须在 owner 销毁前消费或序列化。它包含
backend/adapter、capability source、精确 error 与 category、features、limits、marker/capture/
profiling support、resource count、work serial 和 object-cache diagnostics。

## 推荐 Issue Bundle

建议一起附上：

1. 精确的 vkmtl commit 和 Zig version。
2. Host OS/version、target、所选 backend、adapter，以及 driver/runtime 信息。
3. 失败环境上 `zig build run-capability-dump` 的完整输出。
4. 精确 error name/category 和 `IssueReportSnapshot` 字段。
5. Operation/object label，以及最小可复现 command sequence。
6. 如果涉及 shader/pipeline creation，附 shader declaration 和相关
   `zig-out/shaders/<name>/` inspection artifact。
7. 可用时附 Metal capture 或 Vulkan validation/debug output。
8. 同一 workload 在另一 backend 是否失败，以及该失败属于 native、validation-only，还是预期的
   unsupported gate。

不要把 native handle 当作稳定标识；优先使用 `scene:opaque-pass`、`upload:staging` 这类确定性
label。

## Device Evidence 命令

Period 44 会把 build、GPU、pixel、soak 和 release evidence 分开：

```sh
zig build run-validation-plan
zig build run-pixel-regression
zig build run-gpu-soak -- --iterations=120
zig build run-release-readiness
```

Readiness 命令默认把所有 evidence gate 设为 missing。只有审阅对应 hosted/self-hosted artifact
后才能传入 gate flag。当前已经观察到和仍缺失的 lane 记录在
`docs/develop/period44/parity-report.md`。
