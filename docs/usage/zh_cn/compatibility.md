# Compatibility

vkmtl 优先覆盖 portable Vulkan 和 Metal workflow；高级能力放在显式 capability gate 后面。

## 当前后端预期

| Platform | Preferred Backend | Notes |
| --- | --- | --- |
| macOS | Metal | Metal 可用时 `.auto` 默认走这条路径。 |
| macOS | Vulkan via MoltenVK | 只用于 backend testing；需要显式 loader 和 ICD path。 |
| Linux | Vulkan | Apple 以外平台的主要 portable backend。 |
| Windows | Vulkan | Apple 以外平台的主要 portable backend。 |
| iOS | Metal | Planned；surface packaging 尚未完成。 |

## Capability Gates

使用 `device.features()`、`device.limits()` 和 `device.getFormatCaps(...)`，不要靠平台假设。
不支持的 optional behavior 应该返回 typed error，而不是静默改变语义。

## Sync And Query Defaults

vkmtl 会保持普通 command path portable：resource usage tracking、binary fence、event、
timestamp query 和 occlusion query 都通过 backend-neutral runtime object 暴露。显式 barrier
和 queue ownership transfer 是高级 escape hatch；Vulkan 会把 barrier path 下沉到 native，
Metal 会在 encoder boundary 已经定义 ordering 的地方使用 validation/no-op marker。Timeline
fence、shared event 和 logical queue planning 已经有 portable descriptor / validation 入口；
native timeline/shared-event submit、native dedicated queue、native queue-family ownership transfer
和 pipeline statistics query 仍然保持 capability-gated，等 backend lowering 完成后再打开。

## Advanced Features

Advanced features 会继续放在 feature gate 后面。Period 22 的一部分 binding 路径已经有
runtime object 和 command entry point；sparse resource、external texture interop、
tessellation、mesh shader、ray tracing 和 driver-level pipeline cache 仍然保持 gated，直到
native backend work 完成。

Heap、memory-budget、transient-allocation 和 sparse-residency API 目前提供 portable planning
与 diagnostics。Native heap-backed buffer/texture creation 和 native sparse/tiled page binding
仍是后续 backend work。

Descriptor indexing 映射到 Vulkan descriptor indexing，argument buffer 映射到 Metal
argument buffer。两者通过 `DescriptorIndexingLayoutDescriptor`、
`AdvancedBindGroupLayout` 和 `ResourceTable` 表达。当所选后端声明所需 feature 时，
resource table 可以 update、clear，并通过 render / compute encoder 绑定。

大型 table 压力通过 `Device.planResourceTablePressure(...)` 规划。Plan 会在分配前明确
partially-bound 和 update-after-bind 要求；真实 GPU 压力证据仍属于后端 / 设备矩阵验证。

Root constants 会在 pipeline 声明兼容 `root_constant_layout` 后下沉到 Vulkan push constants 和
Metal `set*Bytes`。

Shader specialization 由 capability gate 控制。Vulkan pipeline specialization info 已经接上；
Metal function-constant specialization 会等 Metal bridge 暴露 variant path 后再打开。

Sparse buffer/texture 未来映射到 Vulkan sparse resource 和 Metal tiled/sparse texture 概念。
当前 descriptor 只校验 page-aligned mapping intent。

External memory、buffer、texture、semaphore 和 shared-event interop 使用显式
platform/backend handle descriptor。Runtime wrapper 会校验 ownership 和 backend
compatibility；native import 和 wait/signal lowering 仍是高级 feature-gated work。
`ExternalInteropCapabilityMatrix` 会在 import 前按 backend/platform 分类 handle support。

Tessellation 由 `TessellationDescriptor` 表示，仍然是 optional render pipeline extension，不是默认
portable render path。`TessellationPatchDrawDescriptor` 可以生成 Vulkan / Metal 的 public
planning metadata；可见 native 输出还需要 backend pipeline hook。

Mesh/task shader 由 `MeshPipelineDescriptor` 表示。Vulkan mesh shader 和 Metal object/mesh-like
path 都被视为 backend-gated advanced feature。`MeshDispatchDescriptor` 可以生成 Vulkan
task/mesh 或 Metal object/mesh planning metadata。

Ray tracing descriptor 和普通 render pipeline 隔离，因为 Vulkan 和 Metal 在 acceleration
structure、pipeline 和 shader table 细节上差异很大。
Ray tracing completeness API 现在包括 AS maintenance planning、TLAS instance metadata
planning、Vulkan ray query planning、complex SBT planning 和 deterministic RT stress
planning。Metal ray query 会报告 unsupported，因为这一层没有直接等价的 Metal shader
feature。Native GPU stress evidence 仍属于 backend / device validation matrix。

Driver-level pipeline cache 和 Metal binary archive 使用显式 cache identity descriptor。它们和
Period 8 object-cache diagnostics 是分开的层。
Shader / pipeline artifact compatibility 通过 `Device.planPipelineArtifactCache(...)` 规划；
当 shader hash、entry point、reflection、format、backend、schema 或 toolchain identity
变化时会确定性失效。Native `VkPipelineCache`、pipeline library 和 `MTLBinaryArchive`
持久化仍是 backend work。
