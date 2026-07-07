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
mipmap generation 的公开可验证 shape；当前 command encoder 仍需要应用显式 upload/copy 每个 mip level。

Runtime `TextureView` 会保存 resolved view format、dimension、mip range 和 layer range。可以通过
`descriptor()`、`baseMipLevel()`、`mipLevelCount()`、`baseArrayLayer()`、`arrayLayerCount()` 查询。

`SamplerDescriptor` 包含 compare、anisotropy 和 border-color 字段。这些高级字段通过
`DeviceFeatures.sampler_compare`、`DeviceFeatures.sampler_anisotropy`、
`DeviceFeatures.sampler_border_color` 和 `DeviceLimits.max_sampler_anisotropy` gate。compare
sampler 和 anisotropy 已经下沉到 Vulkan/Metal sampler 创建；border color 仍然是
descriptor-level shape，默认关闭。

`HeapDescriptor` 定义 future advanced memory/heap shape。默认资源创建仍由 vkmtl 内部管理 memory；
`DeviceFeatures.heaps` 在显式 Vulkan/Metal heap allocation 实现前保持 false。

Sparse/tiled resource shape 由 `SparseBufferMappingDescriptor`、
`SparseTextureMappingDescriptor` 和 `SparseMappingCommitDescriptor` 表示。它们会在
`DeviceFeatures.sparse_buffers`、`DeviceFeatures.sparse_textures` 和
`DeviceFeatures.tiled_textures` gate 后面校验 page size、region alignment 和 residency intent。
Native residency management 仍是 future backend work。

External interop shape 由 `ExternalHandleDescriptor`、`ExternalTextureDescriptor` 和
`ExternalSemaphoreDescriptor` 表示。它们会在 `DeviceFeatures.external_textures` 和
`DeviceFeatures.external_semaphores` gate 后面校验 handle kind、selected backend compatibility 和
texture shape。Native handle import/export 仍是显式 future backend work。

Period 2 开始，runtime resource 会记录 portable usage state。当前 `ResourceUsageState`
能识别 read-after-write、write-after-read 和 write-after-write hazard；blit copy、
render attachment、vertex buffer 和 index buffer 路径已经写入 usage state。后续 Vulkan
barrier lowering 会消费这些 transition。

手动 barrier 是高级 escape hatch。`BufferBarrierDescriptor` 和
`TextureBarrierDescriptor` 会校验范围与 before/after usage transition；
`ResourceUsageState.applyExplicitBarrier(...)` 会记录显式 tracked transition。Native
explicit-barrier command 由 `DeviceFeatures.explicit_resource_barriers` gate 控制，默认关闭；
普通代码应该继续走自动 usage-tracking 路径。

Fence 与 event synchronization 在这个 period 仍是 descriptor-only。
`FenceDescriptor`、`FenceSignalDescriptor` 和 `FenceWaitDescriptor` 会在
`DeviceFeatures.fences` 与 `DeviceFeatures.timeline_fences` 后面校验 binary/timeline fence
值。`EventDescriptor` 以及 event wait/signal descriptor shape 由 `DeviceFeatures.events`
和 `DeviceFeatures.shared_events` gate 控制。Runtime fence/event object 是后续工作。

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
`ShaderSpecializationDescriptor`，为后续 shader variants 预留。
`ShaderLibraryCacheKeyDescriptor` 也包含 specialization 输入，这样未来 variant cache
可以区分不同 specialization。Descriptor 层会校验重复 ID、重复名称和空名称。当前
runtime pipeline 创建会用 `UnsupportedShaderSpecialization` 拒绝非空 specialization，
而不是静默忽略。

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
和 `DescriptorIndexingRange` 描述 future Vulkan descriptor indexing 或 Metal argument buffer
lowering 需要的 bindless-style range。它们会校验 descriptor count、shader visibility 和选择的
`AdvancedBindingModel`，但 backend lowering 还没有实现。

当前资源类别包括 uniform buffer、storage buffer、storage texture、sampled texture、
sampler 和 compare sampler。Layout entry 也包含 `array_count` 和 `dynamic_offset`
元数据。Descriptor 层会校验 array count 非零、dynamic offset 只用于 buffer，以及
storage texture 只允许 compute visibility。

Runtime bind group 创建会校验 layout shape、资源类别、后端是否匹配、资源是否还活着，
以及 storage resource usage 是否满足访问意图。当前 native lowering 只支持单资源
binding（`array_count = 1`），并会用明确的 `UnsupportedResourceArray` /
`UnsupportedDynamicBinding` 错误拒绝 dynamic-offset layout；后续 backend lowering 阶段
再接上真正的数组和动态 offset 支持。

Storage resource 可以在 `BindGroupLayoutEntry.storage_access` 上声明 `.read`、`.write` 或
`.read_write`。这个 metadata 只允许用于 storage buffer 和 storage texture。Storage buffer 默认
read-write，storage texture 为了兼容现有 compute readback 示例默认 write。Runtime bind group
creation 会按这个访问意图检查 buffer `storage` usage，以及 texture `shader_read` /
`shader_write` usage，并记录 portable storage read/write usage transition。

`DynamicOffset` 和 `DynamicOffsetList` 是后续动态 offset 命令路径的公开校验 shape。
它会校验每个 dynamic buffer binding 都有一个 offset、非 dynamic binding 没有收到 offset，
并根据 `DeviceLimits.min_uniform_buffer_offset_alignment` 或
`DeviceLimits.min_storage_buffer_offset_alignment` 检查对齐。

`SmallConstantDescriptor` 是小块 per-draw / per-dispatch 常量数据的第一版 portable shape。
它由 `DeviceFeatures.small_constants`、`DeviceLimits.max_small_constant_bytes` 和
`DeviceLimits.small_constant_alignment` gate。当前还没有接入 command encoder lowering。

`RootConstantRange`、`RootConstantLayoutDescriptor` 和
`RootConstantWriteDescriptor` 定义 Vulkan push constants / Metal inline constants
的 portable 等价 shape。它由 `DeviceFeatures.root_constants`、
`DeviceLimits.max_root_constant_bytes` 和 `DeviceLimits.root_constant_alignment`
gate。当前 API 会校验 range 和 write，但还没有 lowering 到 command encoder。

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
是这个默认路径的显式写法。Dedicated compute/transfer queue 与 queue ownership transfer 已经由
descriptor 和 feature gate 表达，但 runtime 选择非 graphics queue 目前会返回 typed unsupported
error。

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

Query support 目前是 descriptor-only。`QuerySetDescriptor` 覆盖 occlusion、timestamp 和
pipeline statistics query，并带 feature gate。`QueryResolveDescriptor` 和
`QueryReadbackDescriptor` 会校验 query range 和 result alignment，但 runtime query pool
以及 encoder command 是后续工作。

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
texture-to-texture。`BlitCommandEncoder.fillBuffer(...)` 也会下沉到 native backend；
Metal 支持任意 byte range，Vulkan 使用 `vkCmdFillBuffer`，因此 Vulkan 路径要求 offset 和
size 都按 4 字节对齐，否则返回 `UnsupportedFillBuffer`。

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

`ObjectCachePolicy` 控制一个 key 是否请求复用、关闭 diagnostics，或只记录 diagnostics。
`ObjectCacheDiagnostics` 会报告 hit、miss、creation attempts、equivalent recreation attempts、
bypassed reuse、suppressed diagnostics 和总创建耗时。可以通过
`device.objectCacheDiagnostics()` 或 `context.objectCacheDiagnostics()` 读取快照。

这些 diagnostics 目前统计 key-equivalent runtime object creation attempts；它还不能证明
backend-native handle 已经被复用。

Driver-level cache identity 由 `DriverCacheIdentityDescriptor` 和
`DriverPipelineCacheDescriptor` 单独表示。Vulkan pipeline cache 和 Metal binary archive support 由
`DeviceFeatures.driver_pipeline_cache` 与 `DeviceFeatures.metal_binary_archive` gate。Identity 包含
backend、device、driver、shader hash 和 schema version，方便后续显式做 disk cache invalidation。

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
