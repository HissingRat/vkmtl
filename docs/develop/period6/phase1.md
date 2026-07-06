# Phase 1: Command Lifecycle

Phase 1 tightens command-buffer lifecycle semantics without changing the
existing example path.

## First Slice

- Add a command-buffer descriptor for labels and future pooling hints.
- Preserve `Queue.makeCommandBuffer()` as the simple default path.
- Add status helpers so tests and tools can inspect recording, ended, and
  committed state.
- Define reset/reuse as validation-shape-first until backend pooling is wired.

## Current Limits

- Runtime command buffers are still one-shot after `commit()`.
- `Queue.makeCommandBufferWithDescriptor(...)` accepts labels now, while
  pooled/reusable command buffers are feature-gated and disabled by default.
- `CommandBuffer.state()` reports portable lifecycle state for diagnostics.
- Vulkan and Metal backends allocate native command buffers through the current
  per-submit path.
- Command buffer pooling and native reset/reuse remain future backend work.
