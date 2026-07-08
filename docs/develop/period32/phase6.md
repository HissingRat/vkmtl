# Phase 6: Validation On Supported Vulkan Hardware

Phase 6 proves the Vulkan ray traced scene path with real hardware or a real
Vulkan RT-capable runtime.

## Scope

- Keep `zig build test` passing.
- Keep `zig build` passing.
- Run `zig build run-ray-traced-scene -Dvulkan` on a supported Vulkan ray
  tracing setup.
- Document the visible result.
- Document unsupported behavior for runtimes without required extensions.

## Acceptance

- The validation notes name the GPU/runtime used.
- The visible window result is captured or manually documented.
- Unsupported-runtime behavior is deterministic and actionable.

## Deferred

- Automated Vulkan RT CI coverage is Period32+ work.

