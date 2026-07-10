# Period 44 GPU Runner Setup

GPU validation accepts reviewed local physical-device artifacts and
self-hosted runner artifacts because hosted compilation is not physical-device
evidence. The Linux self-hosted Vulkan lane remains the reusable automated
baseline, while a local Windows/NVIDIA artifact bundle can satisfy the physical
Vulkan evidence class without claiming a Linux or hosted Windows artifact.

## Metal Runner

Required labels:

```text
self-hosted, macOS, ARM64, vkmtl-metal
```

Host requirements:

- Apple Silicon Mac with a Metal-capable physical device;
- logged-in GUI session able to create a GLFW window;
- Xcode command-line tools and network access for pinned package downloads;
- Zig 0.16.0, installed by the workflow or already available;
- enough free space for `.zig-cache`, `zig-out`, and evidence artifacts.

Local preflight:

```sh
zig build test
scripts/ci/run_gpu_smoke.sh metal artifacts/metal-smoke
scripts/ci/run_gpu_soak.sh metal 120 artifacts/metal-soak
```

## Vulkan Evidence Hosts

Physical Vulkan evidence may come from an x86_64 Linux or Windows host with a
native loader/vendor ICD and an active graphical desktop session.

### Linux Self-Hosted Runner

Required labels:

```text
self-hosted, Linux, X64, vkmtl-vulkan
```

Host requirements:

- x86_64 Linux host with a physical Vulkan device;
- Vulkan loader and vendor ICD visible to `vulkaninfo --summary`;
- active X11 or Wayland session available to the runner service account;
- GLFW build dependencies (`libx11`, RandR, Xinerama, Xcursor, Xi, Wayland,
  and xkbcommon development packages on Debian-family hosts);
- Zig 0.16.0 and network access for pinned package downloads.

Set `VK_ICD_FILENAMES` in the runner service environment when more than one ICD
is installed or the vendor ICD is not discovered automatically. Then run:

```sh
scripts/ci/run_gpu_smoke.sh vulkan artifacts/vulkan-smoke
scripts/ci/run_gpu_soak.sh vulkan 120 artifacts/vulkan-soak
```

This lane remains configured but was not executed for the current report.

### Windows Local Host

Host requirements:

- x86_64 Windows host with a physical Vulkan device;
- Vulkan loader and vendor ICD visible to `vulkaninfo --summary`;
- active desktop session able to create a GLFW window;
- Zig 0.16.0 and network access for pinned package downloads;
- a Bash-compatible shell for the reusable artifact scripts, or equivalent
  PowerShell command and log capture.

The reusable artifact sequence from Git Bash is:

```sh
scripts/ci/run_gpu_smoke.sh vulkan artifacts/vulkan-smoke
scripts/ci/run_gpu_soak.sh vulkan 120 artifacts/vulkan-soak
```

The current reviewed Windows evidence host used Windows 10 build 19045 x86_64,
an NVIDIA GeForce RTX 5080, NVIDIA driver 610.62, Vulkan API 1.4.341, Zig
0.16.0, and commit `e2a7362f`.

## Optional macOS MoltenVK Lane

MoltenVK is an additional Vulkan compatibility lane, not a replacement for a
native physical Vulkan evidence host. Configure:

```sh
export VKMTL_VULKAN_LOADER_DIR=/path/to/vulkan/lib
export VKMTL_VULKAN_ICD=/path/to/MoltenVK_icd.json
scripts/ci/run_gpu_smoke.sh vulkan artifacts/moltenvk-smoke
```

## Artifact Review

Do not mark a readiness flag from a queued job or workflow configuration. Check
that the artifact contains host identity, capability dump, workload log, and a
passed status file. Preserve the commit SHA and, for workflow-produced
evidence, the workflow URL. For reviewed local evidence, preserve the OS, GPU,
driver, and graphics API/runtime versions when updating `parity-report.md`.
