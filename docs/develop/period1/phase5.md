# Phase 5 Decisions

These decisions start command encoding while keeping the public API
Metal-inspired and backend-neutral.

## Current Status

Phase 5 defines command descriptors, a debug validation state machine, runtime
command wrappers, and native current-drawable command recording on Vulkan and
Metal.

The user flow is:

- create a command buffer
- create a render command encoder from a render pass descriptor
- set render pipeline state
- set vertex or index buffers
- draw primitives or indexed primitives
- end encoding
- present and commit

The implementation uses lightweight validation types in `core.zig` so Vulkan
and Metal share ordering rules.

Completed so far:

- public render pass and draw descriptors
- shared command ordering validation
- runtime `CommandBuffer` and `RenderCommandEncoder` wrappers
- Vulkan current-drawable command recording for render pass, pipeline binding,
  vertex and index buffers, draw calls, submit, and present
- Metal current-drawable command recording through the bridge for render pass,
  pipeline binding, vertex and index buffers, draw calls, present, and commit

## Lifecycle

The public flow should mirror Metal names where possible:

```zig
var command_buffer = try context.makeCommandBuffer();
var encoder = try command_buffer.makeRenderCommandEncoder(render_pass);
try encoder.setRenderPipelineState(pipeline);
try encoder.setVertexBuffer(vertices, .{ .index = 0 });
try encoder.drawPrimitives(.{ .primitive_type = .triangle, .vertex_count = 3 });
try encoder.endEncoding();
try command_buffer.presentDrawable();
try command_buffer.commit();
```

Debug builds validate the ordering:

- a command buffer starts in `ready`
- a render encoder can only be created while the command buffer is `ready`
- while a render encoder is active, the command buffer is `render_encoding`
- draw calls require a pipeline
- indexed draw calls require an index buffer
- an ended encoder cannot record more commands
- a command buffer can only present and commit after encoders have ended

## First Render Target

The first render pass target is `current_drawable`. Explicit offscreen render
targets arrive in Phase 7 with render target textures and resolves.

## Scope

Phase 5 did not introduce resource bindings for textures, samplers, or uniform
buffers. Phase 6 owns their public descriptors, runtime wrappers, and backend
binding implementations.
