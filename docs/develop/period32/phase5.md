# Phase 5: Vulkan Trace Rays And Present

Phase 5 submits the first Vulkan ray tracing dispatch and presents pixels
produced by the ray generation shader.

Status: complete for the first-scene Vulkan ray traced output path.

## Scope

- Build a minimal TLAS that references the first-scene BLAS.
- Bind the TLAS and storage output texture through the Vulkan ray tracing
  pipeline descriptor set.
- Submit `vkCmdTraceRaysKHR` through the Vulkan backend command buffer.
- Bind the native Vulkan ray tracing pipeline and SBT regions for the dispatch.
- Transition and copy the output image into the current swapchain image.
- Report whether trace dispatch and output presentation were submitted to the
  driver path.

## Acceptance

- `zig build run-ray-traced-scene -Dvulkan` opens a window and submits
  `vkCmdTraceRaysKHR` on supported Vulkan ray tracing devices.
- The example reports `trace_driver_submitted=true` when the native Vulkan
  dispatch path is used.
- The example reports `driver_pixels=visible_vulkan_rt_output` when the Vulkan
  ray tracing output path is used.
- The scene is presented from the ray tracing output image rather than a
  fullscreen render-shader bridge.
- Unsupported devices still report a clear feature-gate message.

## Deferred

- Vulkan frame graph optimization and async compute/transfer scheduling are
  Period32+ work.
- TLAS update/refit, multiple instances, ray query, procedural geometry, and
  larger SBT layouts remain Period32+ ray tracing completeness work.
