# Period 44: CI, Device Matrix, And Soak Validation

Status: planned after Period43.

Goal: turn the parity work into something trustworthy by validating examples,
feature gates, screenshots, readbacks, and long-running workloads across a
documented backend/device matrix.

## Expected Result

After Period44, vkmtl should have a practical validation matrix for supported
Metal and Vulkan setups, including automated build/test coverage, GPU smoke
runs where available, screenshot or pixel regression for representative
examples, and long-running soak tests for resource churn.

## Phase Plan

### Phase 1: CI Job Matrix And Feature Reporting

- Define host OS, target OS, backend, and device classes.
- Record unsupported features as expected matrix outcomes.
- Keep capability dump output attached to failures.

### Phase 2: Metal And Vulkan Smoke Hosts

- Add or document at least one Metal smoke host.
- Add or document at least one Vulkan smoke host.
- Separate local-only GPU runs from ordinary CPU-only CI.

### Phase 3: Screenshot And Pixel Regression Harness

- Add screenshot or pixel readback checks for representative examples.
- Track expected tolerances for Vulkan/Metal differences.
- Keep visual tests deterministic where possible.

### Phase 4: GPU Soak And Resource Churn Tests

- Add long-running presentation, shader, resource, and residency churn runs.
- Record memory pressure, queue sync, and device-loss behavior.
- Keep soak failures actionable and scoped.

### Phase 5: Release Readiness And Parity Report

- Produce a backend capability/parity report from current test data.
- Document known unsupported items and native escape hatch requirements.
- Decide whether the voxel-world pressure test can move from deferred to active.

## Acceptance

- CI/build matrix reflects supported and unsupported backend paths.
- Representative GPU examples have visual or pixel validation.
- Long-run tests produce repeatable diagnostics.
- vkmtl can make a measured, evidence-backed parity claim.
