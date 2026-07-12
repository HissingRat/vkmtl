# Changelog

All notable user-facing changes to vkmtl are recorded in this file.

vkmtl follows the release and compatibility policy in
[`docs/develop/release-policy.md`](docs/develop/release-policy.md). Because the
project is still in the `0.x` series, intentional portable source breaks are
reserved for the next minor release and are documented with migration guidance.

## [Unreleased]

### Fixed

- Stopped advertising `occlusion_queries` as usable while both backends still
  lack native GPU visibility-result lowering. Native availability remains
  separately queryable, and query creation now returns the existing typed
  unsupported error.

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
