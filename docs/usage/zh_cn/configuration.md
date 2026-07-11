# 配置

vkmtl 会显式处理后端选择和构建期 shader 编译器。示例尽量暴露相同配置项。

## 后端偏好

`BackendPreference` 控制选择：

- `.auto` 让 vkmtl 自动选择。
- `.vulkan` 强制 Vulkan；不可用时失败。
- `.metal` 强制 Metal；不可用时失败。

已选择后端通过 `selectedBackend()` 查询。

`AdapterSelectionDescriptor` 可以进一步缩小选择范围：

```zig
.adapter_selection = .{
    .backend = .metal,
    .name = "Apple M-series",
}
```

`backend` 会强制 adapter 创建使用该后端。`name` 会在后端初始化并解析 runtime adapter 名称后做精确校验。

## Build-Time Override

`zig build ... -Dvulkan` 会强制 `WindowContext` 请求 Vulkan，即使应用传的是 `.auto` 或 `.metal`。
这是用于 Vulkan 后端路径测试的 override；如果无法为当前 surface 创建 Vulkan，会返回
`VulkanUnavailable`。

## Core 选择规则

`core.selectBackend(...)` 的纯选择逻辑：

1. `adapter_selection.backend` 会强制该后端。
2. 没有指定 adapter backend 时，显式 `.vulkan` 或 `.metal` 优先。
3. backend preference 和 adapter backend 冲突时返回 `AdapterSelectionConflict`。
4. `debug_override` 只在 preference 为 `.auto` 时生效。
5. `.auto` 在 Apple 平台优先 Metal。
6. `.auto` 在其他平台优先 Vulkan。
7. `.auto` 可以 fallback 到另一个可用后端。
8. 没有后端可用时返回 `NoSupportedBackend`。

强制选择不可用后端时返回 `VulkanUnavailable` 或 `MetalUnavailable`。
adapter 名称不匹配时，`WindowContext.init` 会返回 `AdapterNotFound`。

## Runtime Surface 可用性

`WindowContext` 会根据 surface descriptor 缩小后端可用性：

- descriptor 带 `VulkanSurfaceProvider` 时，Vulkan 可用。
- Darwin 上 descriptor 带兼容 native Cocoa window/layer pointer 时，Metal 可用。

仓库示例通过外部 `zig_glfw` 和 `examples/common.zig` 同时提供两者；vkmtl core 不导入 GLFW。

## 示例 Override

`examples/triangle` 支持 debug environment override：

```sh
VKMTL_BACKEND=vulkan zig build run-triangle
VKMTL_BACKEND=metal zig build run-triangle
zig build run-triangle -Dvulkan
```

`VKMTL_BACKEND` 是 example-level plumbing，对应 `debug_backend_override`。`-Dvulkan` 是
build-time `WindowContext` override，优先级高于 `VKMTL_BACKEND` 和应用传入的 `.auto` / `.metal`。

## macOS Vulkan Runtime

macOS Vulkan 只用于后端测试。Apple 平台发布构建应该优先 Metal。

强制运行 Vulkan example 时，显式传 Vulkan loader 目录和 MoltenVK ICD 路径：

```sh
zig build run-triangle -Dvulkan \
  -Dvulkan-loader-dir=/path/to/vulkan/lib \
  -Dvulkan-icd=/path/to/MoltenVK_icd.json
```

`-Dvulkan-loader-dir` 应该指向包含 `libvulkan.1.dylib` 的目录，`-Dvulkan-icd` 应该指向
MoltenVK ICD JSON。

## Slang 预编译

默认 `zig build` 会在受支持 host 上把 pinned Slang distribution 准备到
`.zig-cache/vkmtl-tools`，并在构建期预编译当前 manifest 中的 embedded shader。运行时不会启动
`slangc`，发布产物也不需要携带 Slang compiler 或脚本。

外部应用通过 dependency option 选择 schema-version-1 manifest：

```zig
const vkmtl_dep = b.dependency("vkmtl", .{
    .target = target,
    .optimize = optimize,
    .shader_manifest = b.path("shaders/manifest.json"),
});
```

Manifest array 是 `render_shaders`、`compute_shaders`、`ray_tracing_shaders`；entry 声明
`name`、相对 source path 和各 stage entry point。Shader name 必须全局唯一，并使用 lowercase
portable `[a-z0-9_.-]+` filesystem component。Manifest 必须是 source-backed LazyPath；
schema version 1 不支持 generated manifest。Source 不能越出 LazyPath owner root。
Manifest、每个已声明 source 和 Slang depfile 报告的 include/import dependency 都是
tracked build input。

如果 consumer host 没有对应 pinned package，在同一个 dependency option 中转发构建期
compiler path：

```zig
const vkmtl_dep = b.dependency("vkmtl", .{
    .target = target,
    .optimize = optimize,
    .shader_manifest = b.path("shaders/manifest.json"),
    .slangc = "/path/to/build-time/slangc",
});
```

直接构建仓库 checkout 时，使用等价 command-line override：

```sh
zig build run-rainbow-cube -Dslangc=/path/to/build-time/slangc
```

完整 schema field 见 [Shader 编写](../../api/zh_cn/shaders.md)。

## Shader Artifacts

vkmtl 不在 runtime 管理 shader artifact cache。`zig build` 会把 embedded Slang source
预编译成内嵌 blob，运行时直接从内存解析这些 blob，不创建 `vkmtl-cache`，也不解析
`--cache-dir`。

为了调试，构建时会安装一份可检查 artifact：

```text
zig-out/shaders/<shader-name>/
```

这些文件不影响可执行文件运行；只拷贝 `zig-out/bin/<example>` 也可以运行对应的预编译 shader。
