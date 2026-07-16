# Period 56: Presentation Format Request And Selection

Status: complete. Phases 1-5, deterministic validation, the physical Metal
request-mode offscreen-pixel plus selected-drawable smoke matrix, and both
Metal legacy RT routes are recorded. Vulkan legacy raw-copy execution and
visual orientation are recorded, and the corrected canonical composition
completed 3000 physical frames with the established top-left orientation.

Goal: make the presentation format request observable and make the selected
drawable format deterministic. `PresentationDescriptor.format` remains the
application request. `Swapchain.presentationDescriptor()` returns that request,
while the additive, presentation-owned `Swapchain.selectedFormat()` query
returns the concrete format selected for the current native swapchain or Metal
layer.

The same owner already exposes the extent pair without adding another method:
`Swapchain.presentationDescriptor().extent` is the requested extent, while
`Swapchain.extent()` is the actual native presentation extent selected after
surface constraints.

The bounded portable format set for this period is SDR
`bgra8_unorm_srgb` and `bgra8_unorm`. Automatic selection prefers sRGB and then
linear UNORM, independent of backend enumeration order. An explicit request
must be honored exactly or fail with a typed error; it never silently falls
back to another format.

## Phase Plan

### Phase 1: Contract And API Allocation

- Freeze request versus selected semantics and the deterministic SDR order.
- Allocate `Swapchain.selectedFormat()` without growing the root, `Device`,
  `WindowContext`, or `HeadlessContext` surfaces.
- Define the typed unsupported and mismatch outcomes and the `v0.2.0`
  compatibility boundary.

See `phase1.md`.

### Phase 2: Backend Resolution And Resize

- Resolve the same request deterministically on Metal and Vulkan.
- Keep the original request across resize and re-resolve the selected format
  on every native recreation.
- Publish the actual native extent separately from the requested descriptor
  extent.
- Keep healthy same-request resize cheap, while present/acquire recovery state
  forces a same-request rebuild and changed requests re-query native state.
- Remove Vulkan's unobservable first-format fallback and make Metal configure
  the layer with the selected format and publish resize state only after depth
  allocation succeeds.

See `phase2.md`.

### Phase 3: Pipeline And Drawable Validation

- Use the selected format, never the request, as the current drawable's format.
- Require an exact render-pipeline/current-drawable format match before native
  pipeline bind or draw.
- Make a selected-format change after resize observable before the next frame.
- Reject a Vulkan resize while an uncommitted backend command buffer could
  still reference old presentation resources, and make a destructive recreation
  failure terminal for that presentation runtime.
- Apply the same pre-mutation active-command gate to Vulkan clear, keep clear
  commands on a dedicated pool, and retire backend/query/serial state after a
  failed command-buffer commit.

See `phase3.md`.

### Phase 4: Legacy Ray Dispatch Compatibility

- Keep `dispatchRaysToDrawable(...)` only as a compatibility path.
- Make both backends dispatch into the caller-provided output, then perform
  only a format-compatible raw transfer to the drawable.
- Restrict the legacy dispatch/present command to the graphics queue and
  preflight Metal drawable/staging failures before compute encoding.
- Keep `dispatchRaysToTexture(...)` plus explicit composition as the canonical
  path for new code.

See `phase4.md`.

### Phase 5: Evidence And Closeout

- Lock deterministic resolver, resize, validation, and raw-transfer tests.
- Record physical Metal pixel evidence and forced Vulkan build evidence.
- Record supported-hardware Vulkan RT execution without inferring it from
  forced builds, and keep visual acceptance separate from submission markers.

See `phase5.md`.

The implementation and validation record is summarized in `closeout.md`.
`vulkan-physical-evidence.md` records the successful legacy route, the
canonical vertical-flip finding, its correction, and the accepted rerun.

## Non-Goals

vkmtl does not add HDR formats, HDR metadata, tone mapping, gamut conversion,
or color-management policy in this period. It selects one of the two admitted
SDR formats and validates caller objects against that selection. Applications
own every content transform.

## Compatibility

The declaration change is additive and targets `v0.2.0`: one canonical method
is added to `Swapchain`. No existing declaration, method, field, enum tag,
default, owner, or signature is removed or renamed. Exact enforcement of an
explicit format request also lands only at the `v0.2.0` boundary because a
previously ignored or silently substituted request may now return a typed
error. The legacy drawable RT method remains present but is compatibility-only.
