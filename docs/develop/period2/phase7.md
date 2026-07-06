# Phase 7: Native Handle Escape Hatch

Phase 7 adds an explicit advanced path for backend-native handles.

## First Slice

- Add `VulkanNativeHandles`.
- Add `MetalNativeHandles`.
- Add `NativeHandles`.
- Add `WindowContext.nativeHandles()`.
- Keep native handles out of ordinary descriptors, resources, and command APIs.

## Rules

- Native handles are an escape hatch, not the portable API.
- Code that uses native handles is backend-specific.
- vkmtl does not guarantee portability after a caller mutates native objects
  directly.
- Returned handles are borrowed and only valid while their vkmtl owner is
  alive.
- Threading and synchronization remain the caller's responsibility after using
  the escape hatch.
