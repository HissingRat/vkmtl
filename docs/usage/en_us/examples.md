# vkmtl Examples

Examples are public API consumers. They live under `examples/` and should not
import backend-private modules such as `src/backend/vulkan`,
`src/backend/metal`, raw Vulkan bindings, or Metal bridge headers.

Examples may import:

- the public `vkmtl` module
- external windowing packages such as `zig_glfw`
- shared example-only glue such as `vkmtl_examples_common`
- assets and shaders that belong to the example

If an example needs a backend feature that is not public yet, add the public
vkmtl API first instead of reaching into a backend implementation.

The current gallery metadata is tracked in `tools/development_matrix.zig` so
tests can keep names, paths, run steps, deterministic output markers, and
backend expectations in sync with this document.

Shader-backed examples embed their Slang source with `@embedFile(...)`, compile
it through `Device.compileRenderShader(...)` or
`Device.compileComputeShader(...)` by resolving build-time precompiled blobs,
and attach embedded reflection JSON to pipeline stages. Ray tracing examples
use `Device.compileRayTracingShader(...)` and let the compiled shader apply the
selected backend's ray-generation/miss/hit shader blobs to the pipeline
descriptor. Single-buffer rendering examples derive their vertex descriptors
from reflection. Shader-resource examples also derive bind group layouts from
reflection. Inspectable build-time artifacts are installed under
`zig-out/shaders/`.

## Reviewed Gallery Contract

The names and commands below match the current `build.zig` run steps. “Window”
means the process stays interactive until the window is closed. “Auto-exit”
cases may use either a small GLFW surface or `HeadlessContext`; their row states
which mode applies.

| Example | Command | Mode | Expected result |
| --- | --- | --- | --- |
| Clear screen | `zig build run-clear-screen` | Window | Selected backend name and a stable solid-color drawable. |
| Triangle | `zig build run-triangle` | Window | Selected backend name and a colored triangle. |
| Offscreen texture | `zig build run-offscreen-texture` | Window | Offscreen triangle sampled onto the presented quad; pixel mode prints `render pixel regression ok backend=... max_channel_delta=...`. |
| MSAA triangle | `zig build run-msaa-triangle` | Window | Multisampled triangle resolved and sampled into the drawable. |
| Rainbow cube | `zig build run-rainbow-cube` | Window | Rotating textured cube with depth and indexed drawing. |
| Voxel world | `zig build run-voxel-world` | Window; profile/frame-limit/autopilot envs provide bounded finite runs | Bounded visible-face chunk renderer with atlas materials, camera/culling, streaming, metrics, and `voxel_world_pressure_test=ok`. |
| Transfer readback | `zig build run-transfer-readback` | Auto-exit | Exact copies pass and print `transfer readback ok`. |
| Compute readback | `zig build run-compute-readback` | Auto-exit | Storage buffer/texture bytes match and print `compute readback ok`. |
| Capability dump | `zig build run-capability-dump` | Auto-exit | Console reports requested/selected presentation formats, then backend/adapter, features, limits, formats, and diagnostics. |
| Bindless textures | `zig build run-bindless-textures` | Windowed; set `VKMTL_PIXEL_REGRESSION=1` for one frame | Samples a 65-slot native table through a reusable indirect draw and reports persistent cache use, or prints a typed unsupported message. |
| Multi-window | `zig build run-multi-window` | Two-window probe | Prints both surface records, then availability or the expected feature-gate line. |
| External texture | `zig build run-external-texture` | Auto-exit probe | Prints capability/usage planning plus a real-handle requirement or explicit unsupported line. |
| External import | `zig build run-external-import` | Headless Metal auto-exit | Imports raw Metal buffer/texture objects and an IOSurface, verifies three GPU readbacks, and prints `external import ok: ...`. |
| Streaming texture | `zig build run-streaming-texture` | Auto-exit probe | Prints residency success or `streaming texture unsupported: ...`. |
| Tessellation | `zig build run-tessellation` | Window | Renders native Vulkan patches, or exits with a typed unsupported line. |
| Mesh shader | `zig build run-mesh-shader` | Window | Renders one native Metal/Vulkan mesh grid, or exits with a typed unsupported line. |
| Ray-traced scene | `zig build run-ray-traced-scene` | Window when supported; `VKMTL_RT_FRAME_LIMIT` enables a finite run | Native RT stores accumulated legacy display-referred RGB in `rgba16_float`; a shared fullscreen pass preserves that reference output and prints the backend-specific `driver_pixels=visible_...` marker, or an actionable unsupported diagnostic. |

The repository does not commit screenshot image assets. Visual evidence is
recorded in the Period 32 Vulkan RT validation notes and the Period 44 9/9
parity report; deterministic transfer, compute, and render pixels are also
covered by `zig build run-pixel-regression`. These records document observed
output without fabricating or embedding unavailable images.

## Triangle

`examples/triangle` is the first backend-independent rendering sample. It
creates a GLFW surface, requests `.auto` backend selection, uploads vertex data
through `Device.makeBuffer`, creates a render pipeline through
`Device.makeRenderPipelineState`, handles drawable resize through
`Swapchain.resize(...)`, records commands with `CommandBuffer` /
`RenderCommandEncoder`, and presents through the public command API.
Its current-drawable pipeline uses `Swapchain.selectedFormat()` rather than the
presentation request. The same rule applies to every windowed gallery pipeline;
the capability dump prints both requested and selected formats.

For presentation regressions, shared example glue accepts
`VKMTL_PRESENTATION_FORMAT=automatic`, `srgb`, or `linear`. This is an
example-only request override. An unknown value prints a warning and requests
automatic selection; it does not change the library's exact explicit-request
contract.

Run it with:

```sh
zig build run-triangle
```

On Apple platforms `.auto` selects Metal when available. For backend debugging,
the example accepts:

```sh
zig build run-triangle -Dvulkan
VKMTL_BACKEND=vulkan zig build run-triangle
VKMTL_BACKEND=metal zig build run-triangle
```

The example embeds `examples/triangle/shaders/triangle.slang`, compiles it at
runtime, and uses the cached SPIR-V/MSL/reflection artifacts through public
stage descriptors.

## Clear Screen

`examples/clear_screen` is the presentation smoke test. It should stay small and
focused on surface creation, resize, clear, and present behavior.

Run it with:

```sh
zig build run-clear-screen
```

## Offscreen Texture

`examples/offscreen_texture` is the first explicit render-target sample. It
renders a colored triangle into a texture-backed color attachment, then samples
that texture onto an indexed quad in the current drawable.

Run it with:

```sh
zig build run-offscreen-texture
```

The offscreen texture is created through the public resource API with both
`.render_attachment` and `.shader_read` usage, viewed with
`makeTextureView(...)`, then passed into the render pass as:

```zig
.color_attachments = &.{.{
    .target = .{ .texture_view = &offscreen_view },
    .clear_color = .{ .red = 0.02, .green = 0.025, .blue = 0.035, .alpha = 1.0 },
}},
```

The screen pass binds the same texture view and a sampler through a public bind
group whose layout is derived from shader reflection. The example intentionally
uses two command buffers for now: one for the offscreen pass and one for the
presented pass.

The Slang source lives beside the example:

```text
examples/offscreen_texture/shaders/offscreen_texture.slang
```

## MSAA Triangle

`examples/msaa_triangle` is the first multisample resolve sample. It renders a
colored triangle into a 4x MSAA texture, resolves it into a single-sample
texture, then samples that resolved texture onto an indexed quad in the current
drawable.

Run it with:

```sh
zig build run-msaa-triangle
```

The MSAA pipeline sets:

```zig
.sample_count = 4,
```

The MSAA render pass uses an explicit resolve target:

```zig
.color_attachments = &.{.{
    .target = .{ .texture_view = &msaa_view },
    .resolve_target = &resolved_view,
}},
```

The resolved texture is single-sample and has both `.render_attachment` and
`.shader_read` usage so the screen pass can sample it. The screen pass bind
group layout is derived from shader reflection.

The Slang source lives beside the example:

```text
examples/msaa_triangle/shaders/msaa_triangle.slang
```

## Rainbow Cube

`examples/rainbow_cube` is the first integrated 3D sample. It draws a rotating
indexed cube with per-face vertex colors, a sampled rainbow texture, a per-frame
uniform buffer update, and current-drawable depth testing.
It now replaces the earlier split-out uniform-buffer, sampled-texture, and
depth-only teaching samples as the main render resource-binding example.

Run it with:

```sh
zig build run-rainbow-cube
```

The example uses only public resource and command APIs:

- vertex, index, and uniform buffers through `Device.makeBuffer(...)`
- per-frame uniform updates through `uniform_buffer.replaceBytes(...)`
- texture upload through `texture.replaceAll2D(...)`
- uniform, sampled texture, and sampler bindings through a public bind group
  whose layout is derived from shader reflection
- depth testing through `RenderPipelineDescriptor.depth_stencil` and a render
  pass depth attachment
- indexed drawing through `drawIndexedPrimitives(...)`

The Slang source lives beside the example:

```text
examples/rainbow_cube/shaders/rainbow_cube.slang
```

## Voxel World Pressure Test

`examples/voxel_world` is the completed bounded Minecraft-like renderer
pressure test. It uses deterministic `16 x 64 x 16` chunks, visible-face CPU
meshing with cross-chunk neighbor checks, per-chunk vertex/index buffers, a
generated atlas, reflection-derived layouts, camera uniforms, depth/back-face
culling, CPU chunk culling, and bounded rebuild/upload work. It imports no
backend-private API.

The `smoke`, `default`, and `stress` profiles use radii 1, 4, and 8, bounding
resident grids to 9, 81, and 289 chunks respectively. Select a profile with
`VKMTL_VOXEL_PROFILE`; the default is `default`. `VKMTL_VOXEL_FRAME_LIMIT=N`
provides an exact finite run and `VKMTL_VOXEL_AUTOPILOT=1` moves the camera and
requests periodic rebuilds.

Run it interactively or as a deterministic-control finite pressure run:

```sh
zig build run-voxel-world
VKMTL_VOXEL_PROFILE=smoke VKMTL_VOXEL_FRAME_LIMIT=24 VKMTL_VOXEL_AUTOPILOT=1 VKMTL_BACKEND=metal zig build run-voxel-world
zig build run-voxel-world -Dvulkan
```

Controls are `W/A/S/D` for horizontal movement, `Q/E` for vertical movement,
mouse or arrow keys for look, Shift for faster movement, `R` to rebuild the
current chunk, and Escape to exit. The exit report includes resident,
visible/culled and pending chunks; draws/vertices/indices; rebuilds, retirements,
uploads and allocations; CPU mesh/encode/commit time; and frame p50/p95/max.

Finite success prints `voxel_world_pressure_test=ok`. Metal API Validation runs
on an Apple M4 Pro completed smoke/default/stress at their 9/81/289 resident
bounds. The Vulkan artifacts and forced build pass, but physical Vulkan voxel
execution is not claimed here.

## Transfer Readback

`examples/transfer_readback` uses `HeadlessContext` and does not initialize or
link GLFW. It copies a small RGBA payload buffer to another buffer, copies that
payload into a texture, copies the texture back into a CPU-visible buffer, then
clears a separate texture-view-backed offscreen target and copies it to
readback. It validates every result, prints `transfer readback ok`, and exits
automatically.

Run it with:

```sh
zig build run-transfer-readback
```

For backend debugging:

```sh
VKMTL_BACKEND=vulkan zig build run-transfer-readback
VKMTL_BACKEND=metal zig build run-transfer-readback
```

## Compute Readback

`examples/compute_readback` is a true no-window compute sample using
`HeadlessContext`; it does not initialize or link GLFW. It creates a storage
texture and a storage buffer, binds both through a compute-visible bind group,
dispatches a Slang compute shader, copies both resources to CPU-visible
readback buffers, and validates deterministic bytes before exiting
automatically. Its compute pipeline attaches runtime-generated reflection JSON
and derives the storage texture and storage buffer bind group layout from it
before backend pipeline creation.

Run it with:

```sh
zig build run-compute-readback
```

For backend debugging:

```sh
VKMTL_BACKEND=vulkan zig build run-compute-readback
VKMTL_BACKEND=metal zig build run-compute-readback
```

The Slang source lives beside the example:

```text
examples/compute_readback/shaders/compute_readback.slang
```

Current compute coverage is intentionally deterministic: storage buffer writes,
storage texture writes, transfer readback, reflection-derived bind group
layouts, and byte validation before process exit.

## Capability Dump

`examples/capability_dump` prints the selected backend, adapter identity,
capability source, usable features, native queried features, selected limits,
and representative format capabilities. Period 42 output includes
buffer/texture copy alignment plus exact-copy, scaled-blit, presentation,
resolve, depth-copy, and stencil-copy flags for color, depth, and packed
depth/stencil formats.

Run it with:

```sh
zig build run-capability-dump
```

For backend debugging:

```sh
zig build run-capability-dump -Dvulkan
VKMTL_BACKEND=metal zig build run-capability-dump
```

## Bindless Textures

`examples/bindless_textures` exercises the complete advanced binding path. It
creates a 64-texture-plus-sampler `ResourceTable`, declares the compatible
pipeline layout, executes a CPU-authored reusable draw list, and supplies a
persistent driver cache. Metal lowers this to an argument buffer, native ICB,
and binary archive. Vulkan uses descriptor indexing, exact direct-command
expansion, and a pipeline cache. Unsupported devices exit with a clear typed
message.

Run it with:

```sh
zig build run-bindless-textures
VKMTL_BACKEND=metal VKMTL_PIXEL_REGRESSION=1 zig build run-bindless-textures
```

## Compute Gallery

Period 9 tracks the broader compute gallery in `tools/development_matrix.zig`.
Current status:

- implemented: `compute_readback`
- planned: `image_filter`
- planned: `particle_simulation`
- planned: `prefix_sum`
- planned: `storage_texture`

Planned compute examples should keep deterministic readback or pixel validation
where practical so they can become useful backend regression tests.

## Multi-Window Gallery

`examples/multi_window` is the first multi-surface smoke example. It creates two
external GLFW windows, registers both surfaces through public vkmtl
`SurfaceCollection`, and reports whether the selected backend exposes native
multi-window presentation through `DeviceFeatures.multi_surface`.

Run it with:

```sh
zig build run-multi-window
```

The broader tracked cases are:

- `single_device_multiple_surfaces`
- `multiple_swapchains`
- `multi_window_resize`
- `surface_lost_recovery`

Current public `vkmtl.presentation.SurfaceCollection` can track multiple neutral surface states,
but native multiple swapchain execution remains gated by
`DeviceFeatures.multi_surface`.

## Native Interop Gallery

Native interop examples are explicit advanced samples, not ordinary example
dependencies.

`examples/external_texture` exercises explicit `vkmtl.interop` external texture
validation, `ExternalTextureUsageDescriptor`, and the runtime `ExternalTexture`
wrapper. The interop facade also exposes `ExternalInteropImportPlan`,
`ExternalTextureUsagePlan`, `ExternalSynchronizationPlan`, and
`ExternalInteropImportDiagnostic` for advanced interop validation. The example
uses `vkmtl.interop.externalInteropCapabilityMatrix(device)` to explain which handle
kinds are portable wrappers, capability-gated native imports, native-only
objects, or unsupported on the selected backend/platform.

Run it with:

```sh
zig build run-external-texture
```

`examples/external_import` is the executable Metal interop check. It creates a
raw `MTLBuffer`, raw `MTLTexture`, and IOSurface outside vkmtl, imports all
three through public `vkmtl.interop` descriptors, copies through ordinary vkmtl blit commands, and
verifies deterministic CPU readback:

```sh
zig build run-external-import
```

The example is intentionally Metal-only because Vulkan external allocation and
image metadata are not yet represented by the public descriptor. It also
prints `vkmtl.diagnostics.deviceTopology(device)` identity/group diagnostics.

Tracked cases include:

- `vulkan_native_handles`
- `metal_native_handles`
- `external_texture_import` / `external_texture`
- `native_command_insertion`

Portable examples should keep using public vkmtl abstractions. If an example
needs native access, it should be named and documented as a native interop case.
Metal resource import is executable. Native multi-surface presentation,
Vulkan external resource import, external wait/signal lowering, and command
encoder native handle views remain closed under their current contracts.

## Streaming Texture

`examples/streaming_texture` exercises the `vkmtl.resource` sparse/tiled
texture descriptor and residency map path. It prints an unsupported-feature message until the selected
backend exposes sparse or tiled textures.

Run it with:

```sh
zig build run-streaming-texture
```

## Advanced Geometry

`examples/tessellation` and `examples/mesh_shader` compile schema-2 embedded
Slang artifacts, create public advanced render pipelines, encode native draw
commands, and present visible output. Tessellation currently executes only on
a capable Vulkan device. Mesh-only execution is available on capable Metal and
`VK_EXT_mesh_shader` devices. Task/object stages remain unavailable under the
pinned compiler, and unsupported selections exit before pipeline creation.

Run them with:

```sh
zig build run-tessellation
zig build run-mesh-shader
```

## Ray Tracing

`examples/ray_traced_scene` validates the public `vkmtl.ray_tracing` runtime
contract: acceleration-structure objects, scratch-buffer validation, ray
tracing pipeline state, shader binding table creation, and ray dispatch. Metal
mapping is explicit through `vkmtl.native.metal`. The example calls
`Device.compileRayTracingShader(...)` once and lets the compiled shader fill
`vkmtl.ray_tracing.RayTracingPipelineDescriptor` for the selected
backend. Vulkan consumes the Slang RT SPIR-V stages; Metal consumes the
build-time precompiled Metal ray-generation artifact through the same vkmtl
compiled-shader object. On supported Metal devices it now opens a window, creates a real
`MTLAccelerationStructure`, builds a full mesh RT scene from a user-provided
mesh vertex buffer, and presents a room with multiple spheres through the
native Metal intersector dispatch. It prints
`driver_pixels=visible_metal_full_mesh_rt_scene` after the first visible frame.
The Vulkan path now uses procedural sphere AABBs, Slang intersection SPIR-V,
procedural hit groups, and native `vkCmdTraceRaysKHR` dispatch. On supported
Vulkan RT hardware its success marker is
`driver_pixels=visible_vulkan_procedural_rt_scene`. The Metal schema-2 path has
no linked intersection-function artifact, so procedural function tables are
explicitly unsupported. Both
physical Metal and Vulkan RT output are observed; the Period 44 9/9 result does
not imply completion of unrelated native-pressure lanes.

Period 55 changes the canonical display flow without changing the scene or
backend RT markers. `CommandBuffer.dispatchRaysToTexture(...)` writes a
caller-owned, capability-gated `rgba16_float` texture. The command does not
assign a color space or transform the values written by the ray-generation
shader. This example keeps its established display-referred RGB while using
the floating-point texture for higher-precision accumulation. A second public
render command applies the sRGB EOTF to those values and returns display-linear
color to `bgra8_unorm_srgb`; the attachment's sRGB OETF restores the reference
display values. The example does not apply exposure or tone mapping. An
application that wants true scene-linear HDR instead defines its radiometric
units, exposure, and tone-mapping policy separately. The older drawable
dispatch command remains available for compatibility. That legacy command now
dispatches into the caller's whole, single-sample `bgra8_unorm` output and
raw-copies the bytes to the selected linear or sRGB BGRA8 drawable; it performs
no transfer-function, tone-map, or gamut conversion. RT dispatch and the
fullscreen consumer use separate command buffers because each current command
buffer owns one native encoding segment.

Metal API Validation has physically completed three frames of this new path.
The historical Vulkan physical evidence above still proves the native RT
backend, but it predates the Period 55 shared presentation path. The new Vulkan
path now builds, submits, presents, and completes three physical frames. Its
first canonical screenshot exposed a vertical fullscreen-composition flip;
after the fragment-position UV fix, the corrected Vulkan path completed 3000
frames with the established top-left orientation. The legacy raw-copy
screenshot has the same orientation.

Set `VKMTL_RT_LEGACY_DRAWABLE=1` only to validate the compatibility route. With
`VKMTL_RT_FRAME_LIMIT=3`, the example dispatches into a caller-owned linear
BGRA8 target, raw-copies it to the selected drawable, and exits after three
frames. Without that variable, the canonical texture-plus-composition route
above remains active.

The current procedural marker supersedes the original Period32
`driver_pixels=visible_vulkan_rt_output` marker. It still proves the native
Vulkan acceleration-structure, pipeline, SBT, `vkCmdTraceRaysKHR`, and
output-presentation path, now as part of the later procedural scene. The
[The consolidated validation record](../../develop/validation.md) names
the observed Windows/NVIDIA hardware, command, build gates, and the local
ignored screenshot evidence.

The supplied post-AS-sizing-fix Vulkan stderr contains no error, warning, or
VUID, but it does not positively state that `VK_LAYER_KHRONOS_validation` was
enabled and does not include device/driver identity. It is recorded as physical
execution, not as a validation-layer-clean named-device result.

When the Vulkan runtime lacks a required extension, feature, limit, or device
procedure, the example exits before native ray tracing setup and reports an
actionable diagnostic:

```text
vulkan ray tracing unsupported: blocker=<blocker>, requirement=<requirement>, details=<details>
```

The recorded validation host had no non-ray-tracing ICD. This unsupported
behavior is therefore documented from the passing capability-diagnostics unit
contract, not claimed as a physical unsupported-device run.

Run it with:

```sh
zig build run-ray-traced-scene
zig build run-ray-traced-scene -Dvulkan
MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal VKMTL_RT_FRAME_LIMIT=3 zig build run-ray-traced-scene
VKMTL_BACKEND=vulkan VKMTL_RT_FRAME_LIMIT=3 zig build run-ray-traced-scene -Dvulkan
```

Use `-Dvulkan` when the validation result must prove the Vulkan path rather
than the default backend selection. A successful finite run ends with
`ray traced scene finite run ok: backend=<backend> frames=3`. The frame limit
must be a positive integer. Invalid or zero values, an early window close, or a
framebuffer that remains `0x0` for five seconds return failure rather than a
false success or an unbounded validation run.

`examples/ray_tracing_maintenance` creates no window. Through
`HeadlessContext` it builds an update-capable triangle BLAS, alternates 32
update/refit submissions, performs one compact copy, then builds an AABB BLAS
and a TLAS that references two distinct BLAS sources:

```sh
VKMTL_BACKEND=metal zig build run-ray-tracing-maintenance
VKMTL_BACKEND=vulkan zig build run-ray-tracing-maintenance
```

The repository records physical execution of the first command on an Apple M4
Pro. The second is the exact rerun for a Vulkan RT machine; this host does not
promote a forced build into physical Vulkan evidence.
