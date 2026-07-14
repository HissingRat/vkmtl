# Shader 编写

Slang 是 vkmtl 唯一的 shader 源语言。

## 源码布局

示例 shader 放在各自 example 旁边：

```text
examples/triangle/shaders/triangle.slang
examples/offscreen_texture/shaders/offscreen_texture.slang
examples/msaa_triangle/shaders/msaa_triangle.slang
examples/rainbow_cube/shaders/rainbow_cube.slang
examples/compute_readback/shaders/compute_readback.slang
```

## Consumer Shader Manifest

应用通过 vkmtl dependency 的 source-backed `shader_manifest` lazy-path option
注册自己的 shader：

```zig
const vkmtl_dep = b.dependency("vkmtl", .{
    .target = target,
    .optimize = optimize,
    .shader_manifest = b.path("shaders/manifest.json"),
});
```

Schema version 1 继续支持前三个 array。Schema version 2 保留它们，并增加两个高级
geometry array：

| Array | 必填 entry field |
| --- | --- |
| `render_shaders` | `name`、`source`、`vertex_entry`、`fragment_entry` |
| `compute_shaders` | `name`、`source`、`entry` |
| `ray_tracing_shaders` | `name`、`source`、`metal_ray_generation_source`、`ray_generation_entry`、`miss_entry`、`closest_hit_entry`、`any_hit_entry`、`intersection_entry` |
| `tessellation_shaders` | `name`、`source`、`vertex_entry`、`control_entry`、`evaluation_entry`、`fragment_entry` |
| `mesh_shaders` | `name`、`source`、`mesh_entry`、可选 `task_entry`、`fragment_entry` |

每个 array 都可以为空。Name 在所有 array 中必须全局唯一，并使用 portable lowercase 形式
`[a-z0-9_.-]+`（`.` 和 `..` 不是合法 name）。`source` 与
`metal_ray_generation_source` 都相对于 manifest 文件解析，且不能越出
LazyPath owner 的 logical root。两个 schema 都不支持 generated manifest，因为
dependency graph 会在 configuration 时枚举 shader input。构建会追踪 manifest、
每个已声明 source，并通过 Slang depfile 追踪 include/import dependency。

仓库自身示例默认使用 `shaders/manifest.json`。Consumer 应该传入自己的 manifest，确保
生成的 shader module 包含应用声明，而不是仓库 example set。

示例通过 `@embedFile(...)` 嵌入这些 `.slang` 文件，并在运行时通过 `Device`
声明需要的 shader。`zig build` 会把匹配的 SPIR-V、MSL 和 reflection JSON 预编译进
可执行文件；运行时直接从内嵌 blob 解析，不会写入磁盘。构建时会同时安装一份可检查的
artifact 到 `zig-out/shaders`：

```text
zig-out/shaders/<shader-name>/
  vert.spv
  frag.spv
  vert.msl
  frag.msl
  vert.reflect.json
  frag.reflect.json
```

Compute shader 使用 `compute.spv`、`compute.msl` 和 `compute.reflect.json`。
source hash 保存在内嵌 blob metadata 里。找不到匹配 name、entry 和 source hash 的 blob
时会报 `PrecompiledShaderMissing`。

Tessellation entry 会为 Vulkan 生成 vertex、control、evaluation 与 fragment SPIR-V。
当前 pinned Slang 的 Metal target 会拒绝 hull/domain stage，因此在纯 Slang artifact
contract 下 Metal tessellation 明确不支持。Mesh entry 会生成 mesh/fragment SPIR-V 与
MSL，并在 capability 合格的 backend 上执行。当前 pinned compiler 会在已探测的
task/amplification 形式上崩溃，因此 `task_entry` 尚不能打开 usable gate，
`DeviceFeatures.task_shaders` 保持 false。`ShaderVisibility` 目前也尚未包含高级 stage；
Period 51 的 executable tessellation/mesh 子集要求高级 stage 不使用资源绑定，普通
fragment binding 仍然可用。

## 构建命令

默认 `zig build` 会准备 pinned Slang distribution，目前是 `v2026.12.2`，位置在
`.zig-cache/vkmtl-tools`，并预编译当前 manifest 中的 embedded shader。

pinned Slang 版本和 release package hash 在 `build.zig` 中；下载、校验和解压命令放在
`scripts/`。当前 auto download 覆盖 macOS、Linux 和 Windows 的受支持 host 架构。如果
consumer build host 没有对应 pinned package，通过 dependency option 转发 compiler path：

```zig
const vkmtl_dep = b.dependency("vkmtl", .{
    .target = target,
    .optimize = optimize,
    .shader_manifest = b.path("shaders/manifest.json"),
    .slangc = "/path/to/build-time/slangc",
});
```

直接构建 vkmtl 仓库时，等价 override 是：

```sh
zig build run-rainbow-cube -Dslangc=/path/to/build-time/slangc
```

运行时不需要 shader cache 目录，也不解析 `--cache-dir`。如果需要检查编译后的 shader
产物，使用构建输出中的 `zig-out/shaders/<shader-name>/`。

## 当前 Shader 形状

第一版支持的 shader 形状比较保守：

- vertex 和 fragment stage
- Phase 8 compute stage，用于 storage-buffer 和 storage-texture readback
- 显式 `[shader("vertex")]` / `[shader("fragment")]` entry point attribute
- compute 使用显式 `[shader("compute")]` 和 `[numthreads(...)]`
- 显式 vertex input semantic
- Vulkan 产物是 SPIR-V
- Metal 产物是 MSL

当前约定 entry point：

```text
vs_main
fs_main
cs_main
```

## 运行时消费

应用嵌入 Slang source，然后通过 `Device` 解析对应的预编译 shader：

```zig
const shader_source = @embedFile("shaders/glow.slang");

var device = context.device();
var compiled = try device.compileRenderShader("glow", shader_source, .{
    .vertex_entry = "vs_main",
    .fragment_entry = "fs_main",
});
defer compiled.deinit();

const stages = compiled.stageDescriptors(context.selectedBackend());
```

Compute shader 使用 compute 专用入口：

```zig
const source = @embedFile("shaders/compute.slang");

var device = context.device();
var compiled = try device.compileComputeShader("compute", source, .{
    .entry = "cs_main",
});
defer compiled.deinit();

const compute_stage = compiled.stageDescriptor(context.selectedBackend());
```

内嵌 blob 命中时会打印 `using precompiled slang shader: <name>`。

## Binding 规则

Phase 6 开始的 binding model 使用 bind group layout descriptor 和 bind group descriptor。
Slang 资源声明应该显式写 group 和 binding annotation，这样 reflection 才能派生并校验 layout。

映射关系：

- Slang group -> vkmtl bind group index
- Slang binding -> `BindGroupLayoutEntry.binding`
- Slang resource class -> `BindingResourceKind`
- Slang stage usage -> `ShaderVisibility`
- fixed resource array length -> `BindGroupLayoutEntry.array_count`
- read/RW storage declaration -> `BindGroupLayoutEntry.storage_access`

Sampled texture 示例使用 binding 0 作为 texture，binding 1 作为 sampler：

```text
Texture2D<float4> color_texture : register(t0, space0);
SamplerState color_sampler : register(s1, space0);
```

Rainbow cube 示例在 group 0 使用一个 uniform buffer、一个 sampled texture 和一个 sampler：

```text
ConstantBuffer<Uniforms> uniforms : register(b0, space0);
Texture2D<float4> rainbow_texture : register(t1, space0);
SamplerState rainbow_sampler : register(s2, space0);
```

Compute readback 示例使用一个 writable storage texture 和一个 writable storage buffer：

```text
[[vk::binding(0, 0)]]
[[vk::image_format("rgba8")]]
RWTexture2D<float4> output_texture : register(u0, space0);

[[vk::binding(1, 0)]]
RWStructuredBuffer<uint> output_values : register(u1, space0);
```

Storage texture 需要显式 Vulkan image format annotation，这样 Slang 才能为 SPIR-V 生成 storage
image format。当前示例使用 binding 0 作为 storage texture，binding 1 作为 storage buffer。
Slang 会把 `RWTexture2D` 下沉为 Metal `access::read_write`，所以即使 shader body 只写入，
texture descriptor 也要同时声明 `shader_read` 和 `shader_write` usage。Metal API
Validation 会把 native usage 与这个 access qualifier 一起检查。

Compiled shader handle 会给每个 programmable stage 绑定运行时生成的 reflection JSON：

```zig
const stages = compiled.stageDescriptors(context.selectedBackend());
```

vkmtl 会校验 stage、entry point、bind group index、binding number、resource kind、array
count、storage access 和 shader visibility 是否匹配 pipeline descriptor 提供的
`bind_group_layouts`。Reflection 也能在
pipeline 创建前派生 bind group layout descriptor：

```zig
var layouts = try vkmtl.shader.Reflection.deriveComputePipelineBindGroupLayouts(
    allocator,
    compute_stage,
);
defer layouts.deinit();
```

Vertex-stage reflection 包含 `vertex_inputs`，记录 location、format 和 offset。第一个 helper 能
派生单 buffer 的 `VertexDescriptor`；调用方需要显式提供 stride：

```zig
var vertex_descriptor = try vkmtl.shader.Reflection.deriveSingleBufferVertexDescriptor(
    allocator,
    stages.vertex,
    .{ .stride = @sizeOf(Vertex) },
);
defer vertex_descriptor.deinit();
```

所有 shader-backed examples 都附带运行时生成的 reflection artifact。更多 binding model 决策见
`docs/develop/period1/phase6.md`。

Schema 1 覆盖 portable buffer、texture、sampler、fixed array、storage access 和 vertex-input
子集。Bindless/runtime-sized array、tensor、payload、function table 和 backend-only reflection
protocol 不会被这个 schema 静默近似。
