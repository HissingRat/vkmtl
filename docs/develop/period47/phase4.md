# Phase 4: Compute And Reflection Breadth

Status: complete.

## Scope

- Verify direct and indirect dispatch lowering and document
  `dispatchThreads` as vkmtl's threadgroup composition, including bounds
  responsibility when a grid is not divisible by the threadgroup size.
- Close ordinary compute bindings and explicit buffer/texture barriers using
  existing command and hazard-state paths.
- Query truthful atomics and threadgroup-memory support and native limits, then
  prove supported shader behavior with deterministic GPU readback.
- Extend Slang reflection only for portable buffer, texture, sampler, array,
  access, and vertex-input metadata needed by current layouts and validation.

Native fences/events, heaps, function tables, tensors, payload bindings, and
backend-only reflection protocols remain outside this phase.

## Result

- Direct and indirect dispatch share the existing backend command paths.
  `dispatchThreads` is a ceil-divided threadgroup composition; shaders remain
  responsible for rejecting invocations beyond the requested logical grid.
- Ordinary compute bind groups, root constants, buffer barriers, and texture
  barriers execute on both backends. Native fences and events remain Period 48.
- Both backends report executable 32-bit integer storage-buffer/threadgroup
  atomics and queried threadgroup-memory limits. The compute readback probe now
  validates storage-buffer atomics, threadgroup atomics, shared memory, and a
  deterministic result on physical Metal.
- Schema-1 reflection now preserves portable resource arrays and storage
  access in addition to buffer, texture, sampler, and vertex-input metadata.
  Advanced reflection protocols remain deferred.
