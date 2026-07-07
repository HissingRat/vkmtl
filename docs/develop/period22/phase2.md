# Phase 2: Bindless Resource Table Objects

Phase 2 introduces the runtime object that owns large resource tables.

## Scope

- Add backend-neutral descriptors for resource table allocation.
- Add update and clear operations for texture, sampler, buffer, and storage
  resource slots.
- Define partially-bound behavior and update-after-bind rules.
- Track table lifetime, referenced resource lifetime, and debug labels.
- Preserve the existing `AdvancedBindGroupLayout` metadata object as the layout
  input instead of turning normal bind groups into bindless tables.

## Validation

- Add tests for out-of-range updates, mismatched resource kinds, dead resource
  references, partial bindings, and update-after-bind feature gates.
- Keep unsupported table models behind precise typed errors.

## Result

- Applications can create and update bindless-style resource tables through a
  public vkmtl object.
