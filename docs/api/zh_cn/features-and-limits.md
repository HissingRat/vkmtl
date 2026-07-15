# Features、Limits 与 Format Capabilities

本文定义应用如何解释 vkmtl capability 数据。它是 API contract，但不表示所有 native feature
在每台设备上都有可执行路径。

## Query Model

```zig
const report = device.capabilityReport();
const usable = report.features;
const native = report.native_features;
const limits = report.limits;
const rgba8 = device.getFormatCaps(.rgba8_unorm);
```

Canonical public type 是 `vkmtl.diagnostics.DeviceFeatures`、
`vkmtl.diagnostics.DeviceLimits`、`vkmtl.diagnostics.DeviceCapabilityReport` 和
`vkmtl.resource.FormatCapabilities`。Quick-start 代码仍可使用获准保留的 root alias。

- `device.features()` / `report.features` 表示 vkmtl 可用的执行路径。Native API 能查询到某
  feature，不足以让这里自动变成 `true`。
- `device.nativeFeatures()` / `report.native_features` 表示 selected backend 查询到的 native
  事实；此时 vkmtl 仍可能只有 planning、validation 或 native escape hatch。
- `report.source` 表示 capability 来自 runtime native query 还是 fallback/default source。
- `report.ray_tracing` 另外提供 Vulkan/Metal RT blocker、requirement、limit 和 command
  availability diagnostics。
- 依赖具体 texture format 的操作，以 `device.getFormatCaps(format)` 为准。

应用必须同时检查 usable feature、limit 和 format capability，不能把 platform/backend 名称当作
feature gate。
需要 owner 的 capability 会按当前 owner 报告：`HeadlessContext` 会在
`native_features` 保留 native device 事实，但 usable scheduled-presentation field、present-mode
support、native-handle route 和 format `presentation` flag 都保持关闭，因为它没有 surface 或
drawable。

## Status Vocabulary

| Status | 含义 |
| --- | --- |
| executable | Public command path 已实现，并在 selected backend 上完成验证。 |
| capability-gated | 只有相关 feature/limit/format query 允许时才可执行。 |
| validation-only | Public shape 和 validation 已存在，但不声称 native command 已实现。 |
| planning-only | API 生成 deterministic plan/diagnostics，不提交 GPU work。 |
| typed-unsupported | 在 native work 前以具体 typed error 拒绝。 |
| native escape hatch | 行为有意放在 `vkmtl.native` 下并保持 backend-specific。 |

## DeviceFeatures Fields

下面按领域列出当前全部 `DeviceFeatures` field。`false` 表示 usable path 不可用；只有具体操作
文档明确说明时才能使用 fallback。

### Shader 与 Constants

```text
runtime_slang shader_reflection shader_specialization
small_constants root_constants
```

Runtime API 消费 build-time embedded shader artifact；`runtime_slang` 不表示 executable 可以
启动 `slangc`。

### Resource 与 Storage

```text
buffers textures texture_1d texture_2d texture_3d texture_arrays
cube_textures multisample_textures samplers sampler_compare
sampler_anisotropy sampler_border_color heaps
sparse_buffers sparse_textures tiled_textures memory_budget memory_pressure
storage_buffers storage_textures
buffer_gpu_address memoryless_attachments
```

### Binding

```text
bind_groups descriptor_indexing argument_buffers static_samplers
indirect_command_buffers
```

### Render 与 Advanced Geometry

```text
render_pipelines wireframe_fill_mode depth_bias conservative_rasterization
blend_state independent_blend stencil_state
tessellation mesh_shaders task_shaders
vertex_instance_step_rate draw_base_vertex draw_base_instance
indirect_draw multi_draw depth_attachments offscreen_render_targets
msaa_render_targets indexed_draw
```

Period 51 中，`tessellation` 表示完整的 Vulkan source-to-patch-draw 路径；Metal
保持 false。`mesh_shaders` 表示完整的 mesh-only pipeline 与 dispatch 路径。
`task_shaders` 在两个 backend 上都保持 false，因为 pinned compiler 尚不能稳定生成可选
task/object artifact，即使 `native_features.task_shaders` 报告 device 原生支持也不例外。

### Compute

```text
compute_pipelines compute_dispatch_indirect
compute_atomics compute_threadgroup_memory
```

### Ray Tracing

```text
acceleration_structures acceleration_structure_update
acceleration_structure_refit acceleration_structure_compaction
ray_tracing ray_query ray_tracing_procedural_geometry
ray_tracing_custom_intersection ray_tracing_callable_shaders
```

Period 52 会在 selected device 具备完整路径时开放普通 AS build/update/refit/
compact-copy 和基础 RT dispatch。Metal 与 Vulkan 都支持 triangle/AABB/instance AS
input；Metal custom intersection 保持 false，Vulkan custom intersection 对应可执行的
procedural RT 路径。两个 backend 的 `ray_query` 与
`ray_tracing_callable_shaders` 都保持 false。Vulkan 的
`native_features.ray_query` 可以报告 extension/feature 可用，但普通 AS binding 与
ray-query shader 路径还不存在。`acceleration_structure_compaction` 也不表示支持
post-build compacted-size discovery。

Texture RT output 还必须检查 `getFormatCaps(format).storage` 与 `.sampled`。
Period 55 reference path 使用 `rgba16_float`；不能只因为 `storage_textures` 为 true 就创建它。
Texture dispatch 会在 native encoding 前校验 shader-read/write usage、single-sample 2D view 和
dispatch extent。Presentation 还要单独确认 selected surface path 支持
`bgra8_unorm_srgb`。

### Query 与 Driver Artifact

```text
occlusion_queries occlusion_counting_queries
timestamp_queries pipeline_statistics_queries
driver_pipeline_cache metal_binary_archive
```

只有 selected backend 能分配并 reset native result storage 时，`occlusion_queries`
才可用。Vulkan 要求启用 host-query reset；Metal 使用 pass-bound visibility buffer。
默认 portable result 是 zero/nonzero visibility。设备报告
`occlusion_counting_queries` 时可以请求 `OcclusionQueryMode.counting`：Metal 使用
counting visibility，Vulkan 需要 query 并启用 precise occlusion。`timestamp_queries`
仍可通过 logical ordering fallback 使用。`native_features` 报告底层 queue/counter 的
timestamp 事实；只有 vkmtl 的 allocation/reset/encoder 路径也完整可用时，
`QuerySet.resultSource()` 才是 `native_gpu`，否则仍是 logical。Pipeline statistics
保持 false，因为 scalar query shape 无法表达 typed variable counter result。

### Transfer、Presentation、Interop 与 Native Access

```text
transfer_commands multi_surface scheduled_presentation
minimum_duration_presentation
external_memory external_textures external_semaphores
native_command_insertion native_handles
```

在 Metal 上，`external_memory` 与 `external_textures` 表示同一 device 创建的原生
`MTLBuffer` / `MTLTexture`，以及单 plane IOSurface，可以通过 external owner 变成普通
vkmtl resource。返回 resource 前会校验 native device identity、长度或形状、format、usage、
storage mode 和 IOSurface plane。Vulkan 的 public descriptor 还没有完整 native allocation/image
metadata，因此这些 usable field 在 Vulkan 上保持 false。

`external_semaphores` 与 `native_command_insertion` 在两个 backend 上都保持 false。Planning
record 或 native API availability 不表示已经接上 external submit synchronization，也不表示能拿到
active native command encoder 做插入。

`vkmtl.diagnostics.deviceTopology(device)` 会独立报告 selected-device identity 和 native
peer-group membership；它是 diagnostics query，不是 cross-device execution capability。

### Command、Synchronization 与 Diagnostics

```text
debug_labels debug_markers command_buffer_pooling command_buffer_reset
command_buffer_lifecycle_callbacks
explicit_resource_barriers fences events timeline_fences shared_events
multi_queue dedicated_compute_queue dedicated_transfer_queue
queue_ownership_transfer
```

`timeline_fences` 只有在 native host 与 GPU-submit 路径都完整时才为 true。
`shared_events` 当前表示 native Metal shared event，不表示 portable external handle。
`multi_queue` 表示 command buffer 能在不同 physical backend queue 上执行；只有 backend 能确认
不同 hardware queue family 时，dedicated field 才为 true。Presentation timing 单独 gate，且只有
descriptor 明确允许时才能 fallback。

## DeviceLimits Fields

Feature 为 true 时，descriptor 仍必须满足对应 limit。

| 分组 | Fields |
| --- | --- |
| Render/binding | `max_vertex_buffer_slots`, `max_bind_group_slots`, `max_color_attachments`, `max_sample_count`, `max_sampler_anisotropy` |
| Core resource | `max_buffer_length`, `max_texture_dimension_1d`, `max_texture_dimension_2d`, `max_texture_dimension_3d`, `max_texture_array_layers` |
| Buffer/constants | `min_uniform_buffer_offset_alignment`, `min_storage_buffer_offset_alignment`, `max_small_constant_bytes`, `small_constant_alignment`, `max_root_constant_bytes`, `root_constant_alignment` |
| Query | `query_result_alignment` |
| Compute | `max_compute_threadgroups_per_grid_x`, `max_compute_threadgroups_per_grid_y`, `max_compute_threadgroups_per_grid_z`, `max_compute_threads_per_threadgroup_x`, `max_compute_threads_per_threadgroup_y`, `max_compute_threads_per_threadgroup_z`, `max_compute_total_threads_per_threadgroup`, `max_compute_threadgroup_memory_bytes`, `dispatch_indirect_alignment` |
| Transfer | `buffer_texture_copy_offset_alignment`, `buffer_texture_copy_row_pitch_alignment` |
| Binding | `max_bindless_descriptors_per_range`, `max_bindless_ranges_per_layout` |
| Reusable command | `max_indirect_command_count` |
| Advanced geometry | `max_tessellation_control_points`, `max_mesh_threads_per_threadgroup`, `max_task_threads_per_threadgroup`, `max_mesh_threadgroups_per_grid_x`, `max_mesh_threadgroups_per_grid_y`, `max_mesh_threadgroups_per_grid_z` |
| Ray tracing | `max_ray_tracing_recursion_depth`, `shader_binding_table_alignment`, `max_acceleration_structure_instances`, `max_shader_binding_table_records` |
| Driver artifact | `max_driver_cache_identity_bytes` |
| Sparse resource | `sparse_buffer_page_size`, `sparse_texture_page_width`, `sparse_texture_page_height`, `sparse_texture_page_depth`, `max_sparse_regions_per_commit` |

Optional feature family 的 maximum/page-size 为 0 时，表示 limit 不可用或未建立，不表示 unlimited；
必须同时检查对应 feature。Capability source 为 fallback 时，base alignment 和基础 render/compute
limit 可能使用保守的非零默认值。`max_sampler_anisotropy == 1` 不能在
`sampler_anisotropy == false` 时启用 anisotropy。

`compute_atomics` 当前表示可执行的 portable 32-bit integer storage-buffer/threadgroup
atomic 子集，不表示 storage-texture 或 64-bit atomic breadth。
`compute_threadgroup_memory` 必须和 `max_compute_threadgroup_memory_bytes` 一起使用；feature
为 true 也不能越过这个 byte ceiling。

## FormatCapabilities Fields

每个 texture format 独立报告：

```text
sampled storage color_attachment depth_stencil_attachment
filterable linear_filter mipmapped mipmap_generation blendable
copy_source copy_destination blit_source blit_destination presentation
depth_copy stencil_copy color_resolve depth_resolve stencil_resolve
```

不要从 format 名称推断 copy、blit、resolve、presentation 或 depth/stencil 行为。Encoding 前同时
检查对应 capability flag 和 transfer alignment limit。即使同一 native adapter 可以通过
`WindowContext` 呈现，headless device 也会报告 `presentation = false`。

Color-managed RT 路径必须确认 `rgba16_float` 同时支持 `sampled` 与 `storage`；只有 caller
需要 readback/copy 时才额外要求 `copy_source`。`bgra8_unorm_srgb` 是最终 display target，
不是 scene-linear storage texture。Format support 仍以当前 device/backend query 为准。当前
texture-dispatch contract 还要求 output view 覆盖完整的 single-mip、single-layer texture；format
capability 不会放宽这条 command-specific shape 限制。

## Evidence 与 Diagnostics

应在实际验证使用的同一设备上运行 capability dump：

```sh
zig build run-capability-dump
zig build run-capability-dump -Dvulkan
```

Period44 parity report 的 9/9 表示 hosted/Metal/Vulkan smoke、pixel、bounded-soak gate 已取得
证据；它不会把 planning-only sparse-page 或其他 deferred backend work 自动变成 executable feature。
Native heap、physical queue 和 Metal memoryless attachment 现在有独立 executable evidence。每个
process/device 仍以 capability report 为准。
