# Phase 1: Blend State Lowering

Phase 1 completes the common single-render-target blend path.

## Scope

- Lower `RenderPipelineBlendDescriptor` to Vulkan
  `VkPipelineColorBlendAttachmentState`.
- Lower `RenderPipelineBlendDescriptor` to Metal
  `MTLRenderPipelineColorAttachmentDescriptor`.
- Preserve color write masks in both backends.
- Open `DeviceFeatures.blend_state` for the portable default path.
- Leave true independent blend to the MRT phase.

## Status

Completed.

## Validation

- `zig build test`
- `zig build`
- `git diff --check`
