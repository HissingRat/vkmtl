# Performance Guide

vkmtl 还很年轻，所以最重要的性能规则是：不要在每帧循环里反复创建 expensive object。

## Shader Resolution

启动或资源 reload 时解析 embedded Slang 对应的预编译 shader：

```zig
var compiled = try device.compileRenderShader("main", source, .{
    .vertex_entry = "vs_main",
    .fragment_entry = "fs_main",
});
defer compiled.deinit();
```

shader artifact 在构建期预编译并内嵌进可执行文件；运行时直接从内存解析，不创建
`vkmtl-cache`。修改 embedded Slang 后，下一次 `zig build` 会重新生成内嵌 artifact 和
`zig-out/shaders` 下的调试副本。

## Object Creation

buffer、texture、sampler、bind group layout、shader module 和 pipeline 尽量在 setup 阶段创建。
Period 8 暴露 object-cache key 和 `objectCacheDiagnostics()`，应用可以先发现 repeated equivalent
creation attempts；native object reuse 仍是后续 backend work。

## Resource Updates

优先复用持久资源并做小范围更新：

- CPU-visible uniform update 使用 `buffer.replaceBytes(...)`
- private resource 上传/读回走 transfer/readback path
- texture upload 显式使用 `replaceRegion(...)` 或 `replaceAll2D(...)`

## Commands

保持 command recording 可预测。vkmtl 会校验 command encoder 顺序并追踪 resource usage transition；
显式 `bufferBarrier(...)` 和 `textureBarrier(...)` 会用同一份状态做校验。Vulkan 会下沉到
native barrier；Metal 会把它们当作 validation/no-op marker。
Vulkan 上 `fillBuffer(...)` 在 offset 和 size 都 4-byte aligned 时最便宜；unaligned range 会走
staging-copy fallback。

## Stability Plans

如果想在不开窗口的情况下检查 long-run 压力规划，可以使用 opt-in stability planner：

```sh
zig build run-stability-plan -- --iterations 120
```

这个命令会打印 resize、resource churn、shader artifact、upload，以及 Vulkan unaligned-fill fallback
的计划计数。完整 GPU soak loop 仍属于后续 backend hardening 工作。
