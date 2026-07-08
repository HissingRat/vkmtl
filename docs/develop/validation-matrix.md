# Validation Matrix

The authoritative validation case metadata lives in
`src/development_matrix.zig`.

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
  mismatches are reported before pipeline creation.
- `runtime_sync_objects`: fences and events expose deterministic signal, wait,
  reset, timeout, and unsupported-gate behavior.
- `logical_queue_ownership`: queue views and ownership transfers reject
  cross-queue use until an explicit ownership transfer is recorded.
- `query_readback`: timestamp and occlusion query sets validate availability,
  type, range, readback, and resolve paths before native work.
- `resource_utilities`: mipmap generation, fill fallback selection, texture
  copy compatibility, sampler border colors, heap planning, and transient
  diagnostics keep typed validation.
- `platform_interop`: surface registries, present-mode diagnostics, external
  memory/buffer/texture wrappers, external sync wrappers, and native insertion
  gates keep typed validation.
- `production_hardening`: cache planning, runtime diagnostics, capture names,
  stability planning, and Vulkan fallback diagnostics keep deterministic
  validation.
- `advanced_resource_geometry`: sparse/tiled resource planning, residency
  plans, tessellation lowering, and mesh/task lowering stay capability-gated.
- `ray_tracing_native_parity`: ray tracing planning, Metal mapping, native
  advanced closure, and future Period 29 assignments stay explicit.

The matrix is intentionally tied to unit-test names until backend CI can run
the same cases through native Vulkan and Metal devices.
