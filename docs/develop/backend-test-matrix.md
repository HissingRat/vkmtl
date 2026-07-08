# Backend Test Matrix

The authoritative matrix metadata lives in `src/development_matrix.zig`.

## Required Rows

- `macos_metal_default`: `zig build test && zig build && zig build run-capability-dump`
- `linux_vulkan`: `zig build test && zig build -Dvulkan && zig build run-capability-dump -Dvulkan`
- `windows_vulkan`: `zig build test && zig build -Dvulkan && zig build run-capability-dump -Dvulkan`
- `headless_deterministic`: `zig build run-transfer-readback && zig build run-compute-readback`
- `presentation_feature_gates`: `zig build run-bindless-textures && zig build run-multi-window && zig build run-external-texture && zig build run-streaming-texture`
- `binding_variant_regression`: covered by `zig build test`; includes dynamic buffer array offsets, resource tables, root constant writes, and specialization variant fingerprints.
- `sync_query_regression`: covered by `zig build test`; includes explicit barriers, fences/events, logical queues, ownership transfer validation, and query readback/resolve validation.
- `resource_utility_regression`: covered by `zig build test`; includes mipmap generation, unaligned fill fallback, broader texture copy validation, sampler border colors, heap planning, and transient diagnostics.
- `platform_interop_regression`: covered by `zig build test`; includes surface registries, present-mode diagnostics, external wrappers, external synchronization validation, and native insertion gates.
- `production_hardening_regression`: `zig build test && zig build run-stability-plan -- --iterations 120`; includes object-cache diagnostics, runtime cache planning, runtime diagnostics, capture names, stability plans, and Vulkan fallback diagnostics.
- `advanced_resource_geometry_regression`: covered by `zig build test`; includes sparse/tiled resource planning, residency commit plans, tessellation lowering plans, and mesh/task lowering plans.
- `advanced_geometry_feature_gates`: `zig build run-tessellation && zig build run-mesh-shader`
- `ray_tracing_native_parity_regression`: covered by `zig build test`; includes ray tracing planning, Metal mapping, native advanced closure, and Period 29 routing.
- `ray_tracing_feature_gates`: `zig build run-ray-traced-triangle`

## Optional Rows

- `macos_moltenvk_forced`:

```sh
zig build -Dvulkan \
  -Dvulkan-loader-dir=/path/to/vulkan/lib \
  -Dvulkan-icd=/path/to/MoltenVK_icd.json
```

- `ios_metal_optional`:

```sh
zig build -Dtarget=aarch64-ios
```

The iOS row is planning metadata until platform surface packaging is designed.
The MoltenVK row is explicit because macOS Vulkan is for backend testing, not a
default release target.

## Capability Expectations

`run-capability-dump` is the smoke target for device capability reporting. The
output should include:

- selected backend and adapter identity
- capability source
- usable vkmtl features
- native queried backend features
- selected limits
- representative format capabilities

Advanced native features may appear in the native queried section before vkmtl
exposes usable lowering for them. The usable feature section must stay
conservative until the relevant backend period lands.

## Period 23 Sync And Query Expectations

| Feature | Vulkan | Metal | Public Status |
| --- | --- | --- | --- |
| Explicit buffer/texture barriers | Native barrier commands | Validation/no-op markers | Advanced escape hatch, feature-gated |
| Binary fences | Portable runtime object | Portable runtime object | Available by default |
| Timeline fences | Capability-gated | Capability-gated | Deferred native submit integration |
| Events | Portable runtime object | Portable runtime object | Available by default |
| Shared events | Capability-gated | Capability-gated | Deferred native/shared-handle integration |
| Logical compute/transfer queues | Portable fallback until native queue families are exposed | Portable fallback until dedicated queue use is exposed | Queue descriptors are public |
| Queue ownership transfers | Deferred native queue-family lowering | Validation/no-op markers | Advanced escape hatch, feature-gated |
| Timestamp queries | Portable runtime query set | Portable runtime query set | Available by default |
| Occlusion queries | Portable runtime query set | Portable runtime query set | Available by default |
| Pipeline statistics queries | Capability-gated | Capability-gated | Deferred native query lowering |

## Period 24 Resource Utility Expectations

| Feature | Vulkan | Metal | Public Status |
| --- | --- | --- | --- |
| Full-texture mipmap generation | Native image blits | Native `generateMipmapsForTexture` | Available through blit encoder |
| Partial mip/layer mipmap generation | Deferred | Deferred | Period 31+ validation matrix parity decision |
| Unaligned `fillBuffer` | Staging-copy fallback | Native byte-range fill | Public API accepts unaligned ranges |
| Texture copy array layers | Native `layer_count` | Per-slice fallback loop | `slice_count` is public |
| Compatible color-format copies | Native compatible copy class | Native compatible copy class | unorm/sRGB pairs in same channel order |
| Depth/stencil and MSAA copies | Deferred | Deferred | Period 31+ validation matrix semantic decision |
| Fixed sampler border colors | Native sampler state | Native sampler state | Available by default |
| Custom sampler border colors | Deferred | Deferred | Period 31+ validation matrix parity decision |
| Heap planning | Portable runtime object | Portable runtime object | Feature-gated planning/reservation |
| Native heap-backed resources | Deferred | Deferred | Period 31+ driver parity plan native integration |
| Transient allocation diagnostics | Portable runtime diagnostics | Portable runtime diagnostics | Public diagnostics helper |

## Period 25 Platform And Interop Expectations

| Feature | Vulkan | Metal | Public Status |
| --- | --- | --- | --- |
| Surface registry | Portable runtime state | Portable runtime state | `Device.makeSurfaceCollection(...)` |
| Native multi-surface presentation | Deferred | Deferred | Period 31+ driver parity plan native escape hatch |
| Present-mode resolution | Portable runtime fallback | Portable runtime fallback | `PresentModeSupport` and `FramePacingDiagnostics` |
| Native present-mode query | Deferred | Deferred | Period 31+ driver parity plan platform query |
| External memory / buffer wrappers | Portable runtime wrappers | Portable runtime wrappers | Feature-gated descriptors and lifetime tracking |
| Native external memory import | Deferred | Deferred | Period 31+ driver parity plan native import |
| External texture wrapper | Portable runtime wrapper | Portable runtime wrapper | `ExternalTexture` wrapper |
| Native external texture import | Deferred | Deferred | Period 31+ driver parity plan native import |
| External sync wrappers | Portable runtime wrappers | Portable runtime wrappers | `ExternalSynchronizationDescriptor` validation |
| Native external sync wait/signal | Deferred | Deferred | Period 31+ driver parity plan native lowering |
| Native command insertion API | Capability-gated | Capability-gated | Encoder methods validate explicit callbacks |
| Native command handle lowering | Deferred | Deferred | Period 31+ driver parity plan native handle view |

## Period 26 Production Hardening Expectations

| Feature | Vulkan | Metal | Public Status |
| --- | --- | --- | --- |
| Object-cache lookup diagnostics | Portable runtime diagnostics | Portable runtime diagnostics | `cache_policy` and `objectCacheDiagnostics()` |
| Native object handle pooling | Deferred | Deferred | Period 31+ driver parity plan native pools |
| Driver cache planning | Portable runtime planning | Portable runtime planning | `Device.planDriverPipelineCache(...)` |
| Native driver cache lowering | Deferred | Deferred | Period 31+ driver parity plan `VkPipelineCache` / `MTLBinaryArchive` consumption |
| Runtime cache manifest planning | Portable runtime planning | Portable runtime planning | `Device.planRuntimeCache(...)` |
| Runtime cache manifest I/O | Deferred | Deferred | Period 31+ driver parity plan automatic manifest read/write |
| Runtime diagnostics snapshot | Portable runtime diagnostics | Portable runtime diagnostics | `runtimeDiagnostics()` |
| Capture name helpers | Portable runtime helper | Portable runtime helper | `CaptureNameDescriptor` and `writeCaptureName(...)` |
| Stability run planning | Portable runtime planning | Portable runtime planning | `StabilityRunDescriptor.plan()` and `run-stability-plan` |
| GPU-backed soak loops | Deferred | Deferred | Period 31+ validation matrix native long-run validation |

## Period 27 Advanced Resource And Geometry Expectations

| Feature | Vulkan | Metal | Public Status |
| --- | --- | --- | --- |
| Sparse buffer planning | Runtime plan from native features | Runtime plan from native features | `Device.planSparseBufferLowering(...)` |
| Sparse/tiled texture planning | Runtime plan from native features | Runtime plan from native features | `Device.planSparseTextureLowering(...)` |
| Residency commit planning | Runtime commit/evict summary | Runtime commit/evict summary | `Device.planSparseMappingCommit(...)` |
| Native sparse/tiled page binding | Deferred | Deferred | Period 31+ driver parity plan native integration |
| Tessellation lowering planning | Runtime patch metadata plan | Runtime factor-buffer requirement plan | `Device.planTessellationLowering(...)` |
| Native tessellation pipeline | Deferred | Deferred | Period 31+ driver parity plan native integration |
| Mesh/task lowering planning | Runtime task/mesh metadata plan | Runtime object/mesh metadata plan | `Device.planMeshPipelineLowering(...)` |
| Native mesh/task pipeline | Deferred | Deferred | Period 31+ driver parity plan native integration |
| Advanced geometry examples | Feature-gated examples | Feature-gated examples | `examples/tessellation` and `examples/mesh_shader` |

## Period 28 Ray Tracing And Native Parity Expectations

| Feature | Vulkan | Metal | Public Status |
| --- | --- | --- | --- |
| Acceleration-structure build planning | Runtime plan from native features | Runtime plan from native features | `Device.planAccelerationStructureBuild(...)` |
| Native acceleration-structure builds | Backend-private command records | Backend-private command records | Period 30 Phase 1 runtime native boundary; direct driver handles deferred to Period 31+ |
| Ray tracing pipeline planning | Runtime shader-group plan | Runtime function-table metadata plan | `Device.planRayTracingPipelineLowering(...)` |
| Native ray tracing pipelines | Backend-private pipeline metadata | Backend-private pipeline metadata | Period 30 Phase 2 runtime native boundary; direct driver pipeline handles deferred to Period 31+ |
| SBT and ray dispatch planning | Runtime SBT/dispatch plan | Runtime SBT/dispatch plan | `Device.planRayDispatch(...)` |
| Native ray dispatch commands | Backend-private dispatch records | Backend-private dispatch records | Period 30 Phase 3 runtime native boundary; direct driver dispatch deferred to Period 31+ |
| Metal ray tracing mapping planning | Validation no-op | Runtime Metal mapping plan | `Device.planMetalRayTracingMapping(...)` |
| Native Metal ray tracing execution | Validation no-op | Backend-private table metadata | Period 30 Phase 4 runtime native boundary; direct Metal dispatch binding deferred to Period 31+ |
| Native advanced closure inventory | Runtime roadmap data | Runtime roadmap data | `Device.planNativeAdvancedClosure(...)` |
| Native advanced backend execution | Backend-private inventory | Backend-private inventory | Period 30 Phase 5 runtime inventory; driver execution deferred to Period 31+ |
| Parity semantics and soak loops | Runtime diagnostics plan | Runtime diagnostics plan | Period 30 Phase 6 runtime validation; GPU soak deferred to Period31+ |
| Native advanced examples | Backend-private runtime sample | Backend-private runtime sample | Period 30 Phase 7 example record checks; pixel examples deferred to Period31+ |
