# Phase 4: Blend State

Phase 4 expands color attachment pipeline state for common blending patterns.

## First Slice

- Add blend factors.
- Add blend operations.
- Add color and alpha blend descriptors.
- Validate format blendability.
- Keep independent blending explicit through per-attachment descriptors.

## Current Limits

- Color write masks are already part of the pipeline descriptor.
- Non-empty blending state is validation/API shape first until Metal and Vulkan
  lowering are completed together.
- Runtime pipeline creation rejects non-empty blend state unless a future
  backend reports `DeviceFeatures.blend_state`.
- Per-attachment independent blend descriptors are represented, and mismatched
  descriptors require `DeviceFeatures.independent_blend`.
