# Native API Validation

Use native validation while developing backend or command-encoding changes.
Validation is separate from vkmtl's typed descriptor checks, pixel regression,
GPU soak, and capture scopes: each catches a different class of failure.

## Vulkan Validation Layer

Install the Vulkan SDK or distribution package that provides
`VK_LAYER_KHRONOS_validation`, then verify that the loader can discover it:

```sh
vulkaninfo --summary
vulkaninfo 2>&1 | grep VK_LAYER_KHRONOS_validation
```

In Debug builds, vkmtl checks whether that layer is available. When it is
available, vkmtl enables it together with `VK_EXT_debug_utils` and records
general, validation, and performance warning/error messages through the
`validation` log scope. When the layer is absent, Debug execution continues
without the layer; layer installation is therefore part of the validation
preflight rather than an application startup requirement. Non-Debug builds do
not request the layer.

If the SDK is installed outside the loader's normal search path, configure the
SDK environment before running vkmtl. `VK_LAYER_PATH` may be used for a focused
local setup, but it must name the directory containing the matching layer
manifest and library. Do not point it at an unrelated SDK version. Use
`VK_ICD_FILENAMES` separately only when selecting a particular vendor ICD is
necessary.

Representative Debug runs:

```sh
zig build run-triangle -Dvulkan -Doptimize=Debug
zig build run-pixel-regression -Dvulkan -Doptimize=Debug
scripts/ci/run_gpu_smoke.sh vulkan artifacts/vulkan-validation
```

Acceptance requires the workload to pass without validation errors. Preserve
the host summary, capability dump, application output, and the complete
validation message including its VUID. Validation warnings must be reviewed;
do not hide them merely to make a run green.

The Khronos documentation describes the unified validation layer and its
development-only performance cost:

- https://docs.vulkan.org/guide/latest/validation_overview.html
- https://docs.vulkan.org/guide/latest/layers.html

## Metal API Validation

Metal API Validation checks resource creation, command encoding, lifetime, and
other Metal API usage. It has a measurable CPU cost and is a development tool.

When running through Xcode:

1. Edit the active scheme.
2. Select the Run action and its Diagnostics tab.
3. Enable API Validation.
4. Enable Shader Validation as a separate pass when shader runtime behavior is
   in scope.

For a command-line run, the documented Metal validation environment can be
applied directly to the executable launched by the Zig build:

```sh
MTL_DEBUG_LAYER=1 zig build run-triangle -Doptimize=Debug
MTL_DEBUG_LAYER=1 zig build run-pixel-regression -Doptimize=Debug
MTL_DEBUG_LAYER=1 zig build run-external-import -Doptimize=Debug
```

`MTL_DEBUG_LAYER_ERROR_MODE=nslog` can be used when a log is preferable to the
default assertion behavior. Do not use `ignore` for acceptance evidence.

Apple's current validation options and environment variables are documented at:

- https://developer.apple.com/documentation/xcode/validating-your-apps-metal-api-usage
- https://developer.apple.com/documentation/xcode/validating-your-apps-metal-shader-usage/

The vkmtl `diagnostics.beginCaptureScope(...)` API controls a scoped Metal GPU
capture. Capture and API Validation are independent: a successful capture does
not prove API correctness, and validation does not preserve a replayable GPU
trace.

Acceptance requires the representative example and pixel regression to finish
without Metal API or Shader Validation errors. Preserve the complete message,
object label, encoder/command label, and the smallest reproducing command
sequence for failures.

For Period 53 interop, `run-external-import` additionally proves that borrowed
native owners outlive GPU copy/readback and that the IOSurface plane/format/
storage contract survives import. It is Metal evidence only.

## Validation Evidence Order

For backend changes, use this order:

1. `zig build test --summary all`;
2. Debug native API validation on the affected backend;
3. deterministic transfer, compute, and render pixel regression;
4. the affected visible example or ray tracing marker;
5. bounded GPU soak when resource lifetime, resize, or synchronization changed.

Native validation is required evidence for affected backend work, but it does
not replace capability gates or physical-device results.
