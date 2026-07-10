# Period 44 Backend Capability And Parity Report

Snapshot date: 2026-07-10.

Status: validation infrastructure and all nine release-evidence gates complete.

## Release Gate Summary

| Gate | Current evidence | Status |
| --- | --- | --- |
| Hosted macOS build/test | `macos-15` ARM64, Zig 0.16.0, 550/550 tests, default build, validation plan; artifact `8225103999` | Observed |
| Hosted Linux build/test | `ubuntu-24.04` x86_64, Zig 0.16.0, 550/550 tests, forced-Vulkan build, validation plan; artifact `8225115120` | Observed |
| Hosted Windows build/test | `windows-2025` x86_64, Zig 0.16.0, 550/550 tests, forced-Vulkan build, validation plan; artifact `8225231713` | Observed |
| Physical Metal smoke | macOS 15.7.3 arm64, Apple M4 Pro | Observed |
| Physical Vulkan smoke | Windows 10 19045 x86_64, RTX 5080, NVIDIA 610.62, Vulkan 1.4.341 | Observed |
| Metal pixel regression | Transfer, compute, and offscreen render passed; max render channel delta 0 | Observed |
| Vulkan pixel regression | Transfer, compute, and offscreen render passed; max render channel delta 1 | Observed |
| Metal bounded soak | 120 iterations passed | Observed |
| Vulkan bounded soak | 120 iterations passed on the Windows/NVIDIA host | Observed |

Current explicit readiness result: 9/9 gates observed, `release ready: true`.

## Observed Evidence

Hosted build/test evidence was collected at commit `e303a61` by GitHub Actions
run [29086828016](https://github.com/HissingRat/vkmtl/actions/runs/29086828016).
All three jobs completed successfully and uploaded their `build.log` bundles:

- [`hosted-macos-15`, artifact 8225103999](https://github.com/HissingRat/vkmtl/actions/runs/29086828016/artifacts/8225103999);
- [`hosted-ubuntu-24.04`, artifact 8225115120](https://github.com/HissingRat/vkmtl/actions/runs/29086828016/artifacts/8225115120);
- [`hosted-windows-2025`, artifact 8225231713](https://github.com/HissingRat/vkmtl/actions/runs/29086828016/artifacts/8225231713).

The Metal GPU evidence was collected from a Period 44 worktree based on commit
`d9be332`, using Zig 0.16.0 on macOS 15.7.3 arm64 with an Apple M4 Pro. The
Vulkan evidence was collected at commit `e2a7362f`, using Zig 0.16.0 on Windows
10 build 19045 x86_64 with an NVIDIA GeForce RTX 5080, NVIDIA driver 610.62,
and Vulkan API 1.4.341.

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
- `scripts/ci/run_gpu_smoke.sh vulkan ...`: capability dump, exact transfer
  readback, exact compute readback, and render pixel readback passed on the
  Windows/NVIDIA host.
- Vulkan render pixel regression passed its clear and center samples with
  maximum channel delta 1; configured tolerances remain 2 and 12.
- `run-gpu-soak -- --backend=vulkan --iterations=120`: 15 resize events, 8
  shader resolutions, 120 upload/readback cycles, 120 portable residency churn
  cycles, maximum 4 live resources, and submitted/completed serial 120/120.
- The Vulkan memory-budget source was also `fallback` with `nominal` pressure;
  this is not native Vulkan memory-budget proof.
- Before the hosted run, a local Linux build preflight also passed from the
  validation worktree in
  Debian 13.5 under WSL2, using Zig 0.16.0 installed and selected through zvm:
  `zig fmt --check`, 550/550 tests, all 54 forced-Vulkan build steps, and the
  validation-plan command passed. It remains local preflight evidence rather
  than physical Linux Vulkan-device evidence; the hosted Linux gate is
  satisfied independently by run 29086828016.

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

## Remaining Non-Gate Evidence And Release Decision

- The GitHub hosted workflow produced fresh macOS, Linux, and Windows artifacts
  for commit `e303a61`; all three required hosted build/test gates are observed.
- The configured Linux x86_64 self-hosted Vulkan lane has not executed. The
  reviewed Windows/NVIDIA run now satisfies the physical Vulkan smoke, pixel,
  and bounded-soak evidence classes, but does not claim a physical Linux GPU
  runtime observation.
- The separate carry-over Vulkan RT visual gate was also observed on this host
  and is closed in `docs/develop/period32/phase6.md`; it is not counted as one
  of the nine Period 44 release-readiness flags.
- Longer multi-hour soak, device-loss injection, native memory pressure,
  physical async queues, sparse residency, large binding tables, native cache
  persistence, and native RT stress remain unavailable until their backend
  paths and suitable hosts exist.

The soak runner prints exact errors plus `device_lost`, `surface_lost`,
`validation`, `unsupported_feature`, or other broad categories. No device-loss
event was injected or observed in the current Metal or Windows Vulkan run.

Therefore the explicit Period 44 release-readiness gate is satisfied. vkmtl
remains experimental, and planning-only or typed-unsupported features remain
outside the supported parity claim rather than being promoted by this result.

## Voxel-World Pressure Test Decision

Remain deferred. Activation requires both-backend pixel and soak evidence,
native heap/sparse residency or an explicit non-sparse fallback, large binding
table pressure evidence, and a bounded workload budget. The current smaller
render/readback/soak cases give better isolated failures and should remain the
release gate until those prerequisites are met.
