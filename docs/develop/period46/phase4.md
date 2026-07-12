# Phase 4: Metal Function Constants

Status: complete.

## Mapping

- `bool` maps to `MTLDataTypeBool`.
- `u32` maps to `MTLDataTypeUInt`.
- `i32` maps to `MTLDataTypeInt`.
- `f32` maps to `MTLDataTypeFloat`.
- Every constant uses `setConstantValue:type:atIndex:` with its required stable
  numeric ID. Slang may rewrite the generated MSL symbol name, so the optional
  public `name` remains validation/diagnostic/cache identity only and never
  controls native lookup.
- Current reflection does not export automatically assigned specialization
  IDs. Consumer Slang should use explicit `[vk::constant_id(N)]`, and the
  descriptor must use the same `id = N`; this numeric contract is stable across
  SPIR-V and generated MSL.
- Render stages are specialized independently before constructing the native
  pipeline descriptor. Compute uses the same translation.

Invalid names, IDs, types, or constants not present in the shader return the
existing pipeline/shader failure path; no value is silently ignored.
