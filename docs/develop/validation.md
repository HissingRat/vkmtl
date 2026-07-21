# Validation

This document defines how vkmtl distinguishes source validation, hosted
compilation, deterministic GPU output, physical device execution, and manual
visual evidence. It consolidates the backend test matrix, validation case
inventory, release evidence rules, and the durable Period 44, 55, and 56
records.

The authoritative case and job metadata lives in
`tools/development_matrix.zig`. This document explains that metadata and
records observed evidence. When a command, required flag, host class, or case
name differs, update the tool metadata first and keep this document aligned in
the same change.

The authoritative statement of whether a native semantic is executable lives
in `native-semantic-coverage-inventory.md`. A passing validation row must not
promote planning, native-query availability, or a typed unsupported path to
executable support.

## Evidence Vocabulary

vkmtl uses the following evidence classes. They are deliberately not
interchangeable.

### Source And Deterministic Validation

Unit and focused tests establish backend-neutral contracts, descriptor
validation, state-machine behavior, typed errors, and deterministic CPU
reference values. They can also inspect backend lowering records without
proving that a driver accepted those records.

Use this class for claims such as:

- an invalid descriptor fails before native allocation;
- an unsupported feature returns its documented typed error;
- queue ownership and lifecycle transitions are deterministic;
- a native plan contains the expected format, flags, or resource sizes;
- CPU color reference values map to expected bytes.

This class does not prove native GPU execution.

### Hosted Build Evidence

A hosted build compiles and links a backend on a known operating system and
architecture. It proves source portability, build graph completeness, package
consumption, shader precompilation, and backend-private symbol coverage.

A hosted Vulkan build does not prove that a Vulkan loader, ICD, physical
device, extension, or presentation path executed. A hosted macOS build does
not prove Metal command execution. Hosted runner compilation never upgrades a
GPU gate.

### Headless Physical Evidence

A headless physical run creates a real backend device without creating a GLFW
window or presentation surface. Deterministic transfer, compute, offscreen
render, query, import, and maintenance readbacks belong here when supported by
the selected device.

The artifact must identify the backend and device. Exact or bounded readback
values provide stronger evidence than a successful process exit alone.

### Windowed Physical Evidence

A windowed physical run proves that native surface, swapchain or layer,
command submission, and presentation paths execute on a real device. A finite
success marker is required so opening a window is not treated as completion.

This class can establish execution and presentation without establishing
pixel correctness.

### Deterministic Pixel Evidence

Pixel evidence reads an offscreen result back to the CPU and compares it with
an exact or explicitly tolerant reference. The result must report the maximum
channel delta and the accepted tolerance.

Deterministic offscreen pixels are not current-drawable readback unless the
test explicitly reads the current drawable. A later bind-and-present smoke in
the same executable remains separate windowed physical evidence.

Raster orientation and texture-composition orientation are independent gates.
The raster check uses a counter-clockwise asymmetric triangle with back-face
culling, samples distinct pixels above and below center, and reports
`raster_orientation=top_left`. The 5x2 texture-composition check reports
`presentation_orientation=top_left`; neither result substitutes for the other.

### Soak And Pressure Evidence

A soak repeats bounded resource creation, resize, shader resolution, transfer,
submission, completion, and retirement work. It must publish iteration counts,
live-resource bounds, work serials, and failure classification.

Observed timing, power, and frame-rate numbers are named-host observations,
not portable performance requirements.

### Manual Visual Evidence

A screenshot can accept orientation, scene completeness, and obvious content
errors that deterministic readback does not cover. It cannot by itself prove
the backend, commit, device, validation-layer state, channel order, transfer
function, or byte-exact output.

Separate FPS overlays are not comparative performance evidence.

### API Validation Or Vulkan Validation-Layer Evidence

Metal API Validation evidence requires a positive `Metal API Validation
Enabled` marker or an equivalent captured tool configuration. A quiet Metal
stderr alone is not sufficient.

Vulkan validation-layer evidence requires a positive record that
`VK_LAYER_KHRONOS_validation` was available and enabled, plus the associated
device and driver identity. A quiet log with no error, warning, or VUID proves
only that the supplied output was quiet; it is not a validation-layer-clean
claim.

## Support Status Vocabulary

Every backend row uses one of these meanings:

| Status | Meaning |
| --- | --- |
| Executable | The public path lowers to native or portable runtime work and has the required execution evidence. |
| Capability-gated | The path is executable only when the selected device reports the exact usable feature and limits. |
| Portable fallback | The API executes through a documented fallback with the same public effect. |
| Validation-only | vkmtl validates and records the operation but intentionally emits no equivalent native command. |
| Planning-only | A descriptor or plan exists, but no executable resource or command path is claimed. |
| Typed unsupported | The path rejects with a documented typed error before incorrect lowering. |
| Native escape hatch | A backend-tagged borrowed handle exists outside the portable compatibility promise. |

Planning-only and validation-only rows are not GPU parity. Native feature
discovery is also not executable support. Capability-gated support requires
both a selected-device report and a complete admitted path.

An implementation may intentionally compose several native calls, vkmtl state,
or a compatibility layer to reproduce a semantic. It does not need one native
call per public method. If the effect cannot be reproduced faithfully, the
semantic stays explicitly unsupported.

## Core Validation Commands

Run validation that matches the change. The standard repository baseline is:

```sh
zig fmt --check build.zig src examples tools tests/package_consumer
zig build run-api-guard
zig build run-semantic-inventory-check
zig build test --summary all
zig build
zig build -Dvulkan
zig build run-validation-plan
scripts/ci/run_package_smoke.sh
git diff --check
```

The exact API guard is mandatory for changes to the public root, `Device`,
`Swapchain`, `WindowContext`, or `HeadlessContext`. The semantic inventory
check is mandatory when the native execution inventory or its source data
changes.

Documentation-only changes normally need only link/path checks and
`git diff --check`. Build metadata and package changes require the closest
package fetch or consumer smoke. Backend behavior changes require focused
tests and at least one matching executable example when practical.

The external package smoke uses an independent Zig project with a local vkmtl
dependency. It passes a consumer-owned source-backed `shader_manifest`,
compiles that shader, and verifies canonical API declarations without creating
a device. A successful repository example build is not a substitute for this
consumer contract.

## Required Hosted Build Rows

The following rows are required repository integration lanes.

The general backend registry names these platform rows
`macos_metal_default`, `linux_vulkan`, and `windows_vulkan`. The release-job
registry uses the corresponding `hosted_macos_build`, `hosted_linux_build`,
and `hosted_windows_build` names below.

| Row | Host | Backend | Required command summary | Evidence class |
| --- | --- | --- | --- | --- |
| `hosted_macos_build` | macOS aarch64 | Metal-capable default | format, API guard, tests, default build, validation plan, package smoke | Hosted build only |
| `hosted_linux_build` | Linux x86_64 | Forced Vulkan | format, API guard, tests, `zig build -Dvulkan`, validation plan, package smoke | Hosted build only |
| `hosted_windows_build` | Windows x86_64 | Forced Vulkan | format, API guard, tests, `zig build -Dvulkan`, validation plan, package smoke | Hosted build only |

The Windows forced build additionally gates the backend-private
`vulkan-1.dll` loader and complete non-Darwin Metal bridge stubs.

The hosted command shapes are:

```sh
# macOS
zig fmt --check build.zig src examples tools tests/package_consumer && \
  zig build run-api-guard && \
  zig build test --summary all && \
  zig build && \
  zig build run-validation-plan && \
  scripts/ci/run_package_smoke.sh

# Linux and Windows
zig fmt --check build.zig src examples tools tests/package_consumer && \
  zig build run-api-guard && \
  zig build test --summary all && \
  zig build -Dvulkan && \
  zig build run-validation-plan && \
  scripts/ci/run_package_smoke.sh
```

`.github/workflows/ci.yml` owns hosted build/test evidence. A hosted job must
not be relabeled as physical evidence even if its runner happens to expose a
software adapter.

## Required Physical Release Lanes

The release matrix has six physical GPU rows in addition to the three hosted
rows. Together they are the nine explicit release-readiness gates.

| Row | Backend | Work | Required artifact |
| --- | --- | --- | --- |
| `self_hosted_metal_smoke` | Metal | capability, transfer, compute, render smoke | capability dump and workload logs |
| `self_hosted_vulkan_smoke` | Vulkan | capability, transfer, compute, render smoke | capability dump and workload logs |
| `local_metal_pixel_regression` | Metal | deterministic transfer, compute, asymmetric raster, and presentation-composition readback | readback values, deltas, and orientation markers |
| `local_vulkan_pixel_regression` | Vulkan | deterministic transfer, compute, asymmetric raster, and presentation-composition readback | readback values, deltas, and orientation markers |
| `self_hosted_metal_soak` | Metal | 120 bounded iterations | host, capability, and soak logs |
| `self_hosted_vulkan_soak` | Vulkan | 120 bounded iterations | host, capability, and soak logs |

The canonical commands are:

```sh
scripts/ci/run_gpu_smoke.sh metal artifacts/metal-smoke
scripts/ci/run_gpu_smoke.sh vulkan artifacts/vulkan-smoke

VKMTL_BACKEND=metal zig build run-pixel-regression
VKMTL_BACKEND=vulkan zig build run-pixel-regression -Dvulkan

scripts/ci/run_gpu_soak.sh metal 120 artifacts/metal-soak
scripts/ci/run_gpu_soak.sh vulkan 120 artifacts/vulkan-soak
```

`.github/workflows/gpu-validation.yml` is a manual workflow using labeled
self-hosted physical GPU runners. Its smoke and soak bundles contain
`host.txt`, `capability-dump.txt`, and workload logs. A failure should include a
second capability dump when possible.

`zig build run-release-readiness` marks a gate observed only when the caller
provides its evidence flag. Its default result is not ready. Release evidence
must name the exact release commit and a clean worktree; evidence from an older
commit is historical, not an exact-commit substitute.

## Required Headless And Focused Rows

These rows protect portable contracts without requiring manual visual review.
The names match `tools/development_matrix.zig`.

| Row | Command | Contract |
| --- | --- | --- |
| `headless_deterministic` | `zig build run-transfer-readback && zig build run-compute-readback` | Real transfer, compute, and texture-backed offscreen readback through `HeadlessContext`; no GLFW window or surface. |
| `binding_variant_regression` | `zig build test` | Dynamic buffer array offsets, native resource tables, layout compatibility, reusable indirect ranges, root constants, specialization fingerprints, and driver-cache identity. |
| `sync_query_regression` | `zig build test` | Barriers, fences/events, synchronization descriptors, physical queue selection, ownership transfers, lifecycle retirement, and query validation. |
| `debug_marker_regression` | `zig build test && zig build run-profiling-plan` | Borrowed labels, UTF-8/NUL checks, marker capabilities, capture gates, query sources, profiling fallback, and issue reports. |
| `resource_utility_regression` | `zig build test` | Mipmaps, fills, copies, blits, MSAA, subresource state, sampler borders, heaps, memory reports, and transient diagnostics. |
| `platform_interop_regression` | `zig build test` | Surface registries, present diagnostics, external wrappers, external synchronization validation, and native insertion gates. |
| `production_hardening_regression` | `zig build test && zig build run-stability-plan -- --iterations 120` | Cache plans, runtime diagnostics, capture names, stability planning, and Vulkan fallback diagnostics. |
| `advanced_resource_geometry_regression` | `zig build test` | Sparse/tiled plans, residency commit/churn, tessellation planning, and mesh/task planning. |
| `advanced_geometry_feature_gates` | `zig build run-tessellation && zig build run-mesh-shader` | Public advanced-geometry examples preserve precise executable/unsupported gates. |
| `ray_tracing_native_parity_regression` | `zig build test` | AS, SBT, optional application-resource binding, caller-owned output, presentation selection, raw-copy compatibility, finite-run, and color/radiance-reference contracts. |
| `voxel_world_metal_ray_tracing` | Metal fixed-phase smoke/default finite commands below | Material-bound indexed chunk BLAS/TLAS traversal, complete current 9/169-source physical profile coverage within the 289-source bound, exact 16-byte ground/water/wood/leaf material columns, explicit TLAS-plus-indirect-BLAS read residency, opaque and water normal/distance G-buffers, screen-space refraction, RGB absorption/in-scattering, one opaque-TLAS reflection ray per visible water pixel, one full-resolution diffuse path of at most three sequential cosine-weighted segments per covered opaque pixel, nonzero x/z bounds only for a complete contiguous profile-square TLAS, zero-extent rejection for sparse subsets, terrain-top-only residual environment and outer-edge blending, independent temporal/edge-aware PTGI reconstruction, native driver submission, finite raw/radiance/visibility/reflection readback, and bounded execution under Metal API Validation. |
| `voxel_world_vulkan_ray_tracing` | Vulkan fixed-phase smoke/default finite commands below | The same material-bound PTGI plus refractive-water/opaque-reflection contract on a physical Vulkan RT device; source supports the complete bounded resident set through 289 instances, but physical Vulkan execution remains pending and is never satisfied by forced compilation alone. |

Metal has physical headless evidence for transfer and compute readback. Vulkan
requires a loader and physical device host for equivalent execution. A forced
Vulkan build remains build evidence only.

## Validation Case Inventory

The case metadata in `tools/development_matrix.zig` is authoritative. The
durable expectations are:

| Case | Required behavior |
| --- | --- |
| `invalid_bind_group` | Missing, extra, duplicate, and kind-mismatched entries return typed validation errors. |
| `invalid_texture_format` | Automatic or unsupported ordinary texture formats fail before backend creation; presentation accepts only its bounded request set. |
| `invalid_barrier` | Redundant or mismatched barriers return command-encoding errors. |
| `resource_destroyed_while_in_use` | Pending retirements remain retained until submitted work completes. Backend integration coverage remains an explicit gap. |
| `unsupported_feature` | Feature-gated APIs return typed unsupported errors instead of silently lowering incorrectly. |
| `shader_reflection_mismatch` | Layout, resource kind, visibility, stage, fixed array count, and storage-access mismatches fail before pipeline creation. |
| `runtime_sync_objects` | Fences, events, and synchronization descriptors cover signal, wait, reset, timeout, borrow, same-device, and unsupported behavior. |
| `logical_queue_ownership` | Queue views reject cross-queue resource use until an explicit ownership transfer is recorded. |
| `query_readback` | Bound-pass identity, availability, reset, range/type, feature gates, and readback/resolve agreement remain deterministic. |
| `debug_marker_contract` | Marker lifetime and scope fail before native work; capabilities, capture gates, and profiling sources remain truthful. |
| `resource_utilities` | Copy, mip, blit, resolve, heap, memory, compute, atomic, and managed-readback rules keep typed validation. |
| `platform_interop` | Surface, present, external wrapper/import, synchronization, and native insertion contracts stay backend- and lifetime-aware. |
| `production_hardening` | Cache compatibility, diagnostics, capture names, stability plans, and fallback reports remain deterministic. |
| `advanced_resource_geometry` | Planning records remain distinct from capability-gated or typed-unsupported native execution. |
| `ray_tracing_native_parity` | Planning and advanced gaps remain explicit while geometry-exact AS sizing, one/N TLAS source mapping, transactional Metal AS build-state ownership/compact propagation and transitive residency, AS-kind validation, application-resource binding, caller-owned dispatch, finite runs, and direct/indirect/reconstructed radiance readbacks remain deterministic. |
| `period44_device_evidence` | Hosted builds, physical smoke, pixel readback, soak, and release gates stay distinct; all nine explicit gates have a record. |
| `voxel_world_pressure_test` | Raster smoke/default/stress remain within the current 9/169/289 resident bounds. PTGI smoke/default physically cover complete 9/169-source Metal TLAS sets, while the source remains bounded through 289 instances; finite acceptance requires `ptgi_bounces=3`, nontrivial direct and indirect samples, valid reconstructed radiance, zero invalid pixels, native submission, and the final `voxel_world_pressure_test=ok` marker carrying the bounce count. A fixed-camera water-reflection lane additionally requires nonzero covered and lit reflection pixels, zero invalid reflection pixels, and `rt_reflection_validated=true`; autopilot reports those metrics but may legitimately leave the marker false when no lake is visible. |

Unit-test metadata remains authoritative for portable validation. Integration
gaps must remain marked as gaps rather than being hidden by a nearby unit test.
Command lifecycle/presentation behavior is covered by runtime synchronization,
query, and resource cases. Resource-table persistence is covered by binding and
production-hardening rows. RT maintenance, many-instance TLAS, complex SBT
planning, ray-query discovery, and stress behavior are subcontracts of
`ray_tracing_native_parity`, not separate registered validation-case names.

## Backend Semantic Matrix

This table is a validation summary, not a replacement for the native semantic
inventory.

| Area | Vulkan | Metal | Evidence expectation |
| --- | --- | --- | --- |
| Backend and adapter selection | Executable | Executable | Capability dump names selected backend, adapter, source, limits, and formats. |
| Transfer and readback | Executable | Executable | Exact physical headless readback. |
| Compute dispatch | Executable | Executable | Storage buffer/texture writes and deterministic readback. |
| Render and presentation | Executable | Executable | Pixel readback plus separate current-drawable bind/present smoke. |
| Explicit barriers | Native commands | Validation/tracked no-op composition | State-machine unit tests and native lowering inspection. |
| Runtime fences/events | Executable | Executable | Signal, wait, reset, timeout, and commit ordering tests. |
| Timeline/shared-event submit | Capability-gated native timeline semaphore | Capability-gated native shared event | Full object, host, and submit path must be usable. |
| Compute/transfer queues | Queried physical family or explicit graphics fallback | Independent physical command queue or fallback | Selection plan and cross-queue synchronization. |
| Timestamp queries | Native raw ticks when all gates open; logical fallback | Native common-counter samples when all boundaries open; logical fallback | `QuerySet.resultSource()` must distinguish the source. |
| Boolean occlusion | Capability-gated query pool | Capability-gated visibility result | Physical readback/resolve and reset/reuse. |
| Precise/counting occlusion | Capability-gated precise flag | Counting visibility | Exact `u64` result when enabled. |
| Pipeline statistics | Typed unsupported | Typed unsupported | One-`u64` result cannot represent typed variable counters. |
| Object/encoder markers | Capability-gated native debug utils | Native | Capability report plus native capture/debug tool. |
| Command-buffer markers | Validation-only | Native | `DebugMarkerCapabilities`; do not claim Vulkan native command markers. |
| Native handles | Borrowed escape hatch | Borrowed escape hatch | Backend-tag and owner lifetime contract. |

### Formats, Copies, And Attachments

| Feature | Vulkan | Metal | Validation |
| --- | --- | --- | --- |
| Format capabilities | Queried optimal-tiling and selected-surface properties | Explicit portable-format table plus native selection | `Device.getFormatCaps(...)` and capability dump. |
| Buffer/texture copy alignment | Native offset and row-pitch limits | Portable limit plus native requirements | Validate texel-size, offset, and row-pitch before encoding. |
| Color copies | Same channel-order compatible classes, including unorm/sRGB pairs | Same | Mip, layer, and 3D slice ranges. |
| Scaled color blit | Capability-gated `vkCmdBlitImage` | Typed `UnsupportedTextureBlit` | Source/destination caps; linear requires filtering support. |
| Depth32 exact copy/readback | Capability-gated depth aspect | Capability-gated depth texture copy | No implicit color interpretation. |
| Packed depth/stencil copy | Queried depth or stencil aspect | Typed unsupported | No implicit packed buffer layout. |
| MSAA copy/readback | Typed unsupported | Typed unsupported | Use explicit color resolve. |
| Color MSAA resolve | Native | Native | Matching multisample source and single-sample destination. |
| Depth/stencil resolve | Typed unsupported | Typed unsupported | Capability flags remain false. |
| View reinterpretation | Compatible linear/sRGB class and component swizzle | Same | Other reinterpretations remain unsupported. |
| Memoryless attachment | Typed unsupported | Capability-gated native memoryless storage | Attachment-only; no load/store persistence. |

### Resources, Memory, And Caches

| Feature | Vulkan | Metal | Validation |
| --- | --- | --- | --- |
| Placement heaps | Native device-memory binding | Native placement heap | Exact requirements, reservation offsets, and child-before-heap lifetime. |
| Heap aliasing | Portable lifetime/range plan | Portable lifetime/range plan | Overlap allowed only for compatible non-overlapping lifetimes. |
| Memory budget | Native when extension is usable, explicit fallback otherwise | Native working-set/current-allocation report or fallback | Report source and pressure; fallback is not native proof. |
| Transient diagnostics | Portable | Portable | Resource count, requested units, peak live units, alignment, and savings. |
| Sparse/tiled planning | Available | Available | Page grids and churn plans are diagnostic. |
| Native sparse/tiled page binding | Typed unsupported | Typed unsupported | Planning shapes do not identify an executable binding path. |
| Fixed sampler border colors | Native | Native | Feature and format gates before creation. |
| Custom sampler border colors | Not in portable enum | Not in portable enum | Native-extension-only work remains unallocated. |
| Driver artifact cache | Executable `VkPipelineCache` | Executable `MTLBinaryArchive` | Identity, stale recovery, persistence, and read-only policy. |
| Runtime manifest I/O | Deferred | Deferred | Compatibility planning exists; automatic ownership is not claimed. |

### Binding, Indirect Commands, And Advanced Geometry

| Feature | Vulkan | Metal | Validation |
| --- | --- | --- | --- |
| Scalable resource table | Capability-gated descriptor indexing | Capability-gated argument buffer | Layout, allocation, update, bind, and pressure limits. |
| Pipeline compatibility | Descriptor-set layout in pipeline layout | Runtime fingerprint plus shader slot | Reject mismatch before backend work. |
| Reusable render commands | Exact draw expansion | Native ICB when usable, exact expansion otherwise | CPU-authored fixed slots and ranges. |
| Reusable compute commands | Exact dispatch expansion | Native compute ICB when usable, exact expansion otherwise | CPU-authored fixed slots and reset. |
| Tessellation planning | Available | Available | Patch metadata and factor-buffer requirements. |
| Native tessellation | Capability-gated executable patch pipeline | Typed unsupported with pinned compiler | Public example must exit precisely when unsupported. |
| Mesh planning | Available | Available | Mesh/task or mesh/object metadata. |
| Native mesh-only pipeline | Capability-gated executable | Capability-gated executable | Visible public example and physical evidence where available. |
| Task/object stage | Typed unsupported while compiler artifact is unstable | Typed unsupported while compiler artifact is unstable | Schema-valid declaration does not imply usable execution. |

### Platform And Interop

| Feature | Vulkan | Metal | Validation |
| --- | --- | --- | --- |
| Surface registry | Portable runtime | Portable runtime | Independent descriptor, resize, frame, and generation state. |
| Multiple native presentation chains | Capability-gated | Capability-gated | Do not infer from registry planning alone. |
| Present-mode diagnostics | Native query plus deterministic fallback report | Display-sync support plus fallback report | Surface-specific capability remains conservative. |
| External buffer/texture wrappers | Portable wrappers | Portable wrappers | Backend, device, ownership, lifetime, shape, and usage validation. |
| Native external buffer import | Typed unsupported until exact allocation metadata exists | Same-device `MTLBuffer` import executable | Physical readback for admitted Metal path. |
| Native external texture import | Typed unsupported until image metadata is complete | Same-device `MTLTexture` and single-plane IOSurface executable | Physical readback for admitted Metal path. |
| External synchronization wrappers | Validation available | Validation available | Wait/signal counts and native requirements. |
| Native external wait/signal | Typed unsupported | Typed unsupported | Value and import-ownership rules are absent. |
| Native command insertion | Typed unsupported | Typed unsupported | Callback has no validated active command-buffer/encoder handle. |

### Ray Tracing

| Feature | Vulkan | Metal | Validation |
| --- | --- | --- | --- |
| AS build/update/refit/copy | Backend-private native execution | Backend-private native execution | Resource ownership, size, scratch, and command records. |
| Compact-size query | Typed unsupported | Typed unsupported | No asynchronous post-build compact-size owner. |
| Many-instance TLAS | Complete instance allocation with one repeated or exactly N BLAS sources | Dynamic multi-source ownership plus final descriptor/scratch recheck; failed source/instance replacement restores prior state and compact copy transfers complete reusable build state | Current Metal PTGI smoke/default physically exercise complete 9/169-source sets; the source contract is bounded through 289 sources. Missing Metal traversal dependencies fail as typed invalid command, and Vulkan physical PTGI evidence is pending. |
| Pipeline and dispatch | Native RT pipeline/SBT dispatch with one optional application bind group | Native RT compute pipeline with one optional application bind group plus explicit TLAS and indirect-BLAS read residency | Capability gates, resource layout, dimensions, total rays, typed missing-dependency failure, raw direct/indirect output, and reconstructed-radiance readback. |
| Caller-owned texture output | Executable | Executable | `dispatchRaysToTexture(...)` has no presentation side effect. |
| Procedural AABB geometry | Executable with custom intersection | Native AABB input; custom intersection/function table unsupported | Keep ordinary geometry separate from custom-intersection execution. |
| Ray query | Availability/capability planning; execution remains closed | Typed unsupported | A queried native feature is not executable support. |
| Complex callable SBT | Planning only | Planning only | Schema has no callable artifact or payload region. |
| RT stress | Executable bounded maintenance lane | Executable bounded maintenance lane | `run-ray-tracing-maintenance` does not imply ray-query or function-table support. |

## Presentation And Color Validation

`PresentationDescriptor.format` is the application request.
`Swapchain.selectedFormat()` is the concrete native selection. Automatic SDR
selection prefers `bgra8_unorm_srgb`, then `bgra8_unorm`. An explicit request
must be selected exactly or fail with `UnsupportedPresentationFormat`.

Vulkan selects the exact BGRA8 format with
`VK_COLOR_SPACE_SRGB_NONLINEAR_KHR`; driver enumeration order must not alter
the choice. Metal maps the selected format to `CAMetalLayer.pixelFormat`.

The descriptor extent is requested state. `Swapchain.extent()` is the actual
native drawable extent after surface constraints. Tests cover clamping,
healthy zero-size preservation, unchanged-request fast paths, recovery-forced
recreation, changed-request re-query, and terminal `SurfaceLost` behavior.

Current-drawable render pipelines must declare the selected format exactly.
A mismatch returns `PresentationFormatMismatch` before native pipeline bind or
draw. Offscreen targets retain their own format contracts.

Presentation selection performs no HDR mapping, exposure, tone mapping, gamma
policy, gamut conversion, or scene-content inspection. Those transforms are
application policy. The legacy RT drawable path performs raw byte copying; an
sRGB destination changes how bytes are interpreted, but the copy itself does
not decode or encode them.

## Period 55 Caller-Owned RT Output Record

`ray_tracing.RayTracingTextureResources` identifies a dispatch resource bundle
whose output texture is owned by the caller.
`CommandBuffer.dispatchRaysToTexture(...)` executes on both backends without a
presentation side effect and leaves the output ready for fragment sampling.

Metal binds the caller output without acquiring a drawable. Vulkan writes the
caller texture and transitions it to the sampled-image postcondition. Direct
RT and AS commands consume one native encoding segment; the consumer uses a
later command buffer.

The example uses an `rgba16_float` accumulation target. Dispatch assigns no
color space to those numeric values. The `ray_traced_scene` composition shader
sanitizes and clamps its historical display-referred RGB, applies the standard
sRGB EOTF, and lets the final `bgra8_unorm_srgb` attachment perform the
matching OETF. The locked reference mapping is:

```text
0.0 / 0.18 / 0.5 / 0.8 / 1.0 -> 0 / 46 / 128 / 204 / 255
```

Focused tests cover usage, view shape, queue ownership, dispatch depth and
extent, whole-texture subresources, multisample rejection, the one-segment
rule, finite-run failures, and non-finite color inputs. Vulkan descriptor and
inline-data resources are retained per dispatch.

The Metal offscreen composition readback accepts at most one byte of channel
delta. A physical three-frame Metal run under API Validation established native
command execution separately from the byte-level readback.

## Period 56 Selection And Legacy Raw-Copy Record

The legacy `dispatchRaysToDrawable(...)` route remains a compatibility path.
It dispatches into a whole, single-sample, 2D `bgra8_unorm` caller texture with
shader-write and copy-source usage, then copies bytes to the selected linear or
sRGB BGRA8 drawable. It requires exact dispatch/presentation extent and a
graphics queue.

Metal preflights drawable acquisition, format, extent, and any sRGB staging
allocation before compute. Linear presentation allocates no staging buffer.
The legacy command presents internally; a second explicit present on the same
command buffer returns `InvalidCommandBufferState`.

Vulkan tests cover surface-clamped extents, recovery, active-command resize and
clear rejection, dedicated clear-pool isolation, failed-commit cleanup,
presentation-generation invalidation, and terminal `SurfaceLost`. Teardown
waits the presentation queue before destroying swapchain images, semaphores,
or the swapchain handle.

The canonical physical probes are:

```sh
# Metal application-owned composition
MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_RT_FRAME_LIMIT=3 \
  zig build run-ray-traced-scene

# Metal legacy sRGB and linear raw-copy routes
MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_RT_FRAME_LIMIT=3 \
  VKMTL_RT_LEGACY_DRAWABLE=1 VKMTL_PRESENTATION_FORMAT=srgb \
  zig build run-ray-traced-scene
MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_RT_FRAME_LIMIT=3 \
  VKMTL_RT_LEGACY_DRAWABLE=1 VKMTL_PRESENTATION_FORMAT=linear \
  zig build run-ray-traced-scene

# Vulkan application-owned composition
VKMTL_BACKEND=vulkan VKMTL_RT_FRAME_LIMIT=3 \
  zig build run-ray-traced-scene -Dvulkan

# Vulkan legacy raw-copy route
VKMTL_BACKEND=vulkan VKMTL_RT_FRAME_LIMIT=3 \
  VKMTL_RT_LEGACY_DRAWABLE=1 \
  zig build run-ray-traced-scene -Dvulkan
```

The backend registry calls the Metal command bundle
`ray_tracing_metal_color_path` and the Vulkan composition probe
`ray_tracing_vulkan_color_path`. `manual_ray_traced_scene_visual` records the
separate screenshot-review class; it never replaces deterministic pixel
readback.

## Current Physical Evidence

### Period 44 Release-Matrix Snapshot

The 2026-07-10 report recorded all nine release gates observed:

- hosted macOS, Linux, and Windows build/test jobs;
- physical Metal and Vulkan smoke;
- Metal and Vulkan pixel regression;
- Metal and Vulkan 120-iteration bounded soak.

Hosted evidence was collected with Zig 0.16.0. Physical Metal evidence named
macOS 15.7.3 arm64 and Apple M4 Pro. Physical Vulkan evidence named Windows 10
build 19045 x86_64, NVIDIA GeForce RTX 5080, NVIDIA driver 610.62, and Vulkan
API 1.4.341.

The Metal render pixel result recorded maximum channel delta 0. The Vulkan
render pixel result recorded maximum channel delta 1. Both soak runs completed
120 upload/readback and portable-residency cycles with submitted/completed work
serial 120/120 and a maximum of four live resources.

Both memory-budget reports used the explicit `fallback` source with nominal
pressure. This is not native Metal or Vulkan memory-budget proof. No device
loss was injected or observed. Multi-hour soak, native memory pressure,
physical async-queue pressure, sparse residency, and equivalent advanced
stress remain separate evidence lanes.

This is a historical exact-commit snapshot. Later code changes require fresh
release artifacts for affected lanes.

### v0.1.0 Exact-Commit Snapshot

The annotated `v0.1.0` tag and published release point to commit
`96c5b08c34163a148f9811efff04a6f78936778a`.

That release passed formatting, API guard, tests, default and forced-Vulkan
builds, external consumer smoke, hosted macOS/Linux/Windows CI, physical Metal
and Vulkan smoke/pixel/soak evidence, and a fresh tag-archive consumer smoke.
The readiness evaluator reported 9/9 observed and `release ready: true`.

The record establishes the v0.1.0 release line. It is not evidence for changes
made after that commit.

### Current Metal Presentation Evidence

The automatic, explicit sRGB, and explicit linear pixel-regression requests
completed under physical Metal API Validation:

```sh
MTL_DEBUG_LAYER=1 VKMTL_PRESENTATION_FORMAT=srgb \
  VKMTL_BACKEND=metal zig build run-pixel-regression
MTL_DEBUG_LAYER=1 VKMTL_PRESENTATION_FORMAT=linear \
  VKMTL_BACKEND=metal zig build run-pixel-regression
MTL_DEBUG_LAYER=1 VKMTL_PRESENTATION_FORMAT=automatic \
  VKMTL_BACKEND=metal zig build run-pixel-regression
```

Each printed `max_channel_delta=0 presentation_max_channel_delta=1` and the
positive API Validation marker. Those bytes are offscreen readback, not
drawable readback. Each run then separately encoded, bound, and presented a
pipeline matching the selected current drawable.

The native linear capability probe reported
`requested=bgra8_unorm, selected=bgra8_unorm`, with only linear BGRA8 marked
presentable for that selected configuration.

Both legacy Metal RT format commands printed
`Presentation path: legacy_drawable_raw_copy`,
`trace_driver_submitted=true`, and
`ray traced scene finite run ok: backend=metal frames=3` under Metal API
Validation with no validation error.

The asymmetric 5x2 top/bottom-row composition regression passes physical Metal
readback with at most one byte of channel delta and reports
`presentation_orientation=top_left`.

After the general raster correction, a local physical Metal run also enabled
counter-clockwise front-facing state with back-face culling, preserved the
61170-sample occlusion result, returned `max_channel_delta=0`, and reported
both `raster_orientation=top_left` and
`presentation_orientation=top_left`.

### Current Vulkan RT Evidence

The post-acceleration-structure-sizing Windows reruns selected both expected
presentation paths. Canonical `texture_composition` and compatibility
`legacy_drawable_raw_copy` both built BLAS/TLAS objects, dispatched 518400
rays, reported `trace_driver_submitted=true` and `runtime_ready=true`, and
completed finite runs.

The supplied canonical markers included:

```text
blas_size=2560
tlas_size=2048
scratch_size=2048
blas_built=true
tlas_built=true
trace_driver_submitted=true
runtime_ready=true
driver_pixels=visible_vulkan_procedural_rt_scene
```

The legacy screenshot had the established top-left orientation. The first
canonical screenshot exposed a full vertical flip caused by deriving
fullscreen UV Y from clip-space interpolation. The correction derives 1:1 UVs
from fragment `SV_Position.xy` and source texture dimensions.

After that correction, the canonical route completed 3000 frames. The accepted
screenshot places the blue and yellow emissive spheres above the central sphere
and the lobed object and floor reflection below it. Its direct masked mean
absolute RGB difference from the accepted compatibility screenshot was about
2.34; vertically flipping it increased the difference to about 18.20. Both RT
visual routes are accepted.

The latest supplied Vulkan RT logs do not positively identify the device or
driver and do not prove that `VK_LAYER_KHRONOS_validation` was enabled. They
are physical execution and visual-orientation evidence only. The earlier named
Period 44 NVIDIA host must not be inferred as the identity of these later logs.

The asymmetric 5x2 physical Vulkan composition regression subsequently passed
on clean commit `7d88ffe` with `presentation_max_channel_delta=0` and
`presentation_orientation=top_left`. That version's ordinary raster check
sampled only the background and center, so it did not detect a separate
clip-space Y inversion in general geometry.

After the general raster correction, the supplied physical Windows rerun used:

```sh
zig build run-pixel-regression
```

It selected `.vulkan` and returned `max_channel_delta=0`,
`raster_orientation=top_left`,
`presentation_max_channel_delta=0`, and
`presentation_orientation=top_left`. Counter-clockwise back-culling preserved
the 61170-sample occlusion result; native timestamps and query reset/reuse also
passed. This closes current physical Vulkan raster semantics independently of
the accepted RT scene orientation.

### Current Windows Vulkan Headless And Raster Diagnostic

Clean commit `7d88ffe46d9c5b7f16d8f16319c84e8b6cf9f2e7`
selected an NVIDIA GeForce RTX 5080 through `vulkan_query` with a clean
worktree. `run-pixel-regression` completed physical HeadlessContext transfer
and compute readback, native occlusion/timestamp work and reset/reuse, and the
then-current render/composition checks with `max_channel_delta=1`,
`presentation_max_channel_delta=0`, and
`presentation_orientation=top_left`.

This closes physical Vulkan loader/device execution for that exact commit. It
does not establish general raster orientation: the 5x2 path tested texture
composition, while the ordinary raster readback did not distinguish top from
bottom and did not enable culling.

On the same code line, smoke/default/stress voxel runs completed 24/48/160
frames, drained pending rebuilds, stayed within 9/81/289 resident chunks, and
printed `voxel_world_pressure_test=ok`. These runs are accepted as pressure
diagnostics only. The visible Vulkan voxel scene was vertically inverted, so
they do not close raster parity or the Vulkan voxel release lane.

The subsequent corrected-path run passed the asymmetric raster/composition
readback with both channel deltas at zero. Its smoke/default/stress voxel runs
completed 24/48/160 frames with resident counts 9/81/289, pending work zero,
and `voxel_world_pressure_test=ok`. The stress run rendered 121 visible and
culled 168 resident chunks. Together the deterministic raster readback and
bounded voxel runs close the earlier orientation/pressure diagnostic.

The supplied corrected-path artifact did not repeat `git rev-parse HEAD` or
`git status --short`. It is accepted physical behavior evidence, but it is not
an exact-release-commit cleanliness record. The future release candidate must
still refresh every required lane against its final clean commit.

## Historical Pre-PTGI Textured Hybrid Voxel Record

This record preserves the intermediate post-Period-56 visibility renderer that
preceded material-bound PTGI. It is historical evidence, not a description of
the current voxel output contract. The later PTGI record below supersedes its
nearest-49 TLAS, `rgba8_unorm` visibility target, and no-GI/no-denoising
limitations while retaining this evidence boundary.

That pre-PTGI slice preserved the existing 9/81/289 resident
pressure bounds while adding a deterministic 476 x 68 seven-tile sRGB atlas,
face-specific UVs, alpha-derived detail normals, indexed chunk BLAS objects,
and a TLAS bounded to the nearest 7 x 7 chunks. The atlas has no mipmaps. The
full-resolution `rgba8_unorm` RT target stores directional-light and sky
visibility and is sampled by the raster pass; it is not a path-tracing, GI,
reflection, HDR, or denoising contract.

`VKMTL_VOXEL_RT=auto` is the default and may retain raster rendering when the
device or required format usage is unavailable. `off` fixes the raster
baseline. `required` must either execute the native hybrid path or fail with a
typed capability/format error; it must not silently fall back.

Finite hybrid runs read back visibility after pending work drains and repeat
the readback on the final frame. The second observation prevents a valid early
sample from hiding a late Metal residency regression. The bounded smoke/default
validation lanes run long enough for the drain; intentionally shorter frame
limits may finish with `rt_visibility_validated=false` rather than violating
the exact-frame contract. Both observations must remain nontrivial.
Hybrid-lane acceptance requires
`renderer=hybrid_rt`, `rt_driver_submitted=true`,
`rt_visibility_validated=true`, at least one primary hit, and at least one
shadowed or sky-occluded pixel. The Metal API Validation smoke and default runs
passed. After the 60-second day/night cycle landed, that historical default
49-source TLAS completed 48 frames, 48 dispatches, and 176947200 primary rays
with 81 resident chunks, 49 visible chunks, and zero pending work. Its final
observation reported:

```text
rt_primary_hits=1846752 rt_shadowed=553298 rt_sky_occluded=403844
```

Those values are observations from that run and cycle phase, not portable
numeric thresholds. Acceptance requires nontrivial visibility rather than
matching the exact counts.

This also exercises the Metal corrections that query the real geometry and
final TLAS descriptors, reserve adequate result/scratch sizes, dynamically own
source arrays, and retain the reusable build/traversal state in each AS wrapper
rather than a temporary descriptor. TLAS source/instance replacement is
transactional: failure restores the previous descriptor sources and instance
contents, while successful build/update publishes the new state. TLAS compact
copy transfers the complete descriptor, backing-resource, traversal, and
update-sizing state needed by subsequent operations. Dispatch explicitly
declares the TLAS and all indirectly referenced BLAS objects as compute-read
resources, returns typed invalid command if a built TLAS lacks those
dependencies, and separately rejects a pipeline/AS BLAS-versus-TLAS kind
mismatch. A 300-frame Metal default-profile soak repeated the final visibility
observation and retained non-zero primary, shadowed, and sky-occluded counts.
Focused Vulkan tests cover complete TLAS instance allocation and exact
one-repeated or N-source mapping. That historical Vulkan hybrid lane was never
run physically; the current material-bound Vulkan lane is specified below.

## Material-Bound PTGI Metal-First Record

The historical one-bounce voxel route recorded in this section binds
application material resources directly to the RT pipeline. Its caller-owned
`rgba16_float` target stores direct visibility and one cosine-weighted indirect
sample for every covered full-resolution surface pixel. Secondary hits use the
CPU terrain sampler's exact 16-byte
ground/water/wood/leaf material columns and the same atlas as rasterization. A
normal-plus-distance G-buffer, temporal reprojection with rejection and
clamping, and four edge-aware a-trous passes produce the reconstructed indirect
texture consumed by the linear HDR raster composition.

On 2026-07-18 an Apple M4 Pro executed the then-current material-bound route
with a positive `Metal API Validation Enabled` marker. This historical
snapshot used the former 60-second clock, so fixed time `30` meant noon. Every
recorded run reported
`renderer=hybrid_rt`, `rt_driver_submitted=true`,
`rt_visibility_validated=true`, `rt_ptgi_validated=true`, zero pending work,
and `voxel_world_pressure_test=ok`.

| Profile | Frames | Fixed cycle | Resident / traced | Dispatches | Primary rays | Primary hits | Direct lit | Shadowed | Indirect lit | Low indirect | Reconstructed lit | Invalid |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| smoke | 24 | 0 (midnight) | 9 / 9 | 24 | 88473600 | 3686400 | 727803 | 2958597 | 3558961 | 127559 | 3686400 | 0 |
| default | 48 | 30 (noon) | 81 / 81 | 48 | 176947200 | 3686400 | 1129790 | 2556610 | 3686400 | 10059 | 3686400 | 0 |
| smoke soak | 300 | 0 (midnight) | 9 / 9 | 300 | 1105920000 | 3686400 | 447903 | 3238497 | 3367508 | 323306 | 3686388 | 0 |

The counts are observations, not portable numeric thresholds. `Direct lit` and
`Shadowed` partition covered primary surfaces. `Indirect lit` counts samples
above the admitted nonzero threshold. `Low indirect` is a low-radiance
diagnostic, not a generic sky-occlusion semantic. `Reconstructed lit` comes
from the post-temporal/a-trous texture. `Invalid` combines non-finite or
negative raw/reconstructed samples and must remain zero.

The exact Metal commands for this snapshot were:

```sh
MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_VOXEL_RT=required \
  VKMTL_VOXEL_PROFILE=smoke VKMTL_VOXEL_FRAME_LIMIT=24 \
  VKMTL_VOXEL_AUTOPILOT=1 VKMTL_VOXEL_CYCLE_TIME=0 \
  zig build run-voxel-world
MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_VOXEL_RT=required \
  VKMTL_VOXEL_PROFILE=default VKMTL_VOXEL_FRAME_LIMIT=48 \
  VKMTL_VOXEL_AUTOPILOT=1 VKMTL_VOXEL_CYCLE_TIME=30 \
  zig build run-voxel-world
MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_VOXEL_RT=required \
  VKMTL_VOXEL_PROFILE=smoke VKMTL_VOXEL_FRAME_LIMIT=300 \
  VKMTL_VOXEL_AUTOPILOT=1 VKMTL_VOXEL_CYCLE_TIME=0 \
  zig build run-voxel-world
```

This was a dirty-source snapshot rather than a clean exact-commit run. It is
accepted implementation and physical Metal evidence, but it is not release
candidate evidence and cannot satisfy the future exact-commit refresh.

The source supports a complete resident TLAS through 289 instances. At this
historical snapshot, physical Metal coverage was 9 sources in smoke and 81 in
default; the superseding 169-source record appears below. Vulkan shader
artifacts, focused tests, the ordinary build, and the forced Vulkan build pass,
but none proves execution of the material-bound route. The current physical
Windows Vulkan RT lane remains:

```powershell
$env:VKMTL_BACKEND="vulkan"
$env:VKMTL_VOXEL_RT="required"
$env:VKMTL_VOXEL_PROFILE="smoke"
$env:VKMTL_VOXEL_FRAME_LIMIT="24"
$env:VKMTL_VOXEL_AUTOPILOT="1"
$env:VKMTL_VOXEL_CYCLE_TIME="0"
zig build run-voxel-world -Dvulkan
Remove-Item Env:VKMTL_VOXEL_AUTOPILOT -ErrorAction SilentlyContinue
$env:VKMTL_VOXEL_PROFILE="default"
$env:VKMTL_VOXEL_FRAME_LIMIT="96"
$env:VKMTL_VOXEL_CYCLE_TIME="150"
zig build run-voxel-world -Dvulkan
```

That lane must record backend/device identity, native submission, complete
9/169-source traversal, direct and indirect raw radiance, reconstructed
radiance and visibility, zero invalid pixels, the diagnostic penumbra count,
and the finite success marker. Physical Vulkan PTGI remains pending.

## Celestial-Disk Soft Visibility Refinement Record

The example's displayed sun and moon radii now also define the angular extent
sampled by direct hardware shadow rays. Each pixel keeps one direct shadow ray
per frame: a static pixel scramble and R2 temporal sequence choose a point on
the active source disk, while center-direction `NdotL` keeps fully visible
surface brightness stable. Independent sample lanes are used for the indirect
bounce, primary visibility, and secondary-hit visibility.

Direct visibility no longer reaches the raster material as a raw binary alpha.
Two separate `rgba16_float` histories store its mean, second moment, validity,
and history length. The same depth/normal reprojection contract rejects stale
geometry, a minimum current weight keeps the moving day/night source
responsive, and one 5 x 5 normal/depth-aware pass produces final visibility.
The original indirect path remains independent and retains all four a-trous
passes. This is example-private policy, not a new public denoiser or ray-tracing
semantic.

On 2026-07-18 an Apple M4 Pro reran the deterministic physical Metal lanes
under a positive `Metal API Validation Enabled` marker. This is historical
evidence from the former 60-second clock, where fixed time `30` meant noon:

| Profile | Frames | Fixed cycle | Traced chunks | Primary rays | Penumbra pixels | Invalid |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| smoke | 24 | 0 (midnight) | 9 | 88473600 | 86867 | 0 |
| default | 48 | 30 (noon) | 81 | 176947200 | 237145 | 0 |

Both runs reported `rt_driver_submitted=true`,
`rt_visibility_validated=true`, `rt_ptgi_validated=true`, and the finite
pressure marker. `rt_penumbra` counts reconstructed surface samples between
the admitted fully shadowed and fully lit thresholds; it is an observation,
not a portable numeric gate. `zig build test`, `zig build`,
`zig build -Dvulkan`, and `git diff --check` also passed. Interactive
fixed-noon and lower-sun inspection showed softened but geometry-aligned
transitions. The evidence is from a dirty source snapshot, so it does not
satisfy future exact-release-commit gates, and physical Vulkan execution
remains pending.

## Voxel Biome And Daylight Balance Record

This post-Period-56 refinement remains entirely inside the example. When PTGI
is disabled, raster terrain keeps the established environment term. When PTGI
is enabled, raster environment becomes only a residual fill, preventing the
raster path and reconstructed indirect texture from each supplying a complete
skylight contribution. Direct sun/moon radiance remains controlled by the
separate reconstructed visibility signal. This is scene-lighting policy, not a
vkmtl color, GI, or public rendering semantic.

Deterministic feature columns extend the existing fixed-point terrain. Tree
anchors are accepted only when their complete footprint is ordinary grass,
dry, and level enough; snow footprints therefore cannot contain trunks or
leaves. A low-frequency mask adds water above selected low sandy ground while
preserving the ground below it. Raster meshing uses these same world-coordinate
columns through its one-block halo. RT secondary-hit lookup receives an exact
16-byte packed column containing ground height, surface and water level, plus
wood and leaf vertical spans. The Zig packer, Slang path, and direct Metal MSL
path share that layout.

The atlas now has eleven deterministic tiles, adding wood top/side, leaves, and
water. Atlas alpha remains a height signal, the terrain BLAS remains opaque,
and the raster terrain pass does not blend, so leaves and water are deliberately
opaque voxel materials. This record does not claim cutout foliage, transparent
or refractive water, or RT any-hit transmission.

On 2026-07-18 an Apple M4 Pro reran the current feature-balanced source under
Metal API Validation:

| Profile | Renderer | Frames | Resident / pending | Visible vertices | Primary rays | Penumbra pixels | Invalid |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| smoke | hybrid RT | 24 | 9 / 0 | 19180 | 88473600 | 118340 | 0 |
| default | hybrid RT | 48 | 81 / 0 | 81912 | 176947200 | 258864 | 0 |
| stress | raster | 160 | 289 / 0 | 242336 | n/a | n/a | n/a |

The smoke/default penumbra counts are observations, not portable thresholds;
zero invalid pixels remains required. All three lanes retained their bounded
pressure success markers. Chunk dimensions remain `16 x 64 x 16`, profiles
remain bounded at 9/81/289 resident chunks, and processing remains capped at
two rebuilds and 8 MiB of uploads per frame. `zig build test`, `zig build`, and
`zig build -Dvulkan` passed. The forced Vulkan build proves source and shader
compilation only; physical Vulkan execution of this feature-balanced PTGI route
remains pending. These observations came from the current dirty source snapshot
and do not satisfy a future exact-release-commit refresh.

## Translucent Voxel Water Record

This earlier post-Period-56 refinement is example-private and is superseded by
the refractive-water record below. It changed no vkmtl public
API, backend semantic, or compatibility claim. Leaves remain opaque. Each chunk
now carries exact opaque and water index ranges, and meshing retains the
solid-water interface. Only the opaque range enters the terrain G-buffer and
BLAS; hardware-RT primary, visibility, and indirect rays therefore pass
optically thin through lake water and can reach the bed.

The visible water is a separate premultiplied-alpha pass into the HDR target,
with depth writes disabled and water-bearing chunks ordered far to near. Four
world-coordinate analytic waves use one continuous 64-second phase. Fresnel
response blends body color with the current sky and active celestial highlight.
The path requires `DeviceFeatures.blend_state` and blendable `rgba16_float`.
It does not claim refraction, volumetric absorption, RT reflections, multilayer
transparency, or order-independent transparency.

On 2026-07-18 an Apple M4 Pro reran the translucent-water source under Metal
API Validation:

| Profile | Frames | Resident / pending | Draws | Visible vertices | Visible indices | Uploaded bytes | Primary rays | Invalid |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| smoke | 24 | 9 / 0 | 12 | 20976 | 31464 | 1095464 | 88473600 | 0 |
| default | 48 | 81 / 0 | 44 | 84224 | 126336 | 7080312 | 176947200 | 0 |

Both lanes retained their finite pressure markers and native RT submission.
`zig build test`, `zig build`, and `zig build -Dvulkan` passed on the current
source. The forced Vulkan build remains compilation evidence only, and physical
Vulkan execution of this route is pending. These observations came from a
dirty source snapshot and do not satisfy a future exact-release-commit refresh.

## Refractive And RT-Reflected Voxel Water Record

The current example keeps the exact opaque/water index partition and retained
solid-water contact faces, but no longer treats the visible lake as a
premultiplied-alpha material pass. Opaque sky and terrain first produce a
complete scene-linear HDR texture. Water then resolves transmission and
reflection into a separate full-coverage HDR overlay, whose alpha is a coverage
mask. The presentation pass composites the overlay over opaque HDR before
bloom, tone mapping, and output transfer. This avoids sampling and writing the
same HDR target in one pass.

The G-buffer pass emits two independent normal/distance surfaces: the opaque
surface retains the detailed material normal and camera distance, while the
water surface stores the matching animated wave normal and water distance. The
current clean-room, SEUS PTGI E12-inspired surface combines six
world-continuous analytic wave bands with different scales, directions, and
temporal harmonics. Raster shading and the G-buffer share that evaluation,
including camera-distance and grazing-angle stabilization. No E12 source,
constants, shader organization, or assets are copied.

The water shader projects a thickness- and distance-aware refracted camera
segment into screen space, rejects invalid UV or opaque-depth candidates, and
falls back to the direct pixel. The admitted water-to-opaque distance is
clamped and used as a path-length estimate. A homogeneous single-scattering
medium uses `sigma_a = (0.240, 0.062, 0.014)` and `sigma_s = 0.070` for RGB
Beer-Lambert transmission and in-scattering. It applies no painted blue body
tint, so thin water remains dominated by transmitted scene radiance while
deeper paths develop blue-green attenuation.

When hybrid RT is selected, the existing ray-generation dispatch also clears a
writable `rgba16_float` reflection target. Every valid water G-buffer pixel
reconstructs its world point, reflects the camera ray around the animated
normal, and traces the opaque terrain TLAS with a 96-world-unit maximum; the
opaque PTGI ray bound remains 384. Opaque hits reuse the material column/atlas
plus direct and environment lighting. Misses evaluate a directional day,
twilight, or night sky with a restrained horizon and the active sun or moon
disk and halo. The reflection target's alpha marks valid traced results.
Raster fallback leaves it invalid so the water shader selects the sky
reflection instead. Fresnel uses dielectric `F0 = 0.02` and a narrow
approximately 420-exponent celestial glint. Water itself remains absent from
the TLAS, and reflection rays therefore cannot see another water surface.

The shared HDR/G-buffer admission gate requires `blend_state`,
`independent_blend`, at least three simultaneous color attachments,
`rgba16_float` sampling, filtering, linear filtering, and color-attachment
support, plus a `depth32_float` attachment. `rgba16_float` blending is not
required. The hybrid route separately requires storage and copy-source/
copy-destination support for its RT and readback textures.

This is bounded screen-space transmission, not a general participating-medium
renderer. Off-screen opaque data and geometry hidden behind another opaque
surface are unavailable to refraction. Foam, caustics, rain response, parallax
water, TAA and reflection denoising, nested or underwater media,
water-to-water reflection, multilayer transparency, and OIT remain out of
scope. The reflection is one unfiltered ray per visible water pixel and has no
separate temporal reconstruction or fixed numeric pixel golden.

Finite RT validation now copies the reflection target to CPU-visible memory.
Each texel must be finite and nonnegative; alpha must be either uncovered zero
or covered one, and an uncovered texel may not contain radiance. A fixed-camera
finite run is the deterministic water lane and fails with
`VoxelWaterReflectionRegression` unless it observes nonzero covered pixels,
nonzero lit covered pixels, and zero invalid pixels. It records the maximum
observed counts as `rt_reflection_pixels` and `rt_reflection_lit` and publishes
`rt_reflection_validated=true`. Autopilot can legitimately turn away from every
lake, so it reports the same counts and marker without requiring the marker.

On 2026-07-18 an Apple M4 Pro completed the strict fixed-camera 24-frame smoke
with `MTL_DEBUG_LAYER=1`, `VKMTL_BACKEND=metal`, and
`VKMTL_VOXEL_RT=required`, under a positive `API Validation Enabled` marker. It
submitted 24 RT dispatches and 88,473,600 primary rays and reported 1,017,402
primary-hit pixels, 438,485 reflection-covered pixels, 438,485 lit reflection
pixels, and zero invalid pixels. It ended with:

```text
voxel_world_pressure_test=ok backend=metal profile=smoke frames=24 renderer=hybrid_rt rt_driver_submitted=true rt_visibility_validated=true rt_ptgi_validated=true rt_reflection_validated=true
```

The subsequent E12-inspired clean-room surface refinement retained those
strict fixed-noon counts and validation markers. A fixed-midnight 24-frame API
Validation lane retained 88,473,600 rays, 1,017,402 primary hits, and 438,485
reflection-covered pixels, with 429,947 lit reflection pixels, zero invalid
pixels, and all native/visibility/PTGI/reflection markers true. Its 24-frame
Metal raster lane also passed, as did `zig build test` and
`zig build -Dvulkan`. Together these prove the G-buffer, writable
reflection texture, RT dispatch, strict readback, water overlay, and
presentation route under Metal API Validation. The observed counts are not
fixed numeric gates and cannot prove every screen-space fallback case. The
forced Vulkan build is compilation evidence only; no physical Vulkan execution
of this route is claimed.

## Voxel Day/Night Presentation Record

The example-private presentation slice does not allocate public API or backend
support claims. One 300-second clock maps 0/75/150/225/300 seconds to midnight,
sunrise, noon, sunset, and wrapped midnight. It drives the celestial sky,
terrain lighting, direct RT visibility, and indirect RT environment. The
independent real-time cloud wind and 64-second water loop are not frozen by the
celestial validation override. Validation separates deterministic scene
construction, forced backend compilation, finite physical execution, and
interactive visual review:

| Layer | Required evidence | Current record |
| --- | --- | --- |
| Deterministic source behavior | Terrain coordinate snapshots, bounded climate-biome coverage, grass-only tree and low-lake rules, exact packed RT feature spans, opaque/water index partitioning with retained contact faces, continuous 64-second world-coordinate water phase, cached-halo/direct-sampler equality across negative chunk boundaries, cycle phase/wrap/continuity and opposite-direction checks, PTGI history/reset and finite-radiance/visibility checks, sky/raster/water uniform ABI, and 5x7 UI batching tests | `zig build test` passed for the preceding translucent-water snapshot; shader compilation and the physical smoke below cover the superseding water transmission/reflection route. |
| Forced Vulkan build | Compile the registered sky/UI/opaque-and-water-G-buffer/PTGI/presentation/RT shader artifacts and the windowed example with `zig build -Dvulkan` | Passed. This is compilation evidence, not physical Vulkan execution. |
| Metal material-bound PTGI finite runs | Fixed-phase smoke for 24 frames and default for 48 frames under Metal API Validation; require native submission, direct and indirect raw radiance, reconstructed radiance and visibility, zero invalid pixels, and drained work. A fixed-camera water lane also requires nonzero covered/lit reflection readback and `rt_reflection_validated=true`; autopilot reports but does not require that marker. | The preceding translucent-water rerun completed both lanes. The superseding refractive/RT-reflected fixed-noon smoke and its E12-inspired clean-room surface refinement completed 24 frames with 24 dispatches, 88,473,600 rays, 1,017,402 primary hits, 438,485 reflection-covered and lit pixels, zero invalid pixels, and all native/visibility/PTGI/reflection markers true. A fixed-midnight 24-frame lane retained those rays, hits, covered pixels, zero-invalid result, and markers, with 429,947 lit reflection pixels. Its default lane has not been rerun. |
| Metal material-bound PTGI soak | Fixed-midnight smoke for 300 frames under Metal API Validation; retain native submission, PTGI validation, reconstructed output, zero invalid pixels, and the bounded pressure marker | Passed with nine resident/traced chunks, 300 dispatches, and 1105920000 primary rays. |
| Metal raster pressure | Stress profile, 160 frames, RT off; require 289 resident chunks, zero pending work, and the pressure-test success marker | The current feature terrain rerun passed with 289 resident chunks, zero pending work, and 242,336 visible vertices. The later E12-inspired water-surface refinement also passed a 24-frame raster smoke lane. |
| Metal visual interaction | Inspect representative night, twilight, and daytime frames, their sky/terrain-light transitions, refracted lake composition, depth-dependent absorption, RT/sky Fresnel response, and world-continuous waves; retain the upper-right FPS and both ESC overlay states | The preceding translucent-water presentation was accepted on a physical Metal device. The superseding refraction/absorption/reflection route has API-Validation smoke evidence, but its explicit visual-acceptance lane remains pending. |
| Physical Vulkan presentation | Repeat finite hybrid execution and visually inspect the day/night sky, lighting, UI, and orientation on a supported Vulkan RT host | Pending; no claim is inferred from the forced build. |

The current PTGI fixed-phase commands and 300-frame soak are recorded in the
material-bound PTGI section above. The retained raster stress command is:

```sh
MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_VOXEL_PROFILE=stress \
  VKMTL_VOXEL_FRAME_LIMIT=160 VKMTL_VOXEL_RT=off \
  zig build run-voxel-world
```

The next physical Vulkan host run must use one clean, identified source commit
and must record backend/device identity, finite-run direct/indirect and
reconstructed-radiance metrics, plus representative day/night images with
correctly oriented FPS/title UI. It remains a follow-up evidence lane and is
not required to describe the completed example-private implementation.

## Voxel Five-Minute Atmosphere And Cloud Record

This example-private refinement does not allocate public API or backend support
claims. The celestial clock is 300 seconds with deterministic probes at 0
(midnight), 75 (sunrise), 150 (noon), 225 (sunset), and 300 (wrapped midnight).
`VKMTL_VOXEL_CYCLE_TIME` freezes only that celestial phase. World-anchored
cloud wind continues from real elapsed time, and water retains its independent
continuous 64-second loop.

The clean-room, E12-inspired sky is an analytic direction- and sun-dependent
atmosphere with a bright horizon, deep zenith, and warm low-sun glow around the
existing moon and stars. Lower self-shadowed cumulus and upper stretched
cirrus are evaluated by raster sky and, on the hybrid path, RT miss/PTGI
environment and hardware-RT water reflection. Raster water fallback retains
the analytic current-sky tint and does not evaluate procedural clouds or
celestial disks. The downward ground hemisphere fades smoothly into the ground
response rather than returning a bright sky for downward misses. For cost
control, the RT cloud environment is evaluated only for actual reflection/PTGI
misses and the outer traced-edge environment blend. Dense cumulus supplies
full moving day/twilight cloud shadows plus restrained moonlight shadows.
Active-light strength gates its direct-visibility attenuation so the sun/moon
direction switch occurs at zero directional contribution. No E12 source,
constants, shader organization, textures, or assets are copied. Weather/rain,
volumetric cloud raymarching, cloud TAA, and a public atmospheric API remain out
of scope.

The darker-daylight balance uses daytime ambient `0.44`, hybrid raster
daylight safety `0.14` while night remains `0.20`, RT secondary-hit daylight
environment `0.13`, and traced-edge daylight environment `0.56`. Direct sun,
night ambient, water Fresnel, and the celestial glint are unchanged.

Current validation is:

| Lane | Result |
| --- | --- |
| Deterministic/build | `zig build`, `zig build test`, and `zig build -Dvulkan` passed. The forced Vulkan build is compilation evidence only. |
| Metal required RT, fixed noon `150`, smoke 24 | 88,473,600 rays, 1,017,402 primary hits, 438,485 reflection-covered and lit pixels, zero invalid pixels, every native/visibility/PTGI/reflection marker true, `rt_ms=9.992`. |
| Metal required RT, fixed midnight `0`, smoke 24 | Same ray, hit, and covered counts; 429,962 lit reflection pixels, zero invalid pixels, every marker true, `rt_ms=9.547`. |
| Metal raster, fixed noon `150`, smoke 24 | Passed under Metal API Validation. |
| Interactive Metal observation | Default required-RT noon stabilized around 65-68 FPS after warmup; raster sky was about 120 FPS on this machine. These are observations, not performance gates. |

The physical Vulkan atmosphere/cloud/PTGI lane remains pending.

## Current Wider-View And Chunk-Streaming Record

The superseding example contract uses smoke/default/stress resident bounds of
9/169/289 chunks. CPU terrain meshing runs through one example-private worker
with at most one outstanding ticket. Ticket identity discards stale results
after the desired set changes; startup failure selects the synchronous fallback
instead of weakening correctness. Interactive runs admit one completed mesh per
frame and finite validation admits two, both under the unchanged 8 MiB upload
budget. GPU buffer upload, BLAS construction, and command submission remain
synchronous on the render thread. TLAS publication normally batches additions
for four frames, but bootstrap, queue drain, and source replacement publish
immediately. Replaced BLAS owners retire only after the replacement TLAS is
published. These are example-private scheduling rules: they add no native-
semantic row and do not change the synchronous `CommandBuffer.commit` contract.

The current fixed-noon default commands intentionally omit autopilot and allow
96 frames for the 169-chunk neighborhood to drain:

```sh
MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_VOXEL_RT=required \
  VKMTL_VOXEL_PROFILE=default VKMTL_VOXEL_FRAME_LIMIT=96 \
  VKMTL_VOXEL_CYCLE_TIME=150 zig build run-voxel-world
MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_VOXEL_RT=off \
  VKMTL_VOXEL_PROFILE=default VKMTL_VOXEL_FRAME_LIMIT=96 \
  VKMTL_VOXEL_CYCLE_TIME=150 zig build run-voxel-world
```

Under Metal API Validation, the required-RT command completed 96 frames with
169 resident and 169 traced chunks, zero pending work, 169 BLAS objects, 22
TLAS builds, 96 dispatches, and 353,894,400 rays. Readback reported 2,404,265
primary hits, 862,626 direct-lit and 1,541,639 shadowed pixels, 2,403,729
indirect-lit and 2,404,265 reconstructed-lit pixels, 632,564 reflection-covered
and 632,564 reflection-lit pixels, 298,276 reconstructed penumbra pixels, zero
invalid pixels, and every native/visibility/PTGI/reflection marker true. The
background scheduler reported 169 submitted, 169 completed, zero failed, and
zero stale jobs. Total background mesh time was 411.750 ms; synchronous upload
and TLAS time were 179.797 ms and 18.437 ms. Frame p50/p95/max were
19.919/23.364/401.845 ms; the maximum includes the strict final readback and is
not an interactive frame-time gate.

The matching Metal raster command completed 96 frames with 169 resident
chunks, 81 visible and 88 culled, zero pending work, 104 draws, 180,132
vertices, 270,198 indices, and 14,111,376 uploaded bytes. Both observations are
from the current development snapshot, not a clean exact-release-commit
candidate. Physical Vulkan execution of the 169-chunk default lane remains
pending.

The required-RT metrics immediately above are retained one-bounce development
evidence for the wider-view scheduler. The scheduler and raster observations
remain applicable, but the PTGI shader result is superseded by the current
three-segment record below.

## Current Three-Bounce Experimental PTGI Record

For every covered opaque pixel, each frame launches one path with at most three
sequential cosine-weighted diffuse segments. Every hit evaluates an independent
sun/moon next-event sample, material albedo propagates path throughput, and a
terminal residual environment contribution is added at most once. The water
surface keeps its separate one-segment specular reflection. Ray generation
issues each trace in sequence; shaders do not recurse and the native pipeline
continues to use `max_recursion_depth=1`. `FrameData` receives nonzero x/z
chunk bounds only when the currently published TLAS contains the complete
contiguous square required by the active profile. During initial fill or
movement, a sparse subset publishes zero extent and diffuse misses cannot
sample environment. Once the square is complete, a miss samples residual
environment only when the path is confirmed to reach terrain top before a
horizontal side. The existing outer-edge blend applies the same terrain-top
gate and adds nothing to a side miss. This prevents untraced geometry beyond
the second- or third-bounce boundary from appearing as sky light. Consequently
this is an example-private shader-policy change, not new public API, command
behavior, or a new native-semantic contract. It is a clean-room experimental
enhancement and does not claim that default SEUS PTGI E12 uses three bounces.

The log now emits `ptgi_bounces=3`. The existing `primary_rays` field retains
its compatibility name but counts dispatch threads only; it does not count the
additional sequential diffuse or next-event trace segments. The finite success
marker carries the same bounce count, for example:

```text
voxel_world_pressure_test=ok backend=metal profile=smoke frames=24 renderer=hybrid_rt ptgi_bounces=3 rt_driver_submitted=true rt_visibility_validated=true rt_ptgi_validated=true rt_reflection_validated=true
```

Under Metal API Validation, the fixed-noon default lane completed 96 frames
with 169 resident chunks, zero pending work, 169 submitted/169 completed/zero
failed/zero stale mesh jobs, `ptgi_bounces=3`, 22 TLAS builds, and 96 RT
dispatches. It reported `rt_ms_per_frame=16.327`, 353,894,400 dispatch threads
in `primary_rays`, 2,404,265 primary hits, 863,410 direct-lit and 1,540,855
shadowed pixels, 1,932,365 indirect-lit and 626,079 low-indirect pixels,
2,404,258 reconstructed-lit pixels, 632,564 reflection-covered and 632,564
reflection-lit pixels, 297,535 reconstructed penumbra pixels, zero invalid
pixels, and every native/visibility/PTGI/reflection marker true. Frame
p50/p95/max were 24.081/28.004/442.164 ms.

The final-boundary fixed-noon smoke completed 24 frames with nine resident
chunks, zero pending work, `ptgi_bounces=3`, `rt_ms_per_frame=10.767`, 1,017,402
primary hits, 431,231 direct-lit and 586,171 shadowed pixels, 303,369
indirect-lit and 744,071 low-indirect pixels, 1,017,398 reconstructed-lit pixels,
438,485 reflection-covered/lit pixels, 45,238 penumbra pixels, zero invalid
pixels, and all markers true. Fixed-midnight smoke retained the same resident
and pending counts plus the same primary-hit count with
`rt_ms_per_frame=11.248`, 431,228 direct-lit, 586,174 shadowed, 279,887
indirect-lit, 839,646 low-indirect, 960,442 reconstructed-lit, 438,485
reflection-covered, 429,973 reflection-lit, 53,592 penumbra, zero invalid
pixels, and all markers true.

On the same fixed-noon default96 command, host, and final boundary logic, a
temporary bounce-count-only one-bounce A/B reported
`rt_ms_per_frame=12.870`, frame p50/p95
20.960/23.583 ms, 2,137,634 indirect-lit, 507,522 low-indirect, and 2,404,265
reconstructed-lit pixels, with all validation markers true. The three-bounce
run reported 16.327 RT ms and p50/p95 24.081/28.004 ms, about 26.9% more RT
cost. Its 1,932,365 indirect-lit, 626,079 low-indirect, and 2,404,258
reconstructed-lit counts are not an unbiased energy comparison: terminal
residual is deferred until the final configured hit and side exits are
conservative. Frame maximum and load transients are not performance gates.
Both A/B runs came from a dirty source snapshot and are not clean evidence for
an exact release commit. Physical Vulkan execution of this exact three-bounce
workload remains pending.

The first Windows RTX interactive attempt reached Vulkan `hybrid_rt`, printed
`ptgi_bounces=3`, and loaded all registered voxel shaders, then returned
`InvalidResourceBarrierState` before the first live/metrics line. The async
no-producer frame had no TLAS, so RT plus temporal/a-trous dispatch was skipped
and both PTGI scratch images retained Vulkan's undefined layout. The HDR pass
then drew the sky before binding the terrain group, making the required sampled
layout transition illegal inside the active render pass. The current candidate
guards terrain and water-lighting binding until the first PTGI producer has
completed. Its focused test, Metal interactive startup, forced Vulkan build,
and Windows Vulkan cross-build pass. A follow-up interactive Windows RTX rerun
no longer reproduced the startup error. That confirms the immediate barrier
fix, but does not substitute for a bounded physical run with PTGI pixel metrics.

## Optional And Pressure Lanes

### Capability Dump

`zig build run-capability-dump` should report:

- selected backend and adapter identity;
- capability source;
- usable vkmtl features;
- native queried backend features;
- selected limits;
- representative format capabilities;
- requested and selected presentation state when a surface exists.

Native queried features may appear before vkmtl exposes a complete lowering.
The usable section must stay conservative.

### Voxel World

The bounded raster-only Metal pressure commands are:

```sh
MTL_DEBUG_LAYER=1 VKMTL_VOXEL_RT=off VKMTL_VOXEL_PROFILE=smoke \
  VKMTL_VOXEL_FRAME_LIMIT=24 VKMTL_VOXEL_AUTOPILOT=1 \
  VKMTL_BACKEND=metal zig build run-voxel-world
MTL_DEBUG_LAYER=1 VKMTL_VOXEL_RT=off VKMTL_VOXEL_PROFILE=default \
  VKMTL_VOXEL_FRAME_LIMIT=96 VKMTL_BACKEND=metal \
  zig build run-voxel-world
MTL_DEBUG_LAYER=1 VKMTL_VOXEL_RT=off VKMTL_VOXEL_PROFILE=stress \
  VKMTL_VOXEL_FRAME_LIMIT=160 VKMTL_BACKEND=metal \
  zig build run-voxel-world
```

Each run must print `voxel_world_pressure_test=ok`, drain pending rebuilds,
and remain within the current 9/169/289 resident bounds. The current scheduler
admits one background completion per interactive frame or two per finite frame
under the 8 MiB upload budget; upload and GPU work remain synchronous. The
durable older Metal observation used an Apple M4 Pro and the former bounded
upload/rebuild policy. Equivalent Vulkan pressure execution on `7d88ffe` met
the then-current numeric bounds but used the inverted general raster path. The
post-correction historical rerun again passed smoke/default/stress at
9/81/289 resident chunks with zero pending work; the asymmetric top/bottom
pixel readback independently establishes corrected raster orientation.

The capability-gated material-bound Metal PTGI lane is:

```sh
MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_VOXEL_RT=required \
  VKMTL_VOXEL_PROFILE=smoke VKMTL_VOXEL_FRAME_LIMIT=24 \
  VKMTL_VOXEL_AUTOPILOT=1 VKMTL_VOXEL_CYCLE_TIME=0 \
  zig build run-voxel-world
MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_VOXEL_RT=required \
  VKMTL_VOXEL_PROFILE=default VKMTL_VOXEL_FRAME_LIMIT=96 \
  VKMTL_VOXEL_CYCLE_TIME=150 \
  zig build run-voxel-world
MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_VOXEL_RT=required \
  VKMTL_VOXEL_PROFILE=smoke VKMTL_VOXEL_FRAME_LIMIT=300 \
  VKMTL_VOXEL_AUTOPILOT=1 VKMTL_VOXEL_CYCLE_TIME=0 \
  zig build run-voxel-world
```

These are the current fixed-phase commands. The earlier recorded Metal runs
printed native submission, direct-visibility and PTGI validation,
reconstructed radiance, zero invalid pixels, and the bounded success marker
under the former 60-second clock; its exact `30`-second noon command remains in
the historical record above. The Vulkan physical material-bound lane remains
pending as described in the PTGI record above.

### MoltenVK And iOS

`macos_moltenvk_forced` is an optional forced-backend build and requires
explicit loader and ICD configuration:

```sh
zig build -Dvulkan \
  -Dvulkan-loader-dir=/path/to/vulkan/lib \
  -Dvulkan-icd=/path/to/MoltenVK_icd.json
```

It is for backend testing and is not the default macOS release target.

The `ios_metal_optional` planning command is:

```sh
zig build -Dtarget=aarch64-ios
```

That row remains planning metadata until platform surface packaging is
designed.

### Presentation Feature Gates

The windowed feature-gate bundle is:

```sh
VKMTL_PIXEL_REGRESSION=1 zig build run-bindless-textures
zig build run-multi-window
zig build run-external-texture
zig build run-streaming-texture
```

Each example must preserve a typed unsupported result when its selected-device
gate is closed. A successful planning screen is not native feature execution.

### Ray Tracing Maintenance

`zig build run-ray-tracing-maintenance` provides headless physical evidence for
build, update/refit, compact-copy, AABB, and multi-source acceleration
structure work. It does not imply executable ray query, callable SBT records,
or Metal custom-intersection function tables.

## Artifact And Review Rules

Every physical release bundle should include:

1. the full Git commit and clean/dirty worktree state;
2. Zig version and target triple;
3. operating system and architecture;
4. selected backend, adapter, driver, and native API version when available;
5. capability dump before the workload;
6. the exact command and relevant environment variables;
7. stdout/stderr without truncating the success or error marker;
8. deterministic readback values, deltas, and tolerances where applicable;
9. screenshots only when visual evidence is part of the gate.

Review must distinguish:

- compilation from driver execution;
- process completion from pixel correctness;
- offscreen readback from drawable readback;
- a quiet log from an enabled validation layer;
- native feature discovery from usable vkmtl support;
- fallback output from native execution;
- named-host observations from portable requirements;
- historical exact-commit evidence from current release evidence.

Failures should preserve the typed vkmtl error and classify the broad category
as `device_lost`, `surface_lost`, `validation`, `unsupported_feature`, or
another explicit class. Do not turn an unexpected failure into a skip merely
because another backend passes.

## Release Decision Rule

A release candidate is ready only when every required hosted and physical gate
is observed against the exact candidate commit, the worktree is clean, public
API and semantic inventories pass their guards, the external package consumer
passes, and no supported capability has been promoted from planning or build
evidence alone.

Optional device-specific lanes may remain unavailable when their capability is
not part of the portable release promise. Their unavailable status and typed
behavior must remain documented.

The current durable state is:

- the historical Period 44 and v0.1.0 nine-gate records are complete;
- current Metal caller-owned RT, presentation selection, raw-copy, API
  Validation, and asymmetric 5x2 readback evidence is recorded;
- current Vulkan canonical and legacy RT execution and visual orientation are
  accepted;
- clean-commit Windows Vulkan HeadlessContext and 5x2 composition execution is
  recorded on an RTX 5080, while its old general raster path was vertically
  inverted;
- corrected physical Vulkan asymmetric raster/cull and composition readback
  both report top-left orientation with zero channel delta, and all three voxel
  profiles pass their pressure bounds;
- the historical pre-PTGI textured hybrid voxel route passed Metal smoke/default
  with 9/49 indexed chunk sources, native submission, drain/final-frame
  visibility readback, and a 300-frame non-zero soak; it remains historical
  evidence rather than the current material-bound contract;
- the material-bound PTGI source passes the deterministic test suite, the
  ordinary and forced Vulkan builds, and Metal API Validation on an Apple M4
  Pro. The earlier translucent-water rerun retained complete 9/81-source
  smoke/default TLAS sets. The superseding screen-space-refraction,
  Beer-Lambert absorption/in-scattering, and opaque-TLAS reflection route,
  including the clean-room E12-inspired water and atmosphere/cloud refinement,
  completed a fixed-noon `150` 24-frame Metal API Validation smoke with 24
  dispatches, 88,473,600 rays, 1,017,402 primary hits, 438,485 reflection-
  covered and lit pixels, native submission, PTGI/visibility/reflection
  validation, zero invalid pixels, and `rt_ms=9.992`. Its forced Vulkan build
  is compilation evidence only. A fixed-midnight `0` 24-frame lane retained
  438,485 covered pixels and reported 429,962 lit pixels with the same ray/hit
  counts, zero-invalid result, all markers, and `rt_ms=9.547`. Physical Vulkan
  PTGI/water/atmosphere execution remains pending. The superseding 96-frame
  fixed-noon default run drained and traced all 169 current default chunks,
  built 169 BLAS and 22 batched TLAS versions, submitted 353,894,400 rays,
  retained zero invalid pixels and every validation marker, and reported
  169/169/0/0 submitted/completed/failed/stale CPU mesh jobs. Its matching
  raster lane also drained 169 chunks. The current three-bounce default rerun
  retained the same 169 chunks, job counts, 22 TLAS builds, 96 dispatches, and
  zero-invalid/all-markers result with `ptgi_bounces=3`; `primary_rays` counted
  353,894,400 dispatch threads, reconstructed radiance covered 2,404,258
  pixels, and `rt_ms_per_frame=16.327` after complete-square TLAS-boundary
  publication and terrain-top-only environment correction.
  These current development observations
  are not clean candidate evidence;
- representative night/twilight/day frames, FPS, and the ESC overlay remain
  visually accepted on Metal, while current physical Vulkan presentation and
  material-bound PTGI evidence remain pending;
- every required lane must still be refreshed on the exact clean future
  release commit.
