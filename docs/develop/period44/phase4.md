# Phase 4: GPU Soak And Resource Churn

Status: complete for the executable bounded soak and deferred-lane inventory.
Metal and the Windows/NVIDIA Vulkan host passed the default 120-iteration run.
The configured Linux self-hosted Vulkan lane remains unexecuted.

## Soak Workload

`zig build run-gpu-soak -- --iterations=<count>` is opt-in and executes real
backend work on a windowed GPU host:

- alternating presentation extents and clears;
- per-iteration buffer and texture creation/destruction;
- buffer copy plus texture upload/readback verification;
- periodic embedded shader resolution churn;
- portable residency-map commit/evict churn beside the GPU work;
- runtime diagnostics sampling for live resources, pending retirements, and
  submitted/completed serials;
- fallback/native memory-budget classification.

The tool prints the current iteration before each scope of work and returns the
exact typed failure. It fails if readback differs, resources remain live after
an iteration, retirements do not drain, or work serials regress.
Failures print both the exact error name and broad error category, so an
observed `DeviceLost` or `SurfaceLost` remains distinguishable from validation
and unsupported-feature failures. The current Metal and Windows Vulkan runs
did not inject or observe device loss; that evidence remains open in the parity
report.

`scripts/ci/run_gpu_soak.sh` captures the capability dump and soak log as one
artifact bundle. The short CI/local smoke count is distinct from a release soak
count.

## Deferred Native Pressure Lanes

Native timeline/shared-event submit, physical dedicated queues, native heap
backing, sparse/tiled page binding, large descriptor tables, driver cache
persistence, and native RT stress count as soak evidence only after their
backend execution paths exist. Current planning/typed-unsupported results are
listed in the parity report and are not promoted to GPU proof.

Observed Metal result: 120 iterations, 15 resize events, 8 shader resolutions,
120 upload/readback cycles, 120 portable residency churn cycles, maximum 4 live
resources, and submitted/completed serial 120/120. The memory-budget source was
fallback with nominal pressure.

Observed Vulkan result at commit `e2a7362f` on Windows 10 build 19045 x86_64,
an NVIDIA GeForce RTX 5080, NVIDIA driver 610.62, and Vulkan API 1.4.341: 120
iterations, 15 resize events, 8 shader resolutions, 120 upload/readback cycles,
120 portable residency churn cycles, maximum 4 live resources, and
submitted/completed serial 120/120. The memory-budget source was fallback with
nominal pressure.
