# Phase 2 Decisions

These decisions start the surface and presentation phase without forcing the
triangle prototype to move before the public API is ready.

## Surface vs Presentation

vkmtl keeps two concepts separate:

- `SurfaceDescriptor` describes the external window or layer that can receive
  presented images.
- `PresentationDescriptor` describes how vkmtl should configure presentation:
  extent, format, present mode, and resize behavior.

This separation keeps window integration out of resource and command APIs.

## Surface Source Boundary

Core vkmtl does not import GLFW, Cocoa, X11, Wayland, Win32, Vulkan, or Metal.

Core exposes a small `SurfaceSource` value with:

- a provider tag
- an opaque window/layer pointer
- an optional display pointer
- an optional Vulkan surface provider callback table

Application or example code converts concrete windowing-library objects into
this neutral descriptor. The bundled examples keep that conversion in
`examples/common.zig`, using the external `zig_glfw` package without making
vkmtl core import GLFW.

## Resize Behavior

Presentation configuration has a `SurfaceResizePolicy`:

- `.recreate` rejects zero-sized surfaces.
- `.suspend_when_zero` moves the surface to a suspended state until it receives
  a non-zero extent.

Backends map this to Vulkan swapchain recreation and Metal drawable/layer
resizing behind `WindowContext`.

## Current Phase 2 Status

The public descriptors, placeholder surface state, and external surface-provider
boundary are implemented. Vulkan creates and resizes a swapchain behind
`vkmtl.WindowContext` when the descriptor carries a Vulkan surface provider. On
macOS, `.auto` selects the Metal path when the descriptor carries a compatible
Cocoa native window pointer; that path creates a `CAMetalLayer`, command queue,
command buffer, render pass descriptor, clears the drawable, and presents it
behind `vkmtl.WindowContext`.

`examples/clear_screen` uses `.auto`, imports `vkmtl`, the external `zig_glfw`
package, and the shared example helper. It does not call raw Vulkan or Metal
APIs.
