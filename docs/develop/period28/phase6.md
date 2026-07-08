# Phase 6: Parity Matrix Closure

Phase 6 turns parity into a maintained product artifact.

## Scope

- List portable, Vulkan-only, Metal-only, fallback, and unsupported features.
- Decide which unsupported items become future periods.
- Keep feature reports aligned with backend reality.
- Decide whether partial mip/layer-range mipmap generation becomes a portable
  emulation path or an explicit backend-specific escape hatch.
- Decide depth/stencil and MSAA texture-copy semantics across Vulkan and Metal,
  including which cases are portable, backend-specific, or intentionally
  unsupported.
- Decide whether custom sampler border colors are worth a portable API or
  should remain a backend-specific extension path.

## Validation

- Add matrix consistency checks where possible.
- Update docs whenever feature gates change.
