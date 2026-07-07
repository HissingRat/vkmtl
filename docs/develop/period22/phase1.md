# Phase 1: Binding ABI Cleanup

Phase 1 fixes the public and runtime ABI gaps that block the remaining binding
work.

## Scope

- Add an array-element address to dynamic buffer offsets, or an equivalent
  shape that can identify each buffer inside a binding array.
- Validate dynamic offset count, alignment, and array index against the bind
  group layout.
- Decide immutable/static sampler ownership: layout-owned sampler handles,
  descriptor-owned static sampler descriptors, or an explicit unsupported gate.
- Keep existing single-resource `BindGroupEntry.resource` and
  `BindGroupBinding.dynamic_offsets` source-compatible where possible.

## Validation

- Add tests for dynamic buffer arrays with missing, extra, duplicated, and
  unaligned element offsets.
- Add sampler-layout compatibility tests for immutable/static sampler policy.
- Update API docs with the final ABI.

## Result

- Later phases can bind descriptor tables without guessing how array elements
  are addressed.
- Existing first-slice bind groups keep their current behavior.
