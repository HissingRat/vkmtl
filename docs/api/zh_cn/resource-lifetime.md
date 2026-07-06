# 资源生命周期

vkmtl 资源是显式资源。任何 runtime resource handle 都应该在销毁 owner 前调用 `deinit()`。

## 当前 Owner

`WindowContext` 是当前示例使用的 runtime owner。它拥有后端 presentation 状态，并追踪通过以下
接口创建的资源：

- `makeBuffer(...)`
- `makeTexture(...)`
- `makeSamplerState(...)`
- `makeShaderModule(...)`
- `makeRenderPipelineState(...)`
- `makeBindGroupLayout(...)`
- `makeBindGroup(...)`

Texture view 通过 `texture.makeTextureView(...)` 从 texture 创建，并由同一个 owner 追踪。

## 销毁顺序

先销毁 child resource，再销毁 context：

```zig
defer context.deinit();

var buffer = try context.makeBuffer(descriptor);
defer buffer.deinit();

var pipeline = try context.makeRenderPipelineState(pipeline_descriptor);
defer pipeline.deinit();
```

在 Zig 中，`defer` 按后进先出顺序执行。把 `defer context.deinit()` 写在 resource defer
之前，这样后注册的 resource defer 会先运行，最后才销毁 context。

## Debug 检查

Debug build 会追踪 live buffer、texture、texture view、sampler state、shader module、
render pipeline state、bind group layout 和 bind group。

如果 `WindowContext.deinit()` 时仍有资源存活，会 panic。资源 wrapper 也会防止自身 `deinit()`
之后继续被使用。

## Command Object

Command buffer、render command encoder 和 blit command encoder 都是短生命周期 recording object。
Encoder 必须用 `endEncoding()` 结束。Command buffer 会被 `commit()` 消费；`commit()` 会提交/呈现
工作并释放 native command buffer wrapper。

## 未来 Owner 模型

计划中的所有权树仍然是：

```text
Context
  -> Adapter
    -> Device
      -> Queue
      -> Surface
      -> resources and pipelines
```

当 runtime `Device` 成熟后，资源创建应该从 `WindowContext` 移到 `Device`，但公开 descriptor 不应改变。
