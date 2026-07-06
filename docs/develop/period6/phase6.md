# Phase 6: Debug Markers Integration

Phase 6 extends the existing debug group model with signpost-style markers.

## First Slice

- Add a portable debug signpost descriptor.
- Expose command-buffer and encoder signpost helpers.
- Validate marker labels using the same portable rules as debug groups.
- Keep native marker lowering behind the public API boundary.

## Current Limits

- Signposts are currently recorded only in the portable debug state.
- Vulkan debug-utils labels and Metal GPU capture markers can be lowered later
  without changing user code.
