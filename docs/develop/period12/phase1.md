# Phase 1: Advanced Binding Layout Lowering Contract

Phase 1 defines the backend contract for bindless-style layouts.

## Scope

- Define how `DescriptorIndexingLayoutDescriptor` becomes backend-native layout
  data.
- Define whether advanced layouts share caches with regular bind group layouts.
- Define how descriptor array counts and runtime arrays appear in cache keys.
- Keep the portable bind group path unchanged.

## Validation

- Tests should cover compatibility between regular and advanced layout entries.
- Docs should explain when to use the advanced binding path.

## Current Status

- `AdvancedBindGroupLayout` is a runtime object that snapshots advanced binding
  layout ranges after selected-device validation.
- `Device.makeAdvancedBindGroupLayout(...)` and
  `WindowContext.makeAdvancedBindGroupLayout(...)` are public entry points.
- The portable `BindGroupLayout` path is unchanged; advanced layouts are only
  available when the selected feature gate validates.
