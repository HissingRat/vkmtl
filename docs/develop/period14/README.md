# Period 14: Native Interop / External Resources

Status: in progress.

Goal: support explicit interop with platform APIs, engines, UI frameworks, and
media pipelines while keeping native handles out of ordinary portable paths.

Interop is always intentional. Applications should request external resources
or native handles explicitly and accept the portability risks documented by the
API.

## Phase 1: Native Handle View Stabilization

- Stabilize borrowed native handle views.
- Document lifetimes and mutation rules.
- Add a backend-tagged `NativeHandleView` wrapper for borrowed read-only access.

See `phase1.md`.

## Phase 2: Vulkan External Memory / Image / Semaphore Interop

- Import and export Vulkan external memory, images, and semaphores where
  supported.

See `phase2.md`.

## Phase 3: Metal Texture / Buffer / Event Interop

- Import and wrap Metal textures, buffers, and events where supported.

See `phase3.md`.

## Phase 4: External Texture Creation Path

- Create vkmtl textures from external texture descriptors.
- Keep backend-specific handle kinds capability-gated.

See `phase4.md`.

## Phase 5: Native Command Insertion Hooks

- Provide controlled hooks for backend-native command insertion.

See `phase5.md`.

## Phase 6: External Texture Example

- Add an example that samples from an imported or externally provided texture.

See `phase6.md`.
