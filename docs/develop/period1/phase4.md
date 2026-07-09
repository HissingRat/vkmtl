# Phase 4 Decisions

These decisions start the shader and pipeline phase while preserving the
pluggable backend boundary.

## Current Status

Phase 4 defines public shader and render pipeline descriptors, shader
declaration/cache plumbing, runtime artifact loading, and backend pipeline
creation. The current implementation keeps the public `compile*Shader(...)`
declaration APIs, but shader artifacts are produced by build-time precompilation
and embedded into the executable.

The intended user flow is:

- embed Slang source in the application
- request matching precompiled shader artifacts through `WindowContext`
- describe vertex and fragment shader stages
- describe color targets and vertex input layout
- validate descriptor shape before backend-specific work begins

Completed so far:

- public `ShaderModuleDescriptor`
- public `ShaderSource` variants for Slang, SPIR-V words, MSL, and artifact
  paths
- public `ProgrammableStageDescriptor`
- public vertex input, primitive, cull/winding, color attachment, and
  `RenderPipelineDescriptor` types
- descriptor validation tests for shader source, stage matching, color targets,
  and vertex attribute layout
- runtime `WindowContext.compileRenderShader(...)` and
  `WindowContext.compileComputeShader(...)` plumbing
- shader module loading for explicit SPIR-V and MSL artifact paths
- backend shader module creation and render pipeline state creation for Vulkan
  and Metal

## Shader Tool Dependencies

Shader tools are build-time dependencies discovered by `build.zig` or explicit
user-provided paths.

Initial tool preference:

- `slangc` for Slang to SPIR-V
- `slangc` for Slang to MSL

vkmtl should not vendor this tool in release artifacts. Missing build-time
tools should produce clear build errors with the tool name, searched path, and
target artifact.

Default `zig build` prepares the pinned Slang distribution when the build host
has a known package. The resolver covers macOS, Linux, and Windows hosts for
the pinned release. Unknown build hosts fail unless the user passes an explicit
build-time tool path. `build.zig` owns package metadata and invokes setup
scripts from `scripts/`; the scripts own download, hash verification, and
extraction. Shader artifacts are produced by build-time precompilation and
embedded into the executable.

Tool overrides:

- `-Dslangc=/path/to/build-time/slangc`

Runtime shader declaration stages resolve embedded precompiled blobs from
memory, exposing SPIR-V for Vulkan, MSL for Metal, and per-stage reflection
JSON without writing shader artifacts to disk.

## Shader Artifact Layout

Build-time shader artifacts should stay inspectable.

Build output render shader artifact layout:

```text
zig-out/shaders/<shader-name>/
  vert.spv
  frag.spv
  vert.msl
  frag.msl
  vert.reflect.json
  frag.reflect.json
```

Compute shaders use `compute.spv`, `compute.msl`, and
`compute.reflect.json`.

Examples should keep source Slang next to the example:

```text
examples/triangle/shaders/triangle.slang
```

## Reflection Format

The first reflection format is JSON.

It should describe:

- stage and entry point
- vertex inputs
- bind groups, bindings, resource class, and shader visibility
- push constants when they are introduced

Manual descriptors are still allowed. Generated reflection can now validate
pipeline layout and binding declarations when a stage attaches its reflection
artifact.

## Slang Binding Rules

The first binding rule is:

- Slang explicit binding annotations map to vkmtl bind groups and binding
  indices.
- Texture, sampler, uniform/constant buffer, and storage declarations retain
  their resource class through reflection.

Phase 4 started with explicit descriptors and reflection stubs. Phase 6 added
the first reflection-assisted bind group layout validation slice.

## Example Layout

The first backend-independent pipeline example is `examples/triangle`.

Current layout:

```text
examples/
  common/
    window.zig
  triangle/
    main.zig
    shaders/
      triangle.slang
```

The old Vulkan-only prototype has been removed from the build mainline; shader
examples now live under `examples/` and use embedded Slang plus runtime cache
artifacts.
