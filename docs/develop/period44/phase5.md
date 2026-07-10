# Phase 5: Release Readiness And Parity Report

Status: complete. All 9 required evidence gates are observed and the explicit
readiness result is `release ready: true`.

## Release Gate

`zig build run-release-readiness` evaluates evidence classes rather than source
presence. A release-ready result requires:

- hosted build/test evidence for macOS, Linux, and Windows;
- physical Metal and Vulkan smoke evidence;
- automated Metal and Vulkan pixel-readback evidence;
- bounded Metal and Vulkan soak evidence;
- documented expected unsupported/planning-only/native-escape-hatch lanes.

Evidence flags are explicit command-line inputs. The default report is not
ready, so configuring a workflow cannot be confused with executing it.

GitHub Actions run
[29086828016](https://github.com/HissingRat/vkmtl/actions/runs/29086828016)
validated commit `e303a61` on `macos-15`, `ubuntu-24.04`, and `windows-2025`.
All three jobs passed formatting, 550/550 tests, their configured build, and the
validation-plan command, then uploaded the hosted evidence artifacts referenced
by `parity-report.md`.

## Current Parity Claim

The generated/static report records observed evidence, configured lanes,
missing device runs, known unsupported features, and native escape-hatch
requirements. It may conclude that vkmtl remains experimental even when Period
44's validation infrastructure is complete.

## Voxel-World Decision

The voxel-world pressure test remains deferred. Activating it requires native
heap/sparse residency or a documented non-sparse fallback, large binding-table
GPU evidence on both backends, automated representative pixels, and bounded
soak results. Building the shell before those gates would duplicate smaller
examples without proving the intended pressure characteristics.

See `parity-report.md` for the current observed/configured/missing evidence and
known unsupported/native-escape-hatch inventory.
