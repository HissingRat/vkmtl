# Native API Validation

修改 backend 或 command encoding 时，应同时使用 native API validation。它和 vkmtl 的 typed
descriptor validation、pixel regression、GPU soak、capture scope 是不同的检查层，不能互相
替代。

## Vulkan Validation Layer

安装包含 `VK_LAYER_KHRONOS_validation` 的 Vulkan SDK 或系统 package，然后确认 loader 能找到
它：

```sh
vulkaninfo --summary
vulkaninfo 2>&1 | grep VK_LAYER_KHRONOS_validation
```

Debug build 会先检查这个 layer 是否存在。存在时，vkmtl 会同时启用它和
`VK_EXT_debug_utils`，并把 general、validation、performance 类型的 warning/error 输出到
`validation` log scope。layer 不存在时，Debug 程序会继续运行但没有 native validation；因此
layer 安装属于 validation preflight，而不是普通应用启动要求。非 Debug build 不请求这个
layer。

SDK 不在 loader 默认搜索路径时，应先配置对应 SDK environment。`VK_LAYER_PATH` 可以指向匹配
版本的 layer manifest/library 目录；不要混用不同 SDK 版本。只有需要选择特定 vendor ICD 时才
单独设置 `VK_ICD_FILENAMES`。

代表性 Debug 命令：

```sh
zig build run-triangle -Dvulkan -Doptimize=Debug
zig build run-pixel-regression -Dvulkan -Doptimize=Debug
scripts/ci/run_gpu_smoke.sh vulkan artifacts/vulkan-validation
```

验收要求 workload 通过且没有 validation error。需要保存 host summary、capability dump、程序
输出以及包含 VUID 的完整 validation message。Warning 必须逐项判断，不能为了让结果变绿而
直接隐藏。

Khronos 对统一 validation layer、配置方式和开发期性能成本的说明：

- https://docs.vulkan.org/guide/latest/validation_overview.html
- https://docs.vulkan.org/guide/latest/layers.html

## Metal API Validation

Metal API Validation 会检查 resource creation、command encoding、lifetime 和其他 Metal API
用法。它会带来可测量的 CPU 成本，只用于开发和验证。

通过 Xcode 运行时：

1. 编辑当前 scheme；
2. 选择 Run action 的 Diagnostics tab；
3. 打开 API Validation；
4. shader runtime behavior 在范围内时，另外执行一次 Shader Validation。

命令行可以把 Apple 文档中的 validation environment 传给 Zig 启动的 executable：

```sh
MTL_DEBUG_LAYER=1 zig build run-triangle -Doptimize=Debug
MTL_DEBUG_LAYER=1 zig build run-pixel-regression -Doptimize=Debug
MTL_DEBUG_LAYER=1 zig build run-external-import -Doptimize=Debug
```

需要记录日志而不是使用默认 assertion behavior 时，可以设置
`MTL_DEBUG_LAYER_ERROR_MODE=nslog`。验收时不要使用 `ignore`。

Apple 当前的 API/Shader Validation 设置和 environment variable 文档：

- https://developer.apple.com/documentation/xcode/validating-your-apps-metal-api-usage
- https://developer.apple.com/documentation/xcode/validating-your-apps-metal-shader-usage/

vkmtl 的 `diagnostics.beginCaptureScope(...)` 控制 scoped Metal GPU capture。Capture 和 API
Validation 相互独立：capture 成功不等于 API 使用正确，validation 通过也不会生成可重放 GPU
trace。

验收要求代表性 example 和 pixel regression 结束时没有 Metal API 或 Shader Validation
error。失败时保存完整 message、object label、encoder/command label 和最小复现 command
sequence。

Period 53 interop 还需要用 `run-external-import` 证明 borrowed native owner 覆盖 GPU
copy/readback 生命周期，并且 IOSurface plane/format/storage contract 在导入后仍成立。这只属于
Metal evidence。

## Validation Evidence 顺序

Backend 改动按以下顺序验证：

1. `zig build test --summary all`；
2. 在受影响 backend 上运行 Debug native API validation；
3. deterministic transfer、compute、render pixel regression；
4. 受影响的 visible example 或 ray tracing marker；
5. resource lifetime、resize 或 synchronization 改变时运行 bounded GPU soak。

Native validation 是 backend 改动的重要证据，但不能替代 capability gate 或物理设备结果。
