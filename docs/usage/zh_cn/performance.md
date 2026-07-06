# Performance Guide

vkmtl 还很年轻，所以最重要的性能规则是：不要在每帧循环里反复创建 expensive object。

## Shader Compilation

启动或资源 reload 时编译 embedded Slang：

```zig
var compiled = try device.compileRenderShader("main", source, .{
    .vertex_entry = "vs_main",
    .fragment_entry = "fs_main",
});
defer compiled.deinit();
```

runtime shader artifact 默认缓存在 `vkmtl-cache`。source hash 是 cache identity 的一部分，所以修改
embedded Slang 会自动触发对应 artifact 重新编译。

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
后续 backend lowering 会消费这些状态来生成显式 barrier。
