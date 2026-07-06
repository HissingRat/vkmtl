# Project API

vkmtl exposes backend-neutral descriptors and runtime wrappers through the
public `vkmtl` module. User code should not import `backend/vulkan`,
`backend/metal`, raw Vulkan bindings, or Metal bridge headers.

Windowed examples still use `WindowContext` to assemble backend selection,
surfaces, presentation, and shader-cache configuration. Starting in Period 2,
the long-term resource entry point is `Device`, and the long-term
command-buffer / submit entry point is `Queue`. `WindowContext` remains a
window convenience owner and forwards resource and command helpers to those
views.

## Backend Selection

Applications choose a backend with `BackendPreference`:

- `.auto`
- `.vulkan`
- `.metal`

The selected backend can be queried with `selectedBackend()` on contexts and
runtime resource wrappers.

## Surfaces And Presentation

Windowing integration stays outside the core API. Examples use the external
`zig_glfw` package plus `examples/common.zig` glue to convert a GLFW window into
public descriptors:

- `SurfaceDescriptor`
- `PresentationDescriptor`

For Vulkan, that glue also supplies a `VulkanSurfaceProvider` with the instance
extensions, proc-address lookup, and surface-creation callback required by the
backend. Examples pass the resulting descriptors to `WindowContext.init(...)`.

## Resources

Starting in Period 2, the long-term resource creation entry point is the runtime
`Device`. `WindowContext.device()` returns a device view for the current
context. Existing `WindowContext.make*` methods remain as compatibility
forwards.

- `makeBuffer(BufferDescriptor)`
- `makeTexture(TextureDescriptor)`
- `makeSamplerState(SamplerDescriptor)`

`Device` also exposes the first capability-query shape:

- `adapterInfo()`
- `features()`
- `limits()`
- `getFormatCaps(TextureFormat)`

Buffers created with CPU-visible storage can be updated with
`buffer.replaceBytes(...)` and read back with `buffer.readBytes(...)`. Textures
create views through `texture.makeTextureView(...)`, and upload helpers include
`texture.replaceRegion(...)` and `texture.replaceAll2D(...)`.

## Shaders And Pipelines

Slang is the source language. Applications usually embed `.slang` files and
compile them through `Device` at startup:

```zig
const source = @embedFile("shaders/glow.slang");
var device = context.device();
var compiled = try device.compileRenderShader("glow", source, .{
    .vertex_entry = "vs_main",
    .fragment_entry = "fs_main",
});
defer compiled.deinit();
```

The compiled handle chooses the correct cached artifact for the selected
backend:

```zig
const stages = compiled.stageDescriptors(context.selectedBackend());
```

Compute shaders use `compileComputeShader(...)` and
`CompiledComputeShader.stageDescriptor(...)`.

Runtime compilation writes SPIR-V, MSL, and reflection JSON into an automatically
managed shader cache. By default, the cache lives under `vkmtl-cache` beside the
executable. If callers set `WindowContextOptions.process_args = init.args`,
vkmtl automatically parses `--cache-dir <path>` or `--cache-dir=<path>`.
Application code does not need to parse that argument itself.

Precedence is: explicit `WindowContextOptions.shader_cache_dir` > `--cache-dir`
runtime argument > default `vkmtl-cache`.

Programmable stages can optionally attach reflection data with
`ProgrammableStageDescriptor.reflection`. Runtime pipeline creation validates
reflection artifacts or inline reflection data against the explicit
`bind_group_layouts` before creating backend pipelines. `ShaderReflection`
also exposes helpers that derive bind group layout descriptors from attached
stage reflection:

```zig
var layouts = try vkmtl.ShaderReflection.deriveRenderPipelineBindGroupLayouts(
    allocator,
    stages.vertex,
    stages.fragment,
);
defer layouts.deinit();
```

Reflection can also derive a single-buffer vertex descriptor from a vertex
stage's `vertex_inputs`; the caller still supplies stride because the current
reflection artifact records attribute layout but not host vertex struct size:

```zig
var vertex_descriptor = try vkmtl.ShaderReflection.deriveSingleBufferVertexDescriptor(
    allocator,
    stages.vertex,
    .{ .stride = @sizeOf(Vertex) },
);
defer vertex_descriptor.deinit();
```

## Bindings

Shader resource binding starts with public descriptors:

- `BindGroupLayoutDescriptor`
- `BindGroupDescriptor`
- `BindGroupLayout`
- `BindGroup`
- `ShaderVisibility`
- `BindingResourceKind`

The first resource classes are uniform buffers, storage buffers, storage
textures, sampled textures, and samplers. Runtime bind group creation validates
layout shape, resource class, backend match, whether referenced resources are
alive, and whether storage textures were created with `shader_write` usage.
Render and compute encoders expose `setBindGroup(...)` for debug-validated
command recording.

`BindGroupDescriptor` is the runtime descriptor that points at live resources.
For pure descriptor validation or tests, root exports also expose the shape-only
aliases `BindGroupResourceDescriptor`, `BindGroupEntryDescriptor`, and
`BindGroupDescriptorShape`.

Pipelines that use shader resources should include matching
`bind_group_layouts` in their render or compute pipeline descriptor. Those
layouts can be written manually or derived from reflection with
`ShaderReflection.deriveRenderPipelineBindGroupLayouts(...)` and
`ShaderReflection.deriveComputePipelineBindGroupLayouts(...)`. Vulkan uses the
layouts to build the native pipeline layout, allocate descriptor sets, write
descriptors, and bind them during command encoding.

If a stage supplies reflection data, vkmtl checks that the reflected bind group
indices, binding numbers, resource kinds, and shader visibility match those
pipeline layouts. The example suite attaches runtime-generated reflection
artifacts to every shader-backed pipeline. `zig build test` covers the runtime
reflection parser and the layouts used or derived by those examples.

Metal expands the same bind groups into explicit vertex, fragment, or compute
resource calls based on each layout entry's `ShaderVisibility`.

## Commands

Rendering uses Metal-like command names:

```zig
var queue = context.queue();
var command_buffer = try queue.makeCommandBuffer();
var encoder = try command_buffer.makeRenderCommandEncoder(render_pass);
try encoder.setRenderPipelineState(&pipeline);
try encoder.setVertexBuffer(&vertex_buffer, .{ .index = 0 });
try encoder.drawPrimitives(.{ .primitive_type = .triangle, .vertex_count = 3 });
try encoder.endEncoding();
try command_buffer.presentDrawable();
try command_buffer.commit();
```

Render passes can target the current drawable or an explicit texture view.
Texture-backed color attachments can also provide a single-sample
`resolve_target` when rendering from an MSAA texture.

Transfer work uses a Metal-style blit encoder:

```zig
var queue = context.queue();
var command_buffer = try queue.makeCommandBuffer();
var blit = try command_buffer.makeBlitCommandEncoder();
try blit.copyBufferToBuffer(&source, &destination, .{ .size = byte_count });
try blit.endEncoding();
try command_buffer.commit();
```

The first blit slice supports buffer-to-buffer, buffer-to-texture, and
texture-to-buffer copies.

Compute work uses a Metal-style compute encoder:

```zig
var queue = context.queue();
var command_buffer = try queue.makeCommandBuffer();
var compute = try command_buffer.makeComputeCommandEncoder();
try compute.setComputePipelineState(&pipeline);
try compute.setBindGroup(&bind_group, .{ .index = 0 });
try compute.dispatchThreadgroups(.{
    .threadgroup_count_x = 1,
    .threads_per_threadgroup_x = 4,
});
try compute.endEncoding();
try command_buffer.commit();
```

The first compute slice supports storage-buffer and storage-texture
write/readback validation.
