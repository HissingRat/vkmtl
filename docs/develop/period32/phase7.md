# Phase 7: Documentation And Period32+ Routing

Phase 7 closes the Vulkan ray traced scene period.

## Scope

- Update usage docs for the Vulkan ray tracing output path.
- Update API docs if public behavior changed.
- Route the full native mesh scene to Period33 and procedural/custom
  intersection support to Period34.
- Keep Metal and Vulkan support status separately documented.

## Acceptance

- Docs state that Period32 delivers native Vulkan AS/pipeline/SBT,
  `vkCmdTraceRaysKHR` submission, and first-scene output-image presentation.
- Docs do not claim broader ray tracing parity unless it actually landed.
- Follow-up ray tracing work is assigned to Period33, Period34, or later
  concrete Period32+ targets.
