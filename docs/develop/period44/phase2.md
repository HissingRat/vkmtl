# Phase 2: Metal And Vulkan Smoke Hosts

Status: complete for host definitions, smoke automation, and current evidence
inventory. Metal and physical Windows Vulkan runs were observed locally; the
configured Linux self-hosted Vulkan lane remains unexecuted.

## Host Contract

The minimum GPU smoke pair is:

- Metal: Apple Silicon macOS host with a physical Metal device and an active
  window session. The repository's current local evidence host is recorded
  separately from the reusable self-hosted label.
- Vulkan: x86_64 Linux or Windows host with a physical Vulkan device, native
  loader/vendor ICD, and an active graphical desktop session. The Linux
  self-hosted runner remains the reusable automation lane, while a reviewed
  local Windows artifact bundle may satisfy the physical Vulkan evidence
  class. MoltenVK is useful optional coverage but does not replace a native
  physical Vulkan host.

The reusable self-hosted labels are `vkmtl-metal` and `vkmtl-vulkan` in addition
to GitHub's standard `self-hosted`, OS, and architecture labels.

## Smoke Sequence

`scripts/ci/run_gpu_smoke.sh <metal|vulkan> <artifact-dir>` performs:

1. host, Zig, and backend environment capture;
2. capability dump;
3. transfer buffer/texture readback;
4. compute buffer/texture readback;
5. render pixel regression.

All commands use `VKMTL_BACKEND`; Vulkan also uses `-Dvulkan`. Optional macOS
MoltenVK paths come from `VKMTL_VULKAN_LOADER_DIR` and
`VKMTL_VULKAN_ICD`.

Hosted build jobs and physical GPU evidence remain separate classes. A local
Windows GPU run does not satisfy the hosted Windows build/test gate, and a
configured but unexecuted Linux self-hosted lane is not reported as an
executed Linux artifact.

The current Metal smoke ran on macOS 15.7.3 arm64 with an Apple M4 Pro and
passed capability dump plus transfer, compute, and render readback. The Vulkan
smoke ran at commit `e2a7362f` with Zig 0.16.0 on Windows 10 build 19045 x86_64,
an NVIDIA GeForce RTX 5080, NVIDIA driver 610.62, and Vulkan API 1.4.341. It
passed capability dump plus transfer, compute, and render readback. The Linux
x86_64 self-hosted runner labeled `vkmtl-vulkan` remains configured but has not
executed.

See `runner-setup.md` for labels, prerequisites, local preflight, MoltenVK, and
artifact review.
