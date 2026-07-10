# Phase 2: Metal And Vulkan Smoke Hosts

Status: complete for host definitions, smoke automation, and current evidence
inventory. Metal was observed locally; the physical Vulkan run is still
missing release evidence.

## Host Contract

The minimum GPU smoke pair is:

- Metal: Apple Silicon macOS host with a physical Metal device and an active
  window session. The repository's current local evidence host is recorded
  separately from the reusable self-hosted label.
- Vulkan: x86_64 Linux host with a physical Vulkan device, system loader/ICD,
  and an active X11 or Wayland session. MoltenVK is a useful optional lane but
  does not replace this native Vulkan evidence class.

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

Hosted build jobs and self-hosted GPU jobs remain separate workflows. A missing
physical Vulkan run is reported as missing evidence, not as success inferred
from compilation.

The current Metal smoke ran on macOS 15.7.3 arm64 with an Apple M4 Pro and
passed capability dump plus transfer, compute, and render readback. The Vulkan
host is documented/configured as a Linux x86_64 self-hosted runner labeled
`vkmtl-vulkan`; it was not available in this workspace.

See `runner-setup.md` for labels, prerequisites, local preflight, MoltenVK, and
artifact review.
