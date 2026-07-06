# 配置

vkmtl 会显式处理后端选择、shader 编译器和 runtime cache 位置。示例尽量暴露相同配置项。

## 后端偏好

`BackendPreference` 控制选择：

- `.auto` 让 vkmtl 自动选择。
- `.vulkan` 强制 Vulkan；不可用时失败。
- `.metal` 强制 Metal；不可用时失败。

已选择后端通过 `selectedBackend()` 查询。

## Build-Time Override

`zig build ... -Dvulkan` 会强制 `WindowContext` 请求 Vulkan，即使应用传的是 `.auto` 或 `.metal`。
这是用于 Vulkan 后端路径测试的 override；如果无法为当前 surface 创建 Vulkan，会返回
`VulkanUnavailable`。

## Core 选择规则

`core.selectBackend(...)` 的纯选择逻辑：

1. 显式 `.vulkan` 或 `.metal` 优先。
2. `debug_override` 只在 preference 为 `.auto` 时生效。
3. `.auto` 在 Apple 平台优先 Metal。
4. `.auto` 在其他平台优先 Vulkan。
5. `.auto` 可以 fallback 到另一个可用后端。
6. 没有后端可用时返回 `NoSupportedBackend`。

强制选择不可用后端时返回 `VulkanUnavailable` 或 `MetalUnavailable`。

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

## Slang Compiler

默认 `zig build` 会在受支持 host 上把 pinned Slang distribution 准备到
`.zig-cache/vkmtl-tools`。如果 host 没有对应 pinned package，vkmtl 会 fallback 到 `PATH` 上的
`slangc`。

需要显式指定时：

```sh
zig build run-rainbow-cube -Dslangc=/path/to/slangc
```

## Shader Cache

vkmtl 会自动管理 runtime shader artifact cache。默认情况下，cache 位于可执行文件旁边的
`vkmtl-cache`，cache key 包含 embedded Slang source hash；source 变化时会自动重新编译。

如果应用把 `std.process.Init.Minimal.args` 传给 `WindowContextOptions.process_args`，vkmtl 会自动
解析自己的 runtime 参数。用户可以直接传：

```sh
zig build run-rainbow-cube -- --cache-dir /tmp/vkmtl-cache
```

应用代码不需要自己解析 `--cache-dir`，也不需要把它映射到 `shader_cache_dir`。这个目录只影响
runtime shader artifact，不影响 Zig 编译产物位置。
