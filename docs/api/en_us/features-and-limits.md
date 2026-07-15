# Features, Limits, And Format Capabilities

This document defines how applications interpret vkmtl capability data. It is
an API contract, not a promise that every native feature is executable on every
device.

## Query Model

```zig
const report = device.capabilityReport();
const usable = report.features;
const native = report.native_features;
const limits = report.limits;
const rgba8 = device.getFormatCaps(.rgba8_unorm);
```

The canonical public types are `vkmtl.diagnostics.DeviceFeatures`,
`vkmtl.diagnostics.DeviceLimits`,
`vkmtl.diagnostics.DeviceCapabilityReport`, and
`vkmtl.resource.FormatCapabilities`. Common feature, limit, and format aliases
also remain available at the root for quick-start code.

- `device.features()` and `report.features` describe usable vkmtl execution
  paths. A feature is not set merely because the native API can expose it.
- `device.nativeFeatures()` and `report.native_features` describe facts queried
  from the selected native backend. They may be true while vkmtl still exposes
  only planning, validation, or a native escape hatch.
- `report.source` identifies whether capability data came from a runtime native
  query or a fallback/default source.
- `report.ray_tracing` adds the exact Vulkan/Metal RT blocker, requirement,
  limits, and command-availability diagnostics.
- `device.getFormatCaps(format)` is authoritative for operations that depend on
  one concrete texture format.

Applications must gate optional work with usable features, limits, and format
capabilities together. Platform names and backend assumptions are not gates.
Capabilities that require an owner are reported for that owner:
`HeadlessContext` keeps native device facts in `native_features`, but its usable
scheduled-presentation fields, present-mode support, native-handle route, and
format `presentation` flags are closed because it has no surface or drawable.

## Status Vocabulary

| Status | Meaning |
| --- | --- |
| executable | A public command path is implemented and validated on the selected backend. |
| capability-gated | The API is executable only when the relevant feature/limit/format query permits it. |
| validation-only | The public shape and validation exist, but no native command is claimed. |
| planning-only | The API produces deterministic plans or diagnostics rather than GPU work. |
| typed-unsupported | The selected backend rejects the operation before native work with a specific error. |
| native escape hatch | The behavior is intentionally backend-specific under `vkmtl.native`. |

## DeviceFeatures Fields

All current `DeviceFeatures` fields are grouped below. `false` means the usable
path is unavailable; callers must not infer a fallback unless the operation's
documentation defines one.

### Shader And Constants

```text
runtime_slang shader_reflection shader_specialization
small_constants root_constants
```

Runtime APIs consume build-time embedded shader artifacts; `runtime_slang`
does not mean that an executable may spawn `slangc`.

### Resources And Storage

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

### Rendering And Advanced Geometry

```text
render_pipelines wireframe_fill_mode depth_bias conservative_rasterization
blend_state independent_blend stencil_state
tessellation mesh_shaders task_shaders
vertex_instance_step_rate draw_base_vertex draw_base_instance
indirect_draw multi_draw depth_attachments offscreen_render_targets
msaa_render_targets indexed_draw
```

For Period 51, `tessellation` means the complete Vulkan source-to-patch-draw
path; Metal keeps it false. `mesh_shaders` means a complete mesh-only pipeline
and dispatch path. `task_shaders` remains false on both backends because the
pinned compiler cannot stably produce the optional task/object artifact, even
when `native_features.task_shaders` reports device support.

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

Period 52 makes ordinary AS build/update/refit/compact-copy and basic RT
dispatch usable when the selected device reports the complete path. Metal and
Vulkan expose triangle/AABB/instance AS input; Metal custom intersection stays
false, while Vulkan custom intersection follows the executable procedural RT
path. `ray_query` and `ray_tracing_callable_shaders` remain false on both
backends. `native_features.ray_query` may report Vulkan extension/feature
availability, but no ordinary AS binding plus ray-query shader path exists yet.
Post-build compacted-size discovery is not implied by
`acceleration_structure_compaction`.

Texture RT output additionally requires `getFormatCaps(format).storage` and
`.sampled`. The Period 55 reference path uses `rgba16_float`; it must not be
created merely because `storage_textures` is true. Texture dispatch validates
shader-read/write usage, a single-sample 2D view, and dispatch extent before
native encoding. Presentation separately requires the selected surface path to
support `bgra8_unorm_srgb`.

### Queries And Driver Artifacts

```text
occlusion_queries occlusion_counting_queries
timestamp_queries pipeline_statistics_queries
driver_pipeline_cache metal_binary_archive
```

`occlusion_queries` is usable only when the selected backend can allocate and
reset its native result storage. Vulkan requires enabled host-query reset;
Metal uses pass-bound visibility buffers. The default result is portable
Boolean visibility (zero/nonzero). `occlusion_counting_queries` admits
`OcclusionQueryMode.counting`: Metal uses counting visibility and Vulkan
requires queried and enabled precise occlusion. `timestamp_queries` remains
usable through a logical ordering fallback. `native_features` reports the
underlying queue/counter timestamp fact, while `QuerySet.resultSource()` becomes
`native_gpu` only when vkmtl's complete allocation/reset/encoder path is also
usable; otherwise it remains logical. Pipeline statistics remain false because
the scalar query shape cannot represent typed variable counter results.

### Transfer, Presentation, Interop, And Native Access

```text
transfer_commands multi_surface scheduled_presentation
minimum_duration_presentation
external_memory external_textures external_semaphores
native_command_insertion native_handles
```

On Metal, `external_memory` and `external_textures` mean that same-device raw
`MTLBuffer`/`MTLTexture` objects and single-plane IOSurfaces can become ordinary
vkmtl resources through their external owners. The import validates native
device identity, length or shape, format, usage, storage mode, and IOSurface
plane before returning a resource. These usable fields remain false on Vulkan
until the public descriptors carry complete native allocation/image metadata.

`external_semaphores` and `native_command_insertion` remain false on both
backends. Planning records or native API availability do not imply external
submit synchronization or an active native command-encoder insertion route.

`vkmtl.diagnostics.deviceTopology(device)` reports selected-device identity and
native peer-group membership independently from feature flags. It is a
diagnostic query, not a cross-device execution capability.

### Command, Synchronization, And Diagnostics

```text
debug_labels debug_markers command_buffer_pooling command_buffer_reset
command_buffer_lifecycle_callbacks
explicit_resource_barriers fences events timeline_fences shared_events
multi_queue dedicated_compute_queue dedicated_transfer_queue
queue_ownership_transfer
```

`timeline_fences` is true only for a complete native host and GPU-submit path.
`shared_events` currently identifies native Metal shared events, not portable
external handles. `multi_queue` means command buffers can execute on separate
physical backend queues; dedicated flags describe distinct hardware queue
families only where the backend can establish them. Presentation timing is
independently gated and falls back only when the descriptor permits it.

## DeviceLimits Fields

Limits constrain descriptors even when the matching feature is true.

| Group | Fields |
| --- | --- |
| Render/binding | `max_vertex_buffer_slots`, `max_bind_group_slots`, `max_color_attachments`, `max_sample_count`, `max_sampler_anisotropy` |
| Core resources | `max_buffer_length`, `max_texture_dimension_1d`, `max_texture_dimension_2d`, `max_texture_dimension_3d`, `max_texture_array_layers` |
| Buffer/constants | `min_uniform_buffer_offset_alignment`, `min_storage_buffer_offset_alignment`, `max_small_constant_bytes`, `small_constant_alignment`, `max_root_constant_bytes`, `root_constant_alignment` |
| Queries | `query_result_alignment` |
| Compute | `max_compute_threadgroups_per_grid_x`, `max_compute_threadgroups_per_grid_y`, `max_compute_threadgroups_per_grid_z`, `max_compute_threads_per_threadgroup_x`, `max_compute_threads_per_threadgroup_y`, `max_compute_threads_per_threadgroup_z`, `max_compute_total_threads_per_threadgroup`, `max_compute_threadgroup_memory_bytes`, `dispatch_indirect_alignment` |
| Transfer | `buffer_texture_copy_offset_alignment`, `buffer_texture_copy_row_pitch_alignment` |
| Binding | `max_bindless_descriptors_per_range`, `max_bindless_ranges_per_layout` |
| Reusable commands | `max_indirect_command_count` |
| Advanced geometry | `max_tessellation_control_points`, `max_mesh_threads_per_threadgroup`, `max_task_threads_per_threadgroup`, `max_mesh_threadgroups_per_grid_x`, `max_mesh_threadgroups_per_grid_y`, `max_mesh_threadgroups_per_grid_z` |
| Ray tracing | `max_ray_tracing_recursion_depth`, `shader_binding_table_alignment`, `max_acceleration_structure_instances`, `max_shader_binding_table_records` |
| Driver artifacts | `max_driver_cache_identity_bytes` |
| Sparse resources | `sparse_buffer_page_size`, `sparse_texture_page_width`, `sparse_texture_page_height`, `sparse_texture_page_depth`, `max_sparse_regions_per_commit` |

For optional feature families, a maximum or page-size value of zero means that
the limit is unavailable or was not established; it is not an unlimited value.
Always check the matching feature. Base alignments and baseline render/compute
limits may have conservative nonzero defaults when the capability source is a
fallback. `max_sampler_anisotropy == 1` does not enable anisotropy when
`sampler_anisotropy` is false.

`compute_atomics` currently means the executable portable 32-bit integer
storage-buffer/threadgroup atomic subset, not storage-texture or 64-bit atomic
breadth. `compute_threadgroup_memory` must be combined with
`max_compute_threadgroup_memory_bytes`; a true feature does not override that
byte ceiling.

## FormatCapabilities Fields

Each texture format independently reports:

```text
sampled storage color_attachment depth_stencil_attachment
filterable linear_filter mipmapped mipmap_generation blendable
copy_source copy_destination blit_source blit_destination presentation
depth_copy stencil_copy color_resolve depth_resolve stencil_resolve
```

Do not infer copy, blit, resolve, presentation, or depth/stencil behavior from
format naming. Use the matching capability flag and the transfer alignment
limits before encoding. A headless device reports `presentation = false` even
when the same native adapter can present through a `WindowContext`.

For the color-managed RT path, require both `sampled` and `storage` on
`rgba16_float`; `copy_source` is additionally required only when the caller
requests readback or copies. `bgra8_unorm_srgb` is the final display target,
not the scene-linear storage texture. Format support remains device- and
backend-query-dependent. The current texture-dispatch contract also requires a
whole single-mip, single-layer output view; a format capability does not relax
that command-specific shape restriction.

## Evidence And Diagnostics

Run the capability dump on the same device used for validation:

```sh
zig build run-capability-dump
zig build run-capability-dump -Dvulkan
```

The Period 44 parity report records 9/9 hosted/Metal/Vulkan release-evidence
gates. That result validates the documented smoke, pixel, and bounded-soak
matrix; it does not turn planning-only sparse-page or other deferred backend
work into executable features. Native heaps, physical queues, and Metal
memoryless attachments now have separate executable evidence. The
capability report remains authoritative for each process and device.
