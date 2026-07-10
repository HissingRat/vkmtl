# Phase 3: Resource State And Layout Transitions

Status: complete.

## Decisions

- Public state remains `ResourceUsageKind`; Vulkan image layouts and Metal
  encoder/resource state stay backend-private.
- Texture usage tracking operates on explicit mip/layer ranges. Whole-resource
  operations use the full resolved range.
- A transition summary records affected subresources, hazards, and required
  barriers. State persists across command encoders and command buffers through
  the resource owner.
- Explicit barriers must match the tracked before-state for every covered
  subresource. Queue ownership remains whole-resource in Period 42.
- Metal explicit barriers remain validation/state markers where the native API
  relies on encoder boundaries; Vulkan lowers them to image/buffer barriers.

## Acceptance

- Independent mips/layers may hold different tracked usages.
- Read/write hazards are detected across passes and queue views.
- Invalid partial explicit barriers fail before native commands are recorded.
