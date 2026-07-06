# Phase 4: Basic Usage Tracking / Sync Baseline

Phase 4 introduces portable resource usage tracking before backend-specific
barrier lowering becomes broad enough to cover the full API.

## First Slice

- Add `ResourceUsageKind` for common read/write uses.
- Add `ResourceUsageState` for portable hazard detection.
- Classify read-after-write, write-after-read, and write-after-write hazards.
- Track usage state on runtime `Buffer`, `Texture`, and `TextureView` handles.
- Record usage from blit copies, render attachments, vertex buffers, and index
  buffers.

## Current Limits

- Bind group resource usage is not fully propagated yet because runtime bind
  groups currently materialize backend descriptors instead of retaining typed
  resource references for later encoder inspection.
- Vulkan barrier generation still lives in backend command code. The new
  usage-state model is the portable input for a later lowering pass.
- Metal still relies on encoder boundaries and the current synchronous command
  submission behavior.

## Rules

- The public API keeps automatic tracking as the default path.
- Manual barriers remain out of the base API for this period.
- Future native synchronization should consume `ResourceUsageTransition`
  instead of adding ad hoc per-backend state to user-facing handles.
