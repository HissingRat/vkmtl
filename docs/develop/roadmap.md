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

## Priority 1: Close Current Release Evidence

These items validate the current commit; they do not change API semantics.

- [ ] Run the updated asymmetric 5x2 Vulkan pixel regression on a physical
  Vulkan device:

  ```sh
  VKMTL_BACKEND=vulkan zig build run-pixel-regression -Dvulkan
  ```

  Record `presentation_orientation=top_left` and channel deltas no greater
  than one. This is a required release-matrix artifact, separate from the
  accepted RT scene orientation.
- [ ] Record physical Vulkan `HeadlessContext` loader/device execution on
  Windows or Linux. Forced Windows cross-compilation proves buildability, not
  loader/device execution.
- [ ] Run the bounded voxel pressure example on physical Vulkan hardware and
  record capability/device context. Physical Metal smoke/default/stress and
  forced Vulkan compilation are already recorded.
- [ ] Refresh every required physical lane against the exact future release
  commit before tagging; historical evidence remains history only.

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
synchronous. The voxel pressure run identified this as a future throughput
boundary.

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
