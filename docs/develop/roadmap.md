# Development Roadmap

This document is the single current plan for vkmtl. It contains only active
work, explicitly deferred evidence, and the completion rules for a new slice.
Completed Period 1-56 execution history lives in `history.md`; current API and
backend truth live in the two inventories.

Do not create another `periodNN/` directory. Add a bounded roadmap item here,
complete it as a vertical slice, then move its durable outcome to the relevant
contract, inventory, validation record, or history entry.

## Sources Of Truth

| Question | Authoritative document |
| --- | --- |
| What work is next? | `roadmap.md` |
| What may the public API expose or break? | `public-api.md` |
| What is the exact public surface? | `public-api-inventory.md` |
| How does a caller migrate? | `migration.md` |
| What does each backend execute? | `native-semantic-coverage-inventory.md` |
| What evidence is required and recorded? | `validation.md` |
| Why is the system structured this way? | `architecture.md` |
| What did completed Periods establish? | `history.md` |

When prose and implementation disagree, verify the code and focused tests,
then update the affected document in the same change. Planning, native-query
availability, and forced compilation never substitute for executable support.

## Current Snapshot

- `v0.1.0` is the released compatibility baseline at tag `v0.1.0`.
- Main contains additive and intentionally allocated `v0.2.0` API work from
  the completed native-semantic periods. `build.zig.zon` remains at `0.1.0`
  until an explicit release preparation change.
- The public root, `Device`, `WindowContext`, and `HeadlessContext` surfaces are
  guarded. No unallocated compatibility cleanup is active.
- Periods 1-56 are complete implementation/history slices. Their old
  checklists are not current work.
- The Metal source ledger has no unrouted source-audit gaps. The compact
  backend inventory still contains deliberately incomplete portable rows and
  precise unsupported rows; those remain truthful until explicitly allocated.
- Canonical and compatibility Vulkan ray-traced presentation both execute and
  have accepted top-left visual orientation. The corrected canonical path ran
  3000 frames on the supported RT machine.
- Clean Windows Vulkan evidence on `7d88ffe` selected an RTX 5080, completed
  physical HeadlessContext and 5x2 composition checks, and met every numeric
  voxel pressure bound. The same run exposed a separate vertical inversion in
  ordinary geometry rasterization, so its voxel result is diagnostic rather
  than accepted raster evidence.
- The corrected physical Vulkan rerun reports zero channel delta for both the
  asymmetric raster and 5x2 composition checks, with both orientation markers
  `top_left`. Smoke/default/stress voxel profiles again pass at 9/81/289
  resident chunks with zero pending work.
- The post-Period-56 RT resource-binding slice and example-private,
  material-bound PTGI workload are complete. The superseding clean-room
  experimental path launches one diffuse path for every covered opaque pixel
  per frame and advances it through at most three sequential cosine-weighted
  segments. Every hit performs an independent sun/moon next-event query,
  throughput propagates material albedo, and the terminal residual environment
  is added once. Frame data carries nonzero x/z chunk bounds only after the
  published TLAS contains the complete contiguous square for the active
  profile. Initial and moving sparse subsets use zero extent, so diffuse misses
  cannot sample environment. With a complete square, a miss may sample the
  residual environment only when the path is confirmed to cross terrain top
  before a traced side; the legacy outer-edge blend uses the same terrain-top
  gate and never adds environment back to a side miss. This prevents second-
  or third-bounce edge leaks. Direct visibility and indirect histories remain
  independently reconstructed through temporal and edge-aware filters. The
  water reflection remains a separate one-segment specular ray. Ray generation
  performs the traces sequentially while the native pipeline recursion limit
  remains one;
  this changes example shader policy, not vkmtl API or native RT semantics.
  Historical one-bounce records remain in `history.md` and `validation.md`.
  This enhancement is not a claim that default SEUS PTGI E12 uses three
  bounces.
- The example-private voxel presentation now runs one continuous 300-second
  day/night cycle: 0/75/150/225/300 seconds map to midnight, sunrise, noon,
  sunset, and wrapped midnight across sky, raster terrain lighting, and
  hybrid-RT visibility. A clean-room, E12-inspired analytic atmosphere adds a
  direction-dependent horizon/zenith/low-sun response plus world-anchored
  self-shadowed cumulus and stretched cirrus. The real-time cloud wind and
  independent 64-second water loop are not frozen by the celestial validation
  override. Clouds participate in raster sky and, on the hybrid route, RT
  environment and hardware-RT water reflection. Raster water fallback keeps
  its analytic current-sky tint without procedural clouds or celestial disks.
  Smooth ground-hemisphere fading avoids bright downward misses, and RT cloud
  environment evaluation is deferred to actual misses or the traced edge.
  Strength-gated cumulus attenuation supplies full day/twilight and restrained
  moonlight cloud shadows while keeping the sun/moon handoff at zero
  directional contribution. The fixed-point terrain and 5x7 FPS/ESC UI remain
  private to the example, with no public API growth and no copied E12 source,
  constants, shader organization, textures, or assets.
- The subsequent example-private biome and daylight-balance refinement reduces
  the raster environment term to a residual fill while PTGI is active, so the
  raster and RT paths do not each contribute a full skylight term. Deterministic
  grass-only trees reject snow, water, and steep footprints; low sandy
  depressions can carry bounded lake water. Raster meshing and secondary RT
  material lookup share exact ground, water, wood, and leaf classification
  through a 16-byte packed material-column contract. Leaves remain deliberately
  opaque. That snapshot retained the former 9/81/289 resident bounds, two
  rebuilds per frame, and 8 MiB upload budget; its dated evidence remains
  historical and no public API was added.
- The superseding example-private streaming refinement expands the current
  smoke/default/stress resident contract to 9/169/289 chunks and moves CPU
  meshing behind one background worker with one outstanding ticket. Ticket
  identity rejects stale completions after the desired set changes, while a
  synchronous fallback preserves deterministic operation if the worker cannot
  start. Interactive runs admit one completed mesh per frame and finite runs
  admit two, both under the existing 8 MiB upload budget. GPU buffer upload,
  BLAS build, and command submission remain on the render thread. TLAS rebuilds
  are normally batched across four frames, with immediate rebuild during
  bootstrap, drain, or source replacement; replaced BLAS owners retire only
  after the replacement TLAS is published. This is example policy and does not
  change the synchronous `CommandBuffer.commit` contract or add a native
  semantic row.
- The current darker-daylight refinement lowers daytime ambient and hybrid
  raster/RT environment floors while leaving direct sun, night ambient, water
  Fresnel, and celestial glint unchanged. Exact development constants and
  validation evidence live in the history and validation records.
- The later example-private water refinement splits each chunk into exact
  opaque and water index ranges without removing the solid-water interface.
  Opaque terrain renders into a complete linear HDR target; a parallel water
  normal/distance G-buffer drives screen-space refraction, RGB Beer-Lambert
  absorption and in-scattering in a separate full-coverage HDR overlay. Hybrid
  RT traces one reflection ray per visible water pixel against the opaque
  terrain TLAS, while raster fallback uses the current sky. Water remains
  absent from chunk BLASes so ordinary PTGI rays can reach the lake bed and
  reflections cannot see another water layer. The presentation pass composites
  the overlay before postprocessing. This adds no public API or backend
  semantic. A subsequent clean-room, E12-inspired appearance pass uses six
  shared analytic wave bands, distance/grazing stabilization, physical
  dielectric Fresnel, depth-dependent homogeneous absorption/scattering, a
  bounded opaque-scene reflection ray, and directional celestial sky misses;
  it copies no E12 source or assets. Off-screen/hidden refraction data, foam,
  caustics, rain response, parallax water, temporal/reflection denoising,
  nested or underwater media, water-to-water reflection, multilayer
  transparency, and OIT remain deliberately out of scope.
- Metal API Validation executes the material-bound PTGI smoke and default
  profiles plus a 300-frame smoke soak. The runs cover complete 9/81-source
  neighborhoods within the 17 x 17, 289-source bound and retain finite,
  nonzero direct, indirect, and reconstructed radiance with zero invalid
  samples. The later celestial-disk visibility refinement also reconstructed
  86,867 fixed-midnight smoke and 237,145 fixed-noon default penumbra pixels
  with zero invalid samples. The current biome/daylight-balance rerun completed
  smoke/default at 24/48 frames with 19,180/81,912 visible vertices,
  88,473,600/176,947,200 primary rays, 118,340/258,864 reconstructed penumbra
  pixels, and zero invalid samples. Its 160-frame raster stress lane retained
  289 resident chunks, zero pending work, and 242,336 visible vertices. The
  subsequent translucent-water smoke/default rerun drained 9/81 resident
  chunks with zero pending work and produced 12/44 draws, 20,976/84,224
  visible vertices, 31,464/126,336 visible indices, 1,095,464/7,080,312
  uploaded bytes, 88,473,600/176,947,200 primary rays, and zero invalid
  samples. The superseding fixed-camera refraction/absorption/RT-reflection
  smoke kept Metal API Validation enabled for 24 frames, submitted 24 RT
  dispatches and 88,473,600 primary rays, reported 1,017,402 primary-hit
  pixels, 438,485 reflection-covered and lit pixels, and ended with native
  submission, visibility/PTGI/reflection validation, the bounded pressure
  marker, and zero invalid pixels.
  After the 300-second clock, atmosphere/cloud, and darker-daylight refinement,
  the fixed-noon `150` Metal API Validation smoke retained 88,473,600 rays,
  1,017,402 hits, 438,485 covered/lit reflections, zero invalid pixels, all
  validation markers, and `rt_ms=9.992`. Fixed-midnight `0` retained the same
  ray/hit/coverage counts with 429,962 lit reflections and `rt_ms=9.547`.
  A fixed-noon 24-frame raster lane passed. Default interactive required-RT
  noon observed about 65-68 FPS after warmup and raster sky about 120 FPS on
  the development machine; these are observations, not gates.
  The superseding current fixed-noon default lane runs 96 frames without
  autopilot and drains 169 resident and traced chunks. Under Metal API
  Validation it built 169/169 background jobs with zero failed or stale
  completions, built 169 BLAS objects and 22 TLAS versions, submitted 96 RT
  dispatches and 353,894,400 rays, and retained 2,404,265 primary hits,
  862,626 direct-lit and 1,541,639 shadowed pixels, 2,403,729 indirect-lit and
  2,404,265 reconstructed-lit pixels, 632,564 covered/lit reflection pixels,
  298,276 reconstructed penumbra pixels, zero invalid pixels, and every
  validation marker true. Background CPU mesh time totaled 411.750 ms; the
  synchronous upload and TLAS totals were 179.797 ms and 18.437 ms. Frame
  p50/p95/max were 19.919/23.364/401.845 ms, with the maximum including strict
  final readback. The matching raster default lane also drained 169 chunks
  with 81 visible and 88 culled, 104 draws, 180,132 vertices, 270,198 indices,
  and 14,111,376 uploaded bytes.
  The superseding three-bounce fixed-noon default completed 96 frames under
  Metal API Validation with 169 resident chunks, zero pending work,
  169/169/0/0 submitted/completed/failed/stale mesh jobs, 22 TLAS builds, 96
  dispatches, and `ptgi_bounces=3`. It retained 2,404,265 primary hits,
  863,410 direct-lit and 1,540,855 shadowed pixels, 1,932,365 indirect-lit and
  2,404,258 reconstructed-lit pixels, 626,079 low-indirect pixels, 632,564
  covered/lit reflections, 297,535 penumbra pixels, zero invalid pixels, and
  every validation marker true. `primary_rays=353894400` remains the historical
  log field for dispatch-thread count; it does not include the extra sequential
  path segments. RT time was 16.327 ms per frame and frame p50/p95/max were
  24.081/28.004/442.164 ms. Final fixed-noon and fixed-midnight 24-frame
  smoke also retained all markers, zero invalid pixels, 1,017,402 primary hits,
  and 438,485 covered reflections, with 10.767/11.248 RT ms per frame and
  438,485/429,973 lit reflections respectively. A same-command, final-boundary
  temporary one-bounce A/B reported 12.870 RT ms per frame and p50/p95
  20.960/23.583 ms versus 16.327 and 24.081/28.004 for three bounces; all
  validation markers passed, so the observed RT cost was about 26.9%. The
  indirect/low/reconstructed counts are not an unbiased energy comparison:
  the configured terminal residual and conservative side exits differ by path
  length. Frame maxima and load transients are not performance gates. These
  runs remain dirty-source development evidence rather than clean candidate
  evidence.
  `zig build test`, `zig build`, and `zig build -Dvulkan` pass on the current
  source, but physical Vulkan PTGI and presentation remain explicitly deferred.
- Those Metal observations came from the current dirty source snapshot. They
  establish implementation behavior, not exact-commit or release-candidate
  evidence; every required lane must be refreshed against a clean candidate.

## Priority 1: Close Current Release Evidence

The material-bound PTGI path has physical Metal implementation evidence, while
its Vulkan physical lane remains pending. Current physical results remain
historical until repeated on the final release commit.

- [ ] Refresh every required physical lane against the exact future release
  commit before tagging; historical evidence remains history only.
- [ ] Run the `voxel_world_vulkan_ray_tracing` smoke/default PTGI lane on the
  supported Windows Vulkan RT host. Against the exact candidate commit, record
  `ptgi_bounces=3`, complete 9/169-source traversal, native submission, finite
  nonzero direct, indirect, and reconstructed radiance, and zero invalid
  samples. The first interactive RTX attempt reached `hybrid_rt` and loaded all
  shaders, then exposed an async-startup sampled-image barrier error before the
  first chunk. The guarded-startup fix now passes focused, Vulkan, and Windows
  cross-build validation, and a follow-up interactive Windows RTX rerun no
  longer reproduces the startup error. Keep this row open until the bounded
  physical lane reports PTGI pixel metrics.

## Priority 2: Prepare The Next Release Intentionally

Main has accumulated additive `v0.2.0` allocations while package metadata is
still `0.1.0`. Release preparation is a separate reviewable change.

- [ ] Decide the exact `v0.2.0` release scope from the current inventory and
  changelog; do not add unrelated backend work during release cleanup.
- [ ] Reconcile `public-api-inventory.md` with the API guard and confirm every
  `v0.2.0` addition has migration/API documentation.
- [ ] Update package version and release metadata only after hosted, package,
  semantic, and physical gates target the same commit.
- [ ] Run external package smoke with a consumer-owned schema-1 and schema-2
  shader manifest where supported.
- [ ] Create the annotated tag and verify its archive from a fresh consumer
  only after `validation.md` release gates are complete.

## Priority 3: Resolve Remaining Incomplete Semantic Rows

The following inventory rows are not complete support claims. Each requires an
explicit design allocation before implementation; unsupported is an acceptable
outcome when exact cross-backend semantics cannot be promised.

### Conservative rasterization (`REN-06`)

- [ ] Decide the portable mode/limit contract and exact feature query.
- [ ] Implement both native lowerings or mark the absent backend precisely
  unsupported.
- [ ] Add raster boundary pixel evidence on every executable backend.

### Depth/stencil resolve (`REN-07`)

- [ ] Separate the already-supported compatible texture-view reinterpretation
  from the unresolved depth/stencil resolve contract.
- [ ] Define supported resolve modes, aspects, format gates, and error behavior.
- [ ] Add per-aspect readback tests before promoting the row.

### Transfer edge semantics (`XFR-04`)

- [ ] Split partial mip generation, custom sampler border colors, and packed
  depth/stencil parity into independently supportable contracts.
- [ ] Avoid one broad feature flag for backend-specific subsets.
- [ ] Add exact byte/aspect evidence for any admitted path.

### Vulkan command-buffer marker groups (`DBG-02`)

- [ ] Either add native Vulkan command-buffer debug label scopes with queried
  availability or document validation-only behavior as precisely unsupported.
- [ ] Keep Metal's native marker behavior independent from the Vulkan outcome.

## Priority 4: Harden Existing Executable Paths

These are bounded implementation/evidence improvements, not permission to grow
the public API automatically.

### Descriptor-exact Vulkan AS sizing

The current Vulkan allocation safely reserves the component maximum for the
admitted single-geometry triangle/AABB templates and all update/compaction flag
combinations. It does not establish exact sizing for arbitrary multi-geometry
arrays.

- [ ] Query build/update sizes from the actual geometry array and primitive
  counts used by each build.
- [ ] Preserve validation between the queried descriptor and encoded plan.
- [ ] Add multi-geometry, update, and compaction physical RT coverage.

### Asynchronous and in-flight ownership

Current command commit semantics deliberately keep important paths
synchronous. The voxel example now hides CPU mesh generation behind its own
single-worker, ticketed scheduler, but deliberately leaves buffer upload,
BLAS/TLAS construction, and command submission synchronous. That example-
private improvement neither changes callback/completion timing nor satisfies
the library-wide in-flight ownership work below.

- [ ] Design explicit in-flight resource ownership and completion lifetime;
  do not hide it behind an implementation-only queue change.
- [ ] Preserve failed-commit terminalization, borrow release, callback-once,
  and queue synchronization semantics.
- [ ] Prove bounded frames in flight on both backends before changing defaults.

### Broader physical matrices

- [ ] Exercise Vulkan physical compute/transfer queue selection and timeline
  dependencies across more than one adapter family.
- [ ] Add physical Vulkan Boolean occlusion and timestamp result evidence where
  the queried native path is usable.
- [ ] Expand texture shape/format physical coverage without promoting formats
  outside the allocated portable set.

## Precisely Unsupported Work

Unsupported rows in `native-semantic-coverage-inventory.md` are closed
contracts, not unchecked tasks. Work begins only after a new baseline audit or
an explicit decision explaining the intended exact semantics and backend
outcomes. Notable examples include:

- Metal tessellation under the pinned Slang artifact contract;
- Metal driver-bound procedural intersection tables and custom intersection;
- callable shaders and complex function-table/SBT layouts;
- tensor/ML, pipeline dataset, Metal 4 allocator, and advanced reflection
  contracts without portable owners;
- Vulkan hardware memoryless guarantees;
- timed Vulkan presentation without an exact admitted extension path;
- incomplete external synchronization/import metadata and native command
  insertion.

Do not expose a planning record or native query as a substitute.

## Definition Of A New Slice

Before implementation:

- [ ] State the problem, observable semantics, and explicit non-goals here.
- [ ] Allocate public declarations through `public-api.md`, or state that the
  slice is backend-private.
- [ ] Define Vulkan and Metal outcomes independently: native-exact,
  composed-exact, emulated-exact, or unsupported.
- [ ] Define feature, limit, format, ownership, lifetime, and typed errors.
- [ ] Name deterministic, build, physical GPU, pixel, or soak evidence needed
  for completion.

Before completion:

- [ ] Keep a working vertical slice and canonical examples.
- [ ] Add focused tests for validation and failure paths.
- [ ] Update both inventories when surface or support truth changes.
- [ ] Update `validation.md`, user/API docs, changelog, and migration guidance
  where applicable.
- [ ] Run formatting, API/semantic guards, tests, builds, package smoke, and
  physical evidence in proportion to the change.
- [ ] Move the completed outcome to `history.md` and remove checked task detail
  from this roadmap.

## Historical Reference

The complete pre-consolidation Period/Phase tree is preserved at commit
`4ac780fced49d89ecfd4c09d519ac8dcd5fba07c`. The released `v0.1.0` baseline is
preserved by its annotated tag. Use `history.md` for the compact in-tree record
rather than restoring per-Period folders.
