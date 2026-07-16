# Period 56 Phase 5: Evidence And Closeout

Status: complete.

## Deterministic Evidence

Focused tests must lock:

- automatic preference order independent of native candidate order;
- exact explicit selection and no silent fallback;
- `presentationDescriptor().format` remaining the request while
  `selectedFormat()` is concrete;
- request preservation and selected-format re-resolution across resize;
- requested-versus-actual extent separation, same-request/recovery resize
  decisions, clear/resize active-command gates, and terminal Vulkan lifecycle;
- failed-commit retirement of backend state, query borrows, and work serials;
- exact pipeline/current-drawable validation before native pipeline bind or
  draw;
- caller-output use, graphics-queue restriction, and format-compatible
  raw-transfer validation for the legacy drawable RT path with both admitted
  selected formats;
- absence of HDR, tone-map, gamma, or gamut-conversion behavior in the
  presentation resolver and raw transfer.

Code review must additionally confirm Vulkan submitted-queue completion before
temporary-resource destruction, present-queue retirement before swapchain
teardown, and Metal pre-dispatch drawable/extent/staging ordering. Physical API
Validation covers the corresponding Metal success paths; those native ordering
properties are not claimed as failure-injection or drawable-readback unit tests.

Public API completion requires the API guard, focused and full tests, default
and forced Vulkan builds, package smoke, formatting, and `git diff --check`.
The public API inventory must record the additive `Swapchain` method and any
typed error additions. The native semantic inventory, API and usage docs,
migration guidance, validation matrices, roadmap, checklist, and changelog must
describe request, selection, resize, validation, and compatibility consistently.

## Physical Evidence Boundary

Physical Metal evidence must exercise the automatic sRGB selection and each
supported explicit SDR request. Deterministic bytes come from offscreen
readback; the same run must additionally encode, bind, and present a matching
selected current-drawable pipeline. Native layer-format readback and capability
reporting separately confirm `selectedFormat()`. The legacy RT route must use
the caller output before its raw transfer. API Validation should remain enabled
for the finite runs.

Forced Vulkan tests and builds must cover both portable selections, resolver
order, exact mismatch rejection, resize state, and shader/native compilation.
They are build and deterministic evidence only.

A supported Vulkan RT machine must run the finite `ray_traced_scene`
texture-presentation path and the legacy raw-transfer probe. Execution markers
alone do not accept a visually incorrect presentation result, and a quiet
stderr does not prove that the validation layer was enabled.

The finite legacy probe commands are:

```sh
MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_RT_FRAME_LIMIT=3 VKMTL_RT_LEGACY_DRAWABLE=1 VKMTL_PRESENTATION_FORMAT=srgb zig build run-ray-traced-scene
MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_RT_FRAME_LIMIT=3 VKMTL_RT_LEGACY_DRAWABLE=1 VKMTL_PRESENTATION_FORMAT=linear zig build run-ray-traced-scene
```

Use the same `VKMTL_RT_LEGACY_DRAWABLE=1` and frame limit with
`VKMTL_BACKEND=vulkan ... -Dvulkan` on the supported Vulkan RT machine. Without
the legacy variable, the example continues to validate the canonical texture
dispatch plus composition path.

## Deterministic Gate Record

The 2026-07-15 working-tree validation completed:

- `zig fmt --check build.zig src examples tools tests/package_consumer`;
- `zig build run-api-guard`, including the exact six-method `Swapchain`
  allowlist;
- `zig build run-semantic-inventory-check`;
- `zig build test --summary all`, with 675/675 tests passing;
- `zig build` and `zig build -Dvulkan`;
- `scripts/ci/run_package_smoke.sh`, with 1/1 consumer tests passing.

These commands prove portable validation and compilation. Physical Metal and
Vulkan evidence is recorded separately below and never inferred from those
build gates.

## Physical Metal Request-Mode Record

The explicit format runs completed under the physical Metal backend:

```sh
MTL_DEBUG_LAYER=1 VKMTL_PRESENTATION_FORMAT=srgb VKMTL_BACKEND=metal zig build run-pixel-regression
MTL_DEBUG_LAYER=1 VKMTL_PRESENTATION_FORMAT=linear VKMTL_BACKEND=metal zig build run-pixel-regression
MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_PRESENTATION_FORMAT=automatic zig build run-pixel-regression
```

All three printed
`max_channel_delta=0 presentation_max_channel_delta=1`. Those bytes are
offscreen readbacks, including the offscreen shared-display transform; they are
not drawable readback. After the readbacks, the regression also encodes, binds,
and presents a matching selected current-drawable pipeline. This separately
provides actual drawable pipeline/present smoke under each request mode.

Every command printed `Metal API Validation Enabled` for all three
pixel-regression segments. Native `CAMetalLayer.pixelFormat` readback separately
supplies the selected format. The linear capability probe also printed
`requested=bgra8_unorm, selected=bgra8_unorm`, with only the linear format
reporting `presentation = true`. An unsupported
`VKMTL_PRESENTATION_FORMAT` value is example-only input handling: the shared example glue prints
`Ignoring unsupported ...` and uses `.automatic`. It is not evidence for the
library's explicit-request no-fallback rule; that rule is covered by the
focused resolver tests.

Both physical legacy commands printed `Presentation path:
legacy_drawable_raw_copy`, `trace_driver_submitted=true`, and
`ray traced scene finite run ok: backend=metal frames=3` with no Metal API
Validation error. The existing `metal_table_entries=0/runtime_ready=false`
diagnostic describes the separate function-table route and is not promoted by
this evidence.

## Physical Vulkan Record

The 2026-07-16 post-AS-sizing reruns selected the expected canonical and legacy
paths. Both built BLAS/TLAS objects, submitted 518400 rays, reported
`trace_driver_submitted=true` and `runtime_ready=true`, and completed three
frames without an error, warning, or VUID in the supplied stderr.

The legacy raw-copy screenshot has the established orientation and closes that
physical compatibility route. The first canonical screenshot exposed a full
vertical flip in the fullscreen composition stage. After the
fragment-position UV fix, the canonical path completed 3000 frames and its new
screenshot has the same top-left orientation as the accepted compatibility
result. Both physical visual routes are therefore accepted. The logs contain
no positive validation-layer-enabled marker and no device/driver identity;
this record does not claim either. See `vulkan-physical-evidence.md` for the
exact markers and screenshot comparisons.

The updated asymmetric 5x2 physical Vulkan pixel regression remains a required
release-matrix lane. It is separate from, and does not reopen, the accepted RT
visual routes.
