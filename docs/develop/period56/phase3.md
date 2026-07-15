# Period 56 Phase 3: Pipeline And Drawable Validation

Status: complete.

## Exact Current-Drawable Contract

The current drawable has `Swapchain.selectedFormat()`, not
`Swapchain.presentationDescriptor().format`. A render pipeline used with a
current-drawable color attachment must declare exactly that concrete format.
`automatic` is not valid as a pipeline color-attachment format.

The runtime records the pipeline's color-attachment formats and validates the
current-drawable slot against the selected presentation format before binding
the native pipeline or issuing a draw. Encoder creation may already have
acquired the current drawable, so this period does not promise rejection before
drawable acquisition. A mismatch returns the typed presentation-format
mismatch outcome. Metal and Vulkan must reject the same portable mismatch
before native pipeline bind or draw rather than relying on native validation
messages or undefined pixels.

This exact equality rule is intentionally stricter than the raw-copy
compatibility class used only by the Phase 4 legacy path. Render attachment
interpretation differs between `bgra8_unorm` and `bgra8_unorm_srgb`, so a
pipeline for one must not render into the other.

## Resize Interaction

After a successful resize, callers query `selectedFormat()` and recreate a
format-dependent pipeline when the selection changed. An old pipeline remains
a valid object, but encoding it against the new current drawable fails with the
typed mismatch before native work. The runtime must not patch, reinterpret, or
silently recreate caller pipelines.

Offscreen texture-view attachments retain their existing exact view/pipeline
format rules and do not consult the swapchain. No presentation request or
selection is added to `HeadlessContext`.

Focused tests cover request-versus-selected lookup and rejection before a
native pipeline bind or draw is recorded. Backend resolver tests cover exact
selection for both admitted SDR formats and automatic selection independent of
candidate order. A resize that re-queries or recreates native presentation
state resolves from the preserved request; a caller must query
`selectedFormat()` after successful recreation before reusing a
format-dependent pipeline. A healthy same-request Vulkan resize remains a
no-query no-op.

Drawable-sized resources use `Swapchain.extent()`, the actual selected native
extent, rather than `presentationDescriptor().extent`, which remains the
request. The legacy drawable RT route validates its dispatch and caller output
against that actual extent.
