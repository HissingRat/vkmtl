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

## Advanced Features

Period 10 advanced features are descriptor/API shape first. Descriptor indexing,
sparse resources, external texture interop, tessellation, mesh shaders, ray
tracing, and driver-level pipeline caches remain gated until backend lowering is
implemented.

Descriptor indexing maps toward Vulkan descriptor indexing. Argument buffers map
toward Metal argument buffers. Both are represented by
`DescriptorIndexingLayoutDescriptor` and remain disabled by default.

Sparse buffers/textures map toward Vulkan sparse resources and Metal tiled or
sparse texture concepts. The current descriptors validate page-aligned mapping
intent only.

External texture and semaphore interop uses explicit platform/backend handle
descriptors. It is related to native handles, but it is not part of ordinary
portable resource creation.

Tessellation is represented by `TessellationDescriptor` and remains an optional
render pipeline extension, not a default portable render path.

Mesh/task shaders are represented by `MeshPipelineDescriptor`. Vulkan mesh
shader and Metal object/mesh-like paths are treated as backend-gated advanced
features.

Ray tracing descriptors are isolated from the normal render pipeline because
Vulkan and Metal differ in acceleration structure, pipeline, and shader table
details.

Driver-level pipeline caches and Metal binary archives use explicit cache
identity descriptors. They are separate from Period 8 object-cache diagnostics.
