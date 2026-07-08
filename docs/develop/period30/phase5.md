# Phase 5: Native Advanced Escape Hatches

Phase 5 implements the backend-private work tracked by
`NativeAdvancedClosurePlan`.

## Scope

- Lifetime-safe native object handle pools.
- Vulkan pipeline cache and Metal binary archive consumption.
- Automatic runtime cache manifest read/write.
- Persistent staging pools and reusable upload rings.
- Native heap-backed resources and sparse/tiled page binding.
- Native external memory, texture, and synchronization imports.
- Native command handle views.
- Native tessellation and mesh/task execution.

## Validation

- Add focused backend tests for invalid escape-hatch use.
- Update capability and backend matrices for every newly executable path.
