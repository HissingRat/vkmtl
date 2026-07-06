# Phase 4 Decisions

These decisions start the shader and pipeline phase while preserving the
pluggable backend boundary.

## Current Status

Phase 4 defines public shader and render pipeline descriptors, runtime Slang
compilation/cache plumbing, runtime artifact loading, and backend pipeline
creation.

The intended user flow is:

- embed Slang source in the application
- compile Slang source through `WindowContext`
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
- runtime shader artifact loading for SPIR-V and MSL files
- backend shader module creation and render pipeline state creation for Vulkan
  and Metal

## Shader Tool Dependencies

Shader tools are external dependencies discovered by `build.zig` or explicit
user-provided paths.

Initial tool preference:

- `slangc` for Slang to SPIR-V
- `slangc` for Slang to MSL

vkmtl should not vendor this tool in this early phase. Missing tools should
produce clear build errors with the tool name, searched path, and target
artifact.

Default `zig build` prepares the pinned Slang distribution when the build host
has a known package. The resolver covers macOS, Linux, and Windows hosts for
the pinned release. Unknown hosts fall back to `slangc` on `PATH` unless the
user passes an explicit tool path. `build.zig` owns package metadata and invokes
setup scripts from `scripts/`; the scripts own download, hash verification, and
extraction. Shader artifacts are produced by runtime compilation.

Tool overrides:

- `-Dslangc=/path/to/slangc`

Runtime compilation stages embedded source Slang into the shader cache, emits
SPIR-V for Vulkan, emits MSL for Metal, and writes per-stage reflection JSON.

## Shader Artifact Layout

Runtime shader artifacts should stay inspectable.

Runtime render shader cache layout:

```text
<internal-cache-root>/<shader-name>/
  hash
  source.slang
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
