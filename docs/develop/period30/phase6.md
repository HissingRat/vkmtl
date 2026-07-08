# Phase 6: Native Parity And Soak Validation

Phase 6 turns `BackendParitySemanticsPlan` into backend-private runtime
validation diagnostics and routes true GPU-backed soak work to the Period32+
validation matrix.

Status: completed for runtime validation-plan and diagnostics output. Long-run
GPU soak loops, device-matrix validation, and unresolved copy/format edge
semantics remain Period32+ work.

## Scope

- Add opt-in stability diagnostics derived from soak descriptors.
- Keep partial mip/layer semantics documented as portable runtime behavior.
- Keep depth/stencil/MSAA copy expansion and custom border-color expansion
  routed to Period32+ validation until backend semantics are proven on real
  devices.

## Validation

- Add focused core/runtime tests for parity diagnostics and deferred driver
  validation routing.
- Keep typed unsupported behavior for parity cases that remain intentionally
  outside the portable API.

## Deferred

- Long-running native validation on supported CI or local hosts is deferred to
  Period32+ validation matrix work.
