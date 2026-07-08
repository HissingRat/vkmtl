# Phase 6: Native Parity And Soak Validation

Phase 6 turns `BackendParitySemanticsPlan` into GPU-backed validation where the
backend paths are ready.

## Scope

- Add opt-in GPU soak loops.
- Validate partial mip/layer semantics over real resources.
- Revisit custom border colors and depth/stencil/MSAA copy expansion only where
  Vulkan and Metal semantics stay explicit.

## Validation

- Run long-running native validation on supported CI or local hosts.
- Keep typed unsupported behavior for parity cases that remain intentionally
  outside the portable API.
