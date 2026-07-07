# Phase 4: Root Constants Command Writes

Phase 4 finishes the root-constant path started in Period 21.

## Scope

- Add render and compute encoder methods for root constant writes.
- Validate write range, alignment, visibility, and active pipeline
  compatibility.
- Lower Vulkan writes to push constants.
- Lower Metal writes to a stable slot model using `setBytes`, a small constant
  buffer, or another documented Metal-compatible path.
- Keep the slot/index contract derived from pipeline layout, not from backend
  implementation details in user code.

## Validation

- Add tests for missing pipeline layout, out-of-range writes, visibility
  mismatches, and backend limit failures.
- Add one render or compute example using command-written constants.

## Result

- Tiny per-draw or per-dispatch data no longer requires users to create small
  buffers manually.
