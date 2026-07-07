# Phase 2: Dispatch Indirect

Phase 2 defines dispatch-indirect validation before backend lowering.

## First Slice

- Add an indirect dispatch descriptor with offset/alignment validation.
- Add buffer usage metadata for indirect arguments.
- Expose runtime command methods that validate before returning typed
  unsupported errors.

## Current Limits

- `DispatchThreadgroupsIndirectDescriptor` validates the 12-byte argument
  block offset and `DeviceLimits.dispatch_indirect_alignment`.
- Indirect argument buffers should be created with `BufferUsage.indirect`.
- Runtime `dispatchThreadgroupsIndirect(...)` validates shape and usage before
  returning `UnsupportedDispatchIndirect`.
- Native Vulkan `vkCmdDispatchIndirect` and Metal indirect dispatch lowering are
  future work.
