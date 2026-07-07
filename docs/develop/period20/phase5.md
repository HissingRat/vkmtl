# Phase 5: Multiple Render Targets

Phase 5 enables more than one color attachment in render passes and pipelines.

## Scope

- Lower multiple color attachments in Vulkan render pass creation.
- Lower multiple color attachments in Metal render pipeline and render pass
  descriptors.
- Validate attachment count, formats, sample counts, resolve targets, and store
  actions.
- Re-enable independent blend lowering once multiple color attachments exist.

## Validation

- Add tests for attachment-count and format mismatch errors.
- Add a small MRT example or backend smoke path.
