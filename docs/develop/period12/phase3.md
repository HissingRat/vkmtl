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
