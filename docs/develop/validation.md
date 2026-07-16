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
| `ray_tracing_native_parity_regression` | `zig build test` | AS, SBT, dispatch, caller-owned output, presentation selection, raw-copy compatibility, finite-run, and color-reference contracts. |

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
| `ray_tracing_native_parity` | Planning and advanced gaps remain explicit while caller-owned dispatch, presentation selection, exact drawable validation, raw copy, finite run, and color references remain deterministic. |
| `period44_device_evidence` | Hosted builds, physical smoke, pixel readback, soak, and release gates stay distinct; all nine explicit gates have a record. |
| `voxel_world_pressure_test` | Smoke/default/stress remain within 9/81/289 resident bounds and end with `voxel_world_pressure_test=ok`. |

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
| Many-instance TLAS | Multiple BLAS sources executable | Multiple BLAS sources executable | Transform, mask, custom/material index, range, and SBT offset validation. |
| Pipeline and dispatch | Native RT pipeline/SBT dispatch | Native RT compute pipeline | Capability gates, records, dimensions, and total rays. |
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

After the general raster correction, this remains the required physical
Vulkan command:

```sh
VKMTL_BACKEND=vulkan zig build run-pixel-regression -Dvulkan
```

It must report both `raster_orientation=top_left` and
`presentation_orientation=top_left`, with channel deltas within the configured
bounds. This lane is independent of the accepted RT scene orientation. Its
absence does not reopen Period 56 visual closure, but it leaves the corrected
general-raster contract incomplete for a fresh release matrix.

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

The corrected exact commit must rerun the pixel regression and all three voxel
profiles. Pixel output must contain both top-left orientation markers; voxel
output must retain the pressure bounds and show the same upright scene as
Metal.

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

The bounded Metal pressure commands are:

```sh
MTL_DEBUG_LAYER=1 VKMTL_VOXEL_PROFILE=smoke \
  VKMTL_VOXEL_FRAME_LIMIT=24 VKMTL_VOXEL_AUTOPILOT=1 \
  VKMTL_BACKEND=metal zig build run-voxel-world
MTL_DEBUG_LAYER=1 VKMTL_VOXEL_PROFILE=default \
  VKMTL_VOXEL_FRAME_LIMIT=48 VKMTL_BACKEND=metal \
  zig build run-voxel-world
MTL_DEBUG_LAYER=1 VKMTL_VOXEL_PROFILE=stress \
  VKMTL_VOXEL_FRAME_LIMIT=160 VKMTL_BACKEND=metal \
  zig build run-voxel-world
```

Each run must print `voxel_world_pressure_test=ok`, drain pending rebuilds,
and remain within the 9/81/289 resident bounds. The durable Metal observation
used an Apple M4 Pro and bounded upload/rebuild budgets. Equivalent Vulkan
pressure execution on `7d88ffe` met all numeric bounds, but its visible scene
was vertically inverted. It remains diagnostic rather than accepted voxel
raster evidence until repeated after the backend viewport correction.

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
- the corrected asymmetric raster/cull pixel regression and voxel profiles
  remain required artifacts for the next fresh release matrix.
