# Period 14: Native Interop / External Resources

Status: completed native-handle, descriptor, validation, and feature-gate
scaffold. Executable external resource import and native command insertion are
tracked in Period 25.

Goal: define explicit interop shapes for platform APIs, engines, UI frameworks,
and media pipelines while keeping native handles out of ordinary portable
paths.

Interop is always intentional. Applications should request external resources
or native handles explicitly and accept the portability risks documented by the
API.

Historical note: this period records the public ownership and validation model.
Period 25 is the current source of truth for native external memory/texture,
shared-event, and command-insertion backend closure.

## Phase 1: Native Handle View Stabilization

- Stabilize borrowed native handle views.
- Document lifetimes and mutation rules.
- Add a backend-tagged `NativeHandleView` wrapper for borrowed read-only access.

See `phase1.md`.

## Phase 2: Vulkan External Memory / Image / Semaphore Interop

- Import and export Vulkan external memory, images, and semaphores where
  supported.
- Add validation shapes for Vulkan external memory/image/semaphore handle kinds.

See `phase2.md`.

## Phase 3: Metal Texture / Buffer / Event Interop

- Import and wrap Metal textures, buffers, and events where supported.
- Add Metal buffer and shared-event descriptor validation with explicit borrowed
  ownership.

See `phase3.md`.

## Phase 4: External Texture Creation Path

- Create vkmtl textures from external texture descriptors.
- Keep backend-specific handle kinds capability-gated.
- Add a runtime `ExternalTexture` wrapper with validation and lifetime tracking.

See `phase4.md`.

## Phase 5: Native Command Insertion Hooks

- Provide controlled hooks for backend-native command insertion.
- Add descriptor-level hooks with explicit callback, encoder kind, insertion
  point, and resource-boundary metadata.

See `phase5.md`.

## Phase 6: External Texture Example

- Add an example that samples from an imported or externally provided texture.
- Provide the current feature-gated `examples/external_texture` wrapper smoke
  path until native sampling import lands.

See `phase6.md`.
