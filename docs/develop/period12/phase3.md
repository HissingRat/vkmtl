# Phase 3: Metal Argument Buffer Lowering

Phase 3 implements Metal argument buffers for supported devices.

## Scope

- Create Metal argument encoders or equivalent backend objects.
- Bind argument buffers in render and compute command encoders.
- Map public descriptor ranges to Metal argument indices.
- Respect argument-buffer tier limits.

## Validation

- Add macOS Metal smoke coverage when argument buffers are available.
- Keep unsupported devices returning typed errors.

## Current Status

- Metal advanced binding has a backend-side metadata object for argument-buffer
  layouts.
- The metadata groups texture, buffer, and sampler argument ranges so later
  native argument encoders have a stable lowering contract.
- The selected-device feature gate still controls whether public creation is
  allowed.
