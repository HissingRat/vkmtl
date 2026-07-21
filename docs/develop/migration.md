# Migration And Compatibility Reference

This is the caller-facing migration reference for vkmtl. It replaces the
prototype migration guide, allocation map, and completed migration plan with
the final names, owners, version boundaries, and build contract that
applications still need.

## Version Boundaries

`v0.1.0` is the first supported portable source baseline. The earlier
prototype flat API was reorganized before that tag and has no compatibility
promise. The mappings below help older checkouts move to the tagged surface.

Within `v0.1.x`, vkmtl preserves the documented portable Zig source contract:

- canonical declarations and public owner methods;
- descriptor defaults and typed error categories;
- ownership, destruction order, and borrowing rules;
- meanings of reported capabilities, limits, and format support.

An intentional break to that surface requires `v0.2.0` or later, changelog
coverage, and migration guidance. Additive declarations that preserve existing
source and behavior may ship in `v0.1.x`; `HeadlessContext` is such an
addition.

The repository currently contains unreleased additions designated for
`v0.2.0`, even while package metadata remains `0.1.0`. Sections marked
"Unreleased v0.2" describe those caller-visible changes.

The compatibility promise is source-level and portable. It does not cover:

- binary ABI or cross-version binary compatibility;
- `_state` size, alignment, layout, or contents;
- raw native-handle values or identity;
- backend-native escape-hatch stability across `0.x` minor releases;
- features not reported by the selected device;
- Zig versions other than the release's supported toolchain.

`v0.1.x` uses Zig `0.16.0`.

## Package Migration

The package exports one supported module, `vkmtl`. Import that module from the
dependency rather than importing repository source files, example helpers, or
backend modules:

```zig
const vkmtl_dep = b.dependency("vkmtl", .{
    .target = target,
    .optimize = optimize,
    .shader_manifest = b.path("shaders/manifest.json"),
});

exe.root_module.addImport("vkmtl", vkmtl_dep.module("vkmtl"));
```

Repository examples, `examples/common.zig`, tools, tests, Vulkan bindings, and
Metal bridge modules are private to the repository build and are not supported
package exports.

If the consumer declares no shaders, the dependency default is sufficient for
repository development. An external application that declares shaders should
always pass its own consumer-owned manifest.

## Shader Manifest Migration

Shaders are build inputs, not runtime files. Pass a source-backed
`std.Build.LazyPath` through the `shader_manifest` dependency option. Generated
manifests are unsupported because vkmtl enumerates the shader dependency graph
while configuring the build.

Schema 1 remains accepted:

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

Manifest arrays and entry fields are:

| Schema | Array | Required entry fields |
| --- | --- | --- |
| 1+ | `render_shaders` | `name`, `source`, `vertex_entry`, `fragment_entry` |
| 1+ | `compute_shaders` | `name`, `source`, `entry` |
| 1+ | `ray_tracing_shaders` | `name`, `source`, `metal_ray_generation_source`, `ray_generation_entry`, `miss_entry`, `closest_hit_entry`, `any_hit_entry`, `intersection_entry` |
| 2 | `tessellation_shaders` | `name`, `source`, `vertex_entry`, `control_entry`, `evaluation_entry`, `fragment_entry` |
| 2 | `mesh_shaders` | `name`, `source`, `mesh_entry`, optional `task_entry`, `fragment_entry` |

Schema 2 retains every schema-1 array and adds advanced geometry; a schema-1
consumer does not need to migrate. Each array may be empty. Names are unique
across arrays and match lowercase portable `[a-z0-9_.-]+`; `.` and `..` are
not valid names.

Source paths are relative to the manifest and must remain inside the
LazyPath owner's logical root. This rule also applies to
`metal_ray_generation_source`. Use `b.path(...)` so the consumer build root is
the logical owner. Absolute, drive-relative, UNC, and backslash paths are
rejected.

The build tracks the manifest, declared sources, and include/import
dependencies from Slang depfiles. It embeds SPIR-V, MSL, and reflection blobs.
Runtime shader APIs do not launch `slangc` or write a shader cache.

On a build host without a known pinned Slang package, forward an explicit
build-time compiler path:

```zig
const vkmtl_dep = b.dependency("vkmtl", .{
    .target = target,
    .optimize = optimize,
    .shader_manifest = b.path("shaders/manifest.json"),
    .slangc = "/path/to/build-time/slangc",
});
```

For a direct repository build, use the equivalent option:

```sh
zig build -Dslangc=/path/to/build-time/slangc
```

Runtime source use remains simple:

```zig
const source = @embedFile("shaders/triangle.slang");
var device = context.device();

var compiled = try device.compileRenderShader("triangle", source, .{
    .vertex_entry = "vs_main",
    .fragment_entry = "fs_main",
});
defer compiled.deinit();
```

The manifest name, entries, and embedded source hash must match or compilation
returns `PrecompiledShaderMissing`.

## Prototype-To-v0.1 Migration Rules

Apply these rules in order:

1. Keep approved common root names unchanged.
2. Prefix advanced flat names with their canonical domain namespace.
3. Replace `vkmtl.ShaderReflection` with `vkmtl.shader.Reflection`.
4. Move backend-specific declarations under `native.vulkan` or
   `native.metal` and remove the redundant backend prefix.
5. Move backend-selected neutral lowerings under `native`.
6. Replace specialized `device.method(args)` with
   `vkmtl.domain.method(device, args)`.
7. Replace removed `WindowContext` forwards with the natural owner.
8. Replace runtime-handle struct literals and implementation-field access with
   public factories and methods.

Facade operations preserve the former receiver as their first argument:

```zig
// Prototype
const plan = try device.planAccelerationStructureBuild(descriptor);

// Canonical
const plan = try vkmtl.ray_tracing.planAccelerationStructureBuild(
    device,
    descriptor,
);
```

The Metal execution mapping factory is a pointer-receiver exception:

```zig
var mapping = try vkmtl.native.metal.makeRayTracingExecutionMapping(
    &device,
    descriptor,
);
```

## Root Type Map

Important advanced paths moved as follows:

| Prototype path | Canonical path |
| --- | --- |
| `vkmtl.ShaderReflection` | `vkmtl.shader.Reflection` |
| `vkmtl.AdvancedBindingModel` | `vkmtl.binding.AdvancedBindingModel` |
| `vkmtl.DescriptorIndexingRange` | `vkmtl.binding.DescriptorIndexingRange` |
| `vkmtl.Size3D` | `vkmtl.resource.Size3D` |
| `vkmtl.SparseResidencyMap` | `vkmtl.resource.SparseResidencyMap` |
| `vkmtl.SparseTextureKind` | `vkmtl.resource.SparseTextureKind` |
| `vkmtl.SparseBufferMappingDescriptor` | `vkmtl.resource.SparseBufferMappingDescriptor` |
| `vkmtl.SparseBufferLoweringMode` | `vkmtl.native.SparseBufferLoweringMode` |
| `vkmtl.SparseBufferLowering` | `vkmtl.native.SparseBufferLowering` |
| `vkmtl.SparseTextureLoweringMode` | `vkmtl.native.SparseTextureLoweringMode` |
| `vkmtl.SparseTextureLowering` | `vkmtl.native.SparseTextureLowering` |
| `vkmtl.SurfaceCollection` | `vkmtl.presentation.SurfaceCollection` |
| `vkmtl.SurfaceInfo` | `vkmtl.presentation.SurfaceInfo` |
| `vkmtl.RayTracingCapabilityDiagnostics` | `vkmtl.diagnostics.RayTracingCapabilityDiagnostics` |
| `vkmtl.ExternalHandleKind` | `vkmtl.interop.ExternalHandleKind` |
| `vkmtl.ExternalTextureDescriptor` | `vkmtl.interop.ExternalTextureDescriptor` |
| `vkmtl.TessellationDescriptor` | `vkmtl.render.TessellationDescriptor` |
| `vkmtl.TessellationPatchDrawDescriptor` | `vkmtl.render.TessellationPatchDrawDescriptor` |
| `vkmtl.MeshPipelineDescriptor` | `vkmtl.render.MeshPipelineDescriptor` |
| `vkmtl.MeshDispatchDescriptor` | `vkmtl.render.MeshDispatchDescriptor` |
| `vkmtl.AccelerationStructureBuildDescriptor` | `vkmtl.ray_tracing.AccelerationStructureBuildDescriptor` |
| `vkmtl.AccelerationStructureGeometryDescriptor` | `vkmtl.ray_tracing.AccelerationStructureGeometryDescriptor` |
| `vkmtl.AccelerationStructureGeometryResources` | `vkmtl.ray_tracing.AccelerationStructureGeometryResources` |
| `vkmtl.RayTracingPipelineDescriptor` | `vkmtl.ray_tracing.RayTracingPipelineDescriptor` |
| `vkmtl.RayTracingShaderGroupDescriptor` | `vkmtl.ray_tracing.RayTracingShaderGroupDescriptor` |
| `vkmtl.ShaderBindingTableDescriptor` | `vkmtl.ray_tracing.ShaderBindingTableDescriptor` |
| `vkmtl.VulkanSurfaceProvider` | `vkmtl.native.vulkan.SurfaceProvider` |
| `vkmtl.MetalIntersectionFunctionDescriptor` | `vkmtl.native.metal.IntersectionFunctionDescriptor` |

Common resource, presentation, pipeline, binding, and command descriptors that
remain root exports are approved aliases, not temporary forwards. Their exact
set is recorded in `public-api-inventory.md`; new documentation may use a
canonical domain path when it improves clarity.

## Native Name Map

Entering `native` removes redundant prefixes:

| Prototype path | Canonical path |
| --- | --- |
| `NativeHandles` | `native.Handles` |
| `NativeHandleLifetime` | `native.HandleLifetime` |
| `NativeHandleView` | `native.HandleView` |
| `nativeHandleView` | `native.handleView` |
| `NativeCommandEncoderKind` | `native.CommandEncoderKind` |
| `NativeCommandInsertionPoint` | `native.CommandInsertionPoint` |
| `NativeCommandCallback` | `native.CommandCallback` |
| `NativeCommandInsertionDescriptor` | `native.CommandInsertionDescriptor` |
| `VulkanNativeHandles` | `native.vulkan.Handles` |
| `VulkanSurfaceProvider` | `native.vulkan.SurfaceProvider` |
| `VulkanTessellationLowering` | `native.vulkan.TessellationLowering` |
| `VulkanTessellationDrawLowering` | `native.vulkan.TessellationDrawLowering` |
| `VulkanMeshPipelineLowering` | `native.vulkan.MeshPipelineLowering` |
| `VulkanMeshDispatchLowering` | `native.vulkan.MeshDispatchLowering` |
| `VulkanRayTracingPipelineLowering` | `native.vulkan.RayTracingPipelineLowering` |
| `MetalNativeHandles` | `native.metal.Handles` |
| `MetalTessellationLowering` | `native.metal.TessellationLowering` |
| `MetalTessellationFactorBufferOwnership` | `native.metal.TessellationFactorBufferOwnership` |
| `MetalTessellationDrawLowering` | `native.metal.TessellationDrawLowering` |
| `MetalMeshPipelineLowering` | `native.metal.MeshPipelineLowering` |
| `MetalMeshDispatchLowering` | `native.metal.MeshDispatchLowering` |
| `MetalIntersectionFunctionDescriptor` | `native.metal.IntersectionFunctionDescriptor` |
| `MetalRayTracingLowering` | `native.metal.RayTracingLowering` |
| `MetalRayTracingMappingDescriptor` | `native.metal.RayTracingMappingDescriptor` |
| `MetalRayTracingMappingPlan` | `native.metal.RayTracingMappingPlan` |
| `MetalRayTracingExecutionMapping` | `native.metal.RayTracingExecutionMapping` |

Sparse lowerings moved from the portable resource facade:

```text
resource.planSparseBufferLowering  -> native.planSparseBufferLowering
resource.planSparseTextureLowering -> native.planSparseTextureLowering
```

Backend planning operations moved and shortened:

```text
Device.planVulkanTessellationPatchDraw -> native.vulkan.planTessellationPatchDraw
Device.planVulkanMeshDispatch          -> native.vulkan.planMeshDispatch
Device.planMetalTessellationPatchDraw  -> native.metal.planTessellationPatchDraw
Device.planMetalMeshDispatch           -> native.metal.planMeshDispatch
Device.planMetalRayTracingMapping      -> native.metal.planRayTracingMapping
Device.makeMetalRayTracingExecutionMapping
                                      -> native.metal.makeRayTracingExecutionMapping
```

`SurfaceSource.vulkan` continues to accept
`native.vulkan.SurfaceProvider`. It is the single native callback exception in
portable presentation integration.

## WindowContext Migration

`WindowContext` owns only lifecycle, backend identity, native views, and access
to natural owners:

```text
init
deinit
selectedBackend
adapterInfo
nativeHandles
nativeHandleView
device
queue
surface
swapchain
```

Move resource and pipeline operations to `Device`:

```zig
// Prototype
var buffer = try context.makeBuffer(descriptor);

// Canonical
var device = context.device();
var buffer = try device.makeBuffer(descriptor);
```

The following former context methods keep the same method name on `Device`:

```text
queueWithDescriptor
compileRenderShader
compileComputeShader
compileRayTracingShader
makeFence
makeEvent
makeQuerySet
makeHeap
makeBuffer
makeShaderModule
makeRenderPipelineState
makeComputePipelineState
makeBindGroupLayout
makeAdvancedBindGroupLayout
makeResourceTable
makeBindGroup
makeTexture
makeExternalMemory
makeExternalBuffer
makeExternalSemaphore
makeExternalEvent
makeExternalTexture
makeSamplerState
```

Command and presentation ownership changed explicitly:

```text
WindowContext.makeCommandBuffer               -> Queue.makeCommandBuffer
WindowContext.makeCommandBufferWithDescriptor -> Queue.makeCommandBufferWithDescriptor
WindowContext.resize                          -> Swapchain.resize
WindowContext.clear                           -> Swapchain.clear
```

Former specialized forwards moved to facades:

| Former method | Canonical call |
| --- | --- |
| `objectCacheDiagnostics` | `diagnostics.objectCacheDiagnostics(device)` |
| `runtimeDiagnostics` | `diagnostics.runtimeDiagnostics(device)` |
| `writeCaptureName` | `diagnostics.writeCaptureName(device, ...)` |
| `planDriverPipelineCache` | `diagnostics.planDriverPipelineCache(device, ...)` |
| `planRuntimeCache` | `diagnostics.planRuntimeCache(device, ...)` |
| `planPipelineArtifactCache` | `diagnostics.planPipelineArtifactCache(device, ...)` |
| `memoryBudgetReport` | `diagnostics.memoryBudgetReport(device, ...)` |
| `planAccelerationStructureMaintenance` | `ray_tracing.planAccelerationStructureMaintenance(device, ...)` |
| `planTopLevelAccelerationStructureLayout` | `ray_tracing.planTopLevelAccelerationStructureLayout(device, ...)` |
| `planRayQuery` | `ray_tracing.planRayQuery(device, ...)` |
| `planComplexShaderBindingTable` | `ray_tracing.planComplexShaderBindingTable(device, ...)` |
| `planRayTracingStress` | `ray_tracing.planRayTracingStress(device, ...)` |
| `queueCapabilities` | `command.queueCapabilities(device)` |
| `syncCapabilities` | `sync.syncCapabilities(device)` |
| `presentModeSupport` | `presentation.presentModeSupport(device)` |
| `resolvePresentMode` | `presentation.resolvePresentMode(device, ...)` |
| `makeSurfaceCollection` | `presentation.makeSurfaceCollection(device)` |
| `transientAllocationDiagnostics` | `resource.transientAllocationDiagnostics(device, ...)` |
| `planResourceTablePressure` | `binding.planResourceTablePressure(device, ...)` |

## Device Method Migration

The common `Device` owner keeps selection, capability queries, compilation,
queue creation, and ordinary object factories. Specialized prototype methods
became facade functions with `device` as the first argument.

| Facade | Former `Device` method names |
| --- | --- |
| `binding` | `validateDescriptorIndexingLayout`, `planResourceTablePressure` |
| `resource` | `validateSparseMappingCommit`, `planSparseMappingCommit`, `planSparseResidencyChurn`, `validateSparseBufferDescriptor`, `validateSparseTextureDescriptor`, `transientAllocationDiagnostics` |
| `render` | `validateTessellationDescriptor`, `validateTessellationPatchDrawDescriptor`, `planTessellationPatchDraw`, `validateMeshPipelineDescriptor`, `validateMeshDispatchDescriptor`, `planMeshDispatch` |
| `ray_tracing` | `validateAccelerationStructureDescriptor`, `planAccelerationStructureBuild`, `planAccelerationStructureMaintenance`, `planTopLevelAccelerationStructureLayout`, `validateRayTracingPipelineDescriptor`, `validateShaderBindingTableDescriptor`, `planComplexShaderBindingTable`, `planRayDispatch`, `planRayQuery`, `planRayTracingStress` |
| `diagnostics` | `validateDriverPipelineCacheDescriptor`, `planDriverPipelineCache`, `planRuntimeCache`, `planPipelineArtifactCache`, `planBackendParitySemantics`, `objectCacheDiagnostics`, `runtimeDiagnostics`, `writeCaptureName`, `memoryBudgetReport` |

All 21 external interop methods move to `interop`:

```text
validateExternalTextureDescriptor
validateExternalMemoryDescriptor
validateExternalBufferDescriptor
validateExternalSemaphoreDescriptor
validateExternalEventDescriptor
planExternalMemoryImportForPlatform
planExternalBufferImportForPlatform
planExternalTextureImportForPlatform
planExternalTextureUsageForPlatform
planExternalSemaphoreImportForPlatform
planExternalEventImportForPlatform
diagnoseExternalInteropImportForPlatform
planExternalMemoryImport
planExternalBufferImport
planExternalTextureImport
planExternalTextureUsage
planExternalSemaphoreImport
planExternalEventImport
diagnoseExternalInteropImport
externalInteropCapabilityMatrix
externalInteropCapabilityMatrixForPlatform
```

The remaining owner-to-facade mappings are:

```text
Device.queueCapabilities      -> command.queueCapabilities
Device.planQueue              -> command.planQueue
Device.syncCapabilities       -> sync.syncCapabilities
Device.presentModeSupport     -> presentation.presentModeSupport
Device.resolvePresentMode     -> presentation.resolvePresentMode
Device.makeSurfaceCollection  -> presentation.makeSurfaceCollection
Device.validateCommandInsertionDescriptor
                              -> native.validateCommandInsertionDescriptor
```

Native sparse and backend mappings are listed in the preceding native section.

## Removed Prototype API

These implementation-shaped methods have no public replacement:

```text
planTessellationLowering
planMeshPipelineLowering
planRayTracingPipelineLowering
validateNativeDriverPipelineCacheDescriptor
planNativeAdvancedClosure
```

`ray_tracing.RayQueryLoweringMode` was removed. A
`ray_tracing.RayQueryPlan` no longer exposes `lowering`; consume its portable
backend, shader-stage, depth, and requirement fields. The concrete lowering is
private.

Conceptual compatibility replacements are:

```text
ContextOptions              -> WindowContextOptions
Context                     -> WindowContext
Adapter                     -> AdapterInfo and WindowContext.adapterInfo()
ClearColorLike              -> ClearColor or render.ClearColor
BindGroupResourceDescriptor -> binding.BindGroupResource
BindGroupEntryDescriptor    -> binding.BindGroupEntry
BindGroupDescriptorShape    -> binding.BindGroupDescriptor
BindGroupShapeResource      -> binding.BindGroupResource
BindGroupShapeEntry         -> binding.BindGroupEntry
BindGroupShapeDescriptor    -> binding.BindGroupDescriptor
```

## Runtime Handle Migration

Runtime objects are no longer application-constructible implementation
records. Create them through `Device`, `Queue`, `Surface`, or `Swapchain`, use
public methods, and call `deinit` where documented:

```zig
var device = context.device();
var buffer = try device.makeBuffer(descriptor);
defer buffer.deinit();

const backend = buffer.selectedBackend();
```

Code that initialized a handle literal, accessed backend unions, or read or
wrote `_state` has no layout-level replacement. `_state` is opaque even when
Zig permits spelling it.

`WindowContext` and `HeadlessContext` own heap runtime state. Their `Device`
and `Queue` values are borrowed. `WindowContext` also lends `Surface` and
`Swapchain`. Do not retain any borrowed view beyond its context, and destroy or
complete all dependent objects before context teardown.

## Adopting HeadlessContext

Existing windowed callers require no migration. New no-window compute,
transfer, resource, ray-tracing, or offscreen-render code can replace window
initialization while retaining the same device and queue API:

```zig
var context = try vkmtl.HeadlessContext.init(allocator, .{
    .app_name = "readback",
    .backend = .auto,
});
defer context.deinit();

var device = context.device();
var queue = context.queue();
var commands = try queue.makeCommandBuffer();
```

`HeadlessContext` does not provide a `Surface`, `Swapchain`, current drawable,
present operation, or presentation-shaped native-handle view. Texture-backed
render passes remain available.

## Unreleased v0.2 Presentation Migration

`PresentationDescriptor.format` remains the application request.
`.automatic` deterministically prefers `bgra8_unorm_srgb`, then
`bgra8_unorm`. An explicit admitted format is exact; unavailable or unrelated
formats return `UnsupportedPresentationFormat` rather than silently falling
back.

Use the concrete selected format for current-drawable pipelines:

```zig
var swapchain = context.swapchain();
const drawable_format = swapchain.selectedFormat();

var pipeline = try device.makeRenderPipelineState(.{
    .vertex = stages.vertex,
    .fragment = stages.fragment,
    .color_attachments = &.{
        .{ .format = drawable_format },
    },
});
```

`presentationDescriptor()` returns the request; `extent()` returns the actual
native drawable extent. Query `selectedFormat()` again after successful
resize before reusing a format-dependent pipeline. A mismatched pipeline
returns `PresentationFormatMismatch`.

On Vulkan, commit every backend command buffer before non-zero resize or
`Swapchain.clear(...)`. An active buffer returns
`InvalidCommandBufferState`. Once native recreation begins, a failure loses
that presentation runtime; recreate `WindowContext` after `SurfaceLost`.

Presentation selection does not perform HDR mapping, exposure, tone mapping,
gamma policy, or gamut conversion. Applications own content transforms.

## Unreleased v0.2 Ray-Tracing Output Migration

`dispatchRaysToDrawable(...)` remains a legacy compatibility path with an
implicit present. New composable, offscreen, or headless-capable code uses a
caller-owned texture:

```zig
var commands = try queue.makeCommandBuffer();
_ = try commands.dispatchRaysToTexture(
    &ray_pipeline,
    &shader_binding_table,
    dispatch_descriptor,
    .{
        .acceleration_structure = &top_level_as,
        .output = &rt_output_view,
    },
);
try commands.commit();

// A later command buffer samples rt_output_view and presents it.
```

The output is a live same-backend 2D single-sample view over mip zero/layer
zero of a one-mip, one-layer shader-readable and shader-writable texture. It
must cover the dispatch extent. Successful texture dispatch neither acquires
nor presents a drawable. Commit the producer before beginning the consumer
command buffer.

The dispatch assigns no color space. Applications define whether values are
display-referred or scene-linear and provide any exposure, transfer, tone-map,
or gamut work in the composition pass.

The legacy drawable route now requires a whole single-sample
`bgra8_unorm` 2D texture with shader-write and copy-source usage at the exact
presentation extent. It is graphics-queue-only and includes presentation; a
duplicate explicit present returns `InvalidCommandBufferState`.

## Unreleased v0.2 Ray-Tracing Bind-Group Migration

Ray pipelines may now declare one application bind-group layout. The layout
uses the ordinary `binding` types and is copied by pipeline creation; dispatch
borrows the matching group and all referenced resources until command-buffer
completion.

```zig
const rt_layout_descriptor = vkmtl.binding.BindGroupLayoutDescriptor{
    .entries = &.{
        .{
            .binding = 3,
            .resource = .sampled_texture,
            .visibility = .{ .ray_tracing = true },
        },
        .{
            .binding = 4,
            .resource = .sampler,
            .visibility = .{ .ray_tracing = true },
        },
    },
};

var pipeline = try device.makeRayTracingPipelineState(.{
    // Existing groups and stages omitted.
    .shader_groups = shader_groups,
    .bind_group_layout = rt_layout_descriptor,
});
defer pipeline.deinit();

var rt_layout = try device.makeBindGroupLayout(rt_layout_descriptor);
defer rt_layout.deinit();
var rt_group = try device.makeBindGroup(.{
    .layout = &rt_layout,
    .entries = &.{
        .{ .binding = 3, .resource = .{ .sampled_texture = &material_view } },
        .{ .binding = 4, .resource = .{ .sampler = &material_sampler } },
    },
});
defer rt_group.deinit();

_ = try commands.dispatchRaysToTexture(
    &pipeline,
    &shader_binding_table,
    .{
        .width = extent.width,
        .height = extent.height,
        .inline_data = std.mem.asBytes(&frame_data),
        .inline_data_binding = 2,
    },
    .{
        .acceleration_structure = &top_level_as,
        .output = &rt_output_view,
        .bind_group = &rt_group,
    },
);
```

The fixed RT binding allocation is:

| Binding | Owner |
| ---: | --- |
| 0 | acceleration structure |
| 1 | primary output texture |
| 2 | inline dispatch data |
| 3-14 | one application bind group |

Application entries may be ordinary uniform/storage buffers,
sampled/storage textures, samplers, or compare samplers. Resource arrays
consume consecutive slots and must end no later than 14. Dynamic offsets and
multiple application groups are not supported by this allocation.

Existing pipelines and resource literals that omit the new nullable fields
continue to use the resource-free route. Inline-data users still have one
required migration: the released default and shader slot were binding 1;
`v0.2.0` moves both to binding 2. Change explicit binding-1 callers and shader
declarations accordingly. When inline data is non-empty, another explicit
binding now returns `InvalidRayTracingPipeline`.

A pipeline that declares `bind_group_layout` cannot use plain
`dispatchRays(...)` and cannot omit the group from a texture/drawable dispatch.
The group must match the pipeline's copied layout exactly. The group and all
buffers, texture views, and samplers it references must remain live and on the
same backend, device/tracker, and compatible queue until the command buffer
completes. Handle `ReservedRayTracingBinding` and
`RayTracingPipelineLayoutMismatch` in exhaustive `BindingError` switches.

## Other Unreleased v0.2 Caller Changes

The following additions preserve ordinary defaults but affect callers that use
the new feature or exhaustively switch over public enums/errors:

| Area | Caller action |
| --- | --- |
| Raster coordinates | Use the documented Metal-like clip-space Y on every backend. Remove Vulkan-only shader or projection Y flips that compensated for the earlier backend inversion; public viewport/scissor coordinates remain top-left with positive dimensions. |
| Queries | Set `QuerySetDescriptor.occlusion_mode = .counting` only when `occlusion_counting_queries` is reported; handle `UnsupportedOcclusionCountingQueries` and `QueryBackendFailure`. |
| Query render passes | Set `RenderPassDescriptor.occlusion_query_set` and pass the same set to begin/end query calls. |
| Synchronization | `timeline_fences` now means a native monotonic object with host and GPU wait/signal; do not infer external sharing. |
| Command lifecycle | Optional lifecycle callback/context fields deliver scheduled and completed notifications once in the synchronous commit path. |
| Presentation timing | Use `presentDrawableWithDescriptor(...)`; timed modes require a nonzero value and matching feature, or explicit immediate fallback. |
| Resource limits | Handle maximum buffer and texture dimension/layer validation errors. |
| Texture views | Only admitted linear/sRGB reinterpretations are portable; component mapping defaults to identity. |
| Samplers | `normalized_coordinates` defaults true; unnormalized use requires the documented filter, clamp, LOD, compare, anisotropy, and border constraints. |
| GPU addresses | Request `shader_device_address` usage and query the feature before `buffer.gpuAddress()`; values are device/process-lifetime only. |
| Private textures | Upload through a staging buffer and transfer encoder; direct CPU upload returns `TextureNotCpuVisible`. |
| Attachments | Texture-backed passes honor all attachments and load/store actions; current-drawable passes retain their narrower action contract. |
| Reflection | Storage bindings expose read/write access and can fail with `ShaderReflectionBindingAccessMismatch`. |
| Heaps | Query exact allocation requirements, reserve them, and destroy placed resources before the heap. |
| Memoryless | Use only for non-sampled, non-stored render attachments; Vulkan reports exact semantics unsupported. |
| Indirect commands | Create immutable CPU-authored lists with `command.makeIndirectCommandBuffer(...)`; resource and pipeline inheritance comes from the encoder. |
| Driver caches | Pipeline descriptors accept an optional backend-matching cache; invalid identity/data falls back empty, and read-only prevents writes. |
| External imports | Imported resource accessors return borrowed pointers; destroy borrowing work before the external owner. |
| RT maintenance | Supply explicit source/scratch or source/destination resources and retain build inputs used by update/refit. |
| Advanced geometry | Manifest schema 2 and `shader.compile*` plus `render.make*PipelineState` expose capability-gated mesh/tessellation paths without new root aliases. |

## Migration Examples

Shader reflection:

```zig
// Prototype
var layouts = try vkmtl.ShaderReflection.deriveRenderPipelineBindGroupLayouts(
    allocator,
    vertex,
    fragment,
);

// Canonical
var layouts = try vkmtl.shader.Reflection.deriveRenderPipelineBindGroupLayouts(
    allocator,
    vertex,
    fragment,
);
```

External interop planning:

```zig
// Prototype
const plan = try device.planExternalTextureUsage(descriptor);

// Canonical
const plan = try vkmtl.interop.planExternalTextureUsage(device, descriptor);
```

Backend-specific tessellation:

```zig
// Prototype
const lowering = try device.planVulkanTessellationPatchDraw(descriptor);

// Canonical
const lowering = try vkmtl.native.vulkan.planTessellationPatchDraw(
    device,
    descriptor,
);
```

Queue ownership:

```zig
var queue = context.queue();
var commands = try queue.makeCommandBufferWithDescriptor(.{
    .label = "upload",
});
```

Presentation ownership:

```zig
var swapchain = context.swapchain();
try swapchain.resize(.{ .width = width, .height = height });
```

## Consumer Validation

After migration, run the checks appropriate to the application:

```sh
zig fmt --check build.zig src
zig build
zig build test
```

When migrating the vkmtl repository itself, also run:

```sh
zig build run-api-guard
zig build run-semantic-inventory-check
zig build test --summary all
zig build
zig build -Dvulkan
git diff --check
```

Search supported examples and user documentation for removed flat paths:

```sh
rg -n 'vkmtl\.(ShaderReflection|Vulkan[A-Z]|Metal[A-Z])' \
  examples docs/api docs/usage README.md
```

Historical commits may contain prototype names. New application code should
use canonical namespaces and natural owners only.
