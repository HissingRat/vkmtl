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
buffer_gpu_address
```

### Binding

```text
bind_groups descriptor_indexing argument_buffers static_samplers
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

### Query 与 Driver Artifact

```text
occlusion_queries timestamp_queries pipeline_statistics_queries
driver_pipeline_cache metal_binary_archive
```

只有 selected backend 能分配并 reset native result storage 时，`occlusion_queries`
才可用。Vulkan 要求启用 host-query reset；Metal 使用 pass-bound visibility buffer。
Portable result 是 zero/nonzero visibility，不是精确 sample count。`timestamp_queries`
仍可通过 logical ordering fallback 使用。`native_features` 报告底层 queue/counter 的
timestamp 事实；只有 vkmtl 的 allocation/reset/encoder 路径也完整可用时，
`QuerySet.resultSource()` 才是 `native_gpu`，否则仍是 logical。Pipeline statistics
保持 false。

### Transfer、Presentation、Interop 与 Native Access

```text
transfer_commands multi_surface
external_memory external_textures external_semaphores
native_command_insertion native_handles
```

### Command、Synchronization 与 Diagnostics

```text
debug_labels debug_markers command_buffer_pooling command_buffer_reset
explicit_resource_barriers fences events timeline_fences shared_events
multi_queue dedicated_compute_queue dedicated_transfer_queue
queue_ownership_transfer
```

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
| Advanced geometry | `max_tessellation_control_points`, `max_mesh_threads_per_threadgroup`, `max_task_threads_per_threadgroup` |
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
检查对应 capability flag 和 transfer alignment limit。

## Evidence 与 Diagnostics

应在实际验证使用的同一设备上运行 capability dump：

```sh
zig build run-capability-dump
zig build run-capability-dump -Dvulkan
```

Period44 parity report 的 9/9 表示 hosted/Metal/Vulkan smoke、pixel、bounded-soak gate 已取得
证据；它不会把 planning-only native heap、sparse-page、physical multi-queue 或其他 deferred
backend work 自动变成 executable feature。每个 process/device 仍以 capability report 为准。
