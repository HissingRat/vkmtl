# Phase 2: Dispatch Indirect

Phase 2 defines dispatch-indirect validation before backend lowering.

## First Slice

- Add an indirect dispatch descriptor with offset/alignment validation.
- Add buffer usage metadata for indirect arguments.
- Expose runtime command methods that validate before returning typed
  unsupported errors.

## Current Limits

- Native Vulkan `vkCmdDispatchIndirect` and Metal indirect dispatch lowering are
  future work.
