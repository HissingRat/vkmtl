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
| Voxel world | `zig build run-voxel-world` | 窗口；通过 profile/frame-limit/autopilot/RT 环境变量执行有界有限帧运行 | 带确定性树木和湖泊的跨 chunk 连续地形、clean-room E12-inspired 解析水波与大气/云层、screen-space 折射、Beer-Lambert 吸收/单次散射、可选 opaque-TLAS RT 反射、5 分钟太阳/月亮/星空循环、FPS/标题 UI、材质一致的三段 diffuse PTGI、HDR 呈现、指标和 `voxel_world_pressure_test=ok`。 |
| Transfer readback | `zig build run-transfer-readback` | 自动退出 | Exact copy 通过并打印 `transfer readback ok`。 |
| Compute readback | `zig build run-compute-readback` | 自动退出 | Storage buffer/texture bytes 匹配并打印 `compute readback ok`。 |
| Capability dump | `zig build run-capability-dump` | 自动退出 | Console 先打印 requested/selected presentation format，再打印 backend/adapter、feature、limit、format 和 diagnostics。 |
| Bindless textures | `zig build run-bindless-textures` | 窗口运行；设置 `VKMTL_PIXEL_REGRESSION=1` 后单帧退出 | 通过可复用 indirect draw 采样 65-slot native table，并报告 persistent cache 使用；不支持时打印 typed error。 |
| Multi-window | `zig build run-multi-window` | 双窗口 probe | 打印两个 surface record，再打印可用或预期 feature-gate 行。 |
| External texture | `zig build run-external-texture` | 自动退出 probe | 打印 capability/usage planning，并说明需要真实 handle，或打印明确 unsupported 行。 |
| External import | `zig build run-external-import` | Headless Metal 自动退出 | 导入 raw Metal buffer/texture 和 IOSurface，校验三次 GPU readback，并打印 `external import ok: ...`。 |
| Streaming texture | `zig build run-streaming-texture` | 自动退出 probe | 打印 residency success 或 `streaming texture unsupported: ...`。 |
| Tessellation | `zig build run-tessellation` | Window | 渲染 native Vulkan patch，或输出 typed unsupported 后退出。 |
| Mesh shader | `zig build run-mesh-shader` | Window | 渲染一个 native Metal/Vulkan mesh grid，或输出 typed unsupported 后退出。 |
| Ray-traced scene | `zig build run-ray-traced-scene` | 支持时显示窗口；`VKMTL_RT_FRAME_LIMIT` 可限定帧数 | Native RT 把 legacy display-referred RGB 累积到 `rgba16_float`，再由共享 fullscreen pass 保持参考输出并打印 backend-specific `driver_pixels=visible_...` marker；否则给出可执行 unsupported 诊断。 |

仓库没有提交 screenshot 图片素材。视觉证据记录在 Period 32 Vulkan RT validation note 和
Period 44 的 9/9 parity report；`zig build run-pixel-regression` 还覆盖确定性 transfer、compute
和 render pixel。这里记录已观察到的输出，不伪造或嵌入不存在的图片。

## Triangle

`examples/triangle` 是第一个后端无关渲染示例。它创建 GLFW surface，请求 `.auto` 后端选择，
通过 `Device.makeBuffer` 上传 vertex data，通过 `Device.makeRenderPipelineState`
创建 render pipeline，通过 `Swapchain.resize(...)` 处理 drawable resize，通过
`CommandBuffer` / `RenderCommandEncoder` 录制命令并呈现。
它的 current-drawable pipeline 使用 `Swapchain.selectedFormat()`，而不是 presentation
request。所有窗口 gallery pipeline 都遵循同一规则；capability dump 会同时打印 requested 与
selected format。

做 presentation regression 时，共享 example glue 接受
`VKMTL_PRESENTATION_FORMAT=automatic`、`srgb` 或 `linear`。它只是 example-only request
override；未知值会打印 warning 并请求 automatic，不会改变库对显式请求的 exact contract。

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

## 昼夜材质一致的硬件 RT PTGI Voxel World

`examples/voxel_world` 保留有界 `16 x 64 x 16` chunk streaming、visible-face CPU
meshing 和 culling，并把 default 视距半径从历史的 4 个 chunk 扩到 6 个。当前
smoke/default/stress 的 resident 上限分别是 9/169/289，对应 3 x 3、13 x 13 和
17 x 17 网格。确定性的 748 x 68 sRGB
atlas 包含 11 个 face-specific grass、dirt、stone、sand、snow、wood、leaves 和 water
tile，并带有复制的边缘 texel；atlas alpha 在 shader 中生成 height-detail normal。这个
示例目前没有 atlas mipmap。

当前地形用确定性的 fixed-point 多尺度 continentalness、erosion、ridge 和 detail field
生成高度，再用 temperature/moisture field 选择 grass、sand 和 snow 表面。采样使用 world
coordinate，meshing 会缓存一格 halo，因此正负坐标上的 chunk 边界都保持连续。确定性的
cell placement 只在普通 grass 地形生成 wood/leaves 树木，snow、湖面 footprint 和不合适的
坡面不会生成树；另一个低洼 mask 会把部分 sand 洼地填充到固定水位形成湖泊。树木进入
raster mesh 和 opaque RT 材质分类；solid-water 界面会保留在 opaque range 中，因此可以透过
水面看到湖底和岸壁。Leaves 仍为 opaque。

CPU 地形 meshing 由单个后台 worker 执行，并且最多只有一个 outstanding job/result。
Interactive 渲染不会等待 CPU mesh 完成，每帧最多向 GPU resource 发布一个已完成 mesh；
finite validation 为了确定性 drain 会等待 worker，每帧最多发布两个。两条路径都保留
8 MiB 的每帧 upload budget。每个请求携带 stream ticket，移动到新的 chunk neighborhood
或请求 replacement 后，旧 ticket 的完成结果会被丢弃，不会发布过期地形。Worker thread
spawn 失败时会打印诊断并回退到同步 CPU meshing。

GPU buffer upload、BLAS build 和 TLAS build 仍然在 render thread 同步执行。普通 TLAS
source addition 最多合并四帧；bootstrap、stream drain 和 replacement 会立即 rebuild。
因此这次优化消除了 interactive frame 对 CPU meshing 的等待，但并不表示 GPU publication
已经完全异步化。

天空和 opaque 地形先写入完整的 scene-linear HDR target，水体再解析到独立的 full-coverage
HDR overlay，因此 water shader 可以采样 opaque HDR 而不产生读写反馈；presentation pass 会在
后处理之前合成 overlay。Overlay alpha 表示水面 coverage，而不是材质透明度。当前水面通过
clean-room 方式参考 SEUS PTGI E12 的策略，以独立的 64 秒周期计算六组不同尺度、方向和时间
谐波的世界连续解析波。Raster shading 与并行 water G-buffer 使用完全相同的 normal，并按
camera distance 和 grazing angle 稳定远处及掠射角结果。没有复制 E12 源码、常量、shader
组织或素材。

Water shader 把一段随厚度和距离变化的折射 camera ray 投影到 screen space，并拒绝越界 UV
或不合法的 opaque depth。水面与被接受的 opaque 表面之间的距离用于估计介质路径长度。
均匀介质使用 `sigma_a = (0.240, 0.062, 0.014)` 和 `sigma_s = 0.070` 完成 RGB
Beer-Lambert transmission 与单次散射，不再叠加人为的蓝色水体底色：浅水以透射场景为主，
深水才逐渐呈现蓝绿色吸收和散射。Hybrid RT 启用时，每个可见水面像素会向 opaque terrain
TLAS 发射一条最长 96 world unit 的 reflection ray；opaque PTGI ray 仍保持独立的 384-unit
上限。命中使用现有 opaque 材质和 direct/environment lighting，miss 则按方向计算带克制地平线
与当前太阳或月亮 disk/halo 的白天、黄昏或夜间天空。Raster 模式使用天空 fallback；Fresnel
采用 `F0 = 0.02`，天体高光使用约 420 exponent 的窄 lobe。

这个有界模型无法恢复屏幕外或被其他 opaque 表面遮住的折射信息。Water 不进入 TLAS，因此
反射只能看到 opaque terrain；普通 PTGI ray 仍会穿过水面到达保留的湖底。目前没有 foam、
caustics、rain response、parallax water、TAA/reflection denoiser、nested/underwater media、
water-to-water reflection、多层透明或 OIT；每个可见水面像素仍只有一个未经滤波的反射样本。
示例私有的 300 秒时钟会在 0/75/150/225/300 秒依次经过午夜、日出、
正午、日落和回绕后的午夜。它统一驱动连续混合的夜间/黄昏/白天天空、方向相反的太阳/月亮、
随日光淡出的闪烁星星、raster 地形光照，以及 hybrid-RT 的光照方向和角半径。示例私有的
CPU 5x7 bitmap font 与 alpha-blended UI pipeline 会绘制右上角 FPS 和 ESC 标题层，不增加
vkmtl 公共 API。

Clean-room E12-inspired 大气会根据观察方向与太阳方向生成明亮地平线、深色天顶和低太阳的暖色
辉光，并保留现有的月亮与星星。世界锚定的低层 self-shadowed cumulus 和高层 stretched
cirrus 使用独立的真实时间风场移动；它们出现在 raster 天空，以及 hybrid 路径的 RT
miss/PTGI environment 和硬件 RT 水面反射中。Raster 水面 fallback 仍使用解析的当前天空色，
不会计算程序化云层或天体 disk。向下的地面半球会平滑过渡到地面响应，避免 downward RT miss
错误返回明亮天空。RT 云环境只在真实 reflection miss，或已确认从 terrain top 逸出并因此
允许 miss/edge environment 的 diffuse path 上计算。
较密的 cumulus 会产生完整的白天/黄昏移动云影，以及较克制的月光云影；衰减由当前光源强度
gate，因此太阳/月亮方向切换发生在方向光贡献为零时。没有复制 E12 源码、常量、shader 组织、
纹理或素材。这是有界解析云层，不包含天气/降雨、volumetric raymarch、cloud TAA，也不是
vkmtl 公共大气 API。

`VKMTL_VOXEL_RT=auto|off|required` 控制可选的混合光追路径。默认 `auto` 会在 native RT、
storage buffer 或所需 `rgba16_float`/depth usage 不可执行时回退到 raster；`off` 固定 raster
压力路径；`required` 不会静默回退，而是返回 typed error。HDR/G-buffer composition 需要
`blend_state`、`independent_blend`、至少 3 个同时 color attachment、`rgba16_float` 的
sampled/filterable/linear-filter/color-attachment 能力，以及 `depth32_float` attachment；不再
要求 `rgba16_float` blendable。Hybrid reflection 还会通过既有 RT capability gate 要求
`rgba16_float` storage 和 copy-source/copy-destination。所选路径缺少能力时示例会明确失败。

启用 RT 后，每个 resident chunk 使用 indexed triangle BLAS，TLAS 覆盖完整的有界
17 x 17 resident neighborhood，最多 289 个实例。Opaque G-buffer 与 BLAS 只使用 opaque
index range，并行的 water G-buffer 使用可见 water range，因此 RT shadow/bounce ray 会穿过
水面到达保留的湖底。每个 opaque 表面的全分辨率像素每帧跟踪一条随机 diffuse path，最多
包含三段 cosine-weighted trace。每次命中都会独立执行一次太阳/月亮 next-event-estimation
visibility sample，因此可以累计到第三次 diffuse interaction 的 direct illumination。所有命中
都读取与 CPU 地形生成器一致的 material-column volume 和同一张 opaque block atlas 材质。
只有已发布 TLAS 包含所选 profile 的完整 contiguous square 时，FrameData 才携带非零的 x/z
origin 和 extent。初始 bootstrap 或移动期间的稀疏子集使用零 extent，因此 diffuse miss 不会
采样 environment。完整 square 发布后，diffuse miss 也只有在向上的 ray 先到达 terrain top、
而不是先越过任一水平边界时才计算 environment。外圈 traced-edge environment mix 使用同一个
path-level 逸出证明，因此 side miss 不能通过 blend 把天空重新加回来。旧的 residual
environment 近似只在配置的 terminal hit 加入，不会每次 bounce 重复加入。间接 radiance 写入
scene-linear `rgba16_float`，经过带
light-change history gate 的 temporal reprojection/clamping 和四次 edge-aware a-trous filter。
Direct visibility 使用独立的 temporal mean/moment history 和一次 normal/depth-aware 空间滤波，
因此 raster composition 读取的是重建后的半影，而不是原始二值 ray 结果。traced neighborhood
最外侧 16 格会把间接光平滑混合回当前天空环境，避免硬边界。

Native pipeline 的 `max_recursion_depth` 仍为 1，因为 ray generation 会顺序发出这些 trace，
并不从 hit shader 递归调用。Water 仍是独立的一段 specular RT path，反射结果不做 denoise。

白天 ambient 与 hybrid raster/RT environment floor 已降低，使 traced indirect 成为主要
skylight 来源并压低白天暗部；raster-only 模式仍保留完整 environment 响应。Direct sun、
夜间 ambient、水面 Fresnel 和窄天体 glint 不变。

最终 linear HDR scene 通过独立编写的 SEUS-PTGI-E12-default-inspired fixed-exposure pass 做
restrained bloom、sharpen、vignette、filmic shoulder、轻微 saturation、dither 和一次输出
transfer。没有复制 SEUS shader、常量、
组织或素材；目标是相近的默认色彩观感，而不是源码或像素一致。这是有界三段 diffuse hybrid
PTGI，加上每个可见水面像素一条未经滤波、只命中 opaque scene 的 reflection ray。E12 默认的
显式 reflection/diffuse chain 不是三 bounce 方案；当前路径是 clean-room experimental
enhancement，不代表 E12 默认行为。它不是通用递归 path tracer、递归反射系统或生产级
denoiser。

交互运行、固定 raster 或要求 Metal 混合光追：

```sh
zig build run-voxel-world
VKMTL_VOXEL_RT=off VKMTL_VOXEL_PROFILE=smoke VKMTL_VOXEL_FRAME_LIMIT=24 VKMTL_VOXEL_AUTOPILOT=1 VKMTL_BACKEND=metal zig build run-voxel-world
MTL_DEBUG_LAYER=1 VKMTL_VOXEL_RT=required VKMTL_VOXEL_PROFILE=default VKMTL_VOXEL_FRAME_LIMIT=96 VKMTL_VOXEL_CYCLE_TIME=150 VKMTL_BACKEND=metal zig build run-voxel-world
```

操作方式：`W/A/S/D` 水平移动，Space 上升，Shift 下降，Ctrl 加速，鼠标或方向键控制
视角，`R` 重建 camera 所在 chunk。Escape 会打开半透明标题层，显示
`VKMTL VOXEL WORLD` 和 `Press ESC to continue`；再次按下 Escape 恢复输入，关闭窗口
才会退出。右上角会持续显示 FPS。Canonical default 命令使用 96 帧并且刻意不启用
autopilot，使固定相机周围完整的 13 x 13 neighborhood 可以 drain。有限帧成功会打印
`voxel_world_pressure_test=ok`；如果到 frame limit 时仍有 pending work，则先打印
`voxel_world_pressure_test=incomplete`，再返回 `VoxelWorldStreamingNotDrained`。退出报告
除了压力/时间指标，还包含 `streaming=background|sync_fallback`、mesh job 的
submitted/completed/stale/failed 计数、累计 mesh/upload/TLAS 时间，并会在 hybrid run 中包含
`ptgi_bounces=3`、BLAS/TLAS/ray 数量、native submission，以及确定性的
finite/nonnegative direct、indirect、
reconstructed-radiance/visibility 和 water-reflection readback。固定相机的 finite RT run 会
严格要求 reflection covered/lit pixel 都非零、invalid reflection pixel 为零，并打印
`rt_reflection_validated=true`；autopilot 可能转离所有湖面，因此只报告
`rt_reflection_pixels`、`rt_reflection_lit` 和 marker，不强制 marker 为 true。报告还包含
诊断用的半影像素数。`primary_rays` 仍表示 ray-generation dispatch thread 数量，不是顺序
diffuse path segment 的总数。
`VKMTL_VOXEL_CYCLE_TIME=S` 可把示例私有的 300 秒天体时钟冻结在指定相位；`0`、`75` 和
`150` 分别用于确定性检查午夜、日出和正午。云层运动与独立的 64 秒水波循环继续使用真实
elapsed time；该 override 不是 vkmtl 公共 API。较早的透明水路径已完成 24/48-frame Metal API
Validation smoke/default。后续的折射、RGB absorption/in-scattering 与 RT-reflection 版本完成
严格的固定相机 24-frame Metal API Validation smoke：24 次 RT dispatch、88,473,600 primary
rays、1,017,402 primary-hit pixels、438,485 reflection-covered pixels、438,485 lit
reflection pixels、零 invalid pixel，并以 native submission、visibility、PTGI 和 reflection
validation 全部为 true 结束。后续 E12-inspired clean-room 水面 refinement 保持了同一组
固定正午计数与 marker。固定午夜 24-frame lane 同样记录 88,473,600 rays、1,017,402 primary
hits、438,485 reflection-covered pixels 和 429,947 reflection-lit pixels，零 invalid pixel，
且所有 native/visibility/PTGI/reflection marker 为 true。该 refinement 还通过 24-frame Metal
raster lane、`zig build test` 和 forced Vulkan build。折射水体与反射路径尚无物理 Vulkan
执行结果。

当前 5 分钟大气/云层与白天暗部 refinement 已通过 `zig build`、`zig build test` 和
`zig build -Dvulkan`。Metal API Validation 下，固定正午 `150` 的 required-RT smoke 完成
24 帧、88,473,600 rays、1,017,402 primary hits、438,485 reflection-covered/lit pixels、
零 invalid pixel、所有 native/visibility/PTGI/reflection marker 为 true，且 `rt_ms=9.992`。
固定午夜 `0` 保持相同 rays、hits 与 covered 计数，记录 429,962 lit reflection pixels、零
invalid pixel、所有 marker 为 true，且 `rt_ms=9.547`。固定正午 24-frame Metal raster lane
也已通过。在验证机器上，default interactive required-RT 正午预热后约 65-68 FPS，interactive
raster sky 约 120 FPS；这些帧率只是本机观测，不是性能门槛。

在后续三段 PTGI 与 TLAS-boundary revision 之前，扩展后的 default profile 和后台 streamer
完成了固定相机 96-frame Metal API Validation。Raster 结果为 resident 169、visible 81、
culled 88、pending 0、draws 104、
vertices 180,132、indices 270,198、累计 uploaded bytes 14,111,376。Required RT 保持相同的
resident/visibility 结果，构建 169 个 BLAS 和 22 个 TLAS，提交 96 次 dispatch 和
353,894,400 条 primary ray；readback 得到 2,404,265 个 primary hit、632,564 个
reflection covered/lit pixel、298,276 个 penumbra pixel，invalid pixel 为零。Native
submission、visibility、PTGI、reflection 和 pressure marker 全部为 true。

该 RT run 的 `mesh_jobs=169/169/0/0` 依次表示
submitted/completed/stale/failed；`mesh_ms=411.750` 是后台 worker 的累计时间，另有
`stream_upload_ms=179.797`、`tlas_build_ms=18.437`、`frame_p50_ms=19.919` 和
`frame_p95_ms=23.364`。`frame_max_ms=401.845` 包含严格 finite-run readback，不能用来表示
interactive chunk-loading 卡顿。另一次 interactive required-RT 观测中，resident count
依次经过 53、115、169，随后稳定在约 63-64 FPS；这只是本机观测，不是 acceptance gate。

最终 TLAS-boundary 收紧后，三段 required-RT smoke 在 Metal API Validation 下完成 24 帧。
固定正午记录 1,017,402 primary hits、431,231 directly lit、586,171 shadowed、303,369
indirect-lit、744,071 low-indirect、1,017,398 reconstructed、438,485 个 covered/lit
reflection pixel、45,238 个 penumbra pixel、零 invalid pixel，且
`rt_ms_per_frame=10.767`。固定午夜保持 1,017,402 hits，记录 431,228 directly lit、
586,174 shadowed、279,887 indirect-lit、839,646 low-indirect、960,442 reconstructed、
438,485 个 covered 和 429,973 个 lit reflection pixel、53,592 个 penumbra pixel、零
invalid pixel，且 `rt_ms_per_frame=11.248`。

当前固定正午 96-frame default lane 在 resident 169、pending 0 时 drain，记录
`ptgi_bounces=3`、22 次 TLAS build、96 次 dispatch，以及 353,894,400 个作为 dispatch
thread 计数的 `primary_rays`。其他结果为 `rt_ms_per_frame=16.327`、2,404,265 primary
hits、863,410 directly lit、1,540,855 shadowed、1,932,365 indirect-lit、626,079
low-indirect、2,404,258 reconstructed、632,564 个 covered/lit reflection pixel、297,535
个 penumbra pixel、零 invalid pixel，所有 validation marker 均为 true。Frame p50/p95/max
为 24.081/28.004/442.164 ms；最大值包含严格 finite-run validation work，不能作为
interactive latency 结论。这些 timing 只是本机观测，不是可移植性能门槛。

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

Period 55 只改变 canonical display flow，不改变 scene 或 backend RT marker。
`CommandBuffer.dispatchRaysToTexture(...)` 会写入 caller-owned、capability-gated 的
`rgba16_float` texture；这个 command 不规定 color space，也不会转换 ray-generation shader
写入的数值。这个示例保留既有的 display-referred RGB，只使用 floating-point texture 提高累积
精度。第二个 public render command 对这些数值执行 sRGB EOTF，再把 display-linear color 返回给
`bgra8_unorm_srgb`；attachment 的 sRGB OETF 会恢复参考 display value。示例不执行 exposure 或
tone mapping。需要真正 scene-linear HDR 的应用应自行定义 radiometric unit、exposure 和
tone-mapping policy。旧 drawable dispatch command 仍为兼容保留；它现在先向 caller 的完整、
single-sample `bgra8_unorm` output dispatch，再把原始字节复制到 selected linear 或 sRGB BGRA8
drawable，不执行 transfer-function、tone-map 或 gamut conversion。RT dispatch 与 fullscreen
consumer 使用两个 command buffer，因为当前每个 command buffer 只拥有一个 native encoding
segment。

Metal API Validation 已物理执行这个新路径 3 帧。上面的历史 Vulkan 物理证据仍能证明 native RT
backend，但早于 Period 55 shared presentation path。新的 Vulkan path 现在已经在 RT 真机上
完成 BLAS/TLAS build、ray dispatch、present 和 3 帧 finite run。第一次 canonical 截图暴露了
fullscreen composition 上下翻转；fragment-position UV 修复后的 Vulkan path 已完成 3000 帧，
并具有正确的 top-left 方向。legacy raw-copy 截图方向同样正确。

只有验证兼容路径时才设置 `VKMTL_RT_LEGACY_DRAWABLE=1`。配合
`VKMTL_RT_FRAME_LIMIT=3`，示例会向 caller-owned linear BGRA8 target dispatch，raw-copy 到
selected drawable，并在三帧后退出。不设置该变量时，仍使用上面的 canonical texture +
composition 路径。

当前 procedural marker 已取代 Period32 原来的
`driver_pixels=visible_vulkan_rt_output` marker。它仍会验证 native Vulkan
acceleration structure、pipeline、SBT、`vkCmdTraceRaysKHR` 和 output presentation，
只是现在这些路径属于后续 procedural scene 的一部分。

本次 AS sizing 修复后的 Vulkan stderr 没有 error、warning 或 VUID，但也没有明确打印
`VK_LAYER_KHRONOS_validation` 已启用，且没有包含 device/driver identity。因此这里只记录为
物理执行证据，不宣称 validation-layer-clean 或具名设备结果。
[整合后的验证记录](../../develop/validation.md)列出了实际观察到的
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
MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_RT_FRAME_LIMIT=3 zig build run-ray-traced-scene
VKMTL_BACKEND=vulkan VKMTL_RT_FRAME_LIMIT=3 zig build run-ray-traced-scene -Dvulkan
```

需要明确验证 Vulkan 路径而不是默认 backend selection 时，请使用 `-Dvulkan`。有限帧数运行成功后会
打印 `ray traced scene finite run ok: backend=<backend> frames=3`。Frame limit 必须是正整数；
非法值、零、窗口提前关闭，或 framebuffer 持续 `0x0` 五秒都会明确失败，不会产生 false success
或无限等待。

`examples/ray_tracing_maintenance` 不创建窗口。它通过 `HeadlessContext` 构建
update-capable triangle BLAS，交替提交 32 次 update/refit，执行一次 compact copy，
再构建 AABB BLAS 和引用两个不同 BLAS 的 TLAS：

```sh
VKMTL_BACKEND=metal zig build run-ray-tracing-maintenance
VKMTL_BACKEND=vulkan zig build run-ray-tracing-maintenance
```

仓库记录了第一条命令在 Apple M4 Pro 上的物理执行。第二条是 Vulkan RT 机器的精确
复验命令；当前主机没有把 forced build 升级成物理 Vulkan 证据。
