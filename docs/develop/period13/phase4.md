# Phase 4: Present Mode And Vsync Configuration

Phase 4 applies presentation preferences per surface.

## Scope

- Map public present mode to Vulkan present modes.
- Map vsync intent to Metal drawable presentation settings.
- Document backend differences where exact parity is not possible.
- Add shared present-mode support and fallback helpers for backend code to use.

## Validation

- Tests should validate present-mode selection and fallback rules.
- Capability dump output should include supported present behavior where known.
- `fifo` remains the portable fallback. `immediate` is treated as the
  non-vsync/tearing-allowed intent; `mailbox` keeps vsync semantics while
  allowing lower-latency replacement where a backend supports it.
