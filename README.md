# vkmtl

`vkmtl` is an experimental Zig graphics library that chooses the best native
graphics backend for the current platform and exposes one small abstraction
layer to applications. Version `0.1.0` establishes the first portable source
compatibility baseline.

The intended default backend selection is:

- Apple platforms: Metal
- Other desktop platforms: Vulkan

The repository now uses backend modules for Vulkan and Metal behind public
runtime wrappers. Examples live under `examples/` and use the vkmtl API instead
of calling Vulkan or Metal directly.

Shader authoring uses Slang. Applications embed Slang source and declare shader
usage through `Device`; `zig build` precompiles matching SPIR-V, MSL, and
reflection JSON into the executable. Runtime consumes those embedded blobs
directly from memory; inspectable build artifacts are installed under
`zig-out/shaders`. The public API should only expose vkmtl concepts, not raw
Vulkan or Metal handles except through explicit debug/native-handle escape
hatches.

## Documentation

- [Docs index](docs/README.md): map of the documentation set.
- [Release policy](docs/develop/release-policy.md): `v0.1.x` compatibility,
  package, toolchain, capability, and release-gate contract.
- [Changelog](CHANGELOG.md): user-visible release history.
- [Roadmap](docs/develop/roadmap.md): route and stage boundaries.
- [Checklist](docs/develop/checklist.md): checkable implementation and polish
  tasks.
- [API migration guide](docs/develop/api-migration-guide.md): updating callers
  from the prototype surface to the final pre-tag namespaces and owners.
- [Core API zh_CN](docs/api/zh_cn/core.md): current public API surface in
  Chinese.
- [Features and limits zh_CN](docs/api/zh_cn/features-and-limits.md): capability
  and limit interpretation in Chinese.
- [Quick Start zh_CN](docs/usage/zh_cn/quick-start.md): current usage path in
  Chinese.
- [Diagnostics zh_CN](docs/usage/zh_cn/diagnostics.md): capture, profiling, and
  issue-report guidance in Chinese.
- [Validation zh_CN](docs/usage/zh_cn/validation.md): Vulkan and Metal native
  API validation setup in Chinese.
- [Core API en_US](docs/api/en_us/core.md): current public API surface in
  English.
- [Features and limits en_US](docs/api/en_us/features-and-limits.md): capability
  and limit interpretation in English.
- [Quick Start en_US](docs/usage/en_us/quick-start.md): current usage path in
  English.
- [Diagnostics en_US](docs/usage/en_us/diagnostics.md): capture, profiling, and
  issue-report guidance in English.
- [Validation en_US](docs/usage/en_us/validation.md): Vulkan and Metal native
  API validation setup in English.
- [Current parity report](docs/develop/period44/parity-report.md): observed,
  configured, and missing backend/device evidence.

## Package And Compatibility

`v0.1.x` preserves the documented portable Zig source API. Intentional
portable source breaks require `v0.2.0` or later and migration guidance. This
promise does not include a stable binary ABI, the layout of opaque `_state`
storage, raw native-handle values, or backend-native escape hatches. The
supported toolchain for this line is Zig `0.16.0`.

The package exports one supported module named `vkmtl`. Applications that use
runtime shader declarations provide a consumer-owned build-time shader
manifest:

```zig
const vkmtl_dep = b.dependency("vkmtl", .{
    .target = target,
    .optimize = optimize,
    .shader_manifest = b.path("shaders/manifest.json"),
});

exe.root_module.addImport("vkmtl", vkmtl_dep.module("vkmtl"));
```

The schema-version-1 manifest has `render_shaders`, `compute_shaders`, and
`ray_tracing_shaders` arrays. It must be a source-backed LazyPath; shader source
paths are relative to it and stay inside its logical package root. The
dependency tracks those sources plus Slang include/import depfiles and embeds
their SPIR-V, MSL, and reflection blobs; runtime code does not launch `slangc`
or write a shader cache. See the
[compatibility notes](docs/usage/en_us/compatibility.md) for the manifest
contract.

Feature availability remains capability-driven: query the selected device
rather than inferring support from its platform. Planning-only or
typed-unsupported paths are not executable feature claims.

## Examples

Examples belong under `examples/`.

Example code should not use raw Vulkan or Metal calls. If an example needs a
capability that is not exposed through vkmtl yet, add the missing abstraction
first or keep the example scoped to existing public API.

## Run Examples

```sh
zig build
zig build run-api-guard
zig build run-triangle
zig build run-offscreen-texture
zig build run-rainbow-cube
zig build run-compute-readback
zig build run-capability-dump
zig build run-profiling-plan
zig build run-validation-plan
zig build run-pixel-regression
zig build run-gpu-soak -- --iterations=120
zig build run-release-readiness
```

On macOS, `.auto` selects Metal when available. Vulkan can be forced for
backend debugging:

```sh
zig build run-triangle -Dvulkan
```

See [Configuration zh_CN](docs/usage/zh_cn/configuration.md) or
[Configuration en_US](docs/usage/en_us/configuration.md) for backend overrides,
macOS Vulkan paths, and Slang precompile setup.

## References

- https://github.com/HissingRat/zig-glfw
- https://github.com/andrewrk/zig-vulkan-triangle
- https://github.com/Snektron/vulkan-zig
- https://www.glfw.org/
