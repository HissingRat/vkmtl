# 资源生命周期

vkmtl 资源是显式资源。任何 runtime resource handle 都应该在销毁 owner 前调用 `deinit()`。

## 当前 Owner

`WindowContext` 拥有后端 presentation 状态和 debug tracker；`HeadlessContext` 持有同一套
device/queue runtime 和 tracker，但没有 presentation state。两种 context 都返回 borrowed
`Device` 和 `Queue` view。资源通过 `Device` 创建，command buffer 通过 `Queue` 创建；窗口专用
resize/clear 操作由 `Swapchain` 负责，`WindowContext` 不转发这些调用。

`Device` 创建并由 tracker 追踪的资源包括：

- `makeBuffer(...)`
- `makeTexture(...)`
- `makeSamplerState(...)`
- `makeShaderModule(...)`
- `makeRenderPipelineState(...)`
- `makeBindGroupLayout(...)`
- `makeBindGroup(...)`
- `makeQuerySet(...)`

Texture view 通过 `texture.makeTextureView(...)` 从 texture 创建，并由同一个 owner 追踪。

## 销毁顺序

先销毁 child resource，再销毁 context：

```zig
defer context.deinit();

var device = context.device();
var buffer = try device.makeBuffer(descriptor);
defer buffer.deinit();

var pipeline = try device.makeRenderPipelineState(pipeline_descriptor);
defer pipeline.deinit();
```

在 Zig 中，`defer` 按后进先出顺序执行。把 `defer context.deinit()` 写在 resource defer
之前，这样后注册的 resource defer 会先运行，最后才销毁 context。

## Debug 检查

Debug build 会追踪 live buffer、texture、texture view、sampler state、shader module、
render pipeline state、bind group layout 和 bind group。

如果 `WindowContext.deinit()` 或 `HeadlessContext.deinit()` 时仍有资源存活，会 panic。资源
wrapper 也会防止自身 `deinit()` 之后继续被使用。

Period 2 开始，tracker 还会记录 command buffer `commit()` 产生的 submitted/completed work serial。
如果资源在 work 尚未完成时释放，会登记为 deferred retirement；当前 Vulkan 和 Metal 后端仍会在
`commit()` 返回前等待 work 完成，所以这些 retirement 会在同一个 commit 结束后被清空。后续取消
wait-idle 时，native destroy 会接到同一套 serial 模型上。

## Label Memory

Object label 是 borrowed 而不是 owned。Descriptor 或 `setLabel(...)` 引用的 backing bytes
必须保持存活且不变，直到 object 销毁、label 被替换，或 `setLabel(null)` 清空 label。Descriptor
本身可以是临时值；只有它引用的 label bytes 需要更长生命周期。

Debug-group 和 signpost label 只需要在调用期间存活，因为 native call 返回后 vkmtl 只保存 marker
stack depth。

## Command Object

Command buffer、render command encoder、blit command encoder 和 compute command encoder 都是短生命周期
recording object。Encoder 必须用 `endEncoding()` 结束。Command buffer 会被 `commit()` 消费；
`commit()` 会提交/呈现工作并释放 native command buffer wrapper。

Debug group 必须在 `endEncoding()` 或 `commit()` 前保持 push/pop 平衡。

## QuerySet

通过 `RenderPassDescriptor.occlusion_query_set` 绑定的 occlusion `QuerySet` 会被 pass
和匹配的 begin/end command borrow。Timestamp set 会被每次 encoder write borrow，所有
query set 都会被 resolve command borrow。必须让 set 活到 `commit()` 返回；当前 backend
会同步完成。

从首次 encode write/begin 到 producer command buffer 的同步 `commit()` 返回之前，不能
reset/destroy set；只结束 encoder 并不会释放 borrow。每次 reset 后一个 slot 只能写一次。
Resolve destination 同样要活到 completion，并且必须有
`copy_destination` usage。

## Owner 迁移方向

目标所有权树是：

```text
Context
  -> Adapter
    -> Device
      -> Queue
      -> Surface
      -> resources and pipelines
```

`Device` / `Queue` 已经作为 view 暴露。后续 Period 2 phase 会继续拆出明确的 `Surface` /
`Swapchain` owner，并决定哪些 `WindowContext` helper 长期保留。
