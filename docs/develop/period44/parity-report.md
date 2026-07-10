# Period 44 Backend Capability And Parity Report

Snapshot date: 2026-07-10.

Status: validation infrastructure complete; release evidence incomplete.

## Release Gate Summary

| Gate | Current evidence | Status |
| --- | --- | --- |
| Hosted macOS build/test | Workflow configured, not executed in this workspace | Missing artifact |
| Hosted Linux build/test | Workflow configured, not executed in this workspace | Missing artifact |
| Hosted Windows build/test | Workflow configured, not executed in this workspace | Missing artifact |
| Physical Metal smoke | macOS 15.7.3 arm64, Apple M4 Pro | Observed |
| Physical Vulkan smoke | Linux self-hosted lane configured | Missing device run |
| Metal pixel regression | Transfer, compute, and offscreen render passed; max render channel delta 0 | Observed |
| Vulkan pixel regression | Linux self-hosted lane configured | Missing device run |
| Metal bounded soak | 120 iterations passed | Observed |
| Vulkan bounded soak | Linux self-hosted lane configured | Missing device run |

Current explicit readiness result: 3/9 gates observed, `release ready: false`.

## Observed Local Evidence

The current Period 44 worktree is based on commit `d9be332` and was exercised
with Zig 0.16.0 on macOS 15.7.3 arm64 using an Apple M4 Pro.

- `zig build test --summary all`: 550/550 tests passed at the first Period 44
  integration checkpoint.
- `scripts/ci/run_gpu_smoke.sh metal ...`: capability dump, transfer readback,
  compute readback, and render pixel readback passed.
- Render pixel regression: clear and center samples passed with maximum channel
  delta 0; configured tolerances remain 2 and 12.
- `run-gpu-soak -- --backend=metal --iterations=120`: 15 resize events, 8
  shader resolutions, 120 upload/readback cycles, 120 portable residency churn
  cycles, maximum 4 live resources, and submitted/completed serial 120/120.
- Memory-budget source remained `fallback` and pressure was `nominal`; this is
  not native Metal memory-budget proof.

Raw GPU logs are workflow/local artifacts rather than committed source. The
reusable artifact layout is produced by `scripts/ci/`.

## Current Backend Expectations

| Feature | Vulkan | Metal |
| --- | --- | --- |
| Object/encoder debug markers | Capability-gated native debug utils | Native |
| Command-buffer markers | Validation-only | Native |
| Native GPU timestamps | Typed unsupported | Typed unsupported |
| Scaled texture blit | Capability-gated | Typed `UnsupportedTextureBlit` |
| Pipeline statistics queries | Typed unsupported | Typed unsupported |
| Native heap-backed resources | Planning-only | Planning-only |
| Native sparse/tiled page binding | Planning-only | Planning-only |
| Native external resource import | Planning-only | Planning-only |
| Physical dedicated queues | Planning-only/fallback | Planning-only/fallback |
| Ray query | Capability-gated | Typed unsupported |
| Native handles | Explicit borrowed escape hatch | Explicit borrowed escape hatch |

Planning-only and validation-only rows are not GPU parity. Capability-gated
rows require the selected device report plus an executed path.

## Native Escape-Hatch Requirements

Applications using `NativeHandles` must keep the owning `WindowContext` alive,
must branch on the tagged backend, and accept that the code is no longer
portable. Native command insertion remains disabled until command-handle views
have a validated lifetime contract. External resource handles require explicit
backend/platform ownership and import support; current wrappers do not prove
native import.

## Missing Evidence And Release Decision

- The GitHub hosted workflow files are configured but have not produced run
  artifacts in this workspace.
- No physical Linux Vulkan loader/ICD/device was available here, so Vulkan
  smoke, pixels, soak, and the carry-over Vulkan RT visual gate remain open.
- Longer multi-hour soak, device-loss injection, native memory pressure,
  physical async queues, sparse residency, large binding tables, native cache
  persistence, and native RT stress remain unavailable until their backend
  paths and suitable hosts exist.

The soak runner prints exact errors plus `device_lost`, `surface_lost`,
`validation`, `unsupported_feature`, or other broad categories. No device-loss
event was injected or observed in the current Metal run.

Therefore vkmtl remains experimental and is not ready for a compatibility or
parity release.

## Voxel-World Pressure Test Decision

Remain deferred. Activation requires both-backend pixel and soak evidence,
native heap/sparse residency or an explicit non-sparse fallback, large binding
table pressure evidence, and a bounded workload budget. The current smaller
render/readback/soak cases give better isolated failures and should remain the
release gate until those prerequisites are met.
