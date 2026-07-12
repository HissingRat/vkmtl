# Changelog

All notable user-facing changes to vkmtl are recorded in this file.

vkmtl follows the release and compatibility policy in
[`docs/develop/release-policy.md`](docs/develop/release-policy.md). Because the
project is still in the `0.x` series, intentional portable source breaks are
reserved for the next minor release and are documented with migration guidance.

## [Unreleased]

### Added

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
- Added capability-gated native Vulkan query pools and Metal visibility/counter
  query sets for occlusion, timestamp readback, and GPU resolve.
- Added default-null `RenderPassDescriptor.occlusion_query_set` so a pass can
  bind the exact visibility storage used by its occlusion commands.
- Added Metal vertex, fragment, and compute function-constant specialization by
  stable numeric ID.

### Changed

- Buffer and texture creation now rejects descriptors that exceed the selected
  device's queried resource limits before native object creation.
- Occlusion query results now have portable Boolean visibility semantics: zero
  means no samples passed and any nonzero value means visible; the magnitude is
  not a portable sample count.
- Timestamp query sets report `native_gpu` only when the selected backend has a
  complete native encoder path. Values remain backend-native ticks and do not
  claim duration conversion; logical fallback sets still report
  `logical_sequence`.
- Query slots may be written once between resets, and query resolve buffers must
  declare `copy_destination` usage.

### Compatibility

- The new `DeviceLimits` and sampler descriptor fields, plus
  `BufferLengthExceedsDeviceLimit`, `TextureExtentExceedsDeviceLimit`, and
  `InvalidUnnormalizedCoordinates`, target `v0.2.0`. Exhaustive public error
  switches need corresponding arms.
- `TextureViewDescriptor.component_mapping` defaults to identity. The new
  `UnsupportedTextureViewComponentMapping` error and resource-facade
  declarations target `v0.2.0`.
- New `TextureFormat` and `VertexFormat` tags target `v0.2.0`; downstream
  exhaustive enum switches must handle the expanded finite set.
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
