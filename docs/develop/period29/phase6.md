# Phase 6: Parity Semantics And Stress Validation

Status: completed for semantic decisions and public runtime planning.

Phase 6 decides the remaining Vulkan/Metal parity semantics.

## Scope

- Added `ParitySemanticStatus`, `BackendParitySemanticsDescriptor`, and
  `BackendParitySemanticsPlan`.
- Decided partial mip/layer-range behavior as portable runtime semantics.
- Decided depth/stencil and MSAA texture copies as typed unsupported behavior
  until a portable copy model is added.
- Decided custom sampler border colors as native-extension-only semantics, not
  part of the portable sampler enum.
- Kept opt-in `StabilityRunPlan` planning for soak loops, while backend-private
  GPU soak execution remains deferred.

## Validation

- Core tests cover parity semantic decisions and stability-plan integration.
- Runtime tests cover `Device.planBackendParitySemantics(...)` for the selected
  backend.

## Deferred Native Work

- Native GPU-backed soak loops, custom-border native extension lowering, and any
  future portable depth/stencil/MSAA copy expansion are deferred to Period 30
  Phase 6.
