# Period 32: Vulkan Ray Traced Triangle Driver Path

Status: planned after Period 31.

Goal: make `zig build run-ray-traced-scene -Dvulkan` produce visible
ray-traced pixels in a window on supported Vulkan ray tracing devices.

Period 31 proves the first pixel-producing path through Metal. Period 32 must
prove the equivalent Vulkan driver path instead of leaving Vulkan ray tracing as
a broad parity note.

## Hard Acceptance Target

On a Vulkan device and runtime that expose the required KHR ray tracing
extensions:

```sh
zig build run-ray-traced-scene -Dvulkan
```

must:

- create a window through the public surface path
- select Vulkan explicitly
- create and build a real `VkAccelerationStructureKHR` for the triangle
- create a real Vulkan ray tracing pipeline
- materialize a shader binding table buffer from shader group handles
- submit `vkCmdTraceRaysKHR`
- write the ray traced result into a texture
- present that texture to the window
- show a visible triangle without importing backend-private modules from the
  example

On Vulkan runtimes that do not expose the required ray tracing extensions, the
example must exit with a clear unsupported-feature message. macOS Vulkan through
MoltenVK may fall into this unsupported path if the runtime does not expose KHR
ray tracing.

## Required Vulkan Extensions

The exact extension list should be confirmed in Phase 1, but the expected
minimum is:

- `VK_KHR_acceleration_structure`
- `VK_KHR_ray_tracing_pipeline`
- `VK_KHR_deferred_host_operations`
- `VK_KHR_buffer_device_address`
- `VK_KHR_spirv_1_4`
- `VK_KHR_shader_float_controls`

vkmtl must report which required extension or feature is missing when the path
is unavailable.

## Scope

In scope:

- Vulkan-only driver path for `examples/ray_traced_scene`
- real Vulkan acceleration structure creation and BLAS build
- real Vulkan ray tracing pipeline creation
- real Vulkan SBT buffer materialization
- real `vkCmdTraceRaysKHR` dispatch
- output texture presentation through existing vkmtl window/render paths
- feature-gated behavior on unsupported Vulkan runtimes

Out of scope:

- Metal changes beyond preserving the Period31 path
- TLAS/multiple instances beyond what is required for the first scene
- compaction, refit, update, ray query, procedural geometry, and callable shader
  completeness
- full Vulkan/Metal ray tracing parity beyond the first visible scene

These out-of-scope items remain Period32+ target work.

## Phase Plan

### Phase 1: Vulkan Capability Gate And Loader Contract

- Confirm required Vulkan extensions, features, and limits.
- Make unsupported runtimes print actionable missing-capability messages.
- Keep the example on public vkmtl APIs.

See `phase1.md`.

### Phase 2: Vulkan Acceleration Structure Build

- Allocate buffers with device-address and acceleration-structure usage.
- Create a real `VkAccelerationStructureKHR`.
- Encode and submit a BLAS build for the triangle.

See `phase2.md`.

### Phase 3: Vulkan Ray Tracing Shader Path

- Add or reuse embedded Slang shader source for Vulkan ray tracing.
- Compile to SPIR-V ray tracing stages.
- Validate entry points and shader stage mapping.

See `phase3.md`.

### Phase 4: Vulkan Ray Tracing Pipeline And SBT

- Create the ray tracing pipeline and shader groups.
- Query shader group handles.
- Materialize the SBT buffer with valid alignment, stride, and device addresses.

See `phase4.md`.

### Phase 5: Vulkan Trace Rays And Present

- Dispatch `vkCmdTraceRaysKHR` into an output texture.
- Transition/copy/draw the output texture into the current drawable.
- Make the triangle visible in the window.

See `phase5.md`.

### Phase 6: Validation On Supported Vulkan Hardware

- Keep `zig build test` and `zig build` passing.
- Run the example on a Vulkan runtime that exposes ray tracing.
- Capture or document the visible result and unsupported-runtime behavior.

See `phase6.md`.

### Phase 7: Documentation And Period32+ Routing

- Update docs to state the first Vulkan ray traced scene support.
- Route broader ray tracing completeness to Period32+.
- Keep Metal and Vulkan support statements separate and precise.

See `phase7.md`.

## Deferred From Period 32

- Vulkan acceleration structure compaction/update/refit
- top-level acceleration structures with many instances
- ray query
- procedural geometry/custom intersection examples
- callable shader completeness
- large SBT stress tests
- cross-backend ray tracing abstraction polish beyond the first scene
- automated multi-device CI screenshots

They should be planned as concrete Period32+ phases after both Metal and Vulkan
ray traced scenes are visible.
