# Period 32: Vulkan Ray Traced Scene Driver Path

Status: in progress; Phases 1-5 complete for the first direct Vulkan ray
tracing output path. Phases 6-7 own supported-hardware validation and docs
closure.

Goal: make `zig build run-ray-traced-scene -Dvulkan` create the Vulkan
ray-tracing driver objects, submit the Vulkan trace command, and present
ray-traced pixels in the window on supported Vulkan ray tracing devices.

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
- bind a TLAS and storage output texture for the ray generation shader
- copy or present the ray tracing output texture to the current drawable
- show a visible scene without importing backend-private modules from the
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
- first-scene TLAS and storage output image binding
- direct ray tracing output presentation to the window
- feature-gated behavior on unsupported Vulkan runtimes

Out of scope:

- Metal changes beyond preserving the Period31 path
- TLAS/multiple instances beyond the minimal first-scene TLAS
- compaction, refit, update, ray query, procedural geometry, and callable shader
  completeness
- full Vulkan/Metal ray tracing parity beyond the first visible scene

Full native mesh-scene parity is Period33. Procedural geometry/custom
intersection support is Period34. The remaining out-of-scope items stay in the
later Period32+ target.

## Phase Plan

### Phase 1: Vulkan Capability Gate And Loader Contract

- Confirm required Vulkan extensions, features, and limits.
- Make unsupported runtimes print actionable missing-capability messages.
- Keep the example on public vkmtl APIs.

See `phase1.md`.

Phase 1 is complete. Vulkan capability reports now include
`RayTracingCapabilityDiagnostics`, with blockers for missing required KHR
extensions, feature bits, limits, or device commands. The example exits before
backend-private runtime setup when the Vulkan ray tracing gate fails.

### Phase 2: Vulkan Acceleration Structure Build

- Allocate buffers with device-address and acceleration-structure usage.
- Create a real `VkAccelerationStructureKHR`.
- Encode and submit a BLAS build for the triangle.

See `phase2.md`.

Phase 2 is complete for the first-scene path. The Vulkan backend now creates a
driver acceleration structure with private storage, allocates an internal
device-address triangle geometry buffer, records `vkCmdBuildAccelerationStructuresKHR`,
and reports the build as driver-submitted when the native command path is used.

### Phase 3: Vulkan Ray Tracing Shader Path

- Add or reuse embedded Slang shader source for Vulkan ray tracing.
- Compile to SPIR-V ray tracing stages.
- Validate entry points and shader stage mapping.

See `phase3.md`.

Phase 3 is complete for the first-scene Vulkan path. The runtime shader
compiler now has `compileRayTracingShader(...)`, emits `raygen.spv`,
`miss.spv`, `closest_hit.spv`, and reflection artifacts, and
`examples/ray_traced_scene` embeds a dedicated Vulkan RT Slang shader.

### Phase 4: Vulkan Ray Tracing Pipeline And SBT

- Create the ray tracing pipeline and shader groups.
- Query shader group handles.
- Materialize the SBT buffer with valid alignment, stride, and device addresses.

See `phase4.md`.

Phase 4 is complete for the first-scene Vulkan path. The Vulkan backend now
creates a `VkRayTracingPipelineKHR`, queries shader group handles, writes an
aligned SBT buffer with device-address support, and stores SBT address regions
for command lowering.

### Phase 5: Vulkan Trace Rays And Present

- Build the first-scene TLAS from the BLAS.
- Bind the TLAS and storage output texture.
- Dispatch `vkCmdTraceRaysKHR`.
- Present the ray tracing output texture in the window.

See `phase5.md`.

Phase 5 is complete for the first-scene Vulkan path. The example now builds a
minimal TLAS, creates and binds a storage output texture, dispatches
`vkCmdTraceRaysKHR`, copies the output image into the current swapchain image,
and reports `driver_pixels=visible_vulkan_rt_output` on the Vulkan path.

### Phase 6: Validation On Supported Vulkan Hardware

- Keep `zig build test` and `zig build` passing.
- Run the example on a Vulkan runtime that exposes ray tracing.
- Capture or document the visible ray traced result and unsupported-runtime
  behavior.

See `phase6.md`.

### Phase 7: Documentation And Follow-Up Routing

- Update docs to state the first Vulkan ray traced scene support.
- Route full native mesh-scene work to Period33.
- Route procedural/custom-intersection work to Period34.
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

Full native mesh-scene work is Period33, and procedural/custom-intersection
work is Period34. The remaining items should be planned as later concrete
Period32+ phases after both Metal and Vulkan ray traced scenes are visible.
