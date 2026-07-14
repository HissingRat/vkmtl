# Configuration

vkmtl keeps backend selection and the build-time shader compiler explicit.
Examples expose the same knobs where possible.

## Preferences

`BackendPreference` controls selection:

- `.auto` lets vkmtl choose.
- `.vulkan` forces Vulkan and fails if Vulkan is unavailable.
- `.metal` forces Metal and fails if Metal is unavailable.

The selected backend is reported by `selectedBackend()`.

`AdapterSelectionDescriptor` can narrow selection further:

```zig
.adapter_selection = .{
    .backend = .metal,
    .name = "Apple M-series",
}
```

`backend` forces the backend used for adapter creation. `name` is validated
against the resolved runtime adapter name after backend initialization.

## Build-Time Override

`zig build ... -Dvulkan` forces `WindowContext` to request Vulkan, even if the
application passed `.auto` or `.metal`. This is a debugging/testing override for
the Vulkan backend path; it fails with `VulkanUnavailable` when Vulkan cannot be
created for the selected surface.

## Core Selection Rules

The pure selection logic in `core.selectBackend(...)` follows this order:

1. `adapter_selection.backend` forces that backend.
2. Explicit `.vulkan` or `.metal` preferences win when no adapter backend was
   specified.
3. Conflicting backend preference and adapter backend return
   `AdapterSelectionConflict`.
4. `debug_override` applies only when preference is `.auto`.
5. `.auto` prefers Metal on Apple platforms when Metal is available.
6. `.auto` prefers Vulkan elsewhere.
7. `.auto` may fall back to the other available backend.
8. If no backend is available, selection returns `NoSupportedBackend`.

Forced unavailable backends return `VulkanUnavailable` or `MetalUnavailable`.
An adapter name mismatch returns `AdapterNotFound` during `WindowContext.init`.

## Runtime Surface Availability

`WindowContext` narrows availability based on the surface descriptor:

- Vulkan is available when the surface descriptor carries a
  `VulkanSurfaceProvider`.
- Metal is available on Darwin only when the surface carries a compatible native
  Cocoa window/layer pointer.

The bundled examples get both from external `zig_glfw` through
`examples/common.zig`; vkmtl core does not import GLFW.

## Example Overrides

`examples/triangle` accepts a debug environment override:

```sh
VKMTL_BACKEND=vulkan zig build run-triangle
VKMTL_BACKEND=metal zig build run-triangle
zig build run-triangle -Dvulkan
```

`VKMTL_BACKEND` is example-level plumbing over `debug_backend_override`.
`-Dvulkan` is a build-time `WindowContext` override and wins over both
`VKMTL_BACKEND` and the requested `.auto` / `.metal` preference.

## macOS Vulkan Runtime

macOS Vulkan is intended for backend testing. Release builds on Apple platforms
should prefer Metal.

When forcing a Vulkan example run, pass the Vulkan loader directory and MoltenVK
ICD path explicitly:

```sh
zig build run-triangle -Dvulkan \
  -Dvulkan-loader-dir=/path/to/vulkan/lib \
  -Dvulkan-icd=/path/to/MoltenVK_icd.json
```

`-Dvulkan-loader-dir` should point to the directory containing
`libvulkan.1.dylib`, and `-Dvulkan-icd` should point to the MoltenVK ICD JSON.

## Slang Precompile

Default `zig build` prepares the pinned Slang distribution under
`.zig-cache/vkmtl-tools` on supported hosts and precompiles embedded shaders
listed by the current manifest. Runtime never launches `slangc`, and release
artifacts do not need to carry a Slang compiler or setup scripts.

External applications select a source-backed manifest through the dependency
option:

```zig
const vkmtl_dep = b.dependency("vkmtl", .{
    .target = target,
    .optimize = optimize,
    .shader_manifest = b.path("shaders/manifest.json"),
});
```

Schema version 1 contains `render_shaders`, `compute_shaders`, and
`ray_tracing_shaders`. Schema version 2 retains them and adds
`tessellation_shaders` and `mesh_shaders`; their entries declare `name`,
relative source paths, and stage-specific entry points. Shader names must be unique lowercase portable
`[a-z0-9_.-]+` filesystem components. The manifest must be source-backed;
generated manifests are not supported by either schema. Sources stay inside
the LazyPath owner's logical root. The manifest, every declared source, and
Slang include/import dependencies from compiler depfiles are tracked build
inputs.

If the consumer host has no pinned package, forward an explicit build-time
compiler path in the same dependency options:

```zig
const vkmtl_dep = b.dependency("vkmtl", .{
    .target = target,
    .optimize = optimize,
    .shader_manifest = b.path("shaders/manifest.json"),
    .slangc = "/path/to/build-time/slangc",
});
```

For a direct checkout build, use the command-line equivalent:

```sh
zig build run-rainbow-cube -Dslangc=/path/to/build-time/slangc
```

The complete schema fields are listed in
[Shader Authoring](../../api/en_us/shaders.md).

## Shader Artifacts

vkmtl does not manage a runtime shader artifact cache. `zig build`
precompiles embedded Slang source into embedded blobs, and runtime resolves
those blobs directly from memory. It does not create `vkmtl-cache` and does not
parse `--cache-dir`.

For debugging, build output includes inspectable artifacts:

```text
zig-out/shaders/<shader-name>/
```

These files are not required at runtime; copying only `zig-out/bin/<example>`
is enough for the matching precompiled shader.
