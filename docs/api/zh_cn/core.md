# 核心 API

vkmtl 通过公开的 `vkmtl` 模块暴露后端无关的描述符和运行时包装。用户代码不应该导入
`backend/vulkan`、`backend/metal`、原始 Vulkan binding 或 Metal bridge header。

当前窗口示例仍通过 `WindowContext` 组装后端选择、surface、presentation 和 shader cache。
Period 2 开始，长期资源入口是 `Device`，长期 command-buffer / submit 入口是 `Queue`；
`WindowContext` 保留为窗口 convenience owner，并把资源和命令 helper 转发到这些 view。

## 后端选择

应用通过 `BackendPreference` 选择后端：

- `.auto`
- `.vulkan`
- `.metal`

已选择的后端可以通过 context 和运行时资源 wrapper 的 `selectedBackend()` 查询。

## Surface 与呈现

窗口集成不属于 vkmtl core。示例使用外部 `zig_glfw` 包和 `examples/common.zig`
里的 glue，把 GLFW window 转成公开描述符：

- `SurfaceDescriptor`
- `PresentationDescriptor`

对于 Vulkan，这层 glue 还会提供 `VulkanSurfaceProvider`，包含 instance extension、
proc-address lookup 和 surface creation callback。示例把这些 descriptor 传给
`WindowContext.init(...)`。

Period 2 开始，`WindowContext.surface()` 和 `WindowContext.swapchain()` 暴露 runtime view。
`Surface` 保留 window/provider descriptor 信息；`Swapchain` 管 presentation-chain resize，
当前 clear-screen helper 也挂在 `Swapchain.clear(...)`。`WindowContext.resize(...)` 和
`WindowContext.clear(...)` 仍是兼容转发。

`SurfaceCollection` 是第一版 multi-surface 管理形状：它可以在一个 selected backend 下追踪多个
neutral surface 的 presentation state，并通过 generation handle 做 resize/remove 校验。当前它还不
创建多个 native swapchain；完整 native multi-window 能力由 `DeviceFeatures.multi_surface` gate。

Presentation helper 包括 `PresentModeSupport`、`PresentModeResolution`、
`defaultPresentModeSupport(...)` 和 `FramePacingDiagnostics`。
`Device.presentModeSupport()` / `WindowContext.presentModeSupport()` 暴露当前 backend
的保守支持表，`resolvePresentMode(...)` 会报告请求的 present mode 是否 fallback。
`SurfaceCollection.framePacingDiagnostics(...)` 按 surface 返回 configured state、selected
mode、vsync intent、generation、frame-in-flight，以及 submitted/completed frame serial。

## 资源

Period 2 开始，长期资源创建入口是 runtime `Device`。`WindowContext.device()` 返回当前 context
的 device view；旧的 `WindowContext.make*` 方法仍保留为兼容转发。

- `makeBuffer(BufferDescriptor)`
- `makeTexture(TextureDescriptor)`
- `makeSamplerState(SamplerDescriptor)`

`Device` 也暴露第一版 capability 查询：

- `vkmtl.enumerateAdapters(allocator, BackendSelectionOptions)`
- `AdapterSelectionDescriptor`
- `adapterInfo()`
- `features()`
- `limits()`
- `getFormatCaps(TextureFormat)`

当前 adapter enumeration 使用和 backend selection 一致的可用性与排序规则，返回每个可用后端的
保守 `AdapterInfo`。`AdapterSelectionDescriptor.backend` 会强制所选后端，
`AdapterSelectionDescriptor.name` 会和 runtime 解析出的 adapter 名称做精确校验。创建 runtime
context 后，`context.adapterInfo()` 和 `device.adapterInfo()` 会尽量返回后端查询到的 selected
adapter 名称/vendor/type。`Device.limits()` 现在会询问当前 runtime 后端的已知 limits；format
capability 仍使用 portable 默认表，后续可以继续接 backend-specific format query。

CPU 可见 buffer 可以用 `buffer.replaceBytes(...)` 更新，也可以用
`buffer.readBytes(...)` 读回。Period 3 也提供显式 range mapping：

```zig
var mapped = try buffer.mapRange(.{
    .offset = 0,
    .length = buffer.length(),
    .mode = .{ .read = true, .write = true },
});
defer mapped.deinit();

const bytes = mapped.bytes();
```

`BufferMapDescriptor` 会校验 range 和 access mode。Private buffer 不 CPU-visible；这类资源的上传或
读回应该走 transfer 路径。

Texture 通过 `texture.makeTextureView(...)` 创建 view，上传 helper 包括
`texture.replaceRegion(...)` 和 `texture.replaceAll2D(...)`。`TextureDescriptor.shape()` 可以把
texture 归类为 1D、2D、3D、array、cube-compatible、cube-array-compatible 和 multisampled。
Cube texture 当前表示为每个 cube 六层的 2D texture；cube-specific view dimension 留到 texture-view
阶段。

Format helper 包括 `textureFormatKind(...)`、`isColorFormat(...)`、`isDepthFormat(...)`、
`isSrgbFormat(...)` 和 `textureFormatBytesPerPixel(...)`。`FormatCapabilities` 会报告当前已实现
portable format 的 sampled、storage、attachment、filter、mip、blend 和 copy 支持。

Mipmap helper 包括 `mipDimension(...)`、`maxMipLevelCountForExtent(...)`、
`TextureDescriptor.maxMipLevelCount()` 和 `TextureDescriptor.mipExtent(level)`。Texture descriptor
会拒绝超过 texture extent 能支持的 mip count。`GenerateMipmapsDescriptor` 是 future automatic
mipmap generation 的公开可验证 shape；blit encoder 可以用 `generateMipmaps(...)` 生成 full-texture
mip chain。

Runtime `TextureView` 会保存 resolved view format、dimension、mip range 和 layer range。可以通过
`descriptor()`、`baseMipLevel()`、`mipLevelCount()`、`baseArrayLayer()`、`arrayLayerCount()` 查询。

`SamplerDescriptor` 包含 compare、anisotropy 和 border-color 字段。这些高级字段通过
`DeviceFeatures.sampler_compare`、`DeviceFeatures.sampler_anisotropy`、
`DeviceFeatures.sampler_border_color` 和 `DeviceLimits.max_sampler_anisotropy` gate。compare
sampler 和 anisotropy 已经下沉到 Vulkan/Metal sampler 创建。固定 border color 在 address mode 使用
`clamp_to_border` 时也会下沉到 Vulkan 和 Metal sampler 创建；custom border color 暂不覆盖。

`HeapDescriptor` 定义显式 heap planning。`Device.makeHeap(...)` 由 `DeviceFeatures.heaps`
gate，返回的 runtime `Heap` 可以通过 `reserve(...)` 追踪 aligned reservation。默认资源创建仍由
vkmtl 内部管理 memory；native Vulkan `VkDeviceMemory` suballocation 和 Metal `MTLHeap`
backed buffer/texture creation 是后续 backend work。

Sparse/tiled resource shape 由 `SparseBufferMappingDescriptor`、
`SparseTextureMappingDescriptor` 和 `SparseMappingCommitDescriptor` 表示。它们会在
`DeviceFeatures.sparse_buffers`、`DeviceFeatures.sparse_textures` 和
`DeviceFeatures.tiled_textures` gate 后面校验 page size、region alignment 和 residency intent。
Native residency management 仍是 future backend work。

External interop shape 由 `ExternalHandleDescriptor`、`ExternalMemoryDescriptor`、
`ExternalBufferDescriptor`、`ExternalTextureDescriptor` 和 `ExternalSemaphoreDescriptor`
表示。它们会校验 handle kind、selected backend compatibility、resource shape、ownership
和 feature gate。Runtime wrapper 包括 `ExternalMemory`、`ExternalBuffer` 和
`ExternalTexture`，分别由 `Device.makeExternalMemory(...)`、
`Device.makeExternalBuffer(...)` 和 `Device.makeExternalTexture(...)` 创建。External sync
wrapper 包括 `ExternalSemaphore` 和 `ExternalEvent`，分别由
`Device.makeExternalSemaphore(...)` 和 `Device.makeExternalEvent(...)` 创建。
`ExternalSynchronizationDescriptor` 可以传给
`CommandBuffer.commitWithExternalSynchronization(...)`，在 native wait/signal lowering
完成前先做 portable backend/lifetime validation。Native handle import/export 仍是显式
future backend work。

Period 2 开始，runtime resource 会记录 portable usage state。当前 `ResourceUsageState`
能识别 read-after-write、write-after-read 和 write-after-write hazard；blit copy、
render attachment、vertex buffer 和 index buffer 路径已经写入 usage state。显式 barrier
command 也会更新同一份 tracked state。

手动 barrier 是高级 escape hatch。`BufferBarrierDescriptor` 和
`TextureBarrierDescriptor` 会校验范围与 before/after usage transition；
`ResourceUsageState.applyExplicitBarrier(...)` 会记录 tracked transition。需要显式同步点时，
可以调用 `BlitCommandEncoder.bufferBarrier(...)` / `textureBarrier(...)`，或对应的
compute encoder 方法。Vulkan 会下沉为 `vkCmdPipelineBarrier`；Metal 会作为 validation/no-op
synchronization marker，因为普通 Metal encoder 已经定义了大多数 resource ordering。这个路径由
`DeviceFeatures.explicit_resource_barriers` gate 控制；普通代码应该继续走自动 usage-tracking 路径。

Fence 与 event synchronization 已经有 runtime object。`Device.makeFence(...)` 会根据
`FenceDescriptor` 创建 `Fence`；用 `signal(...)`、`wait(...)`、`reset(...)` 和
`currentValue()` 管理 CPU-visible 状态。Binary fence 由 `DeviceFeatures.fences` 控制；
timeline fence 仍由 `DeviceFeatures.timeline_fences` gate 控制。`Device.makeEvent(...)`
会创建带 `signal(...)`、`wait(...)`、`reset()` 和 `isSignaled()` 的 `Event`。Shared
event 仍由 `DeviceFeatures.shared_events` gate 控制。Queue-submit 集成是后续 backend 步骤。

## Shader 与 Pipeline

Slang 是唯一的 shader 源语言。应用通常用 `@embedFile(...)` 嵌入 `.slang` 文件，
并在启动时通过 `Device` 编译：

```zig
const source = @embedFile("shaders/glow.slang");
var device = context.device();
var compiled = try device.compileRenderShader("glow", source, .{
    .vertex_entry = "vs_main",
    .fragment_entry = "fs_main",
});
defer compiled.deinit();
```

编译后的 handle 会根据当前后端选择正确的缓存产物：

```zig
const stages = compiled.stageDescriptors(context.selectedBackend());
```

Compute shader 使用 `compileComputeShader(...)` 和
`CompiledComputeShader.stageDescriptor(...)`。

运行时编译会把 SPIR-V、MSL 和 reflection JSON 写入自动管理的 shader cache。默认 cache
位于可执行文件旁边的 `vkmtl-cache`。如果调用方设置
`WindowContextOptions.process_args = init.args`，vkmtl 会自动解析 `--cache-dir <path>` 或
`--cache-dir=<path>`。应用代码不需要自己解析这个参数。

优先级是：显式 `WindowContextOptions.shader_cache_dir` > `--cache-dir` runtime 参数 > 默认
`vkmtl-cache`。

`ProgrammableStageDescriptor.reflection` 可以携带 reflection 数据。创建 runtime
pipeline 时，vkmtl 会把 reflection artifact 或 inline reflection data 与显式
`bind_group_layouts` 校验。`ShaderReflection` 也提供从 stage reflection 派生 bind
group layout descriptor 的 helper：

```zig
var layouts = try vkmtl.ShaderReflection.deriveRenderPipelineBindGroupLayouts(
    allocator,
    stages.vertex,
    stages.fragment,
);
defer layouts.deinit();
```

Vertex stage reflection 还可以派生单 buffer 的 `VertexDescriptor`；调用方仍然需要提供
stride，因为当前 reflection artifact 记录 attribute layout，但不记录宿主端 vertex
struct 大小：

```zig
var vertex_descriptor = try vkmtl.ShaderReflection.deriveSingleBufferVertexDescriptor(
    allocator,
    stages.vertex,
    .{ .stride = @sizeOf(Vertex) },
);
defer vertex_descriptor.deinit();
```

`ProgrammableStageDescriptor.specialization` 可以携带
`ShaderSpecializationDescriptor` 来描述 shader variants。Descriptor 层会校验重复 ID、
重复名称和空名称。Runtime pipeline fingerprint 包含 specialization 输入，这样 variant
cache 可以区分不同 specialization。Vulkan 在 `DeviceFeatures.shader_specialization`
启用时会把 specialization values 下沉到 pipeline specialization info。未声明该 feature
的后端仍然会用 `UnsupportedShaderSpecialization` 拒绝非空 specialization。

Render pipeline raster state 包含 cull mode、front face、fill mode、depth bias 和
conservative-rasterization flag。Cull mode 和 front face 已在现有 lowering 路径里。
Depth bias 现在会在 pipeline bind 和 dynamic encoder command 两条路径下沉。
Wireframe / line fill mode 会在 Metal 以及暴露 `wireframe_fill_mode` 的 Vulkan
设备上下沉。Conservative rasterization 仍保持 capability-gated，在接上 native mapping
之前会用 typed unsupported error 拒绝。

Color attachment pipeline state 包含 write mask 和可选的
`RenderPipelineBlendDescriptor`。Blend descriptor 分别描述 RGB / alpha 的 factor 和
operation，每个 attachment 都可以有自己的 descriptor。非空 blend state 当前由
`DeviceFeatures.blend_state` gate；每个 attachment 使用不同 blend descriptor 还需要
`DeviceFeatures.independent_blend`。Blend state 和每个 attachment 独立 blend 已经跟
MRT 路径一起下沉到 Vulkan 和 Metal。

Depth/stencil state 包含 `depth_test_enabled`、depth compare/write 字段，以及带 front/back
operation 和 read/write mask 的 `StencilDescriptor`。Depth state 和 combined
depth/stencil state 都会下沉到 Vulkan 和 Metal。`depth32_float_stencil8` 是第一种
stencil-capable format。独立 stencil attachment 会等 attachment model 扩展后再补。

Vertex layout 支持多个 buffer 和 attribute。`VertexBufferLayoutDescriptor` 可以指定显式
`buffer_index`；省略时保持现有按数组位置映射的行为。校验会拒绝重复的 resolved buffer
index、重复 attribute location、非法 stride/offset，以及为 0 的 instance step rate。
非默认 `instance_step_rate` 现在会下沉到 Metal vertex descriptor step rate；在暴露
`vertex_instance_step_rate` 的 Vulkan 设备上会下沉到 vertex binding divisor。

`TessellationDescriptor` 表示 future tessellation pipeline extension state。它由
`DeviceFeatures.tessellation` gate，校验 patch control point count 和 required stage presence，
并且在 backend lowering 设计完成前不会进入 base render pipeline path。

`MeshPipelineDescriptor` 表示 future mesh/task shader pipeline metadata。它由
`DeviceFeatures.mesh_shaders` 和 `DeviceFeatures.task_shaders` gate，校验 mesh entry point、
可选 task entry point 和 workgroup limits，并且保持在 base render pipeline 之外。

Ray tracing 被隔离在高级 descriptor 里：`AccelerationStructureDescriptor`、
`RayTracingPipelineDescriptor` 和 `ShaderBindingTableDescriptor`。它们会在
`DeviceFeatures.acceleration_structures` 和 `DeviceFeatures.ray_tracing` gate 后面校验
acceleration structure shape、ray-generation shader group、recursion depth 和 shader binding
table alignment。

## Binding

Shader 资源绑定从公开描述符开始：

- `BindGroupLayoutDescriptor`
- `BindGroupDescriptor`
- `BindGroupLayout`
- `BindGroup`
- `ShaderVisibility`
- `BindingResourceKind`

高级 binding shape 由 capability gate 控制。`DescriptorIndexingLayoutDescriptor`
和 `DescriptorIndexingRange` 描述 Vulkan descriptor indexing 或 Metal argument buffer layout
所需的 bindless-style range。它们会校验 descriptor count、shader visibility 和选择的
`AdvancedBindingModel`。`Device.makeAdvancedBindGroupLayout(...)` 会把这些 range snapshot 到
backend-aware 的 `AdvancedBindGroupLayout`，并提供 descriptor count 和 range flag 查询。

`Device.makeResourceTable(...)` 会根据 `AdvancedBindGroupLayout` 创建 `ResourceTable`。
Resource table 支持 `update(...)`、`clear(...)`、partially-bound 校验、
update-after-bind 校验，并可以通过 render / compute encoder 的 `setResourceTable(...)`
绑定到命令流。普通 `BindGroup` 仍然是 portable 路径；resource table 是 descriptor
indexing / argument buffer 的高级路径。

当前资源类别包括 uniform buffer、storage buffer、storage texture、sampled texture、
sampler 和 compare sampler。Layout entry 也包含 `array_count` 和 `dynamic_offset`
元数据。Descriptor 层会校验 array count 非零、dynamic offset 只用于 buffer，以及
storage texture 只允许 compute visibility。

Runtime bind group 创建会校验 layout shape、资源类别、后端是否匹配、资源是否还活着，
以及 storage resource usage 是否满足访问意图。Native lowering 支持单资源 binding，也支持
uniform buffer、storage buffer、sampled texture、storage texture、sampler 和 compare sampler
数组。单资源 binding 使用 `BindGroupEntry.resource`；数组 binding 使用
`BindGroupEntry.resources`，数量必须正好等于 `BindGroupLayoutEntry.array_count`：

```zig
const texture_resources = [_]vkmtl.BindGroupResource{
    .{ .sampled_texture = &albedo_view },
    .{ .sampled_texture = &normal_view },
};
const sampler_resources = [_]vkmtl.BindGroupResource{
    .{ .sampler = &linear_sampler },
    .{ .sampler = &nearest_sampler },
};
const entries = [_]vkmtl.BindGroupEntry{
    .{ .binding = 0, .resource = texture_resources[0], .resources = texture_resources[0..] },
    .{ .binding = 1, .resource = sampler_resources[0], .resources = sampler_resources[0..] },
};
```

Dynamic buffer offset 支持单 buffer binding，也支持 buffer array。
`DynamicOffset.array_element` 用来定位 dynamic buffer array 里的元素；默认值 `0`
保持单资源 ABI 不变。

Storage resource 可以在 `BindGroupLayoutEntry.storage_access` 上声明 `.read`、`.write` 或
`.read_write`。这个 metadata 只允许用于 storage buffer 和 storage texture。Storage buffer 默认
read-write，storage texture 为了兼容现有 compute readback 示例默认 write。Runtime bind group
creation 会按这个访问意图检查 buffer `storage` usage，以及 texture `shader_read` /
`shader_write` usage，并记录 portable storage read/write usage transition。

`StaticSamplerDescriptor` 记录 immutable/static sampler 的策略。Static sampler 在概念上由
layout 持有，并继续由 `DeviceFeatures.static_samplers` gate；普通 runtime bind group 仍然使用
活的 `SamplerState` 资源。

`DynamicOffset` 和 `DynamicOffsetList` 是 dynamic buffer offset 的公开校验 shape。Render
和 compute encoder 的 `setBindGroup(...)` 可以通过 `BindGroupBinding.dynamic_offsets`
传入每次绑定的 offset：

```zig
try encoder.setBindGroup(&bind_group, .{
    .index = 0,
    .dynamic_offsets = &.{.{ .binding = 0, .array_element = 0, .offset = 256 }},
});
```

它会校验每个 dynamic buffer binding / array element 都有一个 offset、非 dynamic binding
没有收到 offset，并根据 `DeviceLimits.min_uniform_buffer_offset_alignment` 或
`DeviceLimits.min_storage_buffer_offset_alignment` 检查对齐。Vulkan 会 lower 到 dynamic
descriptor offsets；Metal 会把 dynamic offset 加到 buffer base offset 后再绑定。

`SmallConstantDescriptor` 是小块 per-draw / per-dispatch 常量数据的第一版 portable shape。
它由 `DeviceFeatures.small_constants`、`DeviceLimits.max_small_constant_bytes` 和
`DeviceLimits.small_constant_alignment` gate。当前还没有接入 command encoder lowering。

`RootConstantRange`、`RootConstantLayoutDescriptor` 和
`RootConstantWriteDescriptor` 定义 Vulkan push constants / Metal inline constants
的 portable 等价 shape。它由 `DeviceFeatures.root_constants`、
`DeviceLimits.max_root_constant_bytes` 和 `DeviceLimits.root_constant_alignment`
gate。Render 和 compute pipeline descriptor 带有可选的 `root_constant_layout`，用于按当前
device 校验 pipeline compatibility。Render 和 compute encoder 提供
`setRootConstants(...)`。Vulkan 会下沉到 `vkCmdPushConstants`；Metal 会通过保留的
root-constant buffer slot 调用 `set*Bytes`。

Render 和 compute encoder 都通过 `setBindGroup(...)` 绑定资源。

`BindGroupDescriptor` 是指向活资源的 runtime descriptor。对于纯 descriptor 校验或测试，
root module 也暴露 shape-only alias：`BindGroupResourceDescriptor`、
`BindGroupEntryDescriptor` 和 `BindGroupDescriptorShape`。

使用 shader resource 的 pipeline 应该在 render 或 compute pipeline descriptor 里提供匹配的
`bind_group_layouts`。这些 layout 可以手写，也可以由 reflection helper 派生。Vulkan 用它们
创建 native pipeline layout、分配 descriptor set、写 descriptor，并在 command encoding 时绑定。
Metal 则根据每个 layout entry 的 `ShaderVisibility` 展开成显式 vertex、fragment 或 compute
resource call。

## Command

渲染使用接近 Metal 的命令命名：

```zig
var queue = context.queue();
var command_buffer = try queue.makeCommandBuffer();
var encoder = try command_buffer.makeRenderCommandEncoder(render_pass);
try encoder.setRenderPipelineState(&pipeline);
try encoder.setVertexBuffer(&vertex_buffer, .{ .index = 0 });
try encoder.drawPrimitives(.{ .primitive_type = .triangle, .vertex_count = 3 });
try encoder.endEncoding();
try command_buffer.presentDrawable();
try command_buffer.commit();
```

`Queue.makeCommandBufferWithDescriptor(...)` 接受 `CommandBufferDescriptor`，
用于设置 borrowed label，并为后续 pooling/reuse hint 留出字段。默认
`makeCommandBuffer()` 等价于空 descriptor。`CommandBuffer.state()` 可以查询可移植
lifecycle state。当前 command buffer 在 `commit()` 后仍然是 one-shot；pooled 或 reusable
command buffer 已经由 descriptor 表达，但在 native reset/pooling 接上前会被 feature gate 拒绝。

`QueueKind`、`QueueCapabilities` 和 `QueueDescriptor` 定义 multi-queue selection
词汇。`Device.queue()` 仍然返回 default graphics queue，`Device.queueWithDescriptor(.{})`
是这个默认路径的显式写法。当 backend 不支持 `multi_queue` 且允许 fallback 时，非 graphics
descriptor 会回落到 graphics queue。启用 `DeviceFeatures.multi_queue` 以及对应 dedicated queue
gate 后，`queueWithDescriptor(...)` 会返回 logical compute 或 transfer queue view。当前 backend
仍通过已有 native command queue 记录命令；dedicated native queue family 后续再接。

`QueueOwnershipTransferDescriptor` 已经可以通过 blit / compute encoder 的
`bufferOwnershipTransfer(...)` 和 `textureOwnershipTransfer(...)` 执行。Resource 会用
`ownerQueue()` 暴露当前 logical owner queue；从错误 queue 访问会返回
`InvalidQueueOwnershipState`。Metal 当前映射为 validation/no-op 行为；Vulkan queue-family lowering
会跟随后续 dedicated native queue support 一起完成。

Render pass 可以渲染到当前 drawable，也可以渲染到显式 texture view。Texture-backed color
attachment 在 MSAA 场景下还可以提供 single-sample `resolve_target`。Descriptor model
也包含 stencil attachment、transient attachment hint 和多个 color attachment。当前 runtime
lowering 支持 texture-backed MRT render pass；current drawable render pass 仍保持单个
color attachment。`transient` 目前作为 no-op 性能 hint 保留。Combined depth/stencil
attachment 会通过 depth attachment 路径下沉；独立 stencil-only attachment 仍会返回
typed unsupported error。

Dynamic render state descriptor 包括 `Viewport`、`ScissorRect`、`BlendColor`、
`StencilReference` 和 `DepthBiasDescriptor`。`RenderCommandEncoder` 暴露对应 setter。
这些 setter 会先做 portable validation，然后下沉到 Vulkan 和 Metal 的 native dynamic
state 命令。`BlendColor`、`StencilReference` 和 `DepthBiasDescriptor` 是否影响最终输出仍取决于
当前 render pipeline 是否启用了对应 blend、stencil 或 depth-bias state。

Direct draw descriptor 包含 `base_instance`；indexed draw descriptor 也包含 `base_vertex`。
这些 base 字段已经下沉到 Vulkan 和 Metal direct draw 命令。indirect draw 会下沉到
native backend，并要求 indirect buffer 使用 `.indirect` usage；`draw_count > 1` 会按
stride 拆成多条 single indirect draw。显式 `drawPrimitivesMulti(...)` /
`drawIndexedPrimitivesMulti(...)` 也先通过 repeated direct draws lowering，后续可以在
backend 支持真正 multi-draw 时替换为单条 native path。

Query support 现在从 portable `QuerySet` 对象开始。timestamp query 可以从 blit、
compute 和 render encoder 写入，occlusion query 可以从 render encoder begin/end，
query data 可以直接 readback，也可以 resolve 到 buffer。vkmtl 会校验 query range、
result alignment、resource ownership 和 availability。pipeline statistics query 仍然
通过 feature gate 保守关闭，等 native backend lowering 补齐后再开放。

Transfer 使用 Metal 风格的 blit encoder：

```zig
var queue = context.queue();
var command_buffer = try queue.makeCommandBuffer();
var blit = try command_buffer.makeBlitCommandEncoder();
try blit.copyBufferToBuffer(&source, &destination, .{ .size = byte_count });
try blit.endEncoding();
try command_buffer.commit();
```

当前 lowered blit slice 支持 buffer-to-buffer、buffer-to-texture、texture-to-buffer 和
texture-to-texture。Texture-to-texture copy 可以指定 mip level，并用 `slice_count` 一次复制多个
array layer。Color format 可以在同一 copy class 内复制，例如 `rgba8_unorm` 到
`rgba8_unorm_srgb`；channel order 不同、depth/stencil format 和 MSAA texture 仍会拒绝。
`BlitCommandEncoder.fillBuffer(...)` 也会下沉到 native backend；
Metal 支持任意 byte range。Vulkan 对 4-byte aligned range 继续使用 native
`vkCmdFillBuffer`，对 unaligned range 使用 staging-copy fallback。
`BlitCommandEncoder.generateMipmaps(...)` 会通过 `GenerateMipmapsDescriptor` 校验
format support、copy usage、sample count 和 mip count。Vulkan 会用 image blit 下沉
full-texture generation，Metal 会用 `generateMipmapsForTexture` 下沉 full-texture
generation。Partial mip/layer range 仍保持 unsupported，等 backend parity matrix 决定如何暴露
这种后端差异。

高级用户可以在 blit encoder 上通过 `bufferBarrier(...)` 和 `textureBarrier(...)`
插入显式 barrier。这些方法会先用 tracked resource state 校验 descriptor，再进入 backend。

Compute 使用 Metal 风格的 compute encoder：

```zig
var queue = context.queue();
var command_buffer = try queue.makeCommandBuffer();
var compute = try command_buffer.makeComputeCommandEncoder();
try compute.setComputePipelineState(&pipeline);
try compute.setBindGroup(&bind_group, .{ .index = 0 });
try compute.dispatchThreadgroups(.{
    .threadgroup_count_x = 1,
    .threads_per_threadgroup_x = 4,
});
try compute.endEncoding();
try command_buffer.commit();
```

第一版 compute slice 支持 storage-buffer 和 storage-texture 写入/读回验证。
`DispatchThreadgroupsDescriptor` 会根据 `DeviceLimits` 校验 dispatch grid 和 threadgroup
维度；`DispatchThreadsDescriptor` 与 `ComputeCommandEncoder.dispatchThreads(...)` 是便利 API，
会把总线程数 resolve 成 threadgroup 数量，然后走同一条 backend path。

`DispatchThreadgroupsIndirectDescriptor` 表示 indirect dispatch arguments。
Indirect buffer 使用 `BufferUsage.indirect`；runtime `dispatchThreadgroupsIndirect(...)`
会校验 usage、offset、alignment 和 threadgroup size，然后下发到 Vulkan 的
`vkCmdDispatchIndirect` 或 Metal 的 indirect dispatch path。Metal 需要
`threads_per_threadgroup_*`，所以这些字段也保留在 descriptor 里；Vulkan backend 会忽略它们。

高级 compute shader 需求可以用 `ComputeAtomicDescriptor` 和
`ThreadgroupMemoryDescriptor` 显式声明。这些目前是 validation shape，由
`DeviceFeatures.compute_atomics`、`DeviceFeatures.compute_threadgroup_memory` 和
`DeviceLimits.max_compute_threadgroup_memory_bytes` gate 控制；vkmtl 还不会从 Slang source
自动推断这些需求。

`ComputePipelineCacheKeyDescriptor` 定义 Period 8 对 compute pipeline 做 object cache 时必须纳入
key 的输入：shader source identity、backend、compile profile、entry point、bind group layout、
统一的 `PipelineLayoutCacheKeyDescriptor` 和 specialization constants。它目前只是 validation shape；
native compute pipeline object cache 仍是后续工作。

## Object Cache Diagnostics

Period 8 暴露 expensive native object 的 cache-key 和 diagnostics 形状：

- `ShaderModuleCacheKeyDescriptor`
- `BindGroupLayoutCacheKeyDescriptor`
- `PipelineLayoutCacheKeyDescriptor`
- `RenderPipelineCacheKeyDescriptor`
- `ComputePipelineCacheKeyDescriptor`
- `SamplerCacheKeyDescriptor`

`ObjectCachePolicy` 控制一个 descriptor 是否请求复用、关闭 diagnostics，或只记录 diagnostics。
可缓存 object descriptor 都有默认的 `cache_policy` 字段。`ObjectCacheDiagnostics` 会报告 lookup
hit、miss、creation attempts、equivalent recreation attempts、bypassed reuse、
suppressed diagnostics 和总创建耗时。可以通过 `device.objectCacheDiagnostics()` 或
`context.objectCacheDiagnostics()` 读取快照。

这些 diagnostics 现在会经过 runtime object-cache lookup path，覆盖 shader module、bind group
layout、render pipeline、compute pipeline 和 sampler。它仍不能证明 backend-native handle 已经被
复用；lifetime-safe native handle pooling 是后续 backend work。

Driver-level cache identity 由 `DriverCacheIdentityDescriptor` 和
`DriverPipelineCacheDescriptor` 单独表示。Vulkan pipeline cache 和 Metal binary archive support 由
`DeviceFeatures.driver_pipeline_cache` 与 `DeviceFeatures.metal_binary_archive` gate。Identity 包含
backend、device、driver、shader hash 和 schema version，方便后续显式做 disk cache invalidation。
`Device.planDriverPipelineCache(...)` 会按 native feature report 验证并返回
`DriverPipelineCachePlan`，其中包括 path 是否已经存在，以及 shutdown 时是否应该写入新 blob。
Pipeline creation 目前还不会消费 native driver cache object。

## Debug Label 与 Group

Runtime resource、command buffer 和 command encoder 都暴露借用字符串形式的 debug label：

```zig
buffer.setLabel("vertices");
try render_encoder.pushDebugGroup("opaque pass");
try render_encoder.insertDebugSignpost("draw batch");
try render_encoder.popDebugGroup();
```

资源或 pipeline 创建时，descriptor 里的 label 会写入 runtime wrapper，并在后端支持时同步到
native object label。`label()` 返回当前借用 label，`setLabel(null)` 会清空 label。

Debug group 和 signpost 会做可移植验证：空 label、stack underflow、stack overflow、未闭合
group 都会变成 `CommandEncodingError`。`DebugSignpostDescriptor` 是 shape-only marker
descriptor；command buffer 以及 render/blit/compute encoder 都暴露
`insertDebugSignpost(...)`。Metal command buffer/encoder marker 会下沉到 Metal debug API；
Vulkan render/blit/compute encoder marker 会在 command buffer recording 期间下沉到
`EXT_debug_utils`。Vulkan command-buffer-level marker 仍只保留 portable validation，因为该 API
允许在 encoder 创建之前调用，而 Vulkan native marker 要求 command buffer 已经开始 recording。

## Error 分类

vkmtl 保留精确 Zig error name。应用如果需要更粗粒度的处理，可以调用：

```zig
const category = vkmtl.classifyError(err);
```

当前分类包括 validation、unsupported feature、backend、device lost、surface lost、
resource lifetime、shader compilation 和 unknown。

## Native Handle Escape Hatch

高级用户可以显式调用 `context.nativeHandles()` 获取 backend-native borrowed handles。这个 API
返回 `NativeHandles` tagged union；Vulkan 分支暴露 instance/device/surface/queue handle 值，
Metal 分支暴露 device/command queue/layer/view opaque pointer。

这些 handle 只在 vkmtl owner 存活期间有效。使用它们的代码不再是 backend-neutral。

Native command insertion 也必须显式调用。Render、compute、blit encoder 都暴露
`insertNativeCommands(...)`，参数是 `NativeCommandInsertionDescriptor`。Descriptor 会先验证
feature gate、callback 和 encoder kind，再调用用户代码。真实 command-buffer /
command-encoder native handle view 接好之前，backend 会保持这个 feature 关闭。
