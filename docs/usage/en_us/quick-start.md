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
});
const vkmtl = vkmtl_dep.module("vkmtl");

exe.root_module.addImport("vkmtl", vkmtl);
```

vkmtl does not create windows itself. Use a windowing package in the
application, then pass vkmtl a `SurfaceDescriptor` and `PresentationDescriptor`.
The repository examples use `zig_glfw` and keep the adapter code in
`examples/common.zig`.

## Create A Window Context

The current window convenience owner is `WindowContext`. It owns backend
selection, the presentation chain, and shader-cache configuration. Resource
creation goes through the `Device` returned by `context.device()`, and command
buffers go through the `Queue` returned by `context.queue()`. To enable vkmtl
runtime arguments, the application's `main` can accept
`std.process.Init.Minimal` and pass `init.args` to the context.

```zig
const vkmtl = @import("vkmtl");

var context = try vkmtl.WindowContext.init(allocator, .{
    .app_name = "my app",
    .backend = .auto,
    .process_args = init.args,
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

`Device` is the long-term resource creation entry point. `Queue` is the
long-term command-buffer and submit entry point. `Swapchain` is the current
drawable resize and presentation-chain helper entry point. Existing
`WindowContext.make*`, `resize(...)`, and `clear(...)` methods still work, but
they should gradually become compatibility helpers.

## Compile Slang At Runtime

Applications embed Slang source and compile it through the device. vkmtl writes
SPIR-V, MSL, and reflection JSON into the runtime shader cache.

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

Resources are explicit handles and must be destroyed before `WindowContext`.
Debug builds track resource lifetimes and panic if handles are leaked at
`WindowContext.deinit()`.

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
var layouts = try vkmtl.ShaderReflection.deriveRenderPipelineBindGroupLayouts(
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

See `examples/transfer_readback` and `examples/compute_readback` for
deterministic readback samples.

## Shader Cache

vkmtl caches runtime shader artifacts automatically. The cache key includes the
embedded source hash. If the source changes, vkmtl recompiles and rewrites the
cached artifacts. If an application passes `init.args` to `WindowContext`, vkmtl
automatically parses its own `--cache-dir` runtime argument; application code
does not need to handle that argument itself.

## Current Limits

- `Device` and `Queue` are the long-term creation and command-entry views.
  `WindowContext.make*` helpers remain compatibility forwards.
- vkmtl does not decode images, load meshes, or render text. Applications should
  provide pixel data and higher-level asset systems.
- GLFW is not part of vkmtl core. Use an external window adapter, like the
  example `zig_glfw` glue, to provide surface descriptors.
- Runtime wrappers store borrowed debug labels and validate portable debug
  groups. Native backend marker lowering is still future work.
