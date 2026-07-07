# Phase 5: Multiple Render Targets

Phase 5 enables more than one color attachment in render passes and pipelines.

## Scope

- Lower multiple color attachments in Vulkan render pass creation.
- Lower multiple color attachments in Metal render pipeline and render pass
  descriptors.
- Validate attachment count, formats, sample counts, resolve targets, and store
  actions.
- Re-enable independent blend lowering once multiple color attachments exist.

## Status

Completed for texture-backed MRT render passes.

## Backend Notes

- Render pipelines now lower all public color attachment formats, write masks,
  and blend states to Vulkan and Metal.
- Independent blend is enabled on Metal and on Vulkan devices that expose native
  `independentBlend`.
- Texture-backed render passes support up to `default_max_color_attachments`
  color attachments with matching extents/sample counts and per-attachment
  resolve targets.
- Current-drawable render passes remain single-color until swapchain-backed MRT
  presentation semantics are designed.

## Validation

- Add tests for attachment-count and format mismatch errors.
- Add a small MRT example or backend smoke path.
