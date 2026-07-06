# Phase 3: Metal Acceleration Structure And Intersection Lowering

Phase 3 implements Metal ray tracing lowering.

## Scope

- Create Metal acceleration structures where supported.
- Map intersection functions and ray tracing function tables.
- Handle Metal resource usage and synchronization requirements.

## Validation

- Tests should cover feature-gated failure paths.
- Metal smoke tests should trace a visible primitive on supported devices.
