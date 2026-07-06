# Period 13: Multi-Surface / Presentation Backend

Status: planned.

Goal: make one selected device manage multiple presentation surfaces through
real Vulkan and Metal backend resources.

This period turns the earlier multi-surface API shape into production-grade
presentation behavior for multi-window tools and editors.

## Phase 1: Device-Owned Surface Registry

- Keep surface ownership under `Device` or a clearly documented presentation
  owner.
- Validate stale and destroyed surface handles.

See `phase1.md`.

## Phase 2: Multiple Swapchain / Drawable State

- Support multiple Vulkan swapchains.
- Support multiple Metal layers or drawable streams.

See `phase2.md`.

## Phase 3: Resize, Minimize, And Surface-Lost Handling

- Recreate presentation resources cleanly.
- Distinguish minimized windows from lost surfaces.

See `phase3.md`.

## Phase 4: Present Mode And Vsync Configuration

- Apply present mode selection per surface.
- Map vsync intent to backend-native presentation settings.

See `phase4.md`.

## Phase 5: Frame Pacing Baseline

- Add per-surface frame serials.
- Avoid one slow surface blocking unrelated surfaces unnecessarily.

See `phase5.md`.

## Phase 6: Multi-Window Example

- Add a public example with two windows sharing one device.

See `phase6.md`.
