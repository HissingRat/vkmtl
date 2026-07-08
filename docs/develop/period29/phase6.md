# Phase 6: Parity Semantics And Stress Validation

Phase 6 decides the remaining Vulkan/Metal parity semantics.

## Scope

- Decide partial mip/layer-range mipmap semantics.
- Decide depth/stencil and MSAA texture-copy semantics.
- Decide whether custom sampler border colors become portable API or native
  extensions.
- Add GPU-backed long-run soak loops for backend paths that are ready.

## Validation

- Add matrix checks for every decision.
- Run long-running native validation on supported CI or local hosts.
