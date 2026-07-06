# Phase 4: Present Mode And Vsync Configuration

Phase 4 applies presentation preferences per surface.

## Scope

- Map public present mode to Vulkan present modes.
- Map vsync intent to Metal drawable presentation settings.
- Document backend differences where exact parity is not possible.

## Validation

- Tests should validate present-mode selection and fallback rules.
- Capability dump output should include supported present behavior where known.
