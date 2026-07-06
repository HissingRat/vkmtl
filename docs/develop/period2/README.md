# Period 2: Runtime Architecture And Specs

Goal: turn the working vertical slice into the long-term API foundation before
expanding broad resource and pipeline coverage.

Period 2 is intentionally spec-heavy. It should settle ownership, lifetime,
capability, binding terminology, and synchronization principles before vkmtl
adds many more surface-area features.

## Phase 0: Core Architecture Specs

- Define `Device`, `Queue`, `Surface`, `Swapchain`, and `CommandBuffer` owner
  boundaries.
- Write the resource lifetime model.
- Write the binding terminology used by later shader and pipeline phases.
- Write command usage and synchronization principles.
- Define the model first; full implementation can land in later phases.

Decision notes: `phase0.md`.

## Phase 1: Device / Queue / Surface Split

- Move resource creation from `WindowContext` to `Device`.
- Reduce `WindowContext` toward example/helper-level ownership.
- Let `Surface` / `Swapchain` own acquire, drawable, and present semantics.
- Let `Queue` / `CommandQueue` own submit and synchronization semantics.

Decision notes: `phase1.md`.

## Phase 2: Adapter Selection And Capabilities

- Enumerate adapters.
- Support high-performance, low-power, default, and explicit adapter selection.
- Expose adapter name, vendor, device type, and backend type.
- Add `device.features()`.
- Add `device.limits()`.
- Add `device.getFormatCaps(format)`.

Decision notes: `phase2.md`.

## Phase 3: Resource Lifetime And Deferred Destruction

- Define which resources are owned by `Device`.
- Define parent-child relationships for `Surface`, `Swapchain`, `Pipeline`,
  `BindGroup`, and `CommandBuffer`.
- Detect leaks in debug builds.
- Handle resources destroyed while GPU work may still reference them.
- Introduce deferred destruction or an equivalent strategy.

## Phase 4: Basic Usage Tracking / Sync Baseline

- Define a portable resource usage model.
- Track common read/write hazards automatically by default.
- Generate necessary Vulkan barriers from tracked usage.
- Use Metal encoder boundaries and usage hints where they map well.
- Reserve manual barriers as a future escape hatch instead of exposing them in
  the base API immediately.

## Phase 5: Error Model / Validation Layer

- Separate validation errors, unsupported features, backend errors, device lost,
  and surface lost.
- Provide API argument checks in debug builds.
- Reduce runtime checks in release builds where appropriate.
- Convert backend errors into a unified public error model.

## Phase 6: Multi-Surface / Multi-Window

- Support multiple presentation surfaces from one `Device`.
- Let each surface manage its own swapchain or drawable state.
- Support resize, recreate, and surface-lost handling.
- Make clear that `WindowContext` is not equivalent to `Device`.

## Phase 7: Native Handle Escape Hatch

- Provide controlled Vulkan and Metal native handle access.
- Document lifetime, threading, and backend-specific risks.
- Mark native handle access as unsafe or advanced.
- Do not guarantee portability for code that uses native handles.

## Phase 8: Debug Labels / Markers / Diagnostics

- Add resource debug labels.
- Add command and encoder labels.
- Add push/pop debug groups.
- Use Vulkan debug utils where available.
- Use Metal labels and debug groups where available.
- Report unreleased resources in debug builds.
