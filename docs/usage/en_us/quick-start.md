# Quick Start

This document describes the current public vkmtl path for early applications
and examples. vkmtl is still experimental, but the Phase 8 vertical slices are
usable through the public API.

## Add The Package

An application build can depend on vkmtl and import the public module:

```zig
const vkmtl_dep = b.dependency("vkmtl", .{
    .target = target,
    .optimize = optimize,
    .shader_manifest = b.path("shaders/manifest.json"),
});
const vkmtl = vkmtl_dep.module("vkmtl");

exe.root_module.addImport("vkmtl", vkmtl);
```

`shader_manifest` is a consumer-owned, source-backed `std.Build.LazyPath`.
Generated manifests are not supported. Schema version 1 contains
`render_shaders`, `compute_shaders`, and `ray_tracing_shaders`; schema version
2 retains them and adds `tessellation_shaders` and `mesh_shaders`.
Render entries use `name`, `source`, `vertex_entry`, and `fragment_entry`;
compute entries use `name`, `source`, and `entry`; ray-tracing entries use
`name`, `source`, `metal_ray_generation_source`, `ray_generation_entry`,
`miss_entry`, `closest_hit_entry`, `any_hit_entry`, and `intersection_entry`.
Tessellation entries add vertex/control/evaluation/fragment entry points;
mesh entries add mesh, optional task, and fragment entry points.
Source paths are relative to the manifest, stay inside its LazyPath owner root,
and include/import dependencies are tracked through Slang depfiles. Shader
names are unique, lowercase
portable `[a-z0-9_.-]+` values.

On an unknown build host, also forward the build-time compiler as a dependency
option:

```zig
.slangc = "/path/to/build-time/slangc",
```

See [Shader Authoring](../../api/en_us/shaders.md) for the complete field list.

vkmtl does not create windows itself. Use a windowing package in the
application, then pass vkmtl a `SurfaceDescriptor` and `PresentationDescriptor`.
The repository examples use `zig_glfw` and keep the adapter code in
`examples/common.zig`.

## Create A Headless Context

Compute, transfer, ray-tracing, resource, and texture-backed offscreen work can
skip window setup entirely:

```zig
const vkmtl = @import("vkmtl");

var context = try vkmtl.HeadlessContext.init(allocator, .{
    .app_name = "my headless job",
    .backend = .auto,
});
defer context.deinit();

var device = context.device();
var queue = context.queue();
```

This path creates no window, surface, swapchain, drawable, or presentation
queue. Texture-view render attachments remain valid; current-drawable passes
and present operations return a typed presentation error. Destroy resources
before the context.

## Create A Window Context

The current window convenience owner is `WindowContext`. It owns backend
selection and the presentation chain. Resource creation goes through the
`Device` returned by `context.device()`, and command buffers go through the
`Queue` returned by `context.queue()`.

```zig
const vkmtl = @import("vkmtl");

var context = try vkmtl.WindowContext.init(allocator, .{
    .app_name = "my app",
    .backend = .auto,
    .surface = surface_descriptor,
    .presentation = presentation_descriptor,
});
defer context.deinit();

std.debug.print("Using backend: {}\n", .{context.selectedBackend()});

var device = context.device();
var queue = context.queue();
var swapchain = context.swapchain();
```

On Apple platforms `.auto` prefers Metal when the surface is compatible. On
other desktop platforms it prefers Vulkan. Applications can request `.vulkan`
or `.metal` explicitly, and examples also accept the build-time `-Dvulkan`
override for backend testing.

`Device` is the resource creation entry point. `Queue` owns command-buffer
creation and submission, while `Swapchain` owns drawable resize and clear
operations. `WindowContext` is limited to backend identity, native-handle
access, and access to those runtime owners.

## Use Precompiled Slang Shaders

Applications embed Slang source and request the matching shader through the
device. `zig build` precompiles matching SPIR-V, MSL, and reflection JSON;
runtime resolves embedded artifacts directly from memory.

```zig
const shader_source = @embedFile("shaders/triangle.slang");

var compiled = try device.compileRenderShader("triangle", shader_source, .{
    .vertex_entry = "vs_main",
    .fragment_entry = "fs_main",
});
defer compiled.deinit();

const stages = compiled.stageDescriptors(context.selectedBackend());
```

Use those stage descriptors in a render pipeline:

```zig
var pipeline = try device.makeRenderPipelineState(.{
    .vertex = stages.vertex,
    .fragment = stages.fragment,
    .color_attachments = &.{
        .{ .format = .bgra8_unorm },
    },
});
defer pipeline.deinit();
```

Compute shaders use the compute-specific helper:

```zig
var compiled_compute = try device.compileComputeShader("compute", shader_source, .{
    .entry = "cs_main",
});
defer compiled_compute.deinit();

const compute_stage = compiled_compute.stageDescriptor(context.selectedBackend());
```

## Create Resources

Resources are explicit handles and must be destroyed before their
`WindowContext` or `HeadlessContext`. Debug builds track resource lifetimes and
panic if handles are leaked at context destruction.

In a complete function, register `defer context.deinit()` before resource
defers. Zig runs defers in last-in, first-out order, so resources are released
before the context.

```zig
var vertex_buffer = try device.makeBuffer(.{
    .label = "vertices",
    .length = @sizeOf([3]Vertex),
    .usage = .{ .vertex = true },
    .storage_mode = .shared,
    .initial_data = std.mem.sliceAsBytes(vertices[0..]),
});
defer vertex_buffer.deinit();
```

Textures use Metal-style upload naming:

```zig
var texture = try device.makeTexture(.{
    .label = "checker",
    .format = .rgba8_unorm,
    .width = 2,
    .height = 2,
    .usage = .{ .shader_read = true, .copy_destination = true },
});
defer texture.deinit();

try texture.replaceAll2D(.{ .bytes = pixels[0..] });

var texture_view = try texture.makeTextureView(.{});
defer texture_view.deinit();

var sampler = try device.makeSamplerState(.{
    .min_filter = .linear,
    .mag_filter = .linear,
});
defer sampler.deinit();
```

## Bind Shader Resources

The preferred path is to derive bind group layouts from shader reflection, then
bind live runtime resources through `BindGroupDescriptor`.

```zig
var layouts = try vkmtl.shader.Reflection.deriveRenderPipelineBindGroupLayouts(
    allocator,
    stages.vertex,
    stages.fragment,
);
defer layouts.deinit();

var bind_group_layout = try device.makeBindGroupLayout(layouts.descriptors()[0]);
defer bind_group_layout.deinit();

var bind_group = try device.makeBindGroup(.{
    .layout = &bind_group_layout,
    .entries = &.{
        .{ .binding = 0, .resource = .{ .sampled_texture = &texture_view } },
        .{ .binding = 1, .resource = .{ .sampler = &sampler } },
    },
});
defer bind_group.deinit();
```

Runtime bind group creation validates the layout shape, referenced resource
lifetimes, backend match, buffer ranges, and storage-texture usage.

## Encode And Present

Rendering uses Metal-style command names:

```zig
var command_buffer = try queue.makeCommandBuffer();
var encoder = try command_buffer.makeRenderCommandEncoder(.{
    .color_attachments = &.{
        .{
            .clear_color = .{ .red = 0.02, .green = 0.03, .blue = 0.04, .alpha = 1 },
        },
    },
});

try encoder.setRenderPipelineState(&pipeline);
try encoder.setVertexBuffer(&vertex_buffer, .{ .index = 0 });
try encoder.setBindGroup(&bind_group, .{ .index = 0 });
try encoder.drawPrimitives(.{ .primitive_type = .triangle, .vertex_count = 3 });
try encoder.endEncoding();

try command_buffer.presentDrawable();
try command_buffer.commit();
```

Call `swapchain.resize(extent)` when the drawable size changes. The examples do
this every frame after reading the framebuffer extent from the windowing layer.

## Transfer And Compute

Use a blit encoder for explicit copies:

```zig
var command_buffer = try queue.makeCommandBuffer();
var blit = try command_buffer.makeBlitCommandEncoder();
try blit.copyBufferToBuffer(&source, &destination, .{ .size = byte_count });
try blit.endEncoding();
try command_buffer.commit();
```

Use a compute encoder for dispatch:

```zig
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

When it is clearer to think in total thread counts, use
`dispatchThreads(...)`; vkmtl resolves the threadgroup count and applies the
same device-limit checks.

See `examples/transfer_readback` and `examples/compute_readback` for genuinely
headless deterministic readback samples. Neither example initializes or links
GLFW; transfer readback also validates a texture-backed offscreen clear.

## Shader Artifacts

`zig build` precompiles embedded Slang and embeds the result into the
executable. Runtime resolves shader blobs directly from memory and does not
create a cache directory. Inspect SPIR-V, MSL, or reflection JSON under
`zig-out/shaders/<shader-name>/` when needed.

## Current Limits

- `Device`, `Queue`, and `Swapchain` are the creation, command, and
  presentation owners. `WindowContext` does not forward their operations;
  `HeadlessContext` intentionally exposes no `Swapchain`.
- vkmtl does not decode images, load meshes, or render text. Applications should
  provide pixel data and higher-level asset systems.
- GLFW is not part of vkmtl core. Use an external window adapter, like the
  example `zig_glfw` glue, to provide surface descriptors.
- Runtime wrappers store borrowed debug labels; keep their valid UTF-8 backing
  bytes alive until replacement or object destruction. Marker labels are only
  borrowed for the call. Metal markers and Vulkan encoder-level markers lower
  to native debug APIs; Vulkan command-buffer-level markers remain portable
  validation only.
