# Backend Test Matrix

The authoritative matrix metadata lives in `tools/development_matrix.zig`.

## Required Rows

- `hosted_macos_build`: formatting, tests, build, validation plan, and external
  package consumer smoke on `macos-15`; build-only evidence, not GPU proof.
- `hosted_linux_build`: formatting, tests, forced-Vulkan build, validation plan,
  and external package consumer smoke on `ubuntu-24.04`; build-only evidence.
- `hosted_windows_build`: formatting, tests, forced-Vulkan build, validation
  plan, and external package consumer smoke on `windows-2025`; build-only
  evidence.
- `self_hosted_metal_smoke`: `scripts/ci/run_gpu_smoke.sh metal ...` on a
  physical Apple Silicon host labeled `vkmtl-metal`.
- `self_hosted_vulkan_smoke`: `scripts/ci/run_gpu_smoke.sh vulkan ...` on a
  physical Linux Vulkan host labeled `vkmtl-vulkan`.
- `metal/vulkan_pixel_regression`: transfer, compute, and render readback via
  `run-pixel-regression`.
- `metal/vulkan_soak`: capability dump plus bounded `run-gpu-soak` artifact.
- `headless_deterministic`: `zig build run-transfer-readback && zig build run-compute-readback`
- `presentation_feature_gates`: `zig build run-bindless-textures && zig build run-multi-window && zig build run-external-texture && zig build run-streaming-texture`
- `binding_variant_regression`: covered by `zig build test`; includes dynamic buffer array offsets, resource tables, resource-table pressure plans, root constant writes, and specialization variant fingerprints.
- `sync_query_regression`: covered by `zig build test`; includes explicit barriers, runtime fences/events, native timeline/shared-event submission, physical queue selection, ownership transfer validation, lifecycle callback-once behavior, presentation fallback, and query readback/resolve validation.
- `debug_marker_regression`: `zig build test && zig build run-profiling-plan`; includes borrowed label lifetime, UTF-8 and embedded-NUL validation, native/validation-only marker capabilities, capture gates, query-source semantics, profiling fallback, and issue-report snapshots.
- `resource_utility_regression`: covered by `zig build test`; includes mipmap generation, unaligned fill fallback, backend copy alignment, mip/layer/3D-slice copies, depth/stencil aspects, scaled blit gates, MSAA copy rejection/resolve validation, subresource transitions, sampler border colors, heap planning, heap aliasing, memory pressure reports, and transient diagnostics.
- `platform_interop_regression`: covered by `zig build test`; includes surface registries, present-mode diagnostics, external wrappers, external synchronization validation, and native insertion gates.
- `production_hardening_regression`: `zig build test && zig build run-stability-plan -- --iterations 120`; includes object-cache diagnostics, runtime cache planning, pipeline artifact compatibility planning, runtime diagnostics, capture names, stability plans, and Vulkan fallback diagnostics.
- `advanced_resource_geometry_regression`: covered by `zig build test`; includes sparse/tiled resource planning, residency commit/churn plans, tessellation draw plans, and mesh/task dispatch plans.
- `advanced_geometry_feature_gates`: `zig build run-tessellation && zig build run-mesh-shader`
- `ray_tracing_native_parity_regression`: covered by `zig build test`; includes ray tracing planning, AS maintenance, TLAS metadata, ray query, complex SBT layout, RT stress planning, Metal mapping, native advanced closure, and Period 29 routing.
- `ray_tracing_feature_gates`: `zig build run-ray-traced-scene`

The hosted package smoke runs `scripts/ci/run_package_smoke.sh`. Its independent
Zig 0.16 package uses a local `../..` dependency, passes a consumer-owned Slang
manifest through the `shader_manifest` dependency option, compiles that shader,
and checks canonical API declarations without creating a device or requiring a
GPU.

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

## Period 44 Evidence Boundary

`.github/workflows/ci.yml` owns hosted build/test evidence.
`.github/workflows/gpu-validation.yml` is manual and uses labeled self-hosted
physical GPU runners. Hosted runner compilation never upgrades a GPU gate.

Every physical smoke and soak bundle contains `host.txt` with the full Git
commit, worktree state, toolchain, and host identity plus `capability-dump.txt`
before the workload log. Release evidence must report the exact release commit
and a clean worktree. Failures trigger a second failure capability dump when
possible. `zig build run-release-readiness` only marks a gate observed when the
caller provides the corresponding evidence flag; its default result is not
ready.

The current report is `docs/develop/period44/parity-report.md`.

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
| Timeline fences | Native timeline semaphore when queried/enabled | Native shared event when available | Host query/wait/signal and GPU submit wait/signal; feature is closed without the complete path |
| Events | Portable runtime object | Portable runtime object | Available by default |
| Shared events | Typed unsupported | Native shared event | Same-device cross-queue execution only; external handle sharing remains deferred |
| Compute/transfer queues | Queried physical work queue/family with explicit graphics fallback | Independent physical command queue | `QueueSelectionPlan` reports requested/resolved/fallback state; dedicated means a distinct Vulkan hardware family, not merely a separate Metal queue object |
| Queue ownership transfers | Concurrent native sharing plus exclusive vkmtl logical ownership | Native queue ordering plus exclusive vkmtl logical ownership | Raw queue-family control is not exposed |
| Command-buffer synchronization descriptor | Native timeline waits/signals plus runtime binary fallback | Native shared-event waits/signals plus runtime binary fallback | `CommandBuffer.commitWithSynchronization(...)` validates device, values, borrows, and lifetime |
| Timestamp queries | Native query pools when host reset and graphics timestamps are available; logical fallback otherwise | Native common-counter samples only when draw/dispatch/blit boundaries are all available; logical fallback otherwise | Available by default, with `resultSource()` distinguishing raw native ticks from logical order |
| Occlusion queries | Non-precise native query pools | Pass-bound Boolean visibility scratch copied into query storage | Capability-gated zero/nonzero visibility; pass must bind the exact set |
| Pipeline statistics queries | Typed unsupported | Typed unsupported | One-`u64` result shape cannot represent variable multi-counter results |

## Period 36 Sync And Queue Semantics Expectations

| Feature | Vulkan | Metal | Public Status |
| --- | --- | --- | --- |
| Sync capability report | Derived from usable features | Derived from usable features | `vkmtl.sync.syncCapabilities(device)` |
| Queue capability report | Derived from usable features | Derived from usable features | `vkmtl.command.queueCapabilities(device)` |
| Queue planning | Resolves requested queue to a queried physical work queue or graphics fallback | Resolves requested queue to an independent physical command queue or graphics fallback | `vkmtl.command.planQueue(device, descriptor)` returns `vkmtl.sync.QueueSelectionPlan` |
| Portable command synchronization | Runtime fence/event wait and signal around `commit()` | Runtime fence/event wait and signal around `commit()` | `vkmtl.sync.SynchronizationDescriptor` validates lifetimes, backend identity, and fence values |
| Native timeline/shared-event submit | Timeline semaphore path executable when queried | Shared-event path executable when available | Feature reports only the complete object/host/submit path |
| Physical compute/transfer queues | Queried family and queue handles | Independent command queue objects | Cross-queue ordering uses native monotonic synchronization; current commit remains synchronous |

## Period 48 Synchronization, Lifecycle, And Timing Expectations

| Feature | Vulkan | Metal | Public Status |
| --- | --- | --- | --- |
| Lifecycle callbacks | Composed from successful submit and queue completion | Native scheduled/completed handlers | Exactly once; callback thread identity and asynchronous return are not promised |
| Timed drawable present | Typed unsupported; immediate fallback only when requested | Native scheduled-time and minimum-duration present | Each timing lane has an independent feature gate |
| Hazard ownership | Explicit barriers plus tracked automatic state | Native automatic hazards plus tracked state | Default/tracked semantics only; explicit untracked ownership is unsupported |
| Physical evidence | Unit and forced-Vulkan build | Transfer/readback plus render pixel regression | Vulkan physical rerun remains useful before broad adapter claims |

## Period 24 Resource Utility Expectations

| Feature | Vulkan | Metal | Public Status |
| --- | --- | --- | --- |
| Full-texture mipmap generation | Native image blits | Native `generateMipmapsForTexture` | Available through blit encoder |
| Partial mip/layer mipmap generation | Deferred | Deferred | Typed unsupported; tracked in the Period 44 parity report |
| Unaligned `fillBuffer` | Staging-copy fallback | Native byte-range fill | Public API accepts unaligned ranges |
| Texture copy array layers | Native `layer_count` | Per-slice fallback loop | `slice_count` is public |
| Compatible color-format copies | Native compatible copy class | Native compatible copy class | unorm/sRGB pairs in same channel order |
| `depth32_float` exact copy/readback | Native depth-aspect copy | Native depth texture copy | Capability-gated through format caps |
| Packed depth/stencil exact copy/readback | Native depth or stencil aspect when queried | Typed unsupported | Never uses an implicit packed buffer layout |
| MSAA copies/readback | Typed unsupported | Typed unsupported | Color resolve is the explicit single-sample conversion |
| Fixed sampler border colors | Native sampler state | Native sampler state | Available by default |
| Custom sampler border colors | Deferred | Deferred | Native-extension-only; tracked in the Period 44 parity report |
| Heap planning | Portable runtime object | Portable runtime object | Feature-gated planning/reservation |
| Heap aliasing planning | Portable runtime object | Portable runtime object | `HeapAliasingDescriptor` validates overlapping ranges and lifetimes |
| Native heap-backed resources | Deferred | Deferred | Period 32+ driver parity plan native integration |
| Transient allocation diagnostics | Portable runtime diagnostics | Portable runtime diagnostics | Reports requested units, peak live units, max alignment, aliasable pairs, and savings |
| Memory budget/pressure report | Fallback runtime report until native query is wired | Fallback runtime report until native query is wired | `vkmtl.diagnostics.memoryBudgetReport(device, descriptor)` classifies pressure and source |

## Period 42 Format, Copy, And Attachment Expectations

| Feature | Vulkan | Metal | Public Status |
| --- | --- | --- | --- |
| Format capabilities | Optimal-tiling format properties plus selected-surface format query | Explicit portable-format table | `Device.getFormatCaps(...)`; issue dumps include copy, blit, present, resolve, depth, and stencil flags |
| Buffer/texture alignment | Native optimal-copy offset and row-pitch limits | Portable limit of 1 | Runtime also validates texel-size offset and row-pitch alignment before native encoding |
| Exact color copy | Same channel-order copy classes, including unorm/sRGB pairs | Same portable copy classes | Mip, array-layer, and 3D-slice ranges validated |
| Scaled color blit | `vkCmdBlitImage` when source/destination caps allow it | `UnsupportedTextureBlit` | Nearest or linear; linear also requires source linear filtering |
| Resource state | Per-mip/per-layer portable tracker plus backend image layouts | Per-mip/per-layer portable tracker; native encoder state remains private | Texture views share state; partial explicit barriers are transactional |
| Color MSAA resolve | Native render-pass resolve | Native render-pass resolve | Source must be multisampled; destination must be matching single-sample texture |
| Depth/stencil resolve | Typed unsupported | Typed unsupported | Capability flags remain false until validated lowering exists |
| View format reinterpretation | Compatible linear/sRGB classes plus component swizzle | Compatible linear/sRGB classes plus component swizzle | Other reinterpretations remain typed unsupported |

## Period 47 Common Breadth Expectations

| Feature | Vulkan | Metal | Public Status |
| --- | --- | --- | --- |
| Ordinary resource/dispatch limits | Native physical-device properties | Native device properties/family floors | Resource and compute validation consume queried limits |
| Direct/logical-thread compute dispatch | Native dispatch; logical threads ceil-compose | Native dispatch; logical threads ceil-compose | Shader owns final-group bounds checks |
| Indirect compute dispatch | Native indirect dispatch | Native indirect dispatch | Usage, offset, alignment, and threadgroup size are validated |
| Compute bind groups/root constants | Descriptor sets/push constants | Resource slots/inline bytes | Ordinary path is executable; function tables/heaps stay deferred |
| Compute buffer/texture barriers | Native pipeline barriers plus hazard state | Automatic hazard/order composition plus hazard state | Native fences/events stay Period 48 |
| 32-bit integer atomics/threadgroup memory | Core SPIR-V semantics and queried shared-memory limit | Native atomic/groupshared semantics and queried limit | Storage-texture/64-bit atomic breadth is not promised |
| Portable reflection | Schema-1 array/access metadata consumed with SPIR-V | Same schema-1 metadata consumed with MSL | Advanced backend-only protocols stay deferred |
| Managed synchronization | Host-coherent managed buffers | `didModifyRange` plus `synchronizeResource` | Automatic at current map/read/write boundaries |

## Period 43 Debug Label And Marker Expectations

| Feature | Vulkan | Metal | Public Status |
| --- | --- | --- | --- |
| Object label memory | Borrowed portable slice; native call copies synchronously | Borrowed portable slice; Objective-C label copies synchronously | Caller keeps bytes alive until replacement, clear, or object destruction |
| Object label encoding | Invalid UTF-8 or embedded NUL is not forwarded | Invalid UTF-8 or embedded NUL is not forwarded | Object setters stay infallible for compatibility |
| Marker label memory | Borrowed for the push/signpost call | Borrowed for the push/signpost call | Portable stack stores depth only |
| Command-buffer group scope | Portable validation; native command-buffer marker remains deferred | Native command-buffer debug group | May surround complete encoders; push/pop only in ready state |
| Encoder group scope | Native debug-utils label | Native encoder debug group | Local to one encoder and closed before `endEncoding()` |
| Capture naming | Exact caller-buffer formatting | Exact caller-buffer formatting | `scope:name`, optional backend and frame fields |
| Marker capability report | Object/encoder native when debug utils is enabled; command-buffer validation-only | Object/command-buffer/encoder native | `DebugMarkerCapabilities` reports each lane independently |
| Native capture | Typed `UnsupportedCapture` | Opt-in developer-tools capture scope | `CaptureScope` borrows the backend owner and ends explicitly |
| Timestamp source | Raw native ticks behind query-pool gates, otherwise logical sequence | Raw native ticks behind complete counter-sampling gates, otherwise logical sequence | Source is truthful; duration calibration remains unavailable |
| Profiling fallback | Native ticks, CPU wall clock, or markers | Native ticks, CPU wall clock, or markers | `gpu_duration_available` stays false until a portable tick scale exists |
| Issue snapshot | Backend, adapter, features, limits, operations, errors, runtime counters | Same portable bundle | `vkmtl.diagnostics.issueReport(device, descriptor)` plus expanded capability dump |

## Period 25 Platform And Interop Expectations

| Feature | Vulkan | Metal | Public Status |
| --- | --- | --- | --- |
| Surface registry | Portable runtime state | Portable runtime state | `vkmtl.presentation.makeSurfaceCollection(device)` |
| Native multi-surface presentation | Deferred | Deferred | Period 32+ driver parity plan native escape hatch |
| Present-mode resolution | Portable runtime fallback | Portable runtime fallback | `PresentModeSupport` and `FramePacingDiagnostics` |
| Native present-mode query | Deferred | Deferred | Period 32+ driver parity plan platform query |
| External interop capability matrix | Platform handle matrix | Platform handle matrix | `vkmtl.interop.externalInteropCapabilityMatrix(device)` classifies portable, capability-gated, native-only, and unsupported lanes |
| External memory / buffer wrappers | Portable runtime wrappers | Portable runtime wrappers | Feature-gated descriptors and lifetime tracking |
| Native external memory import | Deferred | Deferred | Period 32+ driver parity plan native import |
| External texture wrapper | Portable runtime wrapper | Portable runtime wrapper | `ExternalTexture` wrapper |
| Native external texture import | Deferred | Deferred | Period 32+ driver parity plan native import |
| External sync wrappers | Portable runtime wrappers | Portable runtime wrappers | `ExternalSynchronizationDescriptor` validation |
| Native external sync wait/signal | Deferred | Deferred | Period 32+ driver parity plan native lowering |
| Native command insertion API | Capability-gated | Capability-gated | Encoder methods validate explicit callbacks |
| Native command handle lowering | Deferred | Deferred | Period 32+ driver parity plan native handle view |

## Period 26 Production Hardening Expectations

| Feature | Vulkan | Metal | Public Status |
| --- | --- | --- | --- |
| Object-cache lookup diagnostics | Portable runtime diagnostics | Portable runtime diagnostics | `cache_policy` and `vkmtl.diagnostics.objectCacheDiagnostics(device)` |
| Native object handle pooling | Deferred | Deferred | Period 32+ driver parity plan native pools |
| Driver cache planning | Portable runtime planning | Portable runtime planning | `vkmtl.diagnostics.planDriverPipelineCache(device, descriptor)` |
| Native driver cache lowering | Deferred | Deferred | Period 32+ driver parity plan `VkPipelineCache` / `MTLBinaryArchive` consumption |
| Runtime cache manifest planning | Portable runtime planning | Portable runtime planning | `vkmtl.diagnostics.planRuntimeCache(device, descriptor)` |
| Runtime cache manifest I/O | Deferred | Deferred | Period 32+ driver parity plan automatic manifest read/write |
| Runtime diagnostics snapshot | Portable runtime diagnostics | Portable runtime diagnostics | `vkmtl.diagnostics.runtimeDiagnostics(device)` |
| Capture name helpers | Portable runtime helper | Portable runtime helper | `vkmtl.diagnostics.CaptureNameDescriptor` and `vkmtl.diagnostics.writeCaptureName(device, descriptor, buffer)` |
| Stability run planning | Portable runtime planning | Portable runtime planning | `vkmtl.diagnostics.StabilityRunDescriptor.plan()` and `run-stability-plan` |
| Common GPU-backed soak | Windowed portable command path | Windowed portable command path | `run-gpu-soak`; advanced native pressure lanes remain separate gates |

## Period 38 Resource Table And Pipeline Artifact Expectations

| Feature | Vulkan | Metal | Public Status |
| --- | --- | --- | --- |
| Resource-table pressure planning | Portable descriptor-indexing pressure summary | Portable argument-buffer pressure summary | `vkmtl.binding.planResourceTablePressure(device, descriptor)` |
| Partially-bound table requirements | Capability / opt-in validation | Capability / opt-in validation | `ResourceTablePressurePlan.canCreateTable()` |
| Update-after-bind table requirements | Capability / opt-in validation | Capability / opt-in validation | `ResourceTablePressurePlan.canCreateTable()` plus runtime table update tests |
| Pipeline artifact compatibility | Shader, entry point, reflection, format, schema, backend, and toolchain compatibility plan | Same compatibility plan for MSL / reflection artifacts | `vkmtl.diagnostics.planPipelineArtifactCache(device, descriptor)` |
| Native pipeline cache/library persistence | Deferred | N/A | Period44 device-matrix evidence after backend lowering exists |
| Native binary archive persistence | N/A | Deferred | Period44 device-matrix evidence after backend lowering exists |

## Period 27 Advanced Resource And Geometry Expectations

| Feature | Vulkan | Metal | Public Status |
| --- | --- | --- | --- |
| Sparse buffer planning | Runtime plan from native features | Runtime plan from native features | `vkmtl.native.planSparseBufferLowering(device, descriptor)` |
| Sparse/tiled texture planning | Runtime plan from native features | Runtime plan from native features | `vkmtl.native.planSparseTextureLowering(device, descriptor)` |
| Residency commit planning | Runtime commit/evict summary | Runtime commit/evict summary | `vkmtl.resource.planSparseMappingCommit(device, descriptor)` |
| Residency churn planning | Runtime commit/evict cycle summary | Runtime commit/evict cycle summary | `vkmtl.resource.planSparseResidencyChurn(device, descriptor)` and `vkmtl.resource.SparseResidencyMap.runChurn(...)` |
| Native sparse/tiled page binding | Deferred | Deferred | Period 32+ driver parity plan native integration |
| Tessellation draw planning | Runtime patch-list draw metadata plan | Runtime factor-buffer metadata plan | `vkmtl.render.planTessellationPatchDraw(device, descriptor)` |
| Native tessellation pipeline | Deferred | Deferred | Period44 device-matrix work after backend pipeline hooks |
| Mesh/task dispatch planning | Runtime task/mesh dispatch metadata plan | Runtime object/mesh dispatch metadata plan | `vkmtl.render.planMeshDispatch(device, descriptor)` |
| Native mesh/task pipeline | Deferred | Deferred | Period44 device-matrix work after backend pipeline hooks |
| Advanced geometry examples | Feature-gated planning examples | Feature-gated planning examples | `examples/tessellation` and `examples/mesh_shader` |

## Period 28 Ray Tracing And Native Parity Expectations

| Feature | Vulkan | Metal | Public Status |
| --- | --- | --- | --- |
| Acceleration-structure build planning | Runtime plan from native features | Runtime plan from native features | `vkmtl.ray_tracing.planAccelerationStructureBuild(device, descriptor)` |
| Native acceleration-structure builds | Backend-private command records | Backend-private command records | Period 30 Phase 1 runtime native boundary; first-triangle Metal handles in Period 31, Vulkan handles in Period 32, full scene mesh BLAS/TLAS in Period33, procedural AS geometry in Period34 |
| Ray tracing pipeline planning | Internal shader-group lowering inventory | Internal function-table lowering inventory | Internalized implementation detail; not public API |
| Native ray tracing pipelines | Backend-private pipeline metadata | First native Metal RT compute pipeline | Period 31 implements the first visible Metal pipeline path; Vulkan pipeline in Period 32, full-scene pipelines in Period33, procedural/custom-intersection pipelines in Period34 |
| SBT and ray dispatch planning | Runtime SBT/dispatch plan | Runtime SBT/dispatch plan | `vkmtl.ray_tracing.planRayDispatch(device, sbt, descriptor)` |
| Native ray dispatch commands | Backend-private dispatch records | First native Metal RT dispatch to drawable | Period 31 implements first-triangle Metal dispatch; Vulkan dispatch in Period 32, full-scene dispatch in Period33, procedural dispatch in Period34 |
| Metal ray tracing mapping planning | Validation no-op | Runtime Metal mapping plan | `vkmtl.native.metal.planRayTracingMapping(device, descriptor)` |
| Native Metal ray tracing execution | Validation no-op | First native Metal RT AS/build/dispatch path plus table metadata | Period 31 implements first-triangle Metal dispatch binding; mesh scene support is Period33, function-table procedural support is Period35 |
| Native advanced closure inventory | Internal roadmap data | Internal roadmap data | Internalized planning inventory; not public API |
| Native advanced backend execution | Backend-private inventory | Backend-private inventory | Period 30 Phase 5 runtime inventory; first triangles in Period 31 and Period 32, mesh scene driver execution in Period33, procedural driver execution in Period34 |
| Parity semantics and soak loops | Runtime diagnostics plan | Runtime diagnostics plan | Period 30 Phase 6 runtime validation; GPU soak deferred to Period32+ |
| Native advanced examples | Period 32 target: Vulkan ray traced scene window | Period 31 implemented: Metal ray traced scene window | Period31/32 make first ray traced scenes pixel-producing; Period33/34 own the full mesh/procedural scene examples |
| Full native RT mesh scene | Mesh build-input path implemented and superseded by Period34 procedural scene for the Vulkan example | Visible Metal full mesh scene | Period33 uses user mesh buffers for `ray_traced_scene`; Vulkan mesh validation happened before the Period34 procedural replacement |
| Procedural RT geometry and custom intersection | AABB build-input lowering, intersection SPIR-V precompile, procedural hit groups, SBT records, and procedural `ray_traced_scene` marker implemented; supported-device visual validation pending | Pixel-producing scene path uses shared scene data; driver-level procedural/intersection-function-table execution is Period39 | Period34 closes the Vulkan procedural path; Period35 adds shared scene data; Period39 owns mixed TLAS and Metal procedural parity |

## Period 39 Ray Tracing Completeness Expectations

| Feature | Vulkan | Metal | Public Status |
| --- | --- | --- | --- |
| AS maintenance | Update/refit/compaction planning from native features | Update/refit/compaction planning from native features | `vkmtl.ray_tracing.planAccelerationStructureMaintenance(device, descriptor)` |
| Many-instance TLAS metadata | Backend-neutral instance layout plan | Backend-neutral instance layout plan | `vkmtl.ray_tracing.planTopLevelAccelerationStructureLayout(device, descriptor)` |
| Ray query | Vulkan ray query planning | Typed unsupported | `vkmtl.ray_tracing.planRayQuery(device, descriptor)` |
| Complex SBT and callable records | Complex SBT record/range planning | Complex SBT record/range planning | `vkmtl.ray_tracing.planComplexShaderBindingTable(device, descriptor)` |
| RT stress planning | Deterministic stress plan | Deterministic stress plan without ray query | `vkmtl.ray_tracing.planRayTracingStress(device, descriptor)` |
| Native GPU stress evidence | Deferred | Deferred | Period44 device-matrix runs |

## Period 37 Memory, Heaps, And Residency Expectations

| Feature | Vulkan | Metal | Public Status |
| --- | --- | --- | --- |
| Heap reservation | Portable runtime reservation object | Portable runtime reservation object | `Device.makeHeap(...)` and `Heap.reserve(...)` |
| Heap aliasing | Portable aliasing plan | Portable aliasing plan | `Heap.aliasingPlan(...)` validates range/lifetime compatibility |
| Memory budget report | Fallback report until native budget query is wired | Fallback report until native budget query is wired | `MemoryBudgetReport` records source and pressure |
| Transient pressure diagnostics | Portable runtime diagnostics | Portable runtime diagnostics | Peak live units and aliasing savings are deterministic |
| Sparse residency churn | Portable plan/map execution | Portable plan/map execution | Repeated commit/evict cycles are deterministic |
| Native heap-backed resources | Deferred | Deferred | Requires backend lowering and Period44 device evidence |
| Native sparse/tiled page binding | Deferred | Deferred | Requires backend lowering and Period44 device evidence |
