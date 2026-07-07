# Phase 6: Sampler Completeness

Phase 6 expands sampler descriptor shape while keeping backend differences
capability-gated.

## First Slice

- Add compare samplers.
- Add max anisotropy.
- Add border-color descriptor shape.
- Validate unsupported combinations through sampler errors.
- Report sampler support through features and limits.
- Implemented as `SamplerDescriptor.compare_function`, `max_anisotropy`, and
  `border_color`, validated by `validateForDevice(...)`.

## Current Limits

- Border colors are descriptor-level only until both backend mappings are
  implemented.
- Anisotropy is gated by `DeviceFeatures.sampler_anisotropy` and
  `DeviceLimits.max_sampler_anisotropy`, then lowered into native sampler
  creation.
- Compare samplers are feature-gated and lowered into native sampler creation.
