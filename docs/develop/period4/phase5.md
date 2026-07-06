# Phase 5: Dynamic Offsets / Small Constants

Phase 5 adds portable validation shapes for dynamic offsets and small constants.

## First Slice

- Add `DynamicOffset` and `DynamicOffsetList`.
- Validate dynamic-offset bindings against `BindGroupLayoutDescriptor`.
- Add `SmallConstantDescriptor`.
- Add dynamic-offset and small-constant alignment checks using `DeviceLimits`.
- Keep backend lowering for dynamic offsets and per-draw/per-dispatch constants
  for later command-encoder phases.

## Current Limits

- Existing command encoders still bind resources without dynamic offset arrays.
- `DeviceFeatures.small_constants` defaults to false until Vulkan push constants
  and Metal bytes/constants lowering are implemented.
