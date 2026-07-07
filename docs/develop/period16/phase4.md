# Phase 4: Metal Object / Mesh Function Path

Phase 4 maps mesh-style pipelines to Metal where supported.

## Scope

- Query Metal object/mesh function availability.
- Map mesh pipeline descriptors to Metal pipeline functions.
- Document unsupported Metal versions or devices.
- Treat the public task stage as Metal object-function metadata where supported.

## Validation

- Tests should cover feature-gated failure paths.
- A Metal smoke example should render through the supported mesh-style path.
- Unit tests should validate mesh/object entry point mapping.
