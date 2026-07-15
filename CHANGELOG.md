# Changelog

All notable user-facing changes to vkmtl are recorded in this file.

vkmtl follows the release and compatibility policy in
[`docs/develop/release-policy.md`](docs/develop/release-policy.md). Because the
project is still in the `0.x` series, intentional portable source breaks are
reserved for the next minor release and are documented with migration guidance.

## [Unreleased]

### Added

- Added the exact `ray_tracing.RayTracingTextureResources` alias and
  `CommandBuffer.dispatchRaysToTexture(...)` for native Metal/Vulkan ray
  dispatch into caller-owned textures without drawable acquisition or
  presentation side effects.
- Added a shared color-managed `ray_traced_scene` display path: capability-
  gated scene-linear `rgba16_float`, fixed exposure `1.0`, an ACES-fitted
  fullscreen transform, and one hardware encode through
  `bgra8_unorm_srgb`.
- Completed the bounded Period 19 voxel renderer pressure test with visible-face
  CPU chunk meshing, generated atlas materials, reflection-derived layouts,
  camera and chunk culling, bounded streaming/rebuild work, pressure metrics,
  smoke/default/stress profiles, autopilot, and the finite-run
  `voxel_world_pressure_test=ok` marker through public vkmtl APIs.
- Added capability-gated exact occlusion sample counts through
  `diagnostics.OcclusionQueryMode.counting`, native Metal counting visibility,
  and Vulkan precise occlusion queries.
- Added executable same-device Metal `MTLBuffer` and single-mip/single-sample
  2D/2D-array `MTLTexture` imports plus single-plane IOSurface texture imports,
  exposed as ordinary borrowed vkmtl resources through their external owners.
- Added backend-neutral selected-device identity and peer-group diagnostics for
  Metal registry/peer properties and Vulkan UUID/device-group membership.
- Added a headless deterministic external-import/readback example.
- Added executable Vulkan/Metal acceleration-structure build-update,
  update/refit, and compact-copy commands through
  `CommandBuffer.encodeAccelerationStructureMaintenance(...)`.
- Added native Metal AABB BLAS input, multiple distinct BLAS sources per TLAS,
  and a headless RT maintenance/geometry stress example.
- Added root `HeadlessContext` with nested `Options` and borrowed `Device` and
  `Queue` views for real no-window compute, transfer, resource, ray-tracing,
  and texture-backed offscreen rendering.
- Added Metal device/queue initialization without AppKit presentation objects
  and Vulkan loader/device initialization without a surface,
  `VK_KHR_swapchain`, or presentation-queue requirement.
- Added schema-2 tessellation and mesh shader declarations while retaining
  schema-1 manifest compatibility.
- Added executable Vulkan tessellation pipelines and patch draws, plus native
  Metal/Vulkan mesh-only pipelines and mesh-grid dispatch.
- Added visible public tessellation and mesh examples; the Metal mesh example
  has physical Apple M4 Pro execution evidence.
- Added native Metal argument-buffer and Vulkan descriptor-indexing resource
  tables with compatible render/compute pipeline layouts and exact runtime
  layout validation.
- Added CPU-authored reusable render/compute command lists with native Metal
  ICB execution and exact Vulkan direct-command expansion.
- Added render/compute pipeline persistence through `MTLBinaryArchive` and
  `VkPipelineCache`, including explicit identity, read-only mode, and stale-data
  recovery.
- Added native Metal placement heaps and Vulkan device-memory heaps with exact
  buffer/texture size-and-alignment queries and placed resource creation.
- Added native Metal recommended-working-set/current-allocation reporting and
  Vulkan `VK_EXT_memory_budget` reporting when queried.
- Added capability-gated hardware-memoryless render attachments on Metal,
  including memoryless MSAA resolve usage.
- Added native timeline synchronization: Vulkan timeline semaphores and Metal
  shared events now support host query/wait/signal and GPU submit wait/signal.
- Added physical compute/transfer command queues, capability-gated queue-family
  discovery, cross-queue dependencies, and portable ownership enforcement.
- Added command-buffer scheduled/completed lifecycle callbacks and status.
- Added capability-gated scheduled-time and minimum-duration drawable
  presentation with explicit immediate fallback.
- Completed portable MRT validation/lowering for every color attachment and
  native texture-backed load/store actions, including combined depth/stencil.
- Added executable 32-bit integer storage-buffer/threadgroup atomics and
  threadgroup-memory capability reporting with queried byte limits.
- Added schema-1 reflection preservation for fixed resource arrays and storage
  access through derived bind group layouts.
- Added queried ordinary resource limits for maximum buffer length, 1D/2D/3D
  texture dimensions, texture array layers, and Metal threadgroup memory.
- Added `SamplerDescriptor.normalized_coordinates`; `false` lowers to native
  unnormalized-coordinate samplers on Vulkan and Metal under the portable
  constraint set.
- Added `TextureComponent`, `TextureComponentMapping`, and compatible
  linear/sRGB texture-view reinterpretation with native component swizzles.
- Added a finite common-format expansion covering 8-bit normalized/integer,
  16/32-bit floating-point, 32-bit integer, depth16, stencil8 textures, plus
  half, normalized 8-bit, and signed/unsigned 32-bit vertex inputs.
- Added capability-gated `BufferUsage.shader_device_address` and
  `Buffer.gpuAddress()` with native Metal/Vulkan address queries.
- Added capability-gated native Vulkan query pools and Metal visibility/counter
  query sets for occlusion, timestamp readback, and GPU resolve.
- Added default-null `RenderPassDescriptor.occlusion_query_set` so a pass can
  bind the exact visibility storage used by its occlusion commands.
- Added Metal vertex, fragment, and compute function-constant specialization by
  stable numeric ID.

### Changed

- Direct AS/RT encoding now rejects a second native encoding segment with
  `InvalidCommandBufferState`, and Vulkan RT dispatch owns descriptor/inline
  data per dispatch through completion. Texture RT output is restricted to a
  whole single-mip, single-layer view until Vulkan native layout tracking is
  per-subresource.
- `VKMTL_RT_FRAME_LIMIT` is now a strict positive finite-run contract: invalid
  configuration, early window closure, and a persistent zero-sized framebuffer
  fail explicitly instead of hanging or printing a false success marker.
- Vulkan texture RT dispatch now finishes in sampled-image layout for the
  fragment consumer, while Metal binds the caller's output texture directly.
  The shared fullscreen pass removes backend-dependent RT display conversion.
- Aligned the Metal window drawable with the existing portable window-pipeline
  convention by using `bgra8_unorm_srgb`; Metal format capabilities now report
  presentation only for that actual layer format, matching Vulkan's preferred
  surface format.
- Metal 4 argument-table and explicit-barrier effects are covered through the
  existing resource-table and synchronization compatibility layers. Distinct
  allocator/reusable-command/feedback, flexible-pipeline,
  compiler/archive/dataset, resource-view-pool, tensor/ML, pass-boundary and
  multi-counter/statistics, calibration, advanced-reflection, and function-log
  contracts are explicitly unsupported rather than exposed through a broad
  Metal 4 feature flag.
- External synchronization, native command insertion, Metal I/O/compression,
  and cross-device execution are explicitly unsupported where the current
  contracts cannot preserve their observable native semantics.
- Vulkan external resource imports remain typed unsupported until descriptors
  carry complete allocation/image/handle-consumption metadata.
- Basic RT/AS execution now reports through usable `Device.features()`;
  native-only Vulkan ray query, callable SBT, and Metal custom-intersection
  availability remains non-executable.
- Function/intersection tables, post-build compact-size query, inline ray-query
  execution, callable/complex SBT execution, motion/curve geometry, and Metal 4
  AS descriptors are explicitly unsupported under the current contracts.
- `examples/compute_readback` and `examples/transfer_readback` now use
  `HeadlessContext` and no longer initialize or link GLFW. Transfer readback
  also validates a texture-backed offscreen clear and copy.
- `tessellation` and `mesh_shaders` now report complete selected-backend
  execution paths. Metal tessellation and task/object artifacts remain
  explicitly closed; native-only task bits do not set usable `task_shaders`.
- Variable-rate maps, tile/imageblock memory, raster-order/programmed blend,
  layered amplification, logical attachment remapping, depth clip control, and
  programmable sample positions are explicitly unsupported under the current
  portable contracts.
- `argument_buffers`, `descriptor_indexing`, `driver_pipeline_cache`, and
  `metal_binary_archive` now report usable execution paths instead of
  planning-only availability.
- GPU-authored indirect-command mutation, parallel child render encoders,
  dynamic shader libraries, linked functions, and function stitching are
  explicitly unsupported under the current portable command/shader contracts.
- `DeviceFeatures.heaps` now means heap-backed buffers and textures execute;
  planning-only reservations no longer open the feature.
- Sparse/tiled resource and explicit residency-set execution remain closed:
  current mapping descriptors are planning records and do not identify native
  resource handles.
- `timeline_fences` and Metal `shared_events` now report only complete native
  object and submission paths; binary fence/event fallback remains runtime
  synchronization and is not reported as native.
- Queue descriptors now select physical backend queues where supported. Vulkan
  resources use safe concurrent family sharing while vkmtl preserves exclusive
  logical ownership validation.
- Buffer and texture creation now rejects descriptors that exceed the selected
  device's queried resource limits before native object creation.
- Private textures now reject CPU `replaceRegion` uploads consistently before
  backend access; use transfer commands for private storage.
- Occlusion query results default to portable Boolean visibility: zero means
  no samples passed and any nonzero value means visible. Callers may request
  `.counting` for an exact sample count when
  `occlusion_counting_queries` is reported.
- Timestamp query sets report `native_gpu` only when the selected backend has a
  complete native encoder path. Values remain backend-native ticks and do not
  claim duration conversion; logical fallback sets still report
  `logical_sequence`.
- Query slots may be written once between resets, and query resolve buffers must
  declare `copy_destination` usage.
- Managed CPU/GPU synchronization is automatic at map/read/write boundaries:
  Metal composes `didModifyRange` and `synchronizeResource`, while Vulkan uses
  host-coherent managed buffers.
- `dispatchThreads` is explicitly a ceil-divided threadgroup composition;
  shaders own bounds checks for final-group invocations outside the logical grid.

### Compatibility

- Period 55 adds one exact ray-tracing facade alias and one `CommandBuffer`
  method, targeting `v0.2.0`. The root, `Device`, context-owner, and runtime-
  handle sets are unchanged; `RayTracingDrawableResources` and
  `dispatchRaysToDrawable(...)` remain available with their legacy behavior.
- Period 52 adds one ray-tracing facade resource bundle, one `CommandBuffer`
  method, three `AccelerationStructure` evidence methods, and defaulted plan
  fields. These additive changes target `v0.2.0`; no root, `Device`,
  `WindowContext`, handle-name, or manifest-schema surface changes.
- `HeadlessContext` is an additive `v0.1.x` portable root API. All ten
  `WindowContext` methods and their behavior remain unchanged; the initial
  headless owner intentionally has no presentation-shaped native-handle view.
- Period 51 adds advanced shader/pipeline descriptors and facade operations,
  two render-encoder methods, mesh grid limits, shader-stage values, and
  manifest schema 2. `UnsupportedMeshShaderBindings` records a mesh pipeline
  layout that requests non-fragment visibility. These additive changes target
  `v0.2.0`; schema 1 and ordinary render defaults remain unchanged.
- Period 50 adds defaulted resource-table-layout and driver-cache pipeline
  fields, one command-domain runtime handle and factory, render/compute encoder
  methods, `indirect_command_buffers`, `max_indirect_command_count`, and typed
  command/layout errors. These additions target `v0.2.0`; ordinary pipeline
  defaults remain unchanged.
- Period 49 adds `.memoryless` to `ResourceStorageMode`,
  `memoryless_attachments` to `DeviceFeatures`, five specialized `Heap`
  methods, and memoryless/heap allocation errors. These additions target
  `v0.2.0`; existing resource defaults are unchanged.
- Period 48 adds nullable lifecycle fields to `CommandBufferDescriptor`,
  command/presentation types and feature fields, a descriptor-based present
  method, and synchronization/presentation errors. Defaults preserve existing
  immediate one-shot behavior; the public additions target `v0.2.0`.
- `RuntimeError.UnsupportedRenderPassAttachmentAction` targets `v0.2.0` and
  distinguishes current-drawable action limits from invalid attachments.
- `ShaderReflectionBinding.storage_access` defaults to the existing storage
  resource rules. `ShaderReflectionBindingAccessMismatch` targets `v0.2.0` for
  exhaustive `ShaderError` switches.
- The new `DeviceLimits` and sampler descriptor fields, plus
  `BufferLengthExceedsDeviceLimit`, `TextureExtentExceedsDeviceLimit`, and
  `InvalidUnnormalizedCoordinates`, target `v0.2.0`. Exhaustive public error
  switches need corresponding arms.
- `TextureViewDescriptor.component_mapping` defaults to identity. The new
  `UnsupportedTextureViewComponentMapping` error and resource-facade
  declarations target `v0.2.0`.
- New `TextureFormat` and `VertexFormat` tags target `v0.2.0`; downstream
  exhaustive enum switches must handle the expanded finite set.
- `DeviceFeatures.buffer_gpu_address`, `BufferUsage.shader_device_address`, the
  `Buffer.gpuAddress()` method, and the new buffer/texture errors target
  `v0.2.0`.
- This Unreleased change targets `v0.2.0`, not a `v0.1.x` patch, because the
  public `QueryError` expansion is source-breaking for exhaustive switches.
- The pass field defaults to null; the root, common owner methods, and opaque
  handle shapes are unchanged.
- `QueryBackendFailure` extends `QueryError` for newly executable native
  readback failures, which had no supported result in v0.1.0. Exhaustive
  downstream `QueryError` switches may need one new arm. Invalid pass/query
  association reuses the existing `InvalidRenderCommandEncoderState` error.

## [0.1.0]

This release establishes the first compatibility baseline for vkmtl.

### Added

- A backend-neutral Zig graphics API with interchangeable Vulkan and Metal
  backends.
- Canonical domain facades for resources, shaders, binding, render, compute,
  transfer, command, synchronization, presentation, ray tracing, interop,
  diagnostics, and explicit native access.
- Build-time Slang compilation to embedded SPIR-V, MSL, and reflection data,
  including a consumer-owned `shader_manifest` dependency option.
- Typed capability, limit, format-support, validation, and unsupported-feature
  reporting.
- API guard coverage for the exact public root, `Device`, `WindowContext`, and
  opaque runtime-handle baseline.
- Portable examples, backend validation plans, pixel regression, GPU soak, and
  release-readiness tooling.

### Changed

- Completed the intentional pre-release migration from the prototype flat API
  to canonical namespaces and runtime owners.
- Reduced the supported root to 68 declarations, `Device` to 34 public methods,
  and `WindowContext` to 10 public methods.
- Made the 35 public runtime handles opaque implementation boundaries with a
  single `_state` storage field.
- Moved backend-selected lowering and raw-handle operations under `native`.

### Compatibility

- The documented portable Zig source API is preserved throughout `v0.1.x`.
- Intentional breaking portable source changes require `v0.2.0` or later and
  migration guidance.
- The release does not promise a stable binary ABI, opaque `_state` layout, raw
  native-handle identity, or stable backend-native escape hatches.
- The supported toolchain for this line is Zig `0.16.0`.

[0.1.0]: https://github.com/HissingRat/vkmtl/releases/tag/v0.1.0
