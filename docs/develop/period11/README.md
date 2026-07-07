# Period 11: Backend Capability Reality

Status: completed backend capability baseline.

Goal: make `DeviceFeatures`, `DeviceLimits`, and format capability reports
truthful by filling them from real backend queries.

This period is the gate before advanced backend work. After it lands, optional
features should either be supported by the selected backend or fail through a
specific unsupported-feature error before native work begins.

## Phase 1: Vulkan Capability Query

- Query Vulkan physical-device features, limits, extensions, queue families,
  and format capabilities.
- Record which Period 10 advanced modules are actually available.
- Keep MoltenVK differences explicit.

See `phase1.md`.

## Phase 2: Metal Capability Query

- Query Metal device families, feature sets where available, argument-buffer
  tiers, ray tracing support, sparse/tiled texture support, and binary archive
  support.
- Record platform-version limits separately from device limits.

See `phase2.md`.

## Phase 3: Unified Feature / Limit Fill Path

- Route backend-native query results into the public `DeviceFeatures` and
  `DeviceLimits` structs.
- Keep defaults conservative when a backend cannot prove support.

See `phase3.md`.

## Phase 4: Unsupported Feature Validation

- Validate advanced descriptors against features and limits before backend
  lowering.
- Return precise typed errors for unsupported optional features.

See `phase4.md`.

## Phase 5: Capability Dump Example

- Add an example that prints selected adapter, features, limits, and format
  capabilities through public APIs.
- Use it as a smoke test on every backend.

See `phase5.md`.

## Phase 6: Backend Capability Tests

- Add focused tests that verify feature gates are not accidentally hardcoded
  true.
- Add backend matrix notes for device-dependent expectations.

See `phase6.md`.
