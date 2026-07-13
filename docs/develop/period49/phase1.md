# Phase 1: Semantic Splits And Public Allocation

Status: complete.

## Decisions

- `Heap` becomes the owner of native placement allocation. It queries exact
  backend size/alignment requirements, reserves a range, and creates a buffer
  or texture at that range. Heap-backed resources must be destroyed before the
  heap; the runtime tracks live children.
- Reuse the existing `Heap`, descriptors, allocation info, and `Device.makeHeap`
  factory. Add only specialized `Heap` methods; add no root alias, common owner
  method, or runtime-handle type.
- A native memory report replaces descriptor budget/usage estimates only when
  the selected backend has queried budget and allocation values. Fallback
  reports remain explicit.
- Add `.memoryless` to `ResourceStorageMode` and a
  `memoryless_attachments` feature. It is valid only for render-attachment-only
  textures and means native Metal memoryless storage. Vulkan remains typed
  unsupported because lazily allocated memory cannot guarantee no backing.
- Keep the existing `transient` render-pass option as a lifetime/performance
  hint. It does not request memoryless storage.
- Existing sparse descriptors and residency maps do not identify actual native
  resource handles, so they cannot lower exact page commits. Keep their usable
  features false and record the execution rows unsupported until a future
  resource-bound contract is deliberately allocated.
- Explicit residency sets, CPU cache policy selection, and content optimization
  hints receive no public API. Their observable portable contracts are either
  absent or not exact across both backends.

All public enum, feature, method, and error additions target `v0.2.0`.
