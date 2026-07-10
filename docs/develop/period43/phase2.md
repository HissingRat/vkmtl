# Phase 2: Vulkan Debug Utils Integration

Status: complete.

## Capability Contract

`vkmtl.diagnostics.DebugMarkerCapabilities` reports each diagnostics lane as
`native`, `validation_only`, or `unavailable`. This is deliberately more
specific than a single debug-marker boolean.

- Vulkan object labels are native when `EXT_debug_utils` is enabled.
- Vulkan render, blit, and compute encoder groups and signposts are native
  while their command buffer is recording.
- Vulkan command-buffer groups and signposts remain `validation_only` because
  the public API permits them before an encoder begins, while Vulkan debug
  labels require a recording native command buffer.
- When debug utils are unavailable, portable labels and stack validation stay
  available without claiming native tool visibility.

## Validation And Lowering

- Marker labels are validated for non-empty UTF-8 without embedded NUL bytes
  before Vulkan calls.
- Portable command-buffer and encoder stacks reject underflow, overflow,
  mutation in the wrong state, and unclosed groups.
- Native object label and encoder marker calls are conditional on debug-utils
  availability; the disabled path is a no-op after portable validation.
- Focused core, runtime, and Vulkan backend tests cover capability reporting,
  invalid encoding, and marker scope behavior.

No root alias or new `Device` method was added. Capability queries are
canonical under `vkmtl.diagnostics`.
