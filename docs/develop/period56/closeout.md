# Period 56 Closeout

Status: complete.

## Result

Period 56 separates the application request from the native presentation
selection. `PresentationDescriptor.format` remains the original request,
including `.automatic`, while `Swapchain.selectedFormat()` returns the concrete
selected SDR format. Automatic selection prefers `bgra8_unorm_srgb`, then
`bgra8_unorm`, independent of Vulkan enumeration order. Either explicit format
must be selected exactly or initialization/recreation returns
`UnsupportedPresentationFormat`.

Metal maps the selection to `CAMetalLayer.pixelFormat`. Vulkan maps it to the
exact BGRA8 format with `VK_COLOR_SPACE_SRGB_NONLINEAR_KHR`; it no longer hides
an arbitrary first-format fallback. Successful non-zero resize preserves the
format request and publishes the selected format. Metal allocates replacement
depth state before publishing a new drawable extent. Vulkan rebuilds
format-dependent render-pass resources only when native recreation requires
it.

The requested/selected split also covers extent. The descriptor retains the
requested extent, while `Swapchain.extent()` reports the current actual native
drawable extent after surface constraints. Vulkan `currentExtent` or clamping
may make those values differ. A healthy zero-size resize preserves the last
successful request, actual extent, and selected format.

For Vulkan, an unchanged healthy requested extent is a cheap no-op. A
queue-present or next-image-acquire `SUBOPTIMAL`/`OUT_OF_DATE` result marks
recovery required, making the next resize rebuild even for that same request.
A changed requested extent re-queries native presentation state; when the
resolved native configuration is unchanged and no recovery flag is set, vkmtl
records the request without rebuilding the swapchain.

Vulkan refuses every non-zero resize and every `Swapchain.clear(...)` while an
uncommitted backend command buffer exists, returning
`InvalidCommandBufferState` before native mutation. Clear commands use a
dedicated internal command pool; recording a clear never resets a pool that
owns caller command buffers. If native recreation or dependent rebuilding then
fails, the failing call returns its original error, presentation resources are
torn down permanently, and every later resize (including zero), clear, or new
command-buffer creation returns `SurfaceLost`. The caller must recreate
`WindowContext`.

Both normal and poisoned teardown wait graphics fences and the presentation
queue before destroying swapchain images, semaphores, or the swapchain handle;
a graphics fence alone does not retire `vkQueuePresentKHR` consumption.

A failed runtime commit terminalizes and deinitializes its backend command
buffer, releases its active-command count and query-set resolve borrows,
completes its work serial, and reports lifecycle status `failed`. If a Vulkan
submission occurred before a later commit failure, Vulkan waits that queue
before destroying command-buffer-owned temporary resources.

Current-drawable render pipelines must declare the exact selected format. A
mismatch returns `PresentationFormatMismatch` before native pipeline bind or
draw. Offscreen texture attachments and `HeadlessContext` retain their existing
contracts.

## Legacy Ray Dispatch

`dispatchRaysToDrawable(...)` remains source-compatible but is now explicitly a
compatibility path. Both backends dispatch into the caller-provided
`bgra8_unorm` output, then copy its bytes to a selected linear or sRGB BGRA8
drawable and preserve the existing presentation side effect. The validation
requires shader-write and copy-source usage, a single-sample 2D whole texture,
exact dispatch/presentation extent, and a graphics queue. The copy performs no
EOTF/OETF, tone mapping, gamma correction, HDR mapping, or gamut conversion.

Metal performs drawable acquisition, drawable format/extent validation, and
any sRGB staging-buffer allocation before its compute encoder or dispatch.
Linear presentation allocates no staging buffer. These preflight failures leave
the command buffer free of an untracked encoded dispatch, and every later
failure releases an allocated staging buffer.

New code should use `dispatchRaysToTexture(...)` and an application-owned
composition pass whose pipeline format is `Swapchain.selectedFormat()`.
`examples/ray_traced_scene` keeps that route as its default and exposes the
legacy compatibility probe only when `VKMTL_RT_LEGACY_DRAWABLE=1` is set.
The legacy command includes its own presentation side effect; an explicit
`presentDrawable(...)` appended to the same command buffer returns
`InvalidCommandBufferState` instead of presenting twice.

## Public API And Compatibility

The only new method is the canonical `Swapchain.selectedFormat()`. The exact
owner surface is now six methods. Root 69, `Device` 34, `WindowContext` 10,
`HeadlessContext` six, `CommandBuffer` 22, and the 37 runtime-handle names and
layouts are unchanged. Total public functions in `window_context.zig` increase
from 452 to 453.

`UnsupportedPresentationFormat` and `PresentationFormatMismatch`, the additive
query, and exact explicit-request enforcement target `v0.2.0`. No existing
declaration, descriptor field/default, owner, or method is removed or renamed.

## Color Boundary

The presentation layer only selects and validates the existing SDR
`bgra8_unorm_srgb`/`bgra8_unorm` pair. vkmtl does not inspect scene content and
does not perform HDR conversion, exposure, tone mapping, gamma policy, gamut
conversion, or any other content transform. `PresentationDescriptor.format`
is a request; it is not a color-management pipeline.

The legacy drawable RT route is even narrower: it preserves raw bytes. An sRGB
destination changes how presentation interprets those bytes, but the copy does
not decode or encode them.

## Deterministic Evidence

The 2026-07-15 working tree completed:

- `zig fmt --check build.zig src examples tools tests/package_consumer`;
- `zig build run-api-guard` with root 69, `Device` 34,
  `WindowContext` 10, `HeadlessContext` six, `Swapchain` six, and 37 runtime
  handles;
- `zig build run-semantic-inventory-check`;
- `zig build test --summary all`, 675/675 tests passed;
- `zig build`;
- `zig build -Dvulkan`;
- `scripts/ci/run_package_smoke.sh`, 1/1 consumer tests passed;
- `git diff --check`.

Focused tests cover the bounded request set, Metal and Vulkan selection,
Vulkan candidate-order independence and undefined sentinel, selected-format
capabilities, Vulkan render-pass rebuild and terminal lifecycle decisions,
request-versus-selected format and requested-versus-actual extent state,
same-request/recovery resize decisions, clear/resize active-command gates,
failed-commit cleanup, exact current-drawable pipeline mismatch, legacy
drawable output usage/shape/format/extent/queue validation, and
duplicate-present rejection. Code review covers queue completion before
temporary-resource destruction, present-queue retirement before swapchain
teardown, and Metal pre-dispatch drawable/extent/staging ordering. Physical
Metal API Validation covers the corresponding Metal success paths.

## Physical Metal Evidence Recorded

The following physical Metal runs completed:

```sh
MTL_DEBUG_LAYER=1 VKMTL_PRESENTATION_FORMAT=srgb VKMTL_BACKEND=metal zig build run-pixel-regression
MTL_DEBUG_LAYER=1 VKMTL_PRESENTATION_FORMAT=linear VKMTL_BACKEND=metal zig build run-pixel-regression
MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_PRESENTATION_FORMAT=automatic zig build run-pixel-regression
```

Each printed `max_channel_delta=0 presentation_max_channel_delta=1` and
`Metal API Validation Enabled` for all three pixel-regression segments. The
reported bytes are deterministic offscreen readbacks; they are not read back
from the current drawable. After those checks, the regression separately
encodes, binds, and presents the selected current-drawable pipeline, providing
actual drawable pipeline/present smoke under each request. Metal reports the
selected layer format through a native `CAMetalLayer.pixelFormat` getter.

The native-selected linear probe also completed:

```sh
MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_PRESENTATION_FORMAT=linear zig build run-capability-dump
```

It printed `requested=bgra8_unorm, selected=bgra8_unorm`; only linear BGRA8
reported `presentation = true`, while sRGB reported false.

An invalid `VKMTL_PRESENTATION_FORMAT` string is handled only by example glue:
it prints a warning and requests `.automatic`. That convenience behavior is
not the library's explicit-request no-fallback contract.

The legacy RT caller-output/raw-transfer routes also completed:

```sh
MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_RT_FRAME_LIMIT=3 VKMTL_RT_LEGACY_DRAWABLE=1 VKMTL_PRESENTATION_FORMAT=srgb zig build run-ray-traced-scene
MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_RT_FRAME_LIMIT=3 VKMTL_RT_LEGACY_DRAWABLE=1 VKMTL_PRESENTATION_FORMAT=linear zig build run-ray-traced-scene
```

Both printed `Metal API Validation Enabled`, `Presentation path:
legacy_drawable_raw_copy`, `trace_driver_submitted=true`, and
`ray traced scene finite run ok: backend=metal frames=3`, with no validation
error. The existing `metal_table_entries=0/runtime_ready=false` diagnostic is
for the separate function-table route and is not evidence against the submitted
manual ray dispatch.

## Remaining Physical Follow-Up

The supported Vulkan RT machine must still run the finite Period 55
`ray_traced_scene` texture-presentation path and the Period 56 legacy raw-copy
probe. Forced Vulkan builds and earlier RT screenshots do not satisfy either
run.
