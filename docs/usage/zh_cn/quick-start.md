# 快速开始

本文描述当前 vkmtl 面向早期应用和示例的公开使用路径。vkmtl 仍是实验项目，但 Phase 8 的纵切
已经可以通过公开 API 使用。

## 添加依赖

应用的 `build.zig` 可以依赖 vkmtl 并导入公开模块：

```zig
const vkmtl_dep = b.dependency("vkmtl", .{
    .target = target,
    .optimize = optimize,
});
const vkmtl = vkmtl_dep.module("vkmtl");

exe.root_module.addImport("vkmtl", vkmtl);
```

vkmtl 不负责创建窗口。应用应该使用自己的 windowing package，然后把
`SurfaceDescriptor` 和 `PresentationDescriptor` 传给 vkmtl。仓库示例使用 `zig_glfw`，
adapter 代码放在 `examples/common.zig`。

## 创建 WindowContext

当前 runtime owner 是 `WindowContext`。它拥有后端选择、presentation chain、资源、shader cache
配置和 command 创建能力。需要启用 vkmtl runtime 参数时，应用的 `main` 可以接受
`std.process.Init.Minimal`，并把 `init.args` 传给 context。

```zig
const vkmtl = @import("vkmtl");

var context = try vkmtl.WindowContext.init(allocator, .{
    .app_name = "my app",
    .backend = .auto,
    .process_args = init.args,
    .surface = surface_descriptor,
    .presentation = presentation_descriptor,
});
defer context.deinit();

std.debug.print("Using backend: {}\n", .{context.selectedBackend()});
```

Apple 平台上，`.auto` 会优先选择 Metal。其他桌面平台优先 Vulkan。应用也可以显式请求
`.vulkan` 或 `.metal`；示例还支持用于后端测试的 build-time `-Dvulkan` override。

## 运行时编译 Slang

应用嵌入 Slang source，并通过 context 编译。vkmtl 会把 SPIR-V、MSL 和 reflection JSON 写入
runtime shader cache。

```zig
const shader_source = @embedFile("shaders/triangle.slang");

var compiled = try context.compileRenderShader("triangle", shader_source, .{
    .vertex_entry = "vs_main",
    .fragment_entry = "fs_main",
});
defer compiled.deinit();

const stages = compiled.stageDescriptors(context.selectedBackend());
```

把这些 stage descriptor 用在 render pipeline 中：

```zig
var pipeline = try context.makeRenderPipelineState(.{
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
var compiled_compute = try context.compileComputeShader("compute", shader_source, .{
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
var vertex_buffer = try context.makeBuffer(.{
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
var texture = try context.makeTexture(.{
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

var sampler = try context.makeSamplerState(.{
    .min_filter = .linear,
    .mag_filter = .linear,
});
defer sampler.deinit();
```

## 绑定 Shader 资源

推荐路径是先从 shader reflection 派生 bind group layout，然后通过 `BindGroupDescriptor`
绑定 runtime 资源。

```zig
var layouts = try vkmtl.ShaderReflection.deriveRenderPipelineBindGroupLayouts(
    allocator,
    stages.vertex,
    stages.fragment,
);
defer layouts.deinit();

var bind_group_layout = try context.makeBindGroupLayout(layouts.descriptors()[0]);
defer bind_group_layout.deinit();

var bind_group = try context.makeBindGroup(.{
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
var command_buffer = try context.makeCommandBuffer();
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

Drawable 尺寸变化时调用 `context.resize(extent)`。示例会每帧从 windowing 层读取 framebuffer
extent 后调用 resize。

## Transfer 与 Compute

显式 copy 使用 blit encoder：

```zig
var command_buffer = try context.makeCommandBuffer();
var blit = try command_buffer.makeBlitCommandEncoder();
try blit.copyBufferToBuffer(&source, &destination, .{ .size = byte_count });
try blit.endEncoding();
try command_buffer.commit();
```

Compute dispatch 使用 compute encoder：

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

确定性 readback 示例见 `examples/transfer_readback` 和 `examples/compute_readback`。

## Shader Cache

vkmtl 会自动缓存 runtime shader artifact。cache key 包含 embedded source hash；source
变化后，vkmtl 会重新编译并重写缓存产物。如果应用把 `init.args` 传给 `WindowContext`，vkmtl
会自动解析自己的 `--cache-dir` runtime 参数，应用代码不需要自己处理这个参数。

## 当前限制

- 资源创建当前仍在 `WindowContext` 上；未来稳定的 `Device` owner 应该替代这个临时入口。
- vkmtl 不负责图片解码、mesh 加载或文字渲染。应用应该提供像素数据和更高层 asset 系统。
- GLFW 不属于 vkmtl core。使用外部 window adapter，比如示例里的 `zig_glfw` glue。
- 公开 descriptor 已有 debug label，但 native 后端对象 label 仍是 Phase 9 polish 项。
