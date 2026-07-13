# Phase 2: Native Placement Heaps

Status: complete.

## Scope

- Create/destroy placement heaps on Metal and allocate compatible Vulkan device
  memory blocks.
- Query exact buffer/texture allocation size and alignment.
- Bind resources at validated reserved offsets without double-freeing heap
  memory.
- Track live heap resources and enforce resource-before-heap destruction.
- Exercise both buffer and texture placement on physical Metal.

## Result

`Heap` now owns a native placement allocation. Exact backend requirements feed
`reserve`, and `makeBufferAt`/`makeTextureAt` bind at the returned offset.
Metal uses `MTLHeapTypePlacement`; Vulkan uses a compatible memory type and one
`VkDeviceMemory` block. Resources skip individual memory frees and decrement the
heap child count on destruction. Physical Metal transfer/readback exercised a
shared heap buffer and private heap texture.
