# Compatibility

vkmtl targets portable Vulkan and Metal workflows first, with advanced features
behind explicit capability gates.

## Current Backend Expectations

| Platform | Preferred Backend | Notes |
| --- | --- | --- |
| macOS | Metal | Default `.auto` path when Metal is available. |
| macOS | Vulkan via MoltenVK | Backend testing only; requires explicit loader and ICD paths. |
| Linux | Vulkan | Expected portable non-Apple backend. |
| Windows | Vulkan | Expected portable non-Apple backend. |
| iOS | Metal | Planned; surface packaging is not complete yet. |

## Capability Gates

Use `device.features()`, `device.limits()`, and `device.getFormatCaps(...)`
instead of platform assumptions. Unsupported optional behavior should fail with
typed errors rather than silently changing semantics.

## Advanced Features

Period 10 advanced features are descriptor/API shape first. Descriptor indexing,
sparse resources, external texture interop, tessellation, mesh shaders, ray
tracing, and driver-level pipeline caches remain gated until backend lowering is
implemented.
