# Day/Night Material-Bound Hardware-RT PTGI Voxel World

`voxel_world` is a bounded Minecraft-like renderer pressure test for vkmtl. It
is not a game or a production world generator. It combines deterministic chunk
streaming, visible-face rasterization, a chunk-continuous terrain sampler, and
an optional native three-segment diffuse PTGI path using public vkmtl APIs on
Metal and Vulkan.

The material atlas is a deterministic 748 x 68 sRGB texture containing eleven
face-specific tiles: grass top/side, dirt, stone, sand, snow top/side, wood
top/side, leaves, and water. Each tile has a 64 x 64 content region plus two
replicated edge texels on every side. The alpha channel supplies shader-side
height detail for the raster normal. The atlas deliberately has no mipmaps yet,
so distant texture shimmer remains a known example limitation rather than a
backend capability gap.

## Five-Minute Day/Night Presentation And Terrain

The example renders a complete world-space day/night cycle in 300 seconds. The
shared phase reaches midnight at 0 seconds, sunrise at 75, noon at 150, sunset
at 225, and wraps to midnight at 300. Night, twilight, and daytime gradients
blend continuously instead of switching between discrete presets.

The sun and moon remain opposite throughout the cycle. The appropriate body is
drawn above the horizon; sparse direction-stable stars twinkle at night and
fade with daylight. A clean-room, E12-inspired analytic atmosphere responds to
view and sun direction, with a bright horizon, deep zenith, and warm low-sun
glow. World-anchored clouds move on their own real-time wind clock: a lower,
self-shadowed cumulus layer and a higher stretched cirrus layer appear in the
raster sky and, on the hybrid path, the RT miss/PTGI environment and hardware-
RT water reflections. Raster water fallback retains the analytic current-sky
tint and does not evaluate the procedural clouds or celestial disks. The
downward ground hemisphere fades smoothly into its ground response rather than
returning a bright sky for downward RT misses. RT cloud environment work is
deferred until an actual reflection miss or a diffuse path whose verified
terrain-top escape admits its miss/edge environment.
Dense cumulus modulates RT direct visibility for full moving day/twilight cloud
shadows and restrained moonlight shadows. That attenuation is gated by active
light strength, so the sun/moon direction switch happens at zero directional
contribution. The same per-frame celestial state supplies raster ambient tint,
directional color/strength, and the hybrid-RT light direction and angular
radius, so the visible source, terrain shading, and shadow softness agree.
No E12 source, constants, shader organization, textures, or assets are copied.
This clock and all scene policy remain private to the example and do not
enlarge vkmtl's public API.

Clouds are bounded analytic layers rather than a volumetric raymarch. The
example does not implement weather, rain, cloud textures, cloud TAA, or a
general atmospheric API.

Terrain height is generated in fixed-point integer math from deterministic
multi-scale continentalness, erosion, ridge, and detail fields. Temperature
and moisture fields select grass, sand, and snow surfaces. Sampling happens in
world coordinates and each meshed chunk caches a one-block halo, so terrain and
face culling remain continuous across positive and negative chunk boundaries.
Deterministic cell placement adds wood-and-leaf trees only to ordinary grass
terrain; snow-covered columns, water footprints, and unsuitable slopes remain
tree-free. A separate lowland mask fills selected sand depressions to a fixed
water level, producing bounded lakes without changing the terrain sampler's
allocation-free contract. Solid-water interfaces remain in the opaque mesh, so
the lake bed and shoreline walls remain visible through the water instead of
being removed as hidden faces. Trees and other opaque terrain share the same
raster and RT material classification. Leaves remain opaque.

Opaque sky and terrain first render into a complete scene-linear HDR target.
Water is then resolved into a separate full-coverage HDR overlay, so its
fragment shader can sample the opaque image without a read/write feedback
hazard. The presentation pass composites that overlay before bloom and tone
mapping; overlay alpha marks water coverage rather than premultiplied material
opacity. Water keeps depth testing and depth writes enabled so the nearest
visible surface owns each covered pixel.

A clean-room, SEUS PTGI E12-inspired surface strategy uses six
world-coordinate analytic wave bands with different scales, directions, and
temporal harmonics. Raster shading and the water G-buffer evaluate the same
normal, stabilized with camera distance and grazing angle, so reflections do
not detach from the visible ripples or collapse into distant shimmer. The wave
clock remains independent of the day/night freeze override, and world-space
evaluation keeps the result continuous across block and chunk boundaries.
No E12 source, constants, shader organization, or assets are copied.

The water shader projects a thickness- and distance-aware refracted camera
segment into screen space, rejects invalid UV or opaque-depth candidates, and
falls back to the direct opaque pixel. The accepted water-to-opaque distance
estimates path length through a homogeneous medium. Beer-Lambert attenuation
uses `sigma_a = (0.240, 0.062, 0.014)` and a single-scattering term uses
`sigma_s = 0.070`. There is no painted blue body tint: shallow water is
primarily transmitted scene radiance, while greater depth develops blue-green
absorption and in-scattering.

When hybrid RT is active, each visible water G-buffer pixel traces one hardware
reflection ray, capped at 96 world units, against the opaque terrain TLAS. A
hit receives the existing opaque material and direct/environment lighting; a
miss returns a direction-dependent day, twilight, or night sky with a
restrained horizon and the active sun or moon disk and halo. Raster mode clears
the reflection target, so Fresnel composition falls back to the current sky.
The dielectric response uses `F0 = 0.02` and a narrow approximately
420-exponent celestial glint rather than a broad cyan highlight. Opaque PTGI
rays keep their separate 384-world-unit bound. Water remains absent from the
chunk BLASes: reflections cannot see another water surface, while ordinary
PTGI rays remain optically thin and can still reach the lake bed.

Refraction is screen-space and can only reuse opaque pixels already present in
the current frame. Off-screen objects and geometry hidden behind another
opaque surface are unavailable. The model does not implement foam, caustics,
rain response, parallax water, temporal anti-aliasing or reflection denoising,
nested or underwater media, water-to-water reflection, multilayer
transparency, or order-independent transparency. The reflection remains one
unfiltered sample per visible water pixel.

The current smoke/default/stress resident-chunk bounds are 9/169/289. The
default view radius is six chunks, producing a 13 x 13 resident grid; smoke
and stress retain their existing 3 x 3 and 17 x 17 bounds.

An example-local CPU 5x7 bitmap font feeds a dynamic alpha-blended UI pipeline.
It draws the live FPS counter in the upper-right corner and the title overlay;
this renderer is private to the example and does not enlarge vkmtl's public
API.

## Workload Profiles

Every profile uses `16 x 64 x 16` chunks. CPU meshing runs on one background
worker with exactly one outstanding job/result, so interactive rendering never
waits for CPU mesh completion. Interactive mode publishes at most one completed
mesh to GPU resources per frame. Finite validation deliberately waits for the
worker so its drain is deterministic and may publish at most two meshes per
frame. Both routes retain the 8 MiB per-frame upload budget.

Each request carries a stream ticket. Moving to another chunk neighborhood or
requesting a replacement advances the ticket, and a completed result from an
older ticket is discarded instead of publishing stale terrain. If the worker
thread cannot be spawned, the example prints a diagnostic and retains the
synchronous meshing fallback.

GPU buffer upload, BLAS construction, and TLAS construction still execute
synchronously on the render thread. Ordinary TLAS source additions are
coalesced for at most four frames; initial bootstrap, a fully drained stream,
and source replacement rebuild immediately. The background worker therefore
removes CPU terrain meshing from interactive frames, but it does not claim to
make all GPU publication work asynchronous.

| Profile | Radius | Resident grid | Maximum resident chunks |
| --- | ---: | ---: | ---: |
| `smoke` | 1 | 3 x 3 | 9 |
| `default` | 6 | 13 x 13 | 169 |
| `stress` | 8 | 17 x 17 | 289 |

Select a profile with `VKMTL_VOXEL_PROFILE=smoke|default|stress`. The default
when the variable is absent is `default`.

## Renderer Modes

`VKMTL_VOXEL_RT` selects the renderer:

- `auto` (the default) uses native hybrid RT when the device and required
  acceleration-structure, ray-tracing, storage-buffer, MRT, filtered
  `rgba16_float`, writable/copyable RT target, and depth-format capabilities
  are executable, otherwise it keeps the raster renderer;
- `off` disables ray tracing and preserves the original raster pressure lane;
  and
- `required` requires the hybrid path and returns a typed capability/format
  error instead of silently falling back.

The HDR/G-buffer composition path itself requires `blend_state`,
`independent_blend`, at least three simultaneous color attachments,
`rgba16_float` sampling, filtering, linear filtering, and color-attachment
support, plus a `depth32_float` depth attachment. It does not require
`rgba16_float` blending. Hybrid water reflection additionally requires
`rgba16_float` storage and copy-source/copy-destination support through the
existing RT capability gate. These requirements are independent of the RT
selector where applicable and fail with a typed example error when absent.

When RT is enabled, every resident chunk can own an indexed triangle BLAS and
the frame TLAS covers the complete bounded 17 x 17 neighborhood, up to 289
instances. A full-resolution opaque surface G-buffer stores detailed normal
and camera distance; a parallel water G-buffer stores the animated wave normal
and water distance. The opaque G-buffer and BLAS consume only each chunk's
opaque index range, so primary-surface reconstruction and RT shadow/bounce rays
pass through the water to the retained lake bed. Each covered opaque surface
pixel traces one stochastic diffuse path per frame with at most three
cosine-weighted segments. Every diffuse hit performs an independent sun/moon
next-event-estimation visibility sample over the active body's visible disk,
so the path may accumulate direct illumination through the third diffuse
interaction. Diffuse lighting still uses the center direction, so disk sampling
changes occlusion rather than making unoccluded surface brightness flicker.
All path hits read the same deterministic opaque terrain-column material
classification and block atlas as rasterization instead of guessing a material
from height. Frame data receives nonzero TLAS x/z origin and extent only after
the published TLAS contains the complete contiguous square for the selected
profile. Sparse bootstrap or moving subsets use zero extent, so their diffuse
misses cannot sample the environment. Once the square is complete, a miss
evaluates the environment only when an upward ray reaches the terrain top
before crossing either horizontal boundary. The outer traced-edge environment
mix is gated by the same path-level terrain-top escape proof, so a side miss
cannot add the sky back through that blend. The old low residual environment
fill is added only at a terminal configured hit, not once per bounce.

The native ray-tracing pipeline retains `max_recursion_depth = 1`: ray
generation emits these trace operations sequentially rather than recursively
calling hit shaders. The water path is separate and remains one specular RT
segment per visible water pixel without temporal or spatial reflection
denoising.

Indirect radiance is accumulated in scene-linear `rgba16_float`. Reprojection
rejects invalid depth/normal history, clamps surviving history, shortens or
resets it when the celestial light changes, and resets after resize, camera or
TLAS discontinuities. Four edge-aware a-trous passes denoise the single-sample
indirect result. Direct visibility has a separate history that accumulates the
binary disk samples as a mean and second moment, enforces a minimum current
sample weight, and then receives one normal/depth-aware 5 x 5 pass. The raster
material pass consumes that reconstructed visibility rather than the raw 0/1
sample. Indirect lighting fades to the current sky environment over the outer
16 blocks of the bounded traced neighborhood, avoiding a hard GI boundary.
Daytime ambient and the hybrid raster/RT environment floors are reduced so the
traced indirect path remains the primary skylight source and fully shadowed
regions stay darker. Raster-only mode keeps its complete environment response.
Direct sun, night ambient, water Fresnel, and the narrow celestial glint are
unchanged.

The complete scene is rendered into a linear HDR target, then an independently
authored SEUS-PTGI-E12-default-inspired fixed-exposure presentation pass
applies restrained bloom, sharpening, vignette, a filmic highlight shoulder,
subtle saturation, dithering, and exactly one output transfer. The SEUS
shaders, constants, organization, and assets are not copied; the target is
similar default color character, not
source equivalence or pixel identity. This workload is bounded three-segment
diffuse hybrid PTGI plus one unfiltered opaque-scene reflection ray per visible
water pixel. E12's default explicit reflection/diffuse chain is not a
three-bounce prescription; this path is a clean-room experimental enhancement,
not a claim about E12's default behavior. It is not a general recursive path
tracer, recursive reflection renderer, or production denoiser.

## Running

Run interactively with automatic capability selection:

```sh
zig build run-voxel-world
```

Run the bounded raster baseline:

```sh
VKMTL_VOXEL_RT=off VKMTL_VOXEL_PROFILE=smoke \
VKMTL_VOXEL_FRAME_LIMIT=24 VKMTL_VOXEL_AUTOPILOT=1 \
VKMTL_BACKEND=metal zig build run-voxel-world
```

Require native hybrid RT on Metal:

```sh
MTL_DEBUG_LAYER=1 VKMTL_VOXEL_RT=required \
VKMTL_VOXEL_PROFILE=default VKMTL_VOXEL_FRAME_LIMIT=96 \
VKMTL_VOXEL_CYCLE_TIME=150 VKMTL_BACKEND=metal zig build run-voxel-world
```

On a configured Vulkan RT host:

```sh
VKMTL_BACKEND=vulkan VKMTL_VOXEL_RT=required \
VKMTL_VOXEL_PROFILE=default VKMTL_VOXEL_FRAME_LIMIT=96 \
VKMTL_VOXEL_CYCLE_TIME=150 zig build run-voxel-world -Dvulkan
```

`VKMTL_VOXEL_FRAME_LIMIT=N` exits after exactly `N` presented frames.
`VKMTL_VOXEL_AUTOPILOT=1` moves the camera and periodically requests a rebuild,
making finite runs exercise streaming without interactive input.
The canonical 96-frame default commands above intentionally omit autopilot so
the complete 13 x 13 neighborhood can drain around a fixed camera.
`VKMTL_VOXEL_CYCLE_TIME=S` freezes the example-private celestial clock at a
finite time in the 300-second cycle; `0`, `75`, and `150` are useful
deterministic night, sunrise, and noon visual probes. It does not freeze cloud
motion or the independent 64-second water-wave loop; both use real elapsed
time. It is a validation override, not public vkmtl API.

A successful finite run ends with a marker such as:

```text
voxel_world_pressure_test=ok backend=metal profile=smoke frames=24 renderer=hybrid_rt ptgi_bounces=3 streaming_drained=true rt_driver_submitted=true rt_visibility_validated=true rt_ptgi_validated=true rt_reflection_validated=true
```

Hybrid finite runs read back raw RT lighting, reconstructed indirect radiance
and visibility, and the water reflection target after streaming drains.
Acceptance rejects NaN, infinity, negative radiance, visibility outside its
valid range, and non-binary reflection coverage. It requires primary hits plus
nonzero directly lit, shadowed, indirect-lit, and reconstructed pixels. A
fixed-camera finite RT run is also the deterministic water lane: it must find
at least one covered reflection pixel, at least one lit reflection pixel, and
zero invalid reflection pixels or it returns
`VoxelWaterReflectionRegression`. `rt_reflection_validated=true` records that
strict result. Autopilot may legitimately turn away from every lake, so it
still reports `rt_reflection_pixels`, `rt_reflection_lit`, and the marker but
does not require the marker to become true. If a finite run reaches its frame
limit before streaming drains, it prints
`voxel_world_pressure_test=incomplete` and returns
`VoxelWorldStreamingNotDrained`; it must not be treated as a successful
pressure result. Raster-only runs do not claim RT pixels.

## Controls

- `W/A/S/D`: move horizontally.
- Space: ascend.
- Shift: descend.
- Ctrl: move faster.
- Mouse or arrow keys: yaw and pitch.
- `R`: rebuild the chunk containing the camera.
- Escape: toggle the translucent title overlay. While open, the overlay shows
  `VKMTL VOXEL WORLD` and `Press ESC to continue`; pressing Escape again
  resumes input. Escape does not close the window.
- Window close: exit.

The upper-right FPS label remains visible during ordinary rendering and while
the title overlay is open.

## Metrics

The renderer prints live resident/visible/culled/pending/draw/rebuild/upload
counts approximately once per second. On exit, `voxel metrics:` reports:

- resident, visible, culled, and pending chunks;
- draw calls, visible vertices, and visible indices;
- rebuilt and retired chunks, uploaded bytes, and buffer allocations;
- maximum resident chunks and rebuild-queue depth;
- `streaming=background|sync_fallback` plus submitted/completed/stale/failed
  mesh-job counts;
- cumulative CPU meshing, render-thread stream upload/BLAS, and TLAS build
  times, plus per-frame command encode/commit time and CPU frame
  p50/p95/maximum;
- renderer mode, `ptgi_bounces`, BLAS/TLAS builds and bytes, traced chunks, RT
  dispatches and `primary_rays`, and RT time; `primary_rays` remains the number
  of ray-generation dispatch threads, not the number of sequential diffuse
  segments they trace; and
- native driver submission plus primary-hit, directly lit, shadowed,
  indirect-lit, low-indirect, reconstructed-lit, reflection-covered,
  reflection-lit, penumbra, and invalid-pixel readback counts.
  `rt_reflection_pixels` and `rt_reflection_lit` retain the maximum strict
  reflection readback counts observed during the finite run; `rt_penumbra`
  counts reconstructed surface pixels whose final visibility is strictly
  between the admitted fully shadowed and fully lit thresholds;
  `rt_low_indirect` remains a diagnostic threshold, not a sky-occlusion
  semantic.

These are pressure-test observations, not hardware-independent performance
requirements. Correctness requires bounded resident resources and pending
work; it does not impose a universal frame-rate gate.

## Recorded Evidence

The raster-only Metal pressure baseline previously completed all three profiles
under Metal API Validation on an Apple M4 Pro and retained the 9/81/289
resident bounds. Corrected physical Vulkan raster runs also completed all
three profiles with zero pending work; those runs do not prove the new hybrid
RT lane.

On 2026-07-18, an earlier dirty-source snapshot ran on an Apple M4 Pro with
`Metal API Validation Enabled`. It used the then-current 60-second celestial
clock, where fixed time `30` meant noon:

- fixed-midnight smoke completed 24 frames with 9 traced chunks, 24 RT
  dispatches, 88,473,600 primary rays, 3,686,400 primary hits, 727,803 directly
  lit, 2,958,597 shadowed, 3,558,961 indirect-lit, and 3,686,400 reconstructed
  pixels, with zero invalid pixels;
- fixed-noon default completed 48 frames with 81 traced chunks, 48 dispatches,
  176,947,200 rays, 3,686,400 primary hits, 1,129,790 directly lit, 2,556,610
  shadowed, 3,686,400 indirect-lit and reconstructed pixels, with zero invalid
  pixels; and
- a fixed-midnight 300-frame moving/rebuild smoke soak completed 300 dispatches
  and 1,105,920,000 rays with native submission, PTGI validation, drained work,
  nonzero direct/indirect/reconstructed pixels, and zero invalid pixels.

The later celestial-disk visibility refinement reran the first two lanes. The
fixed-midnight smoke run reconstructed 86,867 penumbra pixels; the fixed-noon
default run reconstructed 237,145. Both retained native submission, complete
9/81-source traversal, PTGI validation, and zero invalid pixels under Metal API
Validation. Interactive noon and lower-sun inspection showed softened shadow
transitions without detaching them from terrain geometry.

The earlier transparent-water revision reran the bounded hybrid-RT lanes under
Metal API Validation:

- smoke completed 24 frames with 9 resident chunks, zero pending work, 12
  draws, 20,976 vertices, 31,464 indices, 1,095,464 cumulative uploaded bytes,
  88,473,600 rays, and zero invalid pixels; and
- default completed 48 frames with 81 resident chunks, zero pending work, 44
  draws, 84,224 vertices, 126,336 indices, 7,080,312 cumulative uploaded
  bytes, 176,947,200 rays, and zero invalid pixels.

The final refraction/absorption/RT-reflection revision completed a fixed-camera
24-frame smoke run under Metal API Validation. It submitted 24 RT dispatches
and 88,473,600 primary rays, reported 1,017,402 primary-hit pixels, 438,485
reflection-covered pixels, 438,485 lit reflection pixels, and zero invalid
pixels. The run ended with `rt_driver_submitted=true`,
`rt_visibility_validated=true`, `rt_ptgi_validated=true`,
`rt_reflection_validated=true`, and `voxel_world_pressure_test=ok`.

The subsequent E12-inspired clean-room water-surface refinement retained those
historical strict fixed-noon counts and validation markers. A fixed-midnight
24-frame Metal API Validation lane retained the same 88,473,600 rays and
1,017,402 primary hits, with 438,485 reflection-covered pixels, 429,947 lit
reflection pixels, zero invalid pixels, and all native/visibility/PTGI/
reflection markers true. Its 24-frame Metal raster lane also passed.
`zig build test` and `zig build -Dvulkan` also pass on the refined source; the
forced Vulkan result is still compilation evidence rather than physical
execution.

After the five-minute clock, darker daytime balance, analytic atmosphere, and
cloud integration landed, `zig build`, `zig build test`, and
`zig build -Dvulkan` passed. Metal API Validation fixed-noon time `150` smoke
completed 24 frames with 88,473,600 rays, 1,017,402 primary hits, 438,485
reflection-covered and lit pixels, zero invalid pixels, every native/
visibility/PTGI/reflection marker true, and `rt_ms=9.992`. Fixed-midnight time
`0` retained the same ray, hit, and covered counts, reported 429,962 lit
reflection pixels, zero invalid pixels, all markers true, and `rt_ms=9.547`.
The fixed-noon 24-frame Metal raster lane also passed. On this machine, the
default interactive required-RT noon view stabilized around 65-68 FPS after
warmup, while the interactive raster sky was about 120 FPS; these are local
observations, not performance gates.

Before the later three-segment and TLAS-boundary revisions, the widened default
profile and background streamer completed
fixed-camera 96-frame Metal API Validation lanes. Raster ended with 169
resident chunks, 81 visible, 88 culled, zero pending, 104 draws, 180,132
vertices, 270,198 indices, and 14,111,376 cumulative uploaded bytes. Required
RT retained the same resident/visibility result, built 169 BLASes and 22
TLASes, submitted 96 dispatches and 353,894,400 primary rays, and read back
2,404,265 primary hits, 632,564 covered/lit reflection pixels, 298,276
penumbra pixels, and zero invalid pixels. Native submission, visibility, PTGI,
reflection, and pressure markers were all true.

That RT run reported `mesh_jobs=169/169/0/0` in
submitted/completed/stale/failed order, `mesh_ms=411.750` as cumulative
background-worker time, `stream_upload_ms=179.797`, `tlas_build_ms=18.437`,
`frame_p50_ms=19.919`, and `frame_p95_ms=23.364`. Its
`frame_max_ms=401.845` contains the strict finite-run readback and is not a
measurement of interactive chunk-loading latency. During a separate
interactive required-RT observation, resident counts progressed from 53 to
115 to 169 and then stabilized around 63-64 FPS. That is a local observation,
not an acceptance threshold.

After the final TLAS-boundary tightening, the three-segment required-RT smoke
lanes completed 24 frames under Metal API Validation. Fixed noon reported
1,017,402 primary hits, 431,231 directly lit, 586,171 shadowed, 303,369
indirect-lit, 744,071 low-indirect, 1,017,398 reconstructed, 438,485 covered/lit
reflection pixels, 45,238 penumbra pixels, zero invalid pixels, and
`rt_ms_per_frame=10.767`. Fixed midnight retained 1,017,402 hits, reported
431,228 directly lit, 586,174 shadowed, 279,887 indirect-lit, 839,646
low-indirect, 960,442 reconstructed, 438,485 covered and 429,973 lit reflection
pixels, 53,592 penumbra pixels, zero invalid pixels, and
`rt_ms_per_frame=11.248`.

The current fixed-noon 96-frame default lane drained at 169 resident chunks
and zero pending with `ptgi_bounces=3`, 22 TLAS builds, 96 dispatches, and
353,894,400 `primary_rays` dispatch threads. It reported
`rt_ms_per_frame=16.327`, 2,404,265 primary hits, 863,410 directly lit,
1,540,855 shadowed, 1,932,365 indirect-lit, 626,079 low-indirect, 2,404,258
reconstructed, 632,564 covered and lit reflection pixels, 297,535 penumbra
pixels, zero invalid pixels, and all validation markers true. Frame
p50/p95/max were 24.081/28.004/442.164 ms. The maximum includes strict
finite-run validation work and is not an interactive chunk-loading latency
claim; all timings remain local observations rather than performance gates.

The uploaded-byte observations above are cumulative run totals, not per-frame
peaks. Finite validation retains its two-publication limit, interactive mode
uses one publication per frame, and the 8 MiB per-frame upload budget remains
unchanged.

These values are observations rather than portable thresholds. Because the
working tree was not committed, they are development evidence rather than an
exact release-commit record. The refractive water and RT-reflection path has no
physical Vulkan execution evidence yet.

The first interactive Windows RTX attempt selected Vulkan `hybrid_rt`, reported
`ptgi_bounces=3`, and loaded every voxel shader, but failed before the first
streamed chunk with `InvalidResourceBarrierState`. Async startup had no TLAS and
therefore skipped the first RT/PTGI producer; the terrain group then tried to
bind still-undefined PTGI scratch images after the sky draw had started the
Vulkan render pass. The current source defers that terrain/water-lighting bind
until PTGI is ready. Vulkan and Windows cross-builds pass, and a follow-up
interactive Windows RTX rerun no longer reproduced the startup failure. That
interactive confirmation is not finite-run pixel evidence; the bounded
validation lane below still needs a physical Vulkan result.
