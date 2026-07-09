# Shader Authoring

Slang is the only shader source language for vkmtl.

## Source Layout

Example shaders live next to their example:

```text
examples/triangle/shaders/triangle.slang
examples/offscreen_texture/shaders/offscreen_texture.slang
examples/msaa_triangle/shaders/msaa_triangle.slang
examples/rainbow_cube/shaders/rainbow_cube.slang
examples/compute_readback/shaders/compute_readback.slang
```

Examples embed those `.slang` files and declare the required shaders through
`Device`. `zig build` precompiles matching SPIR-V, MSL, and reflection JSON
into the executable. Runtime resolves those embedded blobs directly from
memory and does not write shader artifacts to disk. Build-time artifacts are
also installed for inspection under `zig-out/shaders`:

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
`compute.reflect.json`. The source hash is stored in embedded blob metadata. If
no blob matches the name, entry points, and source hash, vkmtl returns
`PrecompiledShaderMissing`.

## Build Commands

Default `zig build` prepares the pinned Slang distribution, currently
`v2026.12.2`, under `.zig-cache/vkmtl-tools`, and precompiles embedded shaders
listed by the current manifest.

The pinned Slang version and release package hashes live in `build.zig`; the
download, verification, and extraction commands live under `scripts/`. Auto
download currently covers macOS, Linux, and Windows packages for supported host
architectures. If the build host has no pinned package, the build fails; pass an
explicit build-time compiler path when needed:

```sh
zig build run-rainbow-cube -Dslangc=/path/to/build-time/slangc
```

Runtime does not need a shader cache directory and does not parse
`--cache-dir`. Inspect compiled shader artifacts in
`zig-out/shaders/<shader-name>/` when needed.

## Triangle Shape

The first supported shader shape is conservative:

- vertex and fragment stages
- compute stage for Phase 8 storage-buffer and storage-texture readback
- explicit `[shader("vertex")]` / `[shader("fragment")]` entry point attributes
- explicit `[shader("compute")]` and `[numthreads(...)]` for compute entry
  points
- explicit vertex input semantics
- generated SPIR-V for Vulkan
- generated MSL for Metal

Current entry points:

```text
vs_main
fs_main
cs_main
```

## Runtime Consumption

Applications embed Slang source and ask `Device` to resolve the matching
precompiled shader:

```zig
const shader_source = @embedFile("shaders/glow.slang");

var device = context.device();
var compiled = try device.compileRenderShader("glow", shader_source, .{
    .vertex_entry = "vs_main",
    .fragment_entry = "fs_main",
});
defer compiled.deinit();

const stages = compiled.stageDescriptors(context.selectedBackend());
```

Compute shaders use the compute-specific entry point:

```zig
const source = @embedFile("shaders/compute.slang");

var device = context.device();
var compiled = try device.compileComputeShader("compute", source, .{
    .entry = "cs_main",
});
defer compiled.deinit();

const compute_stage = compiled.stageDescriptor(context.selectedBackend());
```

The compiler prints `using precompiled slang shader: <name>` when the embedded
blob matches.

## Binding Rules

Phase 6 starts the binding model with bind group layout descriptors and bind
group descriptors. Slang resource declarations should use explicit group and
binding annotations so reflection can derive and validate these layouts.

The intended mapping is:

- Slang group -> vkmtl bind group index
- Slang binding -> `BindGroupLayoutEntry.binding`
- Slang resource class -> `BindingResourceKind`
- Slang stage usage -> `ShaderVisibility`

The first sampled texture example uses binding 0 for the texture and binding 1
for the sampler:

```text
Texture2D<float4> color_texture : register(t0, space0);
SamplerState color_sampler : register(s1, space0);
```

The offscreen texture example keeps the same binding convention for its screen
pass while using separate Slang entry points for the offscreen and current
drawable passes:

```text
offscreen_vs
offscreen_fs
screen_vs
screen_fs
```

The MSAA triangle example uses the same two-pass shape, but the first pass runs
with a 4x multisample render pipeline:

```text
msaa_vs
msaa_fs
screen_vs
screen_fs
```

The rainbow cube example uses one uniform buffer, one sampled texture, and one
sampler in group 0:

```text
ConstantBuffer<Uniforms> uniforms : register(b0, space0);
Texture2D<float4> rainbow_texture : register(t1, space0);
SamplerState rainbow_sampler : register(s2, space0);
```

The compute readback example uses one writable storage texture and one writable
storage buffer in group 0:

```text
[[vk::binding(0, 0)]]
[[vk::image_format("rgba8")]]
RWTexture2D<float4> output_texture : register(u0, space0);

[[vk::binding(1, 0)]]
RWStructuredBuffer<uint> output_values : register(u1, space0);
```

Storage textures require an explicit Vulkan image format annotation so Slang
can emit a storage image format for SPIR-V. The current example uses binding 0
for the storage texture and binding 1 for the storage buffer because Slang's
Metal output places the texture at `texture(0)` and the buffer at `buffer(1)`.

Compiled shader handles attach runtime-generated reflection JSON to each
programmable stage:

```zig
const stages = compiled.stageDescriptors(context.selectedBackend());
```

vkmtl checks stage, entry point, bind group index, binding number, resource
kind, and shader visibility against the `bind_group_layouts` supplied to the
pipeline descriptor. Reflection can also derive the bind group layout
descriptors before pipeline creation:

```zig
var layouts = try vkmtl.ShaderReflection.deriveComputePipelineBindGroupLayouts(
    allocator,
    compute_stage,
);
defer layouts.deinit();
```

Vertex-stage reflection includes `vertex_inputs` with location, format, and
offset. The first helper can derive a single-buffer `VertexDescriptor`; callers
provide the stride explicitly:

```zig
var vertex_descriptor = try vkmtl.ShaderReflection.deriveSingleBufferVertexDescriptor(
    allocator,
    stages.vertex,
    .{ .stride = @sizeOf(Vertex) },
);
defer vertex_descriptor.deinit();
```

All shader-backed examples attach runtime-generated reflection artifacts.
Shader-resource examples use reflection to derive their bind group layout
descriptors before backend pipeline creation. Single-buffer rendering examples
derive their vertex descriptors from reflection. `zig build test` covers the
runtime reflection parser and reflection derivation helpers.

See `docs/develop/period1/phase6.md` for the binding-model decision notes.
