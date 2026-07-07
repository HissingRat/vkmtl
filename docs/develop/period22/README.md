# Period 22: Binding ABI And Shader Variant Closure

Status: planned after Period 21.

Goal: close the binding and shader backend items that Period 21 intentionally
left as explicit follow-up work. This period should turn the remaining
descriptor-table, root-constant, and shader-variant shapes into executable
backend paths before vkmtl moves on to broader command synchronization work.

Expected result: applications can use advanced binding tables, dynamic buffer
arrays, command-written root constants, immutable/static samplers, and shader
specialization without treating them as descriptor-only placeholders.

## Phase 1: Binding ABI Cleanup

- Add the missing array-element addressing model for dynamic buffer arrays.
- Finalize immutable/static sampler policy.
- Keep ordinary single-resource bind groups source-compatible.

See `phase1.md`.

## Phase 2: Bindless Resource Table Objects

- Add runtime objects for large resource tables.
- Define update, clear, partially-bound, and update-after-bind behavior.

See `phase2.md`.

## Phase 3: Descriptor Table Command Binding

- Bind Vulkan descriptor-indexing tables and Metal argument buffers through
  render and compute encoders.
- Keep the portable bind group path separate.

See `phase3.md`.

## Phase 4: Root Constants Command Writes

- Add render and compute encoder methods for small/root constant writes.
- Lower writes to Vulkan push constants and Metal-compatible constant binding.

See `phase4.md`.

## Phase 5: Shader Specialization Variants

- Lower specialization data through Slang, Vulkan pipeline creation, and Metal
  pipeline/function variant selection.
- Preserve specialization data in runtime cache identity.

See `phase5.md`.

## Phase 6: Binding And Variant Validation

- Add tests, docs, and examples that prove the advanced binding and shader
  variant paths.

See `phase6.md`.

## Deferred Items Routed Here

Period 21 completed dynamic offsets, first-slice resource arrays, advanced
layout metadata, root-constant pipeline compatibility, and specialization cache
identity. The following items are deliberately handled in Period 22:

- dynamic buffer arrays need a per-array-element offset ABI
- bindless resource tables need allocation, update, clear, and command binding
- root constants need command encoder writes and native lowering
- shader specialization needs Slang/backend variant creation, not only cache
  fingerprints
- immutable/static samplers need a clear ownership and layout-compatibility
  policy
