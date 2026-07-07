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
