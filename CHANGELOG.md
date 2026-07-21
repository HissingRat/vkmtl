# Changelog

All notable user-facing changes to vkmtl are recorded in this file.

vkmtl follows the release and compatibility policy in
[`docs/develop/public-api.md`](docs/develop/public-api.md). Because the
project is still in the `0.x` series, intentional portable source breaks are
reserved for the next minor release and are documented with migration guidance.

## [Unreleased]

### Fixed

- Fixed Vulkan `voxel_world` interactive startup returning
  `InvalidResourceBarrierState` before its first streamed chunk. The async
  no-TLAS frame skipped RT/PTGI production, leaving the new a-trous scratch
  images in Vulkan's undefined layout, but the terrain group previously tried
  to bind them after the sky draw had already started the HDR render pass. RT
  mode now defers terrain and water-lighting bindings until the first successful
  PTGI producer has initialized those sampled images. Raster mode is unchanged.
  A follow-up interactive Windows RTX rerun no longer reproduced the startup
  failure; a finite validation run with pixel metrics remains pending.
- Fixed bounded voxel PTGI rays treating incomplete or horizontal TLAS exits as
  unobstructed sky. Nonzero x/z bounds now enter frame data only after a TLAS
  contains the complete contiguous profile square; sparse bootstrap and moving
  subsets publish zero extent, so their diffuse misses cannot sample the
  environment. With complete bounds, environment radiance and the traced-edge
  mix both require proof that the path reaches the terrain top before crossing
  a horizontal boundary. Side exits no longer inject false sky light.
- Reduced interactive `voxel_world` chunk-loading stalls with one bounded
  background CPU meshing worker and exactly one outstanding job/result.
  Interactive rendering never waits for CPU mesh completion and publishes at
  most one completed chunk per frame; deterministic finite validation may wait
  for each worker result and publish two. Stream tickets discard stale
  completions, while a
  worker-spawn failure retains the synchronous fallback. GPU upload, BLAS, and
  TLAS work remains synchronous on the render thread under the existing 8 MiB
  upload budget. Ordinary TLAS additions coalesce for at most four frames;
  bootstrap, drain, and replacement rebuild immediately. An undrained finite
  run now prints `voxel_world_pressure_test=incomplete` and returns
  `VoxelWorldStreamingNotDrained` instead of reporting success.
- Fixed overly bright daytime voxel shadows in hybrid PTGI mode. The raster
  fallback keeps its full analytic sky environment, while the active PTGI path
  uses reconstructed RT indirect lighting as its primary environment
  contribution. Daytime ambient and hybrid raster/RT environment floors are
  reduced; direct sun, night ambient, water Fresnel, and the celestial glint
  remain unchanged.
- Fixed late Metal hybrid-RT visibility loss caused by declaring only the TLAS
  at compute dispatch. Each AS wrapper now owns the build and traversal state
  needed for later maintenance and dispatch. TLAS source/instance replacement
  is transactional and restores the previous state on failure; successful
  build/update publishes the replacement, while TLAS compact copy transfers
  the complete reusable state to its destination. Metal marks the bound TLAS
  and every indirectly referenced BLAS as read resources, while a dispatch
  missing retained dependencies returns a typed invalid-command error. Finite
  voxel runs validate visibility after pending work drains and repeat the
  readback on the final frame; a 300-frame Metal soak retains non-zero primary,
  shadowed, and sky-occluded counts.
- Fixed acceleration-structure sizing and many-source TLAS execution discovered
  by the hybrid voxel workload. Vulkan now allocates every declared instance
  and maps either one repeated or exactly N BLAS sources. Metal now sizes from
  the real selected/final descriptor, rechecks result and scratch capacity,
  dynamically owns source arrays, and rejects a reflected BLAS/TLAS pipeline
  kind mismatch before dispatch.
- Fixed ordinary Vulkan raster geometry appearing vertically inverted relative
  to Metal. vkmtl now lowers its positive, top-left public viewport to an
  adjusted negative-height Vulkan viewport, applies Metal winding/cull state
  natively, and checks asymmetric back-culled top/bottom pixels in the render
  regression.
- Fixed the shared `ray_traced_scene` fullscreen composition appearing
  vertically inverted on Vulkan. The presentation shader now derives 1:1 UVs
  from top-left fragment coordinates instead of interpolated clip-space Y, and
  the display readback regression uses asymmetric top and bottom rows.
- Fixed Vulkan acceleration-structure allocation on drivers whose native build
  size for ordinary, update, or compaction flags is larger than the combined
  update-plus-compaction query. vkmtl now reserves the component maximum across
  all four update/compaction combinations instead of assuming those query
  results are monotonic.

### Added

- Expanded the current `voxel_world` diffuse PTGI sample from one segment to a
  bounded path of at most three sequential cosine-weighted segments per covered
  opaque pixel. Every hit performs independent sun/moon next-event estimation,
  and the residual environment approximation is added only at a terminal
  configured hit. A miss evaluates the environment only after escaping above
  the published terrain/TLAS bounds, as described in the boundary fix above.
  The native pipeline retains recursion depth 1 because ray generation issues
  the traces sequentially. Water reflection remains a separate one-segment,
  unfiltered and undenoised specular path. Logs and the final pressure marker
  now report `ptgi_bounces=3`; `primary_rays` remains dispatch-thread count,
  not segment count. This is a clean-room experimental enhancement, not a claim
  that the default SEUS PTGI E12 reflection/diffuse chain uses three bounces.
  After the final TLAS-boundary tightening, 24-frame fixed-noon and
  fixed-midnight Metal API Validation smokes recorded
  `rt_ms_per_frame=10.767` and `11.248` with zero invalid pixels. The fixed-noon
  96-frame
  default lane drained 169 resident chunks with 22 TLAS builds, 96 dispatches,
  353,894,400 dispatch threads, `rt_ms_per_frame=16.327`, 2,404,265 primary
  hits, 863,410 directly lit, 1,540,855 shadowed, 1,932,365 indirect-lit,
  626,079 low-indirect, 2,404,258 reconstructed, 632,564 covered/lit reflection,
  297,535 penumbra, zero invalid pixels, and all markers true. Frame p50/p95/max
  were 24.081/28.004/442.164 ms; these are validation observations rather than
  portable performance gates.
- Increased the `voxel_world` default view radius from four to six chunks. The
  current smoke/default/stress grids are 3 x 3, 13 x 13, and 17 x 17, with
  9/169/289 maximum resident chunks. The canonical fixed-camera default
  validation lane is now 96 frames without autopilot so all 169 chunks can
  drain deterministically. Streaming metrics now report background versus
  synchronous fallback mode, submitted/completed/stale/failed mesh jobs, and
  cumulative mesh, stream-upload, and TLAS-build times.
- Added deterministic grassland trees and low-basin lakes to `voxel_world`.
  Tree roots and complete canopies require ordinary, low-slope grass
  footprints, so snow columns remain tree-free. Wood and opaque leaf atlas
  tiles participate in the same chunk meshing, BLAS/TLAS geometry, and packed
  material-column reconstruction as the terrain.
- Refined the example-private voxel lakes with separate opaque and water index
  ranges while retaining solid-water contact faces. Opaque terrain now renders
  into its own linear HDR target; a wave-normal and camera-distance water
  G-buffer drives screen-space refraction, RGB Beer-Lambert absorption and
  in-scattering in a separate full-coverage HDR water overlay. Hybrid RT traces
  one reflection ray from each visible water pixel against the opaque terrain
  TLAS; raster fallback uses the current sky reflection. The presentation pass
  composites the overlay before bloom and tone mapping. Water remains absent
  from chunk BLASes, so reflection cannot see water and ordinary PTGI rays can
  still reach the lake bed. This adds no public API or backend semantic. The
  bounded model cannot recover off-screen or hidden refraction data and does
  not implement nested/underwater media, caustics, multilayer transparency, or
  order-independent transparency. Fixed-camera finite RT runs now read back the
  reflection target and require nonzero covered/lit pixels with no invalid
  samples, reporting `rt_reflection_validated`; autopilot reports the same
  metrics without requiring visible water.
- Refined that lake surface through a clean-room, SEUS PTGI E12-inspired
  strategy without copying its source, constants, shader organization, or
  assets. Six world-continuous analytic wave bands now share one stabilized
  normal between raster shading and the water G-buffer. Depth- and
  screen-validity-aware refraction feeds a homogeneous single-scattering
  medium with absorption `(0.240, 0.062, 0.014)` and scattering `0.070`, so
  shallow water remains clear instead of receiving a painted blue tint while
  depth develops the intended blue-green attenuation. A dielectric `F0` of
  `0.02`, a narrow sun/moon glint, a 96-world-unit opaque-TLAS reflection ray,
  and directional day/night/twilight sky misses complete the surface response.
  This remains one unfiltered reflection sample per visible water pixel; foam,
  caustics, rain response, parallax water, temporal/reflection denoising,
  nested or underwater media, water-to-water reflection, and off-screen
  refraction recovery remain deliberately unimplemented.
- Added one optional application bind group to native ray-tracing pipelines.
  `ShaderVisibility.ray_tracing`,
  `RayTracingPipelineDescriptor.bind_group_layout`, and
  `RayTracingDrawableResources.bind_group` reuse the ordinary binding domain;
  the exact `RayTracingTextureResources` alias gains the same field. Bindings
  0/1/2 are reserved for acceleration structure, primary output, and inline
  data, while one application group may use 3 through 14 without dynamic
  offsets. Pipeline creation copies the layout; dispatch borrows the matching
  group and its resources through command-buffer completion.
- Added an example-private five-minute day/night presentation to `voxel_world`.
  One continuous 300-second clock maps 0/75/150/225/300 seconds to midnight,
  sunrise, noon, sunset, and wrapped midnight across the sky, raster terrain
  lighting, and hybrid-RT directional visibility. The sky displays opposite
  sun/moon directions, fades and twinkles stars, and retains the CPU 5x7
  bitmap-font UI. The upper-right FPS label remains visible under an
  ESC-toggled translucent title overlay; Escape pauses/resumes input instead
  of closing the window.
- Added a clean-room, E12-inspired analytic voxel atmosphere with a bright
  horizon, deep zenith, warm low-sun glow, and world-anchored lower
  self-shadowed cumulus plus upper stretched cirrus. The independent real-time
  cloud wind appears in raster sky and, on the hybrid path, RT miss/PTGI
  environment and hardware-RT water reflections. Raster water fallback keeps
  an analytic current-sky tint without procedural clouds or celestial disks.
  Smooth ground-hemisphere fading prevents bright downward RT misses, and RT
  cloud environment evaluation is deferred to actual misses or traced-edge
  blending. Strength-gated dense cumulus produces full day/twilight and
  restrained moonlight cloud shadows while keeping the sun/moon handoff at
  zero directional contribution. The celestial freeze does not stop clouds or
  the independent 64-second water loop. No E12 source, constants, shader
  organization, textures, or assets are copied. Weather/rain, volumetric cloud
  raymarching, cloud TAA, and a public atmosphere API remain out of scope.
- Replaced the voxel example's periodic terrain profile with deterministic
  fixed-point continentalness, erosion, ridge, detail, temperature, and
  moisture fields. Grass, sand, and snow surfaces remain continuous across
  positive and negative chunk boundaries while preserving bounded streaming.
- Updated voxel flight controls to WASD, Space/Shift vertical motion, and Ctrl
  acceleration.
- Upgraded `voxel_world` with a deterministic 748 x 68 sRGB atlas containing
  eleven face-specific high-detail grass/dirt/stone/sand/snow/wood/leaves/water
  tiles, replicated borders, and alpha-derived detail normals. Atlas mipmaps
  remain a documented follow-up.
- Added a capability-gated hardware-RT PTGI mode to `voxel_world`: indexed
  per-chunk triangle BLAS objects, a complete bounded 17 x 17 TLAS (up to 289
  instances), exact CPU-terrain material-column data plus atlas
  reads through the new RT bind group, full-resolution `rgba16_float`
  scene-linear radiance, separate direct sun/moon visibility, and one
  cosine-weighted indirect sample per pixel per frame. Temporal reprojection,
  rejection/clamping, and four edge-aware a-trous passes reconstruct the
  indirect result before composition; camera/light/source/resize discontinuities
  reset history, and the outer traced-neighborhood band fades to the current
  sky environment. `VKMTL_VOXEL_RT=auto|off|required`
  preserves automatic raster fallback and an exact required-native-RT lane.
- Added build-time Metal binding normalization from Slang target reflection so
  generated MSL buffer/texture/sampler indices match vkmtl's logical binding
  slots, including fixed resource arrays, instead of relying on target slot
  compaction.
- Added generic Vulkan bind-group texture transitions around compute dispatch
  and before render sampling, including storage-access masks, resource arrays,
  compute-write visibility, and delayed render-pass begin where a legal image
  barrier is required.
- Added an independently authored voxel presentation profile with fixed
  exposure, bloom, vignette, a filmic shoulder, output gamma, subtle
  saturation, sharpening, and dithering. SEUS PTGI E12 was used only as a
  visual-strategy reference; no
  source, shader organization, constants, or assets were copied, and no
  pixel-identical result is claimed.
- Added finite-run material-bound PTGI validation and bounded history/reset
  checks. Validation rejects NaN, infinity, and negative raw or reconstructed
  radiance and requires nonzero direct, shadowed, indirect, and reconstructed
  pixels. Metal executes the route physically under API Validation. Vulkan has
  focused tests, ordinary/forced builds, and shader compile validation only;
  physical Vulkan execution of this new route remains explicitly pending.
- Added `Swapchain.selectedFormat()` as the concrete presentation-owned query;
  `Swapchain.presentationDescriptor().format` continues to expose the original
  request.
- Added the example-only `VKMTL_PRESENTATION_FORMAT=automatic|srgb|linear`
  override so presentation selection and pixels can be reproduced without
  changing application code.
- Added a repeatable legacy drawable RT validation path to
  `ray_traced_scene`: set `VKMTL_RT_LEGACY_DRAWABLE=1` to dispatch into a
  caller-owned linear BGRA8 texture and exercise the compatibility raw copy.
- Added the exact `ray_tracing.RayTracingTextureResources` alias and
  `CommandBuffer.dispatchRaysToTexture(...)` for native Metal/Vulkan ray
  dispatch into caller-owned textures without drawable acquisition or
  presentation side effects.
- Added an explicit `ray_traced_scene` texture-presentation path: ray dispatch
  writes a caller-owned `rgba16_float` accumulation texture, while the shared
  fullscreen pass clamps the example's historical display-referred RGB and
  applies the sRGB EOTF before the final `bgra8_unorm_srgb` attachment restores
  the reference bytes through its OETF. Golden scalar samples
  `0.0/0.18/0.5/0.8/1.0` produce `0/46/128/204/255`.
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

### Fixed

- Fixed Windows Vulkan builds under Zig 0.16 by using a backend-private Win32
  loader for `vulkan-1.dll` instead of the unsupported Windows branch of
  `std.DynLib`. Missing loaders and required symbols still report
  `VulkanUnavailable`.
- Completed the non-Darwin Metal bridge stubs for mesh-pipeline creation and
  mesh-threadgroup draws so the full forced-Vulkan Windows install graph links.

### Changed

- The RT shader binding ABI now reserves 0 for the acceleration structure, 1
  for the primary output, and 2 for inline dispatch data.
  `RayDispatchDescriptor.inline_data_binding` therefore defaults to 2 and
  rejects another explicit value when inline data is present. Resource-free
  pipelines still omit both new nullable layout/group fields.
- Presentation format selection is now bounded and deterministic on both
  backends. `.automatic` prefers `bgra8_unorm_srgb`, then `bgra8_unorm`; either
  explicit SDR request must match exactly or returns
  `UnsupportedPresentationFormat`. Vulkan no longer selects an arbitrary first
  surface format, and Metal configures the layer from the concrete selection.
- Current-drawable pipelines must match `Swapchain.selectedFormat()` exactly;
  mismatches return `PresentationFormatMismatch` before native pipeline bind or
  draw. Windowed examples and quick-start code now build drawable pipelines
  from that selected format.
- `Swapchain.presentationDescriptor().extent` remains the request, while
  `Swapchain.extent()` now reports the actual native drawable extent. Healthy
  zero-size resize preserves the last successful request, actual extent, and
  selected format. Healthy same-request Vulkan resize remains a cheap no-op;
  present/acquire suboptimal or out-of-date state forces recovery, while a
  changed request with the same resolved native configuration avoids rebuild.
  Metal publishes a new drawable extent only after depth allocation succeeds.
- Vulkan rejects non-zero resize and clear while any backend command buffer is
  uncommitted. Clear records through a dedicated pool and never resets caller
  command pools. A failure after destructive recreation begins permanently
  loses presentation; later resize, clear, and new command-buffer creation
  return `SurfaceLost` instead of touching partially rebuilt resources.
- A failed runtime commit now terminalizes and deinitializes its backend command
  buffer, releases active-command/query borrows and work serial tracking, and
  reports lifecycle status `failed`. Vulkan waits any submitted queue before
  destroying command-buffer-owned temporary resources.
- Legacy `dispatchRaysToDrawable(...)` now uses the caller's whole,
  single-sample `bgra8_unorm` shader-write/copy-source output on both backends,
  then copies bytes unchanged to the selected linear or sRGB BGRA8 drawable.
  The compatibility path performs no HDR, tone mapping, transfer-function, or
  gamut conversion; texture dispatch plus explicit composition remains the
  canonical path.
  The legacy command presents implicitly, and an explicit duplicate present on
  the same command buffer returns `InvalidCommandBufferState`.
  The combined command requires a graphics queue. Metal preflights drawable
  availability, selected format/extent, and sRGB staging allocation before
  compute dispatch; the linear route allocates no staging buffer.
- Restored the established `ray_traced_scene` display values after the Metal
  drawable moved to `bgra8_unorm_srgb`: the shared pass now decodes the
  example's display-referred RGB before the attachment re-encodes it. A Metal
  GPU readback regression locks black, `0.18`, `0.5`, saturated yellow, and
  saturated blue within one byte of their reference BGRA8 values.
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

- The RT bind-group allocation targets `v0.2.0`. Its nullable fields are
  defaulted, and root/facade-name/owner-method/runtime-handle sets do not grow,
  but the released inline-data default changes from binding 1 to 2 and
  `BindingError` gains `ReservedRayTracingBinding` and
  `RayTracingPipelineLayoutMismatch`. Inline-data shaders and exhaustive error
  switches require the migration documented in `docs/develop/migration.md`;
  this complete change is not eligible for a `v0.1.x` patch.
- Period 56 adds one `Swapchain` method plus
  `UnsupportedPresentationFormat` and `PresentationFormatMismatch`, targeting
  `v0.2.0`. Root, `Device`, context-owner, `CommandBuffer`, and runtime-handle
  sets are unchanged. Exact explicit-request enforcement is also a `v0.2.0`
  semantic change. Actual-extent, resize/recovery, clear safety, failed-commit
  cleanup, and graphics-only legacy presentation meanings also target `v0.2.0`;
  no existing field, default, owner, method, or signature is removed or
  renamed.
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
