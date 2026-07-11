# 快速开始

本文描述当前 vkmtl 面向早期应用和示例的公开使用路径。vkmtl 仍是实验项目，但 Phase 8 的纵切
已经可以通过公开 API 使用。

## 添加依赖

应用的 `build.zig` 可以依赖 vkmtl 并导入公开模块：

```zig
const vkmtl_dep = b.dependency("vkmtl", .{
    .target = target,
    .optimize = optimize,
    .shader_manifest = b.path("shaders/manifest.json"),
});
const vkmtl = vkmtl_dep.module("vkmtl");

exe.root_module.addImport("vkmtl", vkmtl);
```

`shader_manifest` 是 consumer 自己拥有的 source-backed `std.Build.LazyPath`。
Schema version 1 不支持 generated manifest。Schema version 1 包含
`render_shaders`、`compute_shaders`、`ray_tracing_shaders` 三个 array。Render entry 使用
`name`、`source`、`vertex_entry`、`fragment_entry`；compute entry 使用 `name`、`source`、
`entry`；ray-tracing entry 使用 `name`、`source`、`metal_ray_generation_source`、
`ray_generation_entry`、`miss_entry`、`closest_hit_entry`、`any_hit_entry`、
`intersection_entry`。Source path 相对于 manifest，不能越出 LazyPath owner root；
Slang include/import dependency 通过 depfile 追踪。Shader name 必须全局唯一，并使用
lowercase portable `[a-z0-9_.-]+`。

未知 build host 还需要把构建期 compiler 作为 dependency option 转发：

```zig
.slangc = "/path/to/build-time/slangc",
```

完整字段见 [Shader 编写](../../api/zh_cn/shaders.md)。

vkmtl 不负责创建窗口。应用应该使用自己的 windowing package，然后把
`SurfaceDescriptor` 和 `PresentationDescriptor` 传给 vkmtl。仓库示例使用 `zig_glfw`，
adapter 代码放在 `examples/common.zig`。

## 创建 WindowContext

当前窗口 convenience owner 是 `WindowContext`。它负责后端选择和 presentation chain；
资源创建从 `context.device()` 取得的 `Device` 进入，command buffer 从 `context.queue()`
取得的 `Queue` 进入。

```zig
const vkmtl = @import("vkmtl");

var context = try vkmtl.WindowContext.init(allocator, .{
    .app_name = "my app",
    .backend = .auto,
    .surface = surface_descriptor,
    .presentation = presentation_descriptor,
});
defer context.deinit();

std.debug.print("Using backend: {}\n", .{context.selectedBackend()});

var device = context.device();
var queue = context.queue();
var swapchain = context.swapchain();
```

Apple 平台上，`.auto` 会优先选择 Metal。其他桌面平台优先 Vulkan。应用也可以显式请求
`.vulkan` 或 `.metal`；示例还支持用于后端测试的 build-time `-Dvulkan` override。

`Device` 是资源创建入口；`Queue` 负责 command buffer 创建与提交；`Swapchain` 负责
drawable resize 和 clear。`WindowContext` 只保留 backend identity、native handle，以及
这些 runtime owner 的访问入口。

## 使用预编译 Slang Shader

应用嵌入 Slang source，并通过 device 请求同名 shader。`zig build` 会预编译匹配的
SPIR-V、MSL 和 reflection JSON；运行时直接从内存解析内嵌产物。

```zig
const shader_source = @embedFile("shaders/triangle.slang");

var compiled = try device.compileRenderShader("triangle", shader_source, .{
    .vertex_entry = "vs_main",
    .fragment_entry = "fs_main",
});
defer compiled.deinit();

const stages = compiled.stageDescriptors(context.selectedBackend());
```

把这些 stage descriptor 用在 render pipeline 中：

```zig
var pipeline = try device.makeRenderPipelineState(.{
    .vertex = stages.vertex,
    .fragment = stages.fragment,
    .color_attachments = &.{
        .{ .format = .bgra8_unorm },
    },
});
defer pipeline.deinit();
```

Compute shader 使用 compute 专用 helper：

```zig
var compiled_compute = try device.compileComputeShader("compute", shader_source, .{
    .entry = "cs_main",
});
defer compiled_compute.deinit();

const compute_stage = compiled_compute.stageDescriptor(context.selectedBackend());
```

## 创建资源

资源是显式 handle，必须在 `WindowContext` 前销毁。Debug build 会追踪资源生命周期，如果
`WindowContext.deinit()` 时仍有资源未释放，会 panic。

在完整函数中，先注册 `defer context.deinit()`，再注册资源的 `defer resource.deinit()`。Zig
会以后进先出顺序执行 defer，因此资源会先释放，context 最后释放。

```zig
var vertex_buffer = try device.makeBuffer(.{
    .label = "vertices",
    .length = @sizeOf([3]Vertex),
    .usage = .{ .vertex = true },
    .storage_mode = .shared,
    .initial_data = std.mem.sliceAsBytes(vertices[0..]),
});
defer vertex_buffer.deinit();
```

Texture 上传使用接近 Metal 的命名：

```zig
var texture = try device.makeTexture(.{
    .label = "checker",
    .format = .rgba8_unorm,
    .width = 2,
    .height = 2,
    .usage = .{ .shader_read = true, .copy_destination = true },
});
defer texture.deinit();

try texture.replaceAll2D(.{ .bytes = pixels[0..] });

var texture_view = try texture.makeTextureView(.{});
defer texture_view.deinit();

var sampler = try device.makeSamplerState(.{
    .min_filter = .linear,
    .mag_filter = .linear,
});
defer sampler.deinit();
```

## 绑定 Shader 资源

推荐路径是先从 shader reflection 派生 bind group layout，然后通过 `BindGroupDescriptor`
绑定 runtime 资源。

```zig
var layouts = try vkmtl.shader.Reflection.deriveRenderPipelineBindGroupLayouts(
    allocator,
    stages.vertex,
    stages.fragment,
);
defer layouts.deinit();

var bind_group_layout = try device.makeBindGroupLayout(layouts.descriptors()[0]);
defer bind_group_layout.deinit();

var bind_group = try device.makeBindGroup(.{
    .layout = &bind_group_layout,
    .entries = &.{
        .{ .binding = 0, .resource = .{ .sampled_texture = &texture_view } },
        .{ .binding = 1, .resource = .{ .sampler = &sampler } },
    },
});
defer bind_group.deinit();
```

Runtime bind group 创建会校验 layout shape、资源生命周期、后端匹配、buffer range 和
storage-texture usage。

## 编码并呈现

渲染命令使用 Metal 风格命名：

```zig
var command_buffer = try queue.makeCommandBuffer();
var encoder = try command_buffer.makeRenderCommandEncoder(.{
    .color_attachments = &.{
        .{
            .clear_color = .{ .red = 0.02, .green = 0.03, .blue = 0.04, .alpha = 1 },
        },
    },
});

try encoder.setRenderPipelineState(&pipeline);
try encoder.setVertexBuffer(&vertex_buffer, .{ .index = 0 });
try encoder.setBindGroup(&bind_group, .{ .index = 0 });
try encoder.drawPrimitives(.{ .primitive_type = .triangle, .vertex_count = 3 });
try encoder.endEncoding();

try command_buffer.presentDrawable();
try command_buffer.commit();
```

Drawable 尺寸变化时调用 `swapchain.resize(extent)`。示例会每帧从 windowing 层读取 framebuffer
extent 后调用 resize。

## Transfer 与 Compute

显式 copy 使用 blit encoder：

```zig
var command_buffer = try queue.makeCommandBuffer();
var blit = try command_buffer.makeBlitCommandEncoder();
try blit.copyBufferToBuffer(&source, &destination, .{ .size = byte_count });
try blit.endEncoding();
try command_buffer.commit();
```

Compute dispatch 使用 compute encoder：

```zig
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

如果用总线程数思考更自然，可以使用 `dispatchThreads(...)`；vkmtl 会 resolve threadgroup
数量，并应用同一套 device-limit 校验。

确定性 readback 示例见 `examples/transfer_readback` 和 `examples/compute_readback`。

## Shader Artifacts

`zig build` 会把 embedded Slang 预编译并内嵌进可执行文件。运行时直接从内存解析 shader
blob，不创建 cache 目录。需要检查 SPIR-V、MSL 或 reflection JSON 时，查看
`zig-out/shaders/<shader-name>/`。

## 当前限制

- `Device`、`Queue` 和 `Swapchain` 分别负责资源创建、command 和 presentation；
  `WindowContext` 不再转发这些操作。
- vkmtl 不负责图片解码、mesh 加载或文字渲染。应用应该提供像素数据和更高层 asset 系统。
- GLFW 不属于 vkmtl core。使用外部 window adapter，比如示例里的 `zig_glfw` glue。
- Runtime wrapper 会保存 borrowed debug label；有效 UTF-8 backing bytes 必须存活到 label 被替换或 object 销毁。Marker label 只在调用期间被 borrow。Metal marker 与 Vulkan encoder-level marker 已下沉到 native debug API；Vulkan command-buffer-level marker 仍只做 portable validation。
