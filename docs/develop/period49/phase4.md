# Phase 4: Memoryless And Sparse/Residency Closure

Status: complete.

## Scope

- Validate memoryless textures as render-attachment-only, non-CPU-visible,
  nonpersistent resources.
- Lower memoryless storage directly on Metal and keep Vulkan typed unsupported.
- Exercise a memoryless MSAA attachment with a persistent resolve target.
- Keep sparse/tiled/residency feature gates closed and document why the current
  handle-free mapping descriptors cannot execute native page commits.
- Record default-only cache behavior and unsupported optimization hints.

## Result

`.memoryless` is an attachment-only storage mode with a separately probed Metal
feature. Load/store persistence is rejected; MSAA resolve with a discard store
action executes physically. Vulkan stays typed unsupported. Sparse/tiled
resource creation, residency sets, and native page commits remain closed
because current mapping descriptors contain no resource identity. Default cache
behavior remains executable; explicit cache policies and content optimization
hints receive precise unsupported decisions.
