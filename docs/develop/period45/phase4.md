# Phase 4: Ownership, Evidence, And Drift Checks

Status: complete. The drift check is part of `zig build test` and also has a
dedicated `run-semantic-inventory-check` step.

## Ownership And Evidence

- Existing public semantics link to their canonical facade and runtime/backend
  implementation.
- Missing public semantics identify the likely domain without admitting a new
  declaration.
- Evidence uses the inventory's inspection, unit, GPU smoke, GPU pixels, GPU
  soak, or missing classes.
- Native feature queries, planning tests, and hosted compilation never count as
  physical GPU execution.

## Drift Checks

Add a deterministic repository check that verifies:

- semantic IDs are unique;
- coverage and evidence tokens use the approved vocabulary;
- every current `DeviceFeatures` field appears in the inventory mapping;
- every mapping references a real semantic ID;
- incomplete/unsupported rows are not labeled executable.

The check validates inventory shape, not the truth of native execution. Code
inspection and GPU evidence remain required for status changes.

## Acceptance

- The drift check runs through `zig build` and CI-compatible hosts.
- Intentional capability additions fail until the inventory changes with them.
- The public API guard baseline remains unchanged unless a later implementation
  period separately admits new API.

The check validates 86 feature fields, 54 feature-family inventory IDs, 99
Metal semantic IDs, 78 Metal protocol mappings, approved status/evidence
tokens, and exactly-once routing for all 77 incomplete rows.
