# Phase 2: Fill Buffer Fallbacks

Phase 2 removes the Vulkan alignment footgun for public `fillBuffer(...)`.

## Scope

- Keep native `vkCmdFillBuffer` for aligned fills.
- Add staging or upload fallback for unaligned Vulkan fills.
- Preserve Metal direct fill behavior.
- Validate ranges before fallback selection.

## Validation

- Add aligned and unaligned fill tests.
- Keep fallback behavior documented as potentially slower.

## Result

- Vulkan keeps native `vkCmdFillBuffer` for 4-byte-aligned ranges.
- Vulkan unaligned ranges use a temporary staging buffer and `cmdCopyBuffer`
  fallback so the public API no longer exposes the alignment footgun.
- Metal keeps its direct byte-range fill path.
- Persistent staging-buffer pooling is deferred to Period 26 Phase 5 as part of
  long-run upload/resource-churn stability work.
