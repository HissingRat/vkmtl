# Phase 4: Compute And Reflection Breadth

Status: planned.

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
