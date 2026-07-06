# Phase 0: Resource Coverage Contract

Phase 0 defines how Period 3 expands resource coverage without turning vkmtl
into a direct union of Vulkan and Metal resource APIs.

## Decisions

- Public resource descriptors stay backend-neutral.
- Optional features are exposed through `DeviceFeatures`, `DeviceLimits`, and
  `FormatCapabilities`.
- Backend-native memory handles remain behind native-handle escape hatches or
  future advanced heap APIs.
- Validation helpers belong in `core.zig` so examples and tests can exercise
  them without creating a native device.
- Runtime wrappers may expose convenience methods when both backends can map
  them cleanly.

## First-Slice Scope

- Buffer range mapping and CPU-visible checks.
- Texture shape helper methods and validation coverage.
- Format classification and capability helpers.
- Mipmap range helpers and explicit view range queries.
- Sampler descriptor completeness for compare/anisotropy/border-color shapes.
- Heap capability shape without default heap allocation.
