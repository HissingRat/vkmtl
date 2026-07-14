# Compatibility

vkmtl targets portable Vulkan and Metal workflows first, with advanced features
behind explicit capability gates.

## v0.1.x Source Compatibility

`v0.1.0` establishes the first compatibility baseline. Patch releases in the
`v0.1.x` line preserve the documented portable Zig source API, including
canonical declarations, documented owner methods and descriptor defaults,
typed error categories, ownership/lifetime rules, and supported capability
meanings. An intentional portable source break requires `v0.2.0` or later and
migration guidance.

The current Unreleased Period 46 work extends `QueryError` with
`QueryBackendFailure` and therefore targets `v0.2.0`, not a `v0.1.x` patch.
Exhaustive error switches need one new arm; ordinary error propagation is
unchanged. See the migration guide for the complete query update.

This is not a stable binary ABI. Applications must not depend on the size,
alignment, or contents of opaque `_state` storage, raw native-handle values, or
the stability of backend-native escape hatches. The supported toolchain for
`v0.1.x` is Zig `0.16.0`.

See the authoritative [release policy](../../develop/release-policy.md) and the
[prototype migration guide](../../develop/api-migration-guide.md).

## Package And Shader Manifest

The package exports one supported module named `vkmtl`. Repository example
support code and tools are private to the repository build.

Applications that declare shaders pass a consumer-owned, source-backed
`shader_manifest` dependency option as a `std.Build.LazyPath`:

```zig
const vkmtl_dep = b.dependency("vkmtl", .{
    .target = target,
    .optimize = optimize,
    .shader_manifest = b.path("shaders/manifest.json"),
});

exe.root_module.addImport("vkmtl", vkmtl_dep.module("vkmtl"));
```

Schema version 1 remains accepted and contains three arrays:

```json
{
  "schema_version": 1,
  "render_shaders": [
    {
      "name": "triangle",
      "source": "triangle.slang",
      "vertex_entry": "vs_main",
      "fragment_entry": "fs_main"
    }
  ],
  "compute_shaders": [
    {
      "name": "particles",
      "source": "particles.slang",
      "entry": "cs_main"
    }
  ],
  "ray_tracing_shaders": []
}
```

Render entries contain `name`, `source`, `vertex_entry`, and
`fragment_entry`. Compute entries contain `name`, `source`, and `entry`.
Ray-tracing entries contain `name`, `source`,
`metal_ray_generation_source`, `ray_generation_entry`, `miss_entry`,
`closest_hit_entry`, `any_hit_entry`, and `intersection_entry`. Source paths,
including `metal_ray_generation_source`, are relative to the manifest file and
must remain inside the LazyPath owner's logical root. Generated manifests are
not supported because shader inputs are enumerated while constructing the
dependency graph. Schema version 2 retains all three arrays and adds
`tessellation_shaders` plus `mesh_shaders`; this is an additive build-contract
extension and does not invalidate schema-1 consumers.

The build tracks the manifest and all declared shader sources, consumes Slang
depfiles for include/import dependencies, generates SPIR-V, MSL, and reflection
blobs, and embeds them in the consumer's `vkmtl` module. Runtime shader APIs
never launch `slangc` and never write a runtime shader cache. The repository
default `shaders/manifest.json` serves its own examples; external applications
should provide their own manifest.

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
typed errors rather than silently changing semantics. A planning-only record
or typed-unsupported path is not an executable feature claim.

## Sync And Query Defaults

vkmtl keeps the ordinary command path portable: resource usage tracking, binary
fences, events, timestamp queries, and capability-gated occlusion queries are
available through backend-neutral runtime objects. Timestamp values are either
logical ordering values or raw native GPU ticks; inspect `resultSource()`, and
do not compute duration because calibration is not yet public. Occlusion uses
zero/nonzero visibility and requires the render pass to bind the set. Explicit
barriers and queue ownership transfers
are advanced escape hatches; Vulkan lowers the barrier path natively, while
Metal uses validation/no-op markers where encoder boundaries already define
ordering. Timeline fences, shared events, and logical queue planning now have
portable descriptor and validation entry points. Native timeline/shared-event
submit, native dedicated queues, native queue-family ownership transfers, exact
occlusion sample counts, and pipeline statistics queries remain
capability-gated until their backend lowering is complete.

## Advanced Features

Advanced features stay behind feature gates. Some binding and ray tracing
paths have executable runtime objects and command entry points, while sparse
resources, native external import, tessellation, mesh shaders, and native
driver-cache persistence still require later backend work.

Heap, memory-budget, transient-allocation, and sparse-residency APIs currently
provide portable planning and diagnostics. Native heap-backed buffer/texture
creation and native sparse/tiled page binding remain backend work.

Descriptor indexing maps toward Vulkan descriptor indexing. Argument buffers map
toward Metal argument buffers. Both are represented by
`vkmtl.binding.DescriptorIndexingLayoutDescriptor`, `AdvancedBindGroupLayout`,
and `ResourceTable`. Resource tables can be updated, cleared, and bound through
render/compute encoders when the selected backend advertises the required
feature. Pipelines declare matching `resource_table_layouts`; Metal uses native
argument buffers and Vulkan uses enabled descriptor-indexing sets. Binding the
wrong layout/index is a typed error before backend work.

Large table pressure is planned through
`vkmtl.binding.planResourceTablePressure(device, descriptor)`. The plan makes partially-bound and
update-after-bind requirements explicit before allocation, while native GPU
stress evidence remains part of the backend/device validation matrix.

CPU-authored reusable draw and dispatch lists are created through
`vkmtl.command.makeIndirectCommandBuffer(...)`. They inherit active encoder
state and execute through native Metal ICBs when available or exact direct
command expansion on Vulkan. GPU-authored command mutation remains unsupported.

Root constants lower to Vulkan push constants and Metal `set*Bytes` calls after
a pipeline declares a compatible `root_constant_layout`.

Shader specialization is capability-gated. Vulkan specialization info and
Metal vertex, fragment, and compute function constants are wired by stable
numeric ID when `shader_specialization` is usable. Optional constant names do
not control native lookup.

Sparse buffers/textures map toward Vulkan sparse resources and Metal tiled or
sparse texture concepts. The current descriptors validate page-aligned mapping
intent only.

External memory, buffer, texture, semaphore, and shared-event interop use
explicit platform/backend handle descriptors. Runtime wrappers validate
ownership and backend compatibility. Import plans classify each handle lane,
texture usage plans validate sampling/copy/presentation intent, and external
synchronization plans validate wait/signal ordering before submission. Native
OS/Vulkan/Metal handle import and wait/signal lowering remain backend hook
work. `vkmtl.interop.ExternalInteropCapabilityMatrix` and
`vkmtl.interop.diagnoseExternalInteropImport(device, descriptor)` classify handle support by
backend/platform before import is attempted.

Tessellation is represented by `vkmtl.render.TessellationDescriptor` and remains an optional
render pipeline extension, not a default portable render path.
`TessellationPatchDrawDescriptor` has a portable render plan; explicit Vulkan
and Metal lowering inspection lives under `vkmtl.native.vulkan` and
`vkmtl.native.metal`. Visible native output still requires backend pipeline hooks.

Mesh/task shaders are represented by `vkmtl.render.MeshPipelineDescriptor`. Vulkan mesh
shader and Metal object/mesh-like paths are treated as backend-gated advanced
features. `MeshDispatchDescriptor` has a portable render plan, while
backend-specific planning lives under the matching `native` subnamespace.

`vkmtl.ray_tracing` is isolated from the normal render pipeline because
Vulkan and Metal differ in acceleration structure, pipeline, and shader table
details.
Ray tracing completeness APIs now include AS maintenance planning, TLAS
instance metadata planning, Vulkan ray query planning, complex SBT planning,
and deterministic RT stress planning. Metal ray query is reported as
unsupported because there is no direct equivalent shader feature in this layer.
Physical Metal and Vulkan RT runs have produced visible output, including the
Vulkan procedural scene. Period 44 also records all nine hosted, smoke, pixel,
and bounded-soak gates as observed. This does not claim native memory pressure,
sparse binding, dedicated queues, cache persistence, or multi-hour RT stress.

Driver-level pipeline caches and Metal binary archives use explicit cache
identity descriptors. They are separate from Period 8 object-cache diagnostics.
Shader / pipeline artifact compatibility is planned with
`vkmtl.diagnostics.planPipelineArtifactCache(device, descriptor)`, which invalidates cached artifacts when
shader hashes, entry points, reflection, formats, backend, schema, or toolchain
identity changes. Render/compute pipeline `driver_cache` descriptors now consume
and persist native `VkPipelineCache` / `MTLBinaryArchive` data; native pipeline
libraries remain separate backend work.
