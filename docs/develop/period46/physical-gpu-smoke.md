# Period 46 Physical GPU Smoke

The native query and specialization regression is part of the existing
offscreen pixel lane. Run it from a clean checkout of the commit under test.

## Metal

```sh
VKMTL_BACKEND=metal zig build run-pixel-regression
scripts/ci/run_gpu_smoke.sh metal artifacts/period46-metal
```

## Vulkan

Configure the loader/ICD as required by the host, then run:

```sh
export VKMTL_BACKEND=vulkan
export VKMTL_VULKAN_LOADER_DIR=/path/to/loader-directory
export VKMTL_VULKAN_ICD=/path/to/icd.json

zig build run-pixel-regression \
  -Dvulkan \
  -Dvulkan-loader-dir="$VKMTL_VULKAN_LOADER_DIR" \
  -Dvulkan-icd="$VKMTL_VULKAN_ICD"

scripts/ci/run_gpu_smoke.sh vulkan artifacts/period46-vulkan
```

## Required Observations

When `occlusion_queries` is usable, output must contain:

```text
native occlusion regression ok visible=<nonzero> empty=0
native query reset/reuse regression ok
```

The regression performs both CPU readback and GPU resolve and fails if their
two-value arrays differ. It runs the pass twice around a reset. The offscreen
shader has a default specialization value that would produce black output;
the pipeline supplies numeric ID 7 with value 1.0, so the final non-black pixel
regression also proves native function/specialization-constant application.

When a device reports a complete native timestamp lane, output must also
contain two raw ticks with `end > begin` and `source=native_gpu`. A device that
lacks the full gate must omit this line and report `logical_sequence` in the
capability dump. That is valid gate evidence, not native timestamp execution
evidence.

Record `git rev-parse HEAD`, a clean-worktree check, the capability dump, smoke
output, and final status. Vulkan validation-layer output must contain no query
VUIDs.
