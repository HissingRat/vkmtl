# Phase 4: Sampler Border Color

Phase 4 lowers sampler border-color descriptors.

## Scope

- Map supported border colors to Vulkan sampler state.
- Map supported border colors to Metal sampler state where available.
- Keep unsupported border color values typed and feature-gated.

## Validation

- Add sampler validation tests for supported and unsupported border colors.
- Update feature and limit reporting.

## Result

- `SamplerAddressMode.clamp_to_border` is public.
- Fixed `SamplerBorderColor` values lower to Vulkan sampler border colors.
- Fixed `SamplerBorderColor` values lower to Metal sampler border colors.
- `DeviceFeatures.sampler_border_color` is enabled in the portable default
  feature set for fixed border colors.
- Custom border colors remain deferred to Period 29 Phase 6 because Vulkan and
  Metal expose that space differently.
