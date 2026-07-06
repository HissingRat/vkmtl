# vkmtl

`vkmtl` is an experimental Zig graphics library that will choose the best native
graphics backend for the current platform and expose one small abstraction layer
to applications.

The intended default backend selection is:

- Apple platforms: Metal
- Other desktop platforms: Vulkan

The repository now uses backend modules for Vulkan and Metal behind public
runtime wrappers. Examples live under `examples/` and use the vkmtl API instead
of calling Vulkan or Metal directly.

Shader authoring uses Slang. Applications embed Slang source and compile it
through `WindowContext` at runtime; vkmtl caches SPIR-V for Vulkan, MSL for
Metal, and reflection JSON that can validate or derive bind group layouts. The
public API should only expose vkmtl concepts, not raw Vulkan or Metal handles
except through explicit debug/native-handle escape hatches.

## Documentation

- [Docs index](docs/README.md): map of the documentation set.
- [Roadmap](docs/develop/roadmap.md): route and stage boundaries.
- [Checklist](docs/develop/checklist.md): checkable implementation and polish
  tasks.
- [Core API zh_CN](docs/api/zh_cn/core.md): current public API surface in
  Chinese.
- [Quick Start zh_CN](docs/usage/zh_cn/quick-start.md): current usage path in
  Chinese.
- [Core API en_US](docs/api/en_us/core.md): current public API surface in
  English.
- [Quick Start en_US](docs/usage/en_us/quick-start.md): current usage path in
  English.

## Examples

Examples belong under `examples/`.

Example code should not use raw Vulkan or Metal calls. If an example needs a
capability that is not exposed through vkmtl yet, add the missing abstraction
first or keep the example scoped to existing public API.

## Run Examples

```sh
zig build
zig build run-triangle
zig build run-sampled-texture
zig build run-rainbow-cube
zig build run-rainbow-cube -- --cache-dir /tmp/vkmtl-cache
```

On macOS, `.auto` selects Metal when available. Vulkan can be forced for
backend debugging:

```sh
zig build run-triangle -Dvulkan
```

See [Configuration zh_CN](docs/usage/zh_cn/configuration.md) or
[Configuration en_US](docs/usage/en_us/configuration.md) for backend overrides,
macOS Vulkan paths, Slang compiler selection, and vkmtl runtime arguments.

## References

- https://github.com/HissingRat/zig-glfw
- https://github.com/andrewrk/zig-vulkan-triangle
- https://github.com/Snektron/vulkan-zig
- https://www.glfw.org/
