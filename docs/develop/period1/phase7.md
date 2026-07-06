# Phase 7 Decisions

Phase 7 adds the render pass features needed by real 2D and 3D examples:
depth, later stencil, MSAA, offscreen targets, and resolve targets.

## First Slice

The first implementation slice is depth-only for the current drawable.

- Add `TextureFormat.depth32_float` as the first depth format.
- Add a Metal-inspired `DepthStencilDescriptor` to render pipeline creation.
- Add a `RenderPassDepthAttachmentDescriptor` to render pass encoding.
- Keep the first depth attachment implicit and sized to the current drawable.
- Defer explicit texture-backed render targets until the offscreen attachment
  API is designed later in Phase 7.
- Defer stencil, MSAA, and resolve attachments until depth works on both
  backends.

Status: this slice is implemented. `examples/depth_triangles` exercises
`TextureFormat.depth32_float`, pipeline depth state, render pass depth
attachments, Vulkan depth framebuffers, and Metal depth textures/depth-stencil
state.

The implicit current-drawable depth attachment keeps the public API usable for
windowed examples without forcing a premature `TextureView` ownership shape
into `core.zig`. Once offscreen targets are added, render pass attachments can
gain explicit texture targets without invalidating the depth state model.

## Public API Shape

Pipeline depth state is opt-in:

```zig
.depth_stencil = .{
    .format = .depth32_float,
    .depth_compare_function = .less_equal,
    .depth_write_enabled = true,
},
```

Render pass depth is also opt-in:

```zig
.depth_attachment = .{
    .load_action = .clear,
    .store_action = .dont_care,
    .clear_depth = 1.0,
},
```

For this slice, a depth-enabled render pass uses a backend-owned depth texture
matching the drawable extent. Applications do not upload pixels into depth
textures through `replaceRegion`.

## Backend Mapping

Vulkan uses a depth-capable render pass, depth image, depth image view, and
framebuffers containing both the swapchain image and depth view. Pipelines with
depth state are created against the depth-capable render pass.

Metal uses `MTLPixelFormatDepth32Float`, a per-window depth texture, and an
`MTLDepthStencilState` stored alongside the render pipeline state. Encoders set
the depth state automatically when the selected pipeline has one.

## Explicit Attachments

The second implementation slice defines texture-backed render pass attachments
at the runtime API layer. `core.zig` still owns backend-neutral descriptor
validation, while `runtime/window_context.zig` owns descriptors that can refer
to live `TextureView` objects.

Color attachments can now target either the current drawable or a texture view:

```zig
.color_attachments = &.{.{
    .target = .{ .texture_view = &color_view },
    .clear_color = .{ .red = 0.0, .green = 0.0, .blue = 0.0, .alpha = 1.0 },
}},
```

Depth attachments can use the same shape:

```zig
.depth_attachment = .{
    .target = .{ .texture_view = &depth_view },
    .clear_depth = 1.0,
},
```

The first explicit-attachment slice has these constraints:

- Exactly one color attachment is supported.
- Texture-backed color attachments must use color formats and
  `TextureUsage.render_attachment`.
- Texture-backed depth attachments must use depth formats and
  `TextureUsage.render_attachment`.
- Current-drawable attachments and texture-backed attachments cannot be mixed
  in the same render pass yet.
- `presentDrawable()` is valid only for passes targeting the current drawable.

Vulkan creates a temporary compatible render pass and framebuffer for
texture-backed attachments and destroys them after the command buffer finishes.
Metal passes the texture views directly into `MTLRenderPassDescriptor`.

Status: the API and backend plumbing are implemented. `examples/offscreen_texture`
exercises the texture-backed path visibly by rendering into a sampled color
texture, then drawing that texture into the current drawable.

## MSAA And Resolve Attachments

The third implementation slice adds explicit MSAA render targets and explicit
resolve targets. The first supported shape is:

- create a texture with `sample_count > 1` and `TextureUsage.render_attachment`
- create a single-sample color texture with `TextureUsage.render_attachment`
  and, if it will be sampled later, `TextureUsage.shader_read`
- set `RenderPipelineDescriptor.sample_count` to the MSAA texture sample count
- set `RenderPassColorAttachmentDescriptor.target` to the MSAA texture view
- set `RenderPassColorAttachmentDescriptor.resolve_target` to the single-sample
  texture view

The first MSAA slice deliberately does not add implicit current-drawable MSAA.
Applications resolve into a texture, then render or sample that texture in a
second pass. This keeps swapchain resize behavior independent from MSAA texture
ownership and preserves the explicit attachment model.

Validation rules:

- Supported sample counts are 1, 2, 4, and 8.
- Multisampled textures must be 2D, single-layer, single-mip render
  attachments.
- Multisampled color attachments require a resolve target.
- Resolve targets must be single-sample color texture views with matching
  format and extent.
- Pipeline sample count must match the render pass sample count.

Vulkan maps this to a multisampled color attachment plus
`p_resolve_attachments`. Metal maps it to a multisampled color texture,
`resolveTexture`, and `MTLStoreActionMultisampleResolve`.

Status: the explicit MSAA/resolve path is implemented. `examples/msaa_triangle`
renders into a 4x MSAA color texture, resolves into a single-sample texture, and
then samples that resolved texture into the current drawable.

## Later Work

Remaining render-target work after Phase 7 should be done in small slices:

- Stencil formats and operations.
- More render-target example coverage as new pass shapes land.

The textured 3D cube integration sample is implemented as
`examples/rainbow_cube`.
