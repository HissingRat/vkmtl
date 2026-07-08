# Phase 5: Vulkan Trace Rays And Present

Phase 5 submits the first visible Vulkan ray tracing dispatch.

## Scope

- Create an output image suitable for storage writes and presentation transfer.
- Bind acceleration structure, output image, and any required shader resources.
- Submit `vkCmdTraceRaysKHR`.
- Transition/copy/draw the output image to the current drawable.
- Keep the visible triangle distinct from the background.

## Acceptance

- `zig build run-ray-traced-scene -Dvulkan` opens a window and shows the ray
  traced triangle on supported Vulkan ray tracing devices.
- The example no longer reports Vulkan driver pixels as deferred on supported
  Vulkan devices.
- Unsupported devices still report a clear feature-gate message.

## Deferred

- Vulkan frame graph optimization and async compute/transfer scheduling are
  Period32+ work.

