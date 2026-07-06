# Period 5: Render Pipeline

Goal: cover common graphics rendering features without baking backend-specific
state into user code.

Status: Period 5 public descriptors, validation, and runtime gates are in
place. Existing first-slice lowering remains compatible, while advanced render
pipeline states return typed unsupported errors until backend-specific lowering
is implemented.

Viewport and scissor are dynamic encoder state, not pipeline raster state. That
keeps the API closer to both Metal's encoder model and Vulkan's dynamic-state
path.

## Phase 1: Render Pass / Attachment Model

- Color attachments.
- Depth attachments.
- Stencil attachments.
- Multiple render targets.
- Load actions.
- Store actions.
- Clear values.
- Resolve targets.
- Transient attachments where supported.

## Phase 2: Raster State

- Cull mode.
- Front face.
- Fill mode.
- Depth bias.
- Conservative rasterization as a gated feature.

## Phase 3: Dynamic Render State

- `setViewport`.
- `setScissorRect`.
- Blend constants.
- Stencil reference.
- Dynamic depth bias override.
- Clear errors when a backend or pipeline cannot support a dynamic state.

## Phase 4: Blend State

- Color write mask.
- Blend enable.
- Blend operation.
- Blend factors.
- Alpha blending.
- Independent blending.
- Format blendability checks.

## Phase 5: Depth / Stencil State

- Depth test.
- Depth write.
- Compare function.
- Stencil enable.
- Stencil operations.
- Stencil read mask.
- Stencil write mask.

## Phase 6: Vertex Layout Completeness

- Multiple vertex buffers.
- Multiple attributes.
- Attribute formats.
- Stride.
- Offset.
- Step function.
- Instance rate.
- Index buffer format.

## Phase 7: Draw Commands

- Draw.
- Draw indexed.
- Draw instanced.
- Draw indexed instanced.
- Draw indirect.
- Draw indexed indirect.
- Multi-draw as a gated feature.

## Phase 8: Query Support

- Occlusion queries.
- Timestamp queries.
- Pipeline statistics queries as a gated feature.
- Query resolve.
- Query readback.
- Clear documentation for Metal and Vulkan support differences.
