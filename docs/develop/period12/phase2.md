# Phase 2: Vulkan Descriptor Indexing Lowering

Phase 2 implements Vulkan descriptor indexing for supported devices.

## Scope

- Enable required descriptor indexing features and extensions.
- Create descriptor set layouts with advanced binding flags.
- Support partially bound arrays where the selected device allows it.
- Preserve validation for devices that do not support descriptor indexing.

## Validation

- Add a Vulkan-only smoke path behind feature gates.
- Add tests for descriptor count and runtime-array validation.

## Current Status

- Vulkan advanced binding has a backend-side metadata object for
  descriptor-indexing layouts.
- The metadata records descriptor counts, partially-bound ranges, and
  update-after-bind ranges.
- Native Vulkan descriptor set layout flags remain gated behind the selected
  device feature path and will be expanded from this backend object.
