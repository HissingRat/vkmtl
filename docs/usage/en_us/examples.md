# vkmtl Examples

Examples are public API consumers. They live under `examples/` and should not
import backend-private modules such as `src/backend/vulkan`,
`src/backend/metal`, raw Vulkan bindings, or Metal bridge headers.

Examples may import:

- the public `vkmtl` module
- external windowing packages such as `zig_glfw`
- shared example-only glue such as `vkmtl_examples_common`
- assets and shaders that belong to the example

If an example needs a backend feature that is not public yet, add the public
vkmtl API first instead of reaching into a backend implementation.

The current gallery metadata is tracked in `src/development_matrix.zig` so
tests can keep names, paths, run steps, deterministic output markers, and
backend expectations in sync with this document.

Shader-backed examples embed their Slang source with `@embedFile(...)`, compile
it through `Device.compileRenderShader(...)` or
`Device.compileComputeShader(...)`, and attach runtime-generated reflection JSON
to pipeline stages. Single-buffer rendering examples derive their vertex
descriptors from reflection. Shader-resource examples also derive bind group
layouts from reflection.

vkmtl manages the runtime shader artifact cache automatically. Examples pass
process arguments to `WindowContext`, so users can pass vkmtl runtime arguments
directly while example code does not parse them:

```sh
zig build run-rainbow-cube -- --cache-dir /tmp/vkmtl-cache
```

## Triangle

`examples/triangle` is the first backend-independent rendering sample. It
creates a GLFW surface, requests `.auto` backend selection, uploads vertex data
through `Device.makeBuffer`, creates a render pipeline through
`Device.makeRenderPipelineState`, handles drawable resize through
`Swapchain.resize(...)`, records commands with `CommandBuffer` /
`RenderCommandEncoder`, and presents through the public command API.

Run it with:

```sh
zig build run-triangle
```

On Apple platforms `.auto` selects Metal when available. For backend debugging,
the example accepts:

```sh
zig build run-triangle -Dvulkan
VKMTL_BACKEND=vulkan zig build run-triangle
VKMTL_BACKEND=metal zig build run-triangle
```

The example embeds `examples/triangle/shaders/triangle.slang`, compiles it at
runtime, and uses the cached SPIR-V/MSL/reflection artifacts through public
stage descriptors.

## Clear Screen

`examples/clear_screen` is the presentation smoke test. It should stay small and
focused on surface creation, resize, clear, and present behavior.

Run it with:

```sh
zig build run-clear-screen
```

## Uniform Buffer

`examples/uniform_buffer` is the first shader-resource binding sample. It
creates a uniform buffer through `Device.makeBuffer`, wraps it in a bind
group, derives the matching bind group layout from shader reflection, and
records `setBindGroup(...)` before drawing.

Run it with:

```sh
zig build run-uniform-buffer
```

The example embeds its Slang source beside the example at:

```text
examples/uniform_buffer/shaders/uniform_buffer.slang
```

## Sampled Texture

`examples/sampled_texture` is the first visible texture binding sample. It
uploads a small RGBA texture with `texture.replaceAll2D(...)`, creates a texture
view and sampler, binds both through a bind group, and draws an indexed quad
through the public command API.

Run it with:

```sh
zig build run-sampled-texture
```

The render pipeline attaches runtime-generated reflection JSON and derives both
the single-buffer vertex descriptor and the sampled texture/sampler bind group
layout from it before backend pipeline creation.

The Slang source lives beside the example:

```text
examples/sampled_texture/shaders/sampled_texture.slang
```

## Depth Triangles

`examples/depth_triangles` is the first depth-tested rendering sample. It draws
two overlapping triangles through the public command API, with the nearer
triangle submitted before the farther triangle so depth testing is visible.

Run it with:

```sh
zig build run-depth-triangles
```

The pipeline enables:

```zig
.depth_stencil = .{
    .format = .depth32_float,
    .depth_compare_function = .less_equal,
    .depth_write_enabled = true,
},
```

The render pass requests the current-drawable depth attachment:

```zig
.depth_attachment = .{
    .clear_depth = 1.0,
},
```

The Slang source lives beside the example:

```text
examples/depth_triangles/shaders/depth_triangles.slang
```

## Offscreen Texture

`examples/offscreen_texture` is the first explicit render-target sample. It
renders a colored triangle into a texture-backed color attachment, then samples
that texture onto an indexed quad in the current drawable.

Run it with:

```sh
zig build run-offscreen-texture
```

The offscreen texture is created through the public resource API with both
`.render_attachment` and `.shader_read` usage, viewed with
`makeTextureView(...)`, then passed into the render pass as:

```zig
.color_attachments = &.{.{
    .target = .{ .texture_view = &offscreen_view },
    .clear_color = .{ .red = 0.02, .green = 0.025, .blue = 0.035, .alpha = 1.0 },
}},
```

The screen pass binds the same texture view and a sampler through a public bind
group whose layout is derived from shader reflection. The example intentionally
uses two command buffers for now: one for the offscreen pass and one for the
presented pass.

The Slang source lives beside the example:

```text
examples/offscreen_texture/shaders/offscreen_texture.slang
```

## MSAA Triangle

`examples/msaa_triangle` is the first multisample resolve sample. It renders a
colored triangle into a 4x MSAA texture, resolves it into a single-sample
texture, then samples that resolved texture onto an indexed quad in the current
drawable.

Run it with:

```sh
zig build run-msaa-triangle
```

The MSAA pipeline sets:

```zig
.sample_count = 4,
```

The MSAA render pass uses an explicit resolve target:

```zig
.color_attachments = &.{.{
    .target = .{ .texture_view = &msaa_view },
    .resolve_target = &resolved_view,
}},
```

The resolved texture is single-sample and has both `.render_attachment` and
`.shader_read` usage so the screen pass can sample it. The screen pass bind
group layout is derived from shader reflection.

The Slang source lives beside the example:

```text
examples/msaa_triangle/shaders/msaa_triangle.slang
```

## Rainbow Cube

`examples/rainbow_cube` is the first integrated 3D sample. It draws a rotating
indexed cube with per-face vertex colors, a sampled rainbow texture, a per-frame
uniform buffer update, and current-drawable depth testing.

Run it with:

```sh
zig build run-rainbow-cube
```

The example uses only public resource and command APIs:

- vertex, index, and uniform buffers through `Device.makeBuffer(...)`
- per-frame uniform updates through `uniform_buffer.replaceBytes(...)`
- texture upload through `texture.replaceAll2D(...)`
- uniform, sampled texture, and sampler bindings through a public bind group
  whose layout is derived from shader reflection
- depth testing through `RenderPipelineDescriptor.depth_stencil` and a render
  pass depth attachment
- indexed drawing through `drawIndexedPrimitives(...)`

The Slang source lives beside the example:

```text
examples/rainbow_cube/shaders/rainbow_cube.slang
```

## Transfer Readback

`examples/transfer_readback` is the first non-rendering Phase 8 example. It
copies a small RGBA payload buffer to another buffer, copies that payload into a
texture, copies the texture back into a CPU-visible buffer, validates both
readbacks, prints `transfer readback ok`, and exits automatically.

Run it with:

```sh
zig build run-transfer-readback
```

For backend debugging:

```sh
VKMTL_BACKEND=vulkan zig build run-transfer-readback
VKMTL_BACKEND=metal zig build run-transfer-readback
```

## Compute Readback

`examples/compute_readback` is the first compute sample. It creates a storage
texture and a storage buffer, binds both through a compute-visible bind group,
dispatches a Slang compute shader, copies both resources to CPU-visible
readback buffers, and validates deterministic bytes before exiting
automatically. Its compute pipeline attaches runtime-generated reflection JSON and
derives the storage texture and storage buffer bind group layout from it before
backend pipeline creation.

Run it with:

```sh
zig build run-compute-readback
```

For backend debugging:

```sh
VKMTL_BACKEND=vulkan zig build run-compute-readback
VKMTL_BACKEND=metal zig build run-compute-readback
```

The Slang source lives beside the example:

```text
examples/compute_readback/shaders/compute_readback.slang
```

Current compute coverage is intentionally deterministic: storage buffer writes,
storage texture writes, transfer readback, reflection-derived bind group
layouts, and byte validation before process exit.

## Capability Dump

`examples/capability_dump` prints the selected backend, adapter identity,
capability source, usable features, native queried features, selected limits,
and representative format capabilities.

Run it with:

```sh
zig build run-capability-dump
```

For backend debugging:

```sh
zig build run-capability-dump -Dvulkan
VKMTL_BACKEND=metal zig build run-capability-dump
```

## Bindless Textures

`examples/bindless_textures` exercises the advanced binding layout contract for
bindless texture tables. Until backend lowering is enabled on the selected
device, the example exits with a clear unsupported-feature message.

Run it with:

```sh
zig build run-bindless-textures
```

## Compute Gallery

Period 9 tracks the broader compute gallery in `src/development_matrix.zig`.
Current status:

- implemented: `compute_readback`
- planned: `image_filter`
- planned: `particle_simulation`
- planned: `prefix_sum`
- planned: `storage_texture`

Planned compute examples should keep deterministic readback or pixel validation
where practical so they can become useful backend regression tests.

## Multi-Window Gallery

`examples/multi_window` is the first multi-surface smoke example. It creates two
external GLFW windows, registers both surfaces through public vkmtl
`SurfaceCollection`, and reports whether the selected backend exposes native
multi-window presentation through `DeviceFeatures.multi_surface`.

Run it with:

```sh
zig build run-multi-window
```

The broader tracked cases are:

- `single_device_multiple_surfaces`
- `multiple_swapchains`
- `multi_window_resize`
- `surface_lost_recovery`

Current public `SurfaceCollection` can track multiple neutral surface states,
but native multiple swapchain execution remains gated by
`DeviceFeatures.multi_surface`.

## Native Interop Gallery

Native interop examples are explicit advanced samples, not ordinary example
dependencies. Planned cases are:

- `vulkan_native_handles`
- `metal_native_handles`
- `external_texture_import`
- `native_command_insertion`

Portable examples should keep using public vkmtl abstractions. If an example
needs native access, it should be named and documented as a native interop case.
