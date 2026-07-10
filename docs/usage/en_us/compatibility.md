# Compatibility

vkmtl targets portable Vulkan and Metal workflows first, with advanced features
behind explicit capability gates.

## Current Backend Expectations

| Platform | Preferred Backend | Notes |
| --- | --- | --- |
| macOS | Metal | Default `.auto` path when Metal is available. |
| macOS | Vulkan via MoltenVK | Backend testing only; requires explicit loader and ICD paths. |
| Linux | Vulkan | Expected portable non-Apple backend. |
| Windows | Vulkan | Expected portable non-Apple backend. |
| iOS | Metal | Planned; surface packaging is not complete yet. |

## Capability Gates

Use `device.features()`, `device.limits()`, and `device.getFormatCaps(...)`
instead of platform assumptions. Unsupported optional behavior should fail with
typed errors rather than silently changing semantics.

## Sync And Query Defaults

vkmtl keeps the ordinary command path portable: resource usage tracking, binary
fences, events, timestamp queries, and occlusion queries are available through
backend-neutral runtime objects. Explicit barriers and queue ownership transfers
are advanced escape hatches; Vulkan lowers the barrier path natively, while
Metal uses validation/no-op markers where encoder boundaries already define
ordering. Timeline fences, shared events, and logical queue planning now have
portable descriptor and validation entry points. Native timeline/shared-event
submit, native dedicated queues, native queue-family ownership transfers, and
pipeline statistics queries remain capability-gated until their backend
lowering is complete.

## Advanced Features

Advanced features stay behind feature gates. Some Period 22 binding paths now
have runtime objects and command entry points, while sparse resources,
external texture interop, tessellation, mesh shaders, ray tracing, and
driver-level pipeline caches remain gated until their native backend work is
complete.

Heap, memory-budget, transient-allocation, and sparse-residency APIs currently
provide portable planning and diagnostics. Native heap-backed buffer/texture
creation and native sparse/tiled page binding remain backend work.

Descriptor indexing maps toward Vulkan descriptor indexing. Argument buffers map
toward Metal argument buffers. Both are represented by
`DescriptorIndexingLayoutDescriptor`, `AdvancedBindGroupLayout`, and
`ResourceTable`. Resource tables can be updated, cleared, and bound through
render/compute encoders when the selected backend advertises the required
feature.

Large table pressure is planned through
`Device.planResourceTablePressure(...)`. The plan makes partially-bound and
update-after-bind requirements explicit before allocation, while native GPU
stress evidence remains part of the backend/device validation matrix.

Root constants lower to Vulkan push constants and Metal `set*Bytes` calls after
a pipeline declares a compatible `root_constant_layout`.

Shader specialization is capability-gated. Vulkan pipeline specialization info
is wired for enabled devices. Metal function-constant specialization remains
closed until the Metal bridge exposes that variant path.

Sparse buffers/textures map toward Vulkan sparse resources and Metal tiled or
sparse texture concepts. The current descriptors validate page-aligned mapping
intent only.

External memory, buffer, texture, semaphore, and shared-event interop use
explicit platform/backend handle descriptors. Runtime wrappers validate
ownership and backend compatibility. Import plans classify each handle lane,
texture usage plans validate sampling/copy/presentation intent, and external
synchronization plans validate wait/signal ordering before submission. Native
OS/Vulkan/Metal handle import and wait/signal lowering remain backend hook
work. `ExternalInteropCapabilityMatrix` and
`Device.diagnoseExternalInteropImport(...)` classify handle support by
backend/platform before import is attempted.

Tessellation is represented by `TessellationDescriptor` and remains an optional
render pipeline extension, not a default portable render path.
`TessellationPatchDrawDescriptor` can produce Vulkan / Metal public planning
metadata; visible native output still requires backend pipeline hooks.

Mesh/task shaders are represented by `MeshPipelineDescriptor`. Vulkan mesh
shader and Metal object/mesh-like paths are treated as backend-gated advanced
features. `MeshDispatchDescriptor` can produce Vulkan task/mesh or Metal
object/mesh planning metadata.

Ray tracing descriptors are isolated from the normal render pipeline because
Vulkan and Metal differ in acceleration structure, pipeline, and shader table
details.
Ray tracing completeness APIs now include AS maintenance planning, TLAS
instance metadata planning, Vulkan ray query planning, complex SBT planning,
and deterministic RT stress planning. Metal ray query is reported as
unsupported because there is no direct equivalent shader feature in this layer.
Native GPU stress evidence remains part of the backend/device validation
matrix.

Driver-level pipeline caches and Metal binary archives use explicit cache
identity descriptors. They are separate from Period 8 object-cache diagnostics.
Shader / pipeline artifact compatibility is planned with
`Device.planPipelineArtifactCache(...)`, which invalidates cached artifacts when
shader hashes, entry points, reflection, formats, backend, schema, or toolchain
identity changes. Native `VkPipelineCache`, pipeline-library, and
`MTLBinaryArchive` persistence remains backend work.
