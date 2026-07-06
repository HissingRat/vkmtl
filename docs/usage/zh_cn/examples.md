# 示例

示例是公开 API 的使用者。它们位于 `examples/`，不应该导入 `src/backend/vulkan`、
`src/backend/metal`、原始 Vulkan binding 或 Metal bridge header。

示例可以导入：

- 公开 `vkmtl` 模块
- 外部 windowing package，比如 `zig_glfw`
- 示例专用共享 glue，比如 `vkmtl_examples_common`
- 示例自己的 asset 和 shader

如果示例需要尚未公开的后端能力，应该先补 vkmtl 公开抽象，而不是绕进后端实现。

当前 gallery metadata 记录在 `src/development_matrix.zig`，测试会用它校验名称、路径、
run step、确定性输出 marker 和后端预期不要和文档漂移。

带 shader 的示例用 `@embedFile(...)` 嵌入 Slang source，通过 `Device.compileRenderShader(...)`
或 `Device.compileComputeShader(...)` 编译，并把运行时生成的 reflection JSON 附到 pipeline
stage。单 buffer 渲染示例从 reflection 派生 vertex descriptor，shader-resource 示例也从
reflection 派生 bind group layout。

runtime shader artifact cache 由 vkmtl 自动管理。示例把进程参数交给 `WindowContext`，所以用户可以
直接传 vkmtl runtime 参数，示例代码不需要解析：

```sh
zig build run-rainbow-cube -- --cache-dir /tmp/vkmtl-cache
```

## Triangle

`examples/triangle` 是第一个后端无关渲染示例。它创建 GLFW surface，请求 `.auto` 后端选择，
通过 `Device.makeBuffer` 上传 vertex data，通过 `Device.makeRenderPipelineState`
创建 render pipeline，通过 `Swapchain.resize(...)` 处理 drawable resize，通过
`CommandBuffer` / `RenderCommandEncoder` 录制命令并呈现。

运行：

```sh
zig build run-triangle
```

Apple 平台 `.auto` 优先 Metal。后端调试：

```sh
zig build run-triangle -Dvulkan
VKMTL_BACKEND=vulkan zig build run-triangle
VKMTL_BACKEND=metal zig build run-triangle
```

## Clear Screen

`examples/clear_screen` 是 presentation smoke test，专注于 surface 创建、resize、clear 和 present。

```sh
zig build run-clear-screen
```

## Uniform Buffer

`examples/uniform_buffer` 是第一个 shader-resource binding 示例。它创建 uniform buffer，包装成
bind group，从 shader reflection 派生 bind group layout，并在 draw 前调用 `setBindGroup(...)`。

```sh
zig build run-uniform-buffer
```

## Sampled Texture

`examples/sampled_texture` 上传一个小 RGBA texture，创建 texture view 和 sampler，把它们通过
bind group 绑定，然后绘制 indexed quad。

```sh
zig build run-sampled-texture
```

## Depth Triangles

`examples/depth_triangles` 是第一个 depth-tested 渲染示例，绘制两个重叠三角形验证 depth test。

```sh
zig build run-depth-triangles
```

## Offscreen Texture

`examples/offscreen_texture` 是第一个显式 render-target 示例。它先把彩色三角形渲染到 texture-backed
color attachment，再把这个 texture 采样到当前 drawable 的 indexed quad 上。

```sh
zig build run-offscreen-texture
```

## MSAA Triangle

`examples/msaa_triangle` 是第一个 multisample resolve 示例。它渲染到 4x MSAA texture，resolve 到
single-sample texture，然后在当前 drawable 中采样 resolve 结果。

```sh
zig build run-msaa-triangle
```

## Rainbow Cube

`examples/rainbow_cube` 是第一个整合 3D 示例：旋转 indexed cube、每面 vertex color、采样 rainbow
texture、每帧 uniform buffer update，以及 current-drawable depth testing。

```sh
zig build run-rainbow-cube
```

它只使用公开资源和命令 API：

- `Device.makeBuffer(...)` 创建 vertex/index/uniform buffer
- `uniform_buffer.replaceBytes(...)` 每帧更新 uniform
- `texture.replaceAll2D(...)` 上传 texture
- reflection 派生 bind group layout
- `RenderPipelineDescriptor.depth_stencil` 和 render pass depth attachment 做 depth test
- `drawIndexedPrimitives(...)` 做 indexed drawing

## Transfer Readback

`examples/transfer_readback` 是第一个非渲染 Phase 8 示例。它验证 buffer copy、buffer-to-texture、
texture-to-buffer 和 CPU-visible readback，成功后打印 `transfer readback ok` 并自动退出。

```sh
zig build run-transfer-readback
```

后端调试：

```sh
VKMTL_BACKEND=vulkan zig build run-transfer-readback
VKMTL_BACKEND=metal zig build run-transfer-readback
```

## Compute Readback

`examples/compute_readback` 是第一个 compute 示例。它创建 storage texture 和 storage buffer，
通过 compute-visible bind group 绑定，dispatch Slang compute shader，再把资源 copy 到 CPU-visible
readback buffer 并验证确定性 bytes。

```sh
zig build run-compute-readback
```

后端调试：

```sh
VKMTL_BACKEND=vulkan zig build run-compute-readback
VKMTL_BACKEND=metal zig build run-compute-readback
```

当前 compute 覆盖面刻意保持确定性：storage buffer 写入、storage texture 写入、transfer
readback、reflection-derived bind group layout，以及退出前的 byte validation。

## Compute Gallery

Period 9 在 `src/development_matrix.zig` 里追踪更广的 compute gallery。当前状态：

- implemented: `compute_readback`
- planned: `image_filter`
- planned: `particle_simulation`
- planned: `prefix_sum`
- planned: `storage_texture`

计划中的 compute 示例应该尽量保留 deterministic readback 或 pixel validation，这样后续可以成为
有用的 backend regression test。
