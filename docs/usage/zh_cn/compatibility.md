# Compatibility

vkmtl 优先覆盖 portable Vulkan 和 Metal workflow；高级能力放在显式 capability gate 后面。

## v0.1.x 源码兼容性

`v0.1.0` 建立第一个 compatibility baseline。`v0.1.x` 内的 patch release 会保持文档中
portable Zig source API 的兼容性，包括 canonical declaration、公开 owner method、descriptor
default、typed error category、ownership/lifetime rule，以及已声明支持的 capability meaning。
有意破坏 portable source compatibility 的改动必须进入 `v0.2.0` 或更高版本，并提供迁移说明。

当前 Unreleased 的 Period 46 会给 `QueryError` 增加 `QueryBackendFailure`，因此目标版本是
`v0.2.0`，不是 `v0.1.x` patch。Exhaustive error switch 需要增加一个分支；普通 error
propagation 不受影响。完整 query 更新见 migration guide。

这不是 stable binary ABI。应用不能依赖 opaque `_state` storage 的 size、alignment、内容，
不能依赖 raw native-handle value，也不能假设 backend-native escape hatch 在 `0.x` minor
release 间稳定。`v0.1.x` 支持的工具链是 Zig `0.16.0`。

权威规则见 [release policy](../../develop/release-policy.md)，从 prototype 更新的调用方见
[API migration guide](../../develop/api-migration-guide.md)。

## Package 与 Shader Manifest

package 只导出一个受支持模块：`vkmtl`。仓库中的 example support code 和 tool 只供仓库自身
build 使用，不是 package module export。

声明 shader 的应用通过 source-backed `std.Build.LazyPath` 类型的
`shader_manifest` dependency option 传入自己拥有的 manifest：

```zig
const vkmtl_dep = b.dependency("vkmtl", .{
    .target = target,
    .optimize = optimize,
    .shader_manifest = b.path("shaders/manifest.json"),
});

exe.root_module.addImport("vkmtl", vkmtl_dep.module("vkmtl"));
```

JSON manifest 使用 schema version 1，并包含三个 array：

```json
{
  "schema_version": 1,
  "render_shaders": [
    {
      "name": "triangle",
      "source": "triangle.slang",
      "vertex_entry": "vs_main",
      "fragment_entry": "fs_main"
    }
  ],
  "compute_shaders": [
    {
      "name": "particles",
      "source": "particles.slang",
      "entry": "cs_main"
    }
  ],
  "ray_tracing_shaders": []
}
```

Render entry 包含 `name`、`source`、`vertex_entry`、`fragment_entry`；compute entry
包含 `name`、`source`、`entry`；ray-tracing entry 包含 `name`、`source`、
`metal_ray_generation_source`、`ray_generation_entry`、`miss_entry`、
`closest_hit_entry`、`any_hit_entry`、`intersection_entry`。所有 source path（包括
`metal_ray_generation_source`）都相对于 manifest 文件解析，且不能越出
LazyPath owner 的 logical root。Schema version 1 不支持 generated manifest，因为
dependency graph 会在 configuration 时枚举 shader input。

构建会追踪 manifest 和其中声明的所有 shader source，并通过 Slang
depfile 追踪 include/import dependency，然后生成 SPIR-V、MSL、reflection blob
并嵌入 consumer 的 `vkmtl` module。Runtime shader API 不会启动 `slangc`，也不会写
runtime shader cache。默认 `shaders/manifest.json` 服务于仓库自身示例；外部应用应该提供
自己的 manifest。

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
不支持的 optional behavior 应该返回 typed error，而不是静默改变语义。Planning-only record
或 typed-unsupported path 不构成 executable feature claim。

## Sync And Query Defaults

vkmtl 会保持普通 command path portable：resource usage tracking、binary fence、event、
timestamp query 和 capability-gated occlusion query 都通过 backend-neutral runtime object
暴露。Timestamp value 可能是 logical ordering value，也可能是 raw native GPU tick；先检查
`resultSource()`，在 calibration 尚未公开时不要计算 duration。Occlusion 使用 zero/nonzero
visibility，并要求 render pass 绑定对应 set。显式 barrier
和 queue ownership transfer 是高级 escape hatch；Vulkan 会把 barrier path 下沉到 native，
Metal 会在 encoder boundary 已经定义 ordering 的地方使用 validation/no-op marker。Timeline
fence、shared event 和 logical queue planning 已经有 portable descriptor / validation 入口；
native timeline/shared-event submit、native dedicated queue、native queue-family ownership transfer、
exact occlusion sample count 和 pipeline statistics query 仍然保持 capability-gated，等 backend
lowering 完成后再打开。

## Advanced Features

Advanced features 会继续放在 feature gate 后面。一部分 binding 和 ray tracing 路径已经有
可执行 runtime object 与 command entry point；sparse resource、native external import、
tessellation、mesh shader 和 native driver-cache persistence 仍需要后续 backend work。

Heap、memory-budget、transient-allocation 和 sparse-residency API 目前提供 portable planning
与 diagnostics。Native heap-backed buffer/texture creation 和 native sparse/tiled page binding
仍是后续 backend work。

Descriptor indexing 映射到 Vulkan descriptor indexing，argument buffer 映射到 Metal
argument buffer。两者通过 `vkmtl.binding.DescriptorIndexingLayoutDescriptor`、
`AdvancedBindGroupLayout` 和 `ResourceTable` 表达。当所选后端声明所需 feature 时，
resource table 可以 update、clear，并通过 render / compute encoder 绑定。

大型 table 压力通过 `vkmtl.binding.planResourceTablePressure(device, descriptor)` 规划。Plan 会在分配前明确
partially-bound 和 update-after-bind 要求；真实 GPU 压力证据仍属于后端 / 设备矩阵验证。

Root constants 会在 pipeline 声明兼容 `root_constant_layout` 后下沉到 Vulkan push constants 和
Metal `set*Bytes`。

Shader specialization 由 capability gate 控制。能力可用时，Vulkan specialization info 以及
Metal vertex、fragment、compute function constant 都按稳定 numeric ID 下沉；可选 constant name
不参与 native lookup。

Sparse buffer/texture 未来映射到 Vulkan sparse resource 和 Metal tiled/sparse texture 概念。
当前 descriptor 只校验 page-aligned mapping intent。

External memory、buffer、texture、semaphore 和 shared-event interop 使用显式
platform/backend handle descriptor。Runtime wrapper 会校验 ownership 和 backend
compatibility。Import plan 会分类 handle lane，texture usage plan 会校验
sampling/copy/presentation intent，external synchronization plan 会在提交前校验
wait/signal ordering。Native OS/Vulkan/Metal handle import 和 wait/signal lowering
仍是 backend hook work。`vkmtl.interop.ExternalInteropCapabilityMatrix` 和
`vkmtl.interop.diagnoseExternalInteropImport(device, descriptor)` 会在 import 前按 backend/platform 分类 handle
support。

Tessellation 由 `vkmtl.render.TessellationDescriptor` 表示，仍然是 optional render pipeline
extension，不是默认 portable render path。`TessellationPatchDrawDescriptor` 有 portable render
plan；显式 Vulkan/Metal lowering inspection 位于 `vkmtl.native.vulkan` 和
`vkmtl.native.metal`。可见 native 输出仍需要 backend pipeline hook。

Mesh/task shader 由 `vkmtl.render.MeshPipelineDescriptor` 表示。Vulkan mesh shader 和 Metal object/mesh-like
path 都被视为 backend-gated advanced feature。`MeshDispatchDescriptor` 有 portable render
plan；backend-specific planning 位于对应的 `native` 子 namespace。

`vkmtl.ray_tracing` 和普通 render pipeline 隔离，因为 Vulkan 和 Metal 在 acceleration
structure、pipeline 和 shader table 细节上差异很大。
Ray tracing completeness API 现在包括 AS maintenance planning、TLAS instance metadata
planning、Vulkan ray query planning、complex SBT planning 和 deterministic RT stress
planning。Metal ray query 会报告 unsupported，因为这一层没有直接等价的 Metal shader
feature。物理 Metal 与 Vulkan RT 运行都已经产生可见输出，包括 Vulkan procedural scene。
Period 44 的 hosted、smoke、pixel 和 bounded-soak 九项 gate 也全部 observed。这不代表已经验证
native memory pressure、sparse binding、dedicated queue、cache persistence 或多小时 RT stress。

Driver-level pipeline cache 和 Metal binary archive 使用显式 cache identity descriptor。它们和
Period 8 object-cache diagnostics 是分开的层。
Shader / pipeline artifact compatibility 通过
`vkmtl.diagnostics.planPipelineArtifactCache(device, descriptor)` 规划；
当 shader hash、entry point、reflection、format、backend、schema 或 toolchain identity
变化时会确定性失效。Native `VkPipelineCache`、pipeline library 和 `MTLBinaryArchive`
持久化仍是 backend work。
