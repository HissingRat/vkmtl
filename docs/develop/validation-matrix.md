# Validation Matrix

The authoritative validation case metadata lives in
`tools/development_matrix.zig`.

Current cases:

- `invalid_bind_group`: layout entry mismatch, missing/extra entries, duplicate
  entries, and resource kind mismatch.
- `invalid_texture_format`: automatic or unsupported ordinary texture formats
  fail before backend creation; presentation requests admit only automatic and
  the bounded linear/sRGB BGRA8 pair.
- `invalid_barrier`: redundant or mismatched explicit barriers report command
  encoding errors.
- `resource_destroyed_while_in_use`: resource tracker defers retirements until
  submitted work completes. This still needs backend integration coverage.
- `unsupported_feature`: feature-gated APIs return typed unsupported errors.
- `shader_reflection_mismatch`: reflection layout, kind, visibility, and stage
  mismatches are reported before pipeline creation; fixed array count and
  storage-access mismatches are also preserved and rejected.
- `runtime_sync_objects`: binary fences/events retain deterministic fallback;
  timeline/shared-event objects additionally cover monotonic host operations,
  native submit waits/signals, timeout, same-device, borrow, and unsupported
  behavior.
- `logical_queue_ownership`: queue planning, physical queue views, and
  ownership transfers reject cross-queue use until an explicit ownership
  transfer is recorded; resource sharing does not weaken logical ownership.
- `command_lifecycle_and_presentation`: lifecycle callbacks report scheduled
  then completed exactly once, and timed presentation validates nonzero timing,
  independent capability gates, and explicit immediate fallback. Failed commit
  terminally deinitializes backend state, releases active/query borrows and work
  serials, reports failed lifecycle, and makes Vulkan wait submitted work before
  temporary-resource destruction.
- `query_readback`: timestamp and occlusion query sets validate bound-pass
  identity, availability, type/range, one write per reset, resolve-buffer
  usage, backend failures, Boolean/counting feature gates, and readback/resolve
  agreement. Physical Metal smoke verifies exact visible sample counts,
  empty/zero, and reset/reuse behavior; Vulkan precise mode has feature-enable
  and command-flag unit/forced-build coverage.
- `debug_marker_contract`: borrowed object-label and call-only marker lifetime,
  UTF-8/NUL validation, exact capture names, stack balance, and
  command-buffer/encoder marker scope remain deterministic before native work;
  backend marker capabilities, capture gates, logical/native timestamp sources,
  uncalibrated-duration reporting, profiling fallback, and issue-report
  snapshots stay truthful.
- `resource_utilities`: mipmap generation, fill fallback selection, texture
  copy compatibility, backend alignment, mip/layer/3D-slice ranges,
  depth/stencil aspects, scaled blit gates, MSAA resolve/copy behavior,
  per-subresource state transitions, sampler border colors, native heap
  requirements/placement/lifetime, heap aliasing, native/fallback
  memory-pressure reports, memoryless attachment rules, transient diagnostics, compute
  dispatch/barrier/atomic/threadgroup-memory validation, and automatic managed
  readback keep typed validation.
- `platform_interop`: surface registries, present-mode diagnostics, external
  interop capability matrices, memory/buffer/texture wrappers, Metal raw
  buffer/texture and IOSurface imports, device topology, external sync wrappers,
  and native insertion gates keep typed validation. `run-external-import` adds
  deterministic physical Metal readback without upgrading Vulkan import or
  external synchronization claims.
- `production_hardening`: cache planning, runtime diagnostics, capture names,
  stability planning, and Vulkan fallback diagnostics keep deterministic
  validation.
- `resource_table_pipeline_persistence`: native resource-table layout/update/bind
  paths, active-pipeline compatibility, reusable indirect slots/ranges,
  pipeline artifact compatibility, stale cache identity, and read-only native
  persistence behavior remain deterministic.
- `advanced_resource_geometry`: sparse/tiled resource planning and residency
  commit/churn plans remain distinct from typed-unsupported execution;
  tessellation draw planning and mesh/task dispatch planning stay
  capability-gated.
- `ray_tracing_native_parity`: basic ray tracing, executable AS maintenance,
  Metal AABB/multi-source TLAS input, native-only availability, and planning
  records remain distinct. Period 55 additionally validates caller-owned RT
  output usage/whole-texture shape/extent, per-dispatch Vulkan descriptor
  ownership, the one-native-segment command rule, strict finite-run failure
  states, and CPU/GPU reference-preserving `0/0.18/0.5/0.8/1.0` to
  `0/46/128/204/255` golden values. The executable command writes the generic
  caller-owned accumulation output and establishes the storage-write-to-sampled
  postcondition;
  `ray_traced_scene` separately applies the sRGB EOTF before the
  `bgra8_unorm_srgb` attachment performs the matching encode. Tone mapping is
  application policy. Metal has a three-frame API Validation run and an
  offscreen shared-display readback with a maximum one-byte channel delta; the
  shared-display Vulkan path now submits and completes physically; its first
  screenshot exposed a vertical composition flip, and the corrected
  fragment-position UV path subsequently completed 3000 frames with the
  accepted orientation.
  Period 56 additionally locks request-versus-selected presentation state,
  deterministic and exact SDR selection, selected-only presentation
  capabilities, requested-versus-actual extent, same-request/recovery resize,
  clear/resize active-command gates, clear-pool isolation, terminal lifecycle
  decisions, current-drawable pipeline mismatch before native bind/draw, and
  graphics-only legacy caller-owned linear BGRA8 usage/shape/extent/raw-copy,
  plus duplicate-present validation. Implementation inspection covers Metal
  resize publication and pre-dispatch preflight ordering plus Vulkan
  present-queue retirement before swapchain teardown; physical Metal API
  Validation covers the Metal success paths. The resolver
  and copy perform no HDR, tone-map, gamma, or gamut conversion.
  Physical Metal validation covers automatic/sRGB/linear deterministic
  offscreen pixels plus actual selected-drawable bind/present smoke and
  three-frame sRGB/linear legacy raw-copy runs with
  `trace_driver_submitted=true`. Vulkan canonical and legacy routes both submit
  and complete; legacy visual orientation passes, while the corrected canonical
  route completed 3000 frames with the same top-left orientation. The supplied
  Vulkan stderr does not positively prove that the validation layer was
  enabled. The updated asymmetric 5x2 physical Vulkan pixel readback remains a
  separate required release-matrix artifact.
- `ray_tracing_completeness`: update/refit/compact resources, many-instance
  TLAS validation, native ray-query discovery, planning-only complex/callable
  SBT records, and RT stress plans stay capability-gated and deterministic.
  `run-ray-tracing-maintenance` adds headless physical build/update/refit/
  compact/AABB/multi-source evidence without implying unsupported function
  tables or ray-query execution.
- `period44_device_evidence`: hosted builds, physical smoke, exact/tolerant
  pixel readback, bounded soak, and release evidence gates remain distinct;
  all nine explicit release gates are observed, while physical Linux GPU and
  advanced-native pressure lanes remain outside the claim.
- `voxel_world_pressure_test`: mesher and camera unit tests cover the bounded
  CPU contract; shader precompile/reflection covers the common 32-byte vertex
  stream and uniform/atlas/sampler layout; finite smoke/default/stress runs
  validate 9/81/289 resident limits, two rebuilds and 8 MiB of uploads per
  frame, streaming metrics, and `voxel_world_pressure_test=ok`. Metal API
  Validation execution is physically observed on an Apple M4 Pro. Vulkan has
  artifact and forced-build coverage, but no physical voxel execution is
  claimed.

Unit-test metadata remains authoritative for portable validation. Period 44
adds separate physical GPU evidence workflows so source/build coverage is not
confused with executed Metal/Vulkan behavior. Period 19 follows that same
boundary for the voxel workload: only the Metal execution is currently
observed.
