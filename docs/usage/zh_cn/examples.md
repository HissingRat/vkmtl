# 示例

示例是公开 API 的使用者。它们位于 `examples/`，不应该导入 `src/backend/vulkan`、
`src/backend/metal`、原始 Vulkan binding 或 Metal bridge header。

示例可以导入：

- 公开 `vkmtl` 模块
- 外部 windowing package，比如 `zig_glfw`
- 示例专用共享 glue，比如 `vkmtl_examples_common`
- 示例自己的 asset 和 shader

如果示例需要尚未公开的后端能力，应该先补 vkmtl 公开抽象，而不是绕进后端实现。

当前 gallery metadata 记录在 `tools/development_matrix.zig`，测试会用它校验名称、路径、
run step、确定性输出 marker 和后端预期不要和文档漂移。

带 shader 的示例用 `@embedFile(...)` 嵌入 Slang source，通过 `Device.compileRenderShader(...)`
或 `Device.compileComputeShader(...)` 解析构建期预编译 blob，并把内嵌 reflection JSON 附到
pipeline stage。Ray tracing 示例使用 `Device.compileRayTracingShader(...)`，再由 compiled shader
根据当前 backend 把 ray-generation / miss / hit shader blob 填入 pipeline descriptor。单
buffer 渲染示例从 reflection 派生 vertex descriptor，shader-resource 示例也从 reflection
派生 bind group layout。构建期可检查 artifact 位于 `zig-out/shaders/`。

## 已审查的 Gallery 契约

下表名称和命令与当前 `build.zig` run step 一致。“窗口”表示需要关闭窗口才退出；“自动退出”
case 可能使用小型 GLFW surface，也可能使用 `HeadlessContext`，具体以对应行的 mode 为准。

| 示例 | 命令 | 模式 | 预期结果 |
| --- | --- | --- | --- |
| Clear screen | `zig build run-clear-screen` | 窗口 | 打印所选 backend，并显示稳定纯色 drawable。 |
| Triangle | `zig build run-triangle` | 窗口 | 打印所选 backend，并显示彩色三角形。 |
| Offscreen texture | `zig build run-offscreen-texture` | 窗口 | 显示采样 offscreen triangle 的 presented quad；pixel mode 打印 `render pixel regression ok backend=... max_channel_delta=...`。 |
| MSAA triangle | `zig build run-msaa-triangle` | 窗口 | 显示 resolve 后再采样到 drawable 的 multisampled triangle。 |
| Rainbow cube | `zig build run-rainbow-cube` | 窗口 | 显示带 depth 和 indexed draw 的旋转 textured cube。 |
| Voxel world | `zig build run-voxel-world` | 窗口；设置 `VKMTL_VOXEL_FRAME_LIMIT=N` 可有限帧退出 | Period 19 Phase 1 的 sky-color public API scaffold；Phase 2 开始 chunk rendering。 |
| Transfer readback | `zig build run-transfer-readback` | 自动退出 | Exact copy 通过并打印 `transfer readback ok`。 |
| Compute readback | `zig build run-compute-readback` | 自动退出 | Storage buffer/texture bytes 匹配并打印 `compute readback ok`。 |
| Capability dump | `zig build run-capability-dump` | 自动退出 | Console 从 backend/adapter 开始，包含 feature、limit、format 和 diagnostics。 |
| Bindless textures | `zig build run-bindless-textures` | 窗口运行；设置 `VKMTL_PIXEL_REGRESSION=1` 后单帧退出 | 通过可复用 indirect draw 采样 65-slot native table，并报告 persistent cache 使用；不支持时打印 typed error。 |
| Multi-window | `zig build run-multi-window` | 双窗口 probe | 打印两个 surface record，再打印可用或预期 feature-gate 行。 |
| External texture | `zig build run-external-texture` | 自动退出 probe | 打印 capability/usage planning，并说明需要真实 handle，或打印明确 unsupported 行。 |
| External import | `zig build run-external-import` | Headless Metal 自动退出 | 导入 raw Metal buffer/texture 和 IOSurface，校验三次 GPU readback，并打印 `external import ok: ...`。 |
| Streaming texture | `zig build run-streaming-texture` | 自动退出 probe | 打印 residency success 或 `streaming texture unsupported: ...`。 |
| Tessellation | `zig build run-tessellation` | Window | 渲染 native Vulkan patch，或输出 typed unsupported 后退出。 |
| Mesh shader | `zig build run-mesh-shader` | Window | 渲染一个 native Metal/Vulkan mesh grid，或输出 typed unsupported 后退出。 |
| Ray-traced scene | `zig build run-ray-traced-scene` | 支持时显示窗口 | 显示 RT scene 并打印 backend-specific `driver_pixels=visible_...` marker；否则给出可执行 unsupported 诊断。 |

仓库没有提交 screenshot 图片素材。视觉证据记录在 Period 32 Vulkan RT validation note 和
Period 44 的 9/9 parity report；`zig build run-pixel-regression` 还覆盖确定性 transfer、compute
和 render pixel。这里记录已观察到的输出，不伪造或嵌入不存在的图片。

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
它取代了早期拆开的 uniform-buffer、sampled-texture 和 depth-only 教学样例，作为常规
render resource binding 的主线示例。

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

## Voxel World Pressure Test

`examples/voxel_world` 是有明确上限的 Minecraft-like renderer 压力测试。Period 19
Phase 1 目前提供只使用 public API 的 window/presentation scaffold，并固定
`16 x 64 x 16` chunk、smoke/default/stress profiles、portable non-sparse resource
path、diagnostics 和后续 controls。Phase 2 会加入第一个 visible-face chunk mesh 和真实
Slang pipeline。

交互运行或执行有限帧 scaffold smoke：

```sh
zig build run-voxel-world
VKMTL_VOXEL_FRAME_LIMIT=2 VKMTL_BACKEND=metal zig build run-voxel-world
zig build run-voxel-world -Dvulkan
```

有限帧运行会打印 `voxel_world_phase1_scaffold=ok`。当前画面有意只显示 sky-color
drawable，不能据此声称 voxel geometry 已经执行。

## Transfer Readback

`examples/transfer_readback` 使用 `HeadlessContext`，不初始化或链接 GLFW。它验证 buffer copy、
buffer-to-texture、texture-to-buffer 和 CPU-visible readback，还会 clear 一个绑定 texture view
的 offscreen target，再 copy 并校验结果。成功后打印 `transfer readback ok` 并自动退出。

```sh
zig build run-transfer-readback
```

后端调试：

```sh
VKMTL_BACKEND=vulkan zig build run-transfer-readback
VKMTL_BACKEND=metal zig build run-transfer-readback
```

## Compute Readback

`examples/compute_readback` 是使用 `HeadlessContext` 的真正无窗口 compute 示例，不初始化或
链接 GLFW。它创建 storage texture 和 storage buffer，通过 compute-visible bind group 绑定，
dispatch Slang compute shader，再把资源 copy 到 CPU-visible readback buffer 并验证确定性 bytes。

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

## Capability Dump

`examples/capability_dump` 会打印当前选择的 backend、adapter 信息、capability source、可用
features、native queried features、limits，以及几个代表性 texture format capabilities。
Period 42 输出还包含 buffer/texture copy alignment，以及 color、depth、packed depth/stencil
format 的 exact-copy、scaled-blit、presentation、resolve、depth-copy 和 stencil-copy flag。

运行：

```sh
zig build run-capability-dump
```

后端调试：

```sh
zig build run-capability-dump -Dvulkan
VKMTL_BACKEND=metal zig build run-capability-dump
```

## Bindless Textures

`examples/bindless_textures` 会验证完整 advanced binding 路径：创建 64 个 texture 加一个 sampler
的 `ResourceTable`、声明兼容 pipeline layout、执行 CPU-authored 可复用 draw list，并提供 persistent
driver cache。Metal 会下沉到 argument buffer、native ICB 和 binary archive；Vulkan 使用
descriptor indexing、精确 direct-command expansion 和 pipeline cache。不支持的设备会打印清晰的
typed error 并退出。

运行：

```sh
zig build run-bindless-textures
VKMTL_BACKEND=metal VKMTL_PIXEL_REGRESSION=1 zig build run-bindless-textures
```

## Compute Gallery

Period 9 在 `tools/development_matrix.zig` 里追踪更广的 compute gallery。当前状态：

- implemented: `compute_readback`
- planned: `image_filter`
- planned: `particle_simulation`
- planned: `prefix_sum`
- planned: `storage_texture`

计划中的 compute 示例应该尽量保留 deterministic readback 或 pixel validation，这样后续可以成为
有用的 backend regression test。

## Multi-Window Gallery

`examples/multi_window` 是第一版 multi-surface smoke example。它创建两个外部 GLFW
window，通过公开 vkmtl `SurfaceCollection` 注册两个 surface，并报告当前选择的 backend 是否通过
`DeviceFeatures.multi_surface` 暴露 native multi-window presentation。

运行：

```sh
zig build run-multi-window
```

更广的追踪 case 包括：

- `single_device_multiple_surfaces`
- `multiple_swapchains`
- `multi_window_resize`
- `surface_lost_recovery`

当前公开 `vkmtl.presentation.SurfaceCollection` 可以追踪多个 neutral surface state，但 native multiple swapchain
execution 仍由 `DeviceFeatures.multi_surface` gate。

## Native Interop Gallery

Native interop 示例是显式高级样例，不应该变成普通示例的依赖。

`examples/external_texture` 会验证显式 `vkmtl.interop` external texture descriptor、
`ExternalTextureUsageDescriptor` 和 runtime `ExternalTexture` wrapper。Interop facade 也暴露了
`ExternalInteropImportPlan`、`ExternalTextureUsagePlan`、`ExternalSynchronizationPlan` 和
`ExternalInteropImportDiagnostic`，用于高级 interop validation。示例可以用
`vkmtl.interop.externalInteropCapabilityMatrix(device)` 说明所选 backend/platform 上哪些 handle kind
属于 portable wrapper、capability-gated native import、native-only object 或 unsupported。

运行：

```sh
zig build run-external-texture
```

`examples/external_import` 是真正执行的 Metal interop 检查。它在 vkmtl 外创建 raw
`MTLBuffer`、raw `MTLTexture` 和 IOSurface，通过公开 `vkmtl.interop` descriptor 导入，再使用
普通 vkmtl blit command copy，并校验确定性 CPU readback：

```sh
zig build run-external-import
```

该示例有意只支持 Metal，因为 public descriptor 还没有表达 Vulkan external allocation/image
所需的完整 metadata。它还会打印 `vkmtl.diagnostics.deviceTopology(device)` 的 identity/group
diagnostics。

追踪的 case 包括：

- `vulkan_native_handles`
- `metal_native_handles`
- `external_texture_import` / `external_texture`
- `native_command_insertion`

Portable 示例应该继续使用公开 vkmtl abstraction。如果示例需要 native access，它应该被命名并记录为
native interop case。
Metal resource import 已可执行。Native multi-surface presentation、Vulkan external resource
import、external wait/signal lowering，以及 command encoder native handle view 在当前 contract 下
保持关闭。

## Streaming Texture

`examples/streaming_texture` 会验证 `vkmtl.resource` sparse/tiled texture descriptor 和 residency map 路径。在所选
backend 暴露 sparse 或 tiled texture 之前，它会打印 unsupported-feature 信息。

运行：

```sh
zig build run-streaming-texture
```

## Advanced Geometry

`examples/tessellation` 和 `examples/mesh_shader` 会编译 schema-2 embedded Slang
artifact、创建 public advanced render pipeline、编码 native draw command 并呈现可见输出。
Tessellation 当前只在 capability 合格的 Vulkan device 上执行；mesh-only 路径可在合格的
Metal 或 `VK_EXT_mesh_shader` device 上执行。Pinned compiler 下 task/object stage 仍不可用，
不支持的 backend 会在 pipeline 创建前退出。

运行：

```sh
zig build run-tessellation
zig build run-mesh-shader
```

## Ray Tracing

`examples/ray_traced_scene` 会验证公开 `vkmtl.ray_tracing` runtime contract：
acceleration-structure 对象、scratch buffer validation、ray tracing pipeline state、shader
binding table 创建和 ray dispatch；Metal mapping 显式位于 `vkmtl.native.metal`。这个示例只调用
一次 `Device.compileRayTracingShader(...)`，然后由 compiled shader 根据当前 backend 填充
`vkmtl.ray_tracing.RayTracingPipelineDescriptor`。Vulkan 消费 Slang RT
SPIR-V stages；Metal 通过同一个 vkmtl compiled-shader object 消费构建期预编译的 Metal
ray-generation artifact。在支持的 Metal 设备上，它现在会打开窗口，创建真实
`MTLAccelerationStructure`，使用用户侧 mesh vertex buffer 构建 full mesh RT scene，并通过
native Metal intersector dispatch 显示房间和多个球体。首帧成功后会打印
`driver_pixels=visible_metal_full_mesh_rt_scene`。Vulkan 路径现在使用 procedural sphere AABB、
Slang intersection SPIR-V、procedural hit group 和 native `vkCmdTraceRaysKHR` dispatch。
在支持 Vulkan RT 的硬件上，它的成功 marker 是
`driver_pixels=visible_vulkan_procedural_rt_scene`。Metal schema-2 path 没有 linked
intersection function artifact，因此 procedural function table 明确不支持。物理 Metal 与 Vulkan RT 输出都已经 observed；
Period 44 的 9/9 不代表其他 native-pressure lane 已完成。

当前 procedural marker 已取代 Period32 原来的
`driver_pixels=visible_vulkan_rt_output` marker。它仍会验证 native Vulkan
acceleration structure、pipeline、SBT、`vkCmdTraceRaysKHR` 和 output presentation，
只是现在这些路径属于后续 procedural scene 的一部分。
[Period32 Phase 6 验证记录](../../develop/period32/phase6.md)列出了实际观察到的
Windows/NVIDIA 硬件、命令、build gate 和本地 ignored screenshot evidence。

如果 Vulkan runtime 缺少所需 extension、feature、limit 或 device procedure，示例会在
native ray tracing setup 前退出并打印可执行的诊断：

```text
vulkan ray tracing unsupported: blocker=<blocker>, requirement=<requirement>, details=<details>
```

本次验证主机没有非 ray-tracing ICD。因此 unsupported 行为来自已通过的 capability
diagnostics 单元契约，不声称做过物理 unsupported-device 运行。

运行：

```sh
zig build run-ray-traced-scene
zig build run-ray-traced-scene -Dvulkan
```

需要明确验证 Vulkan 路径而不是默认 backend selection 时，请使用 `-Dvulkan`。

`examples/ray_tracing_maintenance` 不创建窗口。它通过 `HeadlessContext` 构建
update-capable triangle BLAS，交替提交 32 次 update/refit，执行一次 compact copy，
再构建 AABB BLAS 和引用两个不同 BLAS 的 TLAS：

```sh
VKMTL_BACKEND=metal zig build run-ray-tracing-maintenance
VKMTL_BACKEND=vulkan zig build run-ray-tracing-maintenance
```

仓库记录了第一条命令在 Apple M4 Pro 上的物理执行。第二条是 Vulkan RT 机器的精确
复验命令；当前主机没有把 forced build 升级成物理 Vulkan 证据。
