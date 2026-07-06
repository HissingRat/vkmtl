# 核心 API

vkmtl 通过公开的 `vkmtl` 模块暴露后端无关的描述符和运行时包装。用户代码不应该导入
`backend/vulkan`、`backend/metal`、原始 Vulkan binding 或 Metal bridge header。

当前窗口示例的运行时入口是 `WindowContext`。长期看，资源创建会迁移到稳定的
`Device` / `Queue` 拥有者；但在第一阶段纵切里，`WindowContext` 暂时拥有这些能力。

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

## 资源

当前公开资源创建入口在 `WindowContext` 上：

- `makeBuffer(BufferDescriptor)`
- `makeTexture(TextureDescriptor)`
- `makeSamplerState(SamplerDescriptor)`

CPU 可见 buffer 可以用 `buffer.replaceBytes(...)` 更新，也可以用
`buffer.readBytes(...)` 读回。Texture 通过 `texture.makeTextureView(...)` 创建 view，
上传 helper 包括 `texture.replaceRegion(...)` 和 `texture.replaceAll2D(...)`。

## Shader 与 Pipeline

Slang 是唯一的 shader 源语言。应用通常用 `@embedFile(...)` 嵌入 `.slang` 文件，
并在启动时通过 `WindowContext` 编译：

```zig
const source = @embedFile("shaders/glow.slang");
var compiled = try context.compileRenderShader("glow", source, .{
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

## Binding

Shader 资源绑定从公开描述符开始：

- `BindGroupLayoutDescriptor`
- `BindGroupDescriptor`
- `BindGroupLayout`
- `BindGroup`
- `ShaderVisibility`
- `BindingResourceKind`

当前资源类别包括 uniform buffer、storage buffer、storage texture、sampled texture 和
sampler。Runtime bind group 创建会校验 layout shape、资源类别、后端是否匹配、资源是否
还活着，以及 storage texture 是否带有 `shader_write` usage。

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
var command_buffer = try context.makeCommandBuffer();
var encoder = try command_buffer.makeRenderCommandEncoder(render_pass);
try encoder.setRenderPipelineState(&pipeline);
try encoder.setVertexBuffer(&vertex_buffer, .{ .index = 0 });
try encoder.drawPrimitives(.{ .primitive_type = .triangle, .vertex_count = 3 });
try encoder.endEncoding();
try command_buffer.presentDrawable();
try command_buffer.commit();
```

Render pass 可以渲染到当前 drawable，也可以渲染到显式 texture view。Texture-backed color
attachment 在 MSAA 场景下还可以提供 single-sample `resolve_target`。

Transfer 使用 Metal 风格的 blit encoder：

```zig
var command_buffer = try context.makeCommandBuffer();
var blit = try command_buffer.makeBlitCommandEncoder();
try blit.copyBufferToBuffer(&source, &destination, .{ .size = byte_count });
try blit.endEncoding();
try command_buffer.commit();
```

第一版 blit 支持 buffer-to-buffer、buffer-to-texture 和 texture-to-buffer。

Compute 使用 Metal 风格的 compute encoder：

```zig
var command_buffer = try context.makeCommandBuffer();
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
