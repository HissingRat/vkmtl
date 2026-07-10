# Period 44 GPU Runner Setup

GPU validation uses self-hosted runners because hosted compilation is not
physical-device evidence.

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

## Vulkan Runner

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

## Optional macOS MoltenVK Lane

MoltenVK is an additional Vulkan compatibility lane, not a replacement for the
Linux physical Vulkan gate. Configure:

```sh
export VKMTL_VULKAN_LOADER_DIR=/path/to/vulkan/lib
export VKMTL_VULKAN_ICD=/path/to/MoltenVK_icd.json
scripts/ci/run_gpu_smoke.sh vulkan artifacts/moltenvk-smoke
```

## Artifact Review

Do not mark a readiness flag from a queued job or workflow configuration. Check
that the artifact contains host identity, capability dump, workload log, and a
passed status file. Preserve the workflow URL and commit SHA alongside the
artifact when updating `parity-report.md`.
