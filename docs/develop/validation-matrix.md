# Validation Matrix

The authoritative validation case metadata lives in
`tools/development_matrix.zig`.

Current cases:

- `invalid_bind_group`: layout entry mismatch, missing/extra entries, duplicate
  entries, and resource kind mismatch.
- `invalid_texture_format`: automatic or unsupported texture formats fail
  before backend creation.
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
  independent capability gates, and explicit immediate fallback.
- `query_readback`: timestamp and occlusion query sets validate bound-pass
  identity, availability, type/range, one write per reset, resolve-buffer
  usage, backend failures, and readback/resolve agreement. Physical smoke also
  verifies visible/nonzero, empty/zero, and reset/reuse behavior.
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
  interop capability matrices, memory/buffer/texture wrappers, external sync
  wrappers, and native insertion gates keep typed validation.
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
- `ray_tracing_native_parity`: ray tracing planning, Metal mapping, native
  advanced closure, and future Period 29 assignments stay explicit.
- `ray_tracing_completeness`: AS maintenance, many-instance TLAS metadata, ray
  query support, complex SBT layout, callable records, and RT stress plans stay
  capability-gated and deterministic.
- `period44_device_evidence`: hosted builds, physical smoke, exact/tolerant
  pixel readback, bounded soak, and release evidence gates remain distinct;
  all nine explicit release gates are observed, while physical Linux GPU and
  advanced-native pressure lanes remain outside the claim.

Unit-test metadata remains authoritative for portable validation. Period 44
adds separate physical GPU evidence workflows so source/build coverage is not
confused with executed Metal/Vulkan behavior.
