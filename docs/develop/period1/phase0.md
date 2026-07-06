# Phase 0 Decisions

These decisions unblock the binding phase without freezing the later public API.

## Module Layout

Phase 0 started the intended layout while the early triangle prototype was still
being replaced:

- `src/backend/vulkan/` owns Vulkan-only Zig code.
- `src/backend/metal/` owns the Metal bridge, Apple implementation, and
  non-Apple stubs.
- `tools/probes/` owns executable probes that validate bindings.
- Public samples live under `examples/`.
- `src/vkmtl.zig`, `src/core/`, `src/platform/`, and `src/shader/` are reserved
  for Phase 1 and later public API work.

## Metal Bridge ABI

Phase 0 only needs a minimal Metal probe ABI:

- create the system default Metal device
- return a UTF-8 device name for diagnostics
- destroy the probe object

Command queues, libraries, layers, drawables, command buffers, and resource
objects are intentionally deferred until the surface and rendering phases.

## Platform Surface Boundary

GLFW remains a prototype dependency for the current Vulkan triangle. Core vkmtl
does not own GLFW yet.

Metal presentation through `CAMetalLayer` is deferred to Phase 2. Phase 0 only
links Metal-related frameworks and verifies that Zig can call into a native
Metal bridge.

## Validation Commands

- Documentation-only changes: no build required unless package metadata changes.
- Build metadata changes: run `zig build --fetch`.
- Phase 0 binding changes: run `zig build --fetch` and `zig build probe`.
- Non-Apple Metal stub checks: run `zig build probe-build -Dtarget=x86_64-linux`
  or another non-Apple target.
- Rendering path changes: keep `zig build run` available for manual validation.
