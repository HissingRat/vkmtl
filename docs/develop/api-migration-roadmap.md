# Public API Migration Roadmap

Status: complete. All Phase 0-7 exit gates were closed on 2026-07-11.

This document turns the public API rules and inventory into an ordered,
reviewable migration. It is the execution plan for the API portion of Period 1
Phase 9. `public-api-rules.md` remains the authoritative policy, and
`public-api-inventory.md` remains the current surface snapshot.

The approved Phase 0 root, namespace, native-name, and owner decisions are in
`api-migration-map.md`.

Period 44 has completed all nine release-evidence gates, and the supported
Vulkan ray tracing validation carry-over is closed. The next mainline is API
convergence rather than another backend feature period.

## Objective

Move vkmtl from a large prototype-shaped public surface to three intentional
layers:

1. a small root for common, stable, backend-neutral work;
2. domain namespaces for descriptors, advanced features, and diagnostics;
3. explicit native escape hatches or internal implementation records.

The working target is roughly 50 to 80 root names. This is not a quota: every
retained root name must still satisfy the root admission rules.

The historical migration input was:

- 492 flat root exports, including seven namespace facades;
- 108 public `Device` methods;
- 56 public `WindowContext` methods;
- 41 distinct root names referenced by in-tree examples;
- 40 `Device.plan*` and 19 `Device.validate*` methods requiring owner review.

## Completion Result

The completed compatibility boundary has:

- 68 root declarations: 13 facades, 27 portable declarations, and 28 approved
  common aliases;
- 34 public `Device` methods;
- 10 public `WindowContext` methods;
- 35 guarded methods-only runtime handles whose sole `_state` field is opaque
  storage or an opaque owner/view pointer;
- a final facade recount of 508 declarations and 87 callable aliases, with all
  69 operations moved off `Device` still assigned to canonical owners;
- canonical facade paths throughout examples, tools, API docs, and usage docs;
- an exact-name and runtime-handle-layout `zig build run-api-guard` check
  included in all hosted CI jobs;
- a final inventory and caller migration guide.

The migration changed namespace reachability and method ownership without an
intentional backend behavior change. The first tagged compatibility release is
still a separate release decision.

## Target State

The migration is complete when:

- every public declaration has one canonical domain;
- ordinary quick-start code needs only the selected portable root names;
- advanced examples and documentation use domain namespaces;
- `WindowContext` exposes only its ten provisional lifecycle, identity, and
  owner-access methods;
- common resource creation, shader compilation, and command submission stay on
  their natural `Device` and `Queue` owners;
- advanced planning and validation do not continuously enlarge `Device`;
- backend lowering records live under `native.vulkan`, `native.metal`, or are
  internal;
- sparse descriptors and residency work stay under `resource`, while
  backend-selected sparse lowering lives under `native`;
- `RayQueryPlan` remains portable and does not expose a lowering mode;
- no backend-private binding, `BackendRuntime`, `Impl`, `ResourceTracker`,
  debug record, or other implementation state is reachable through a runtime
  handle;
- `SurfaceSource.vulkan` remains the sole approved native callback exception in
  presentation integration;
- compatibility aliases and forwards are removed together at one documented
  pre-release boundary;
- the inventory, API docs, usage docs, and examples describe the same surface.

## Migration Constraints

- Do not mix broad API migration with backend behavior changes.
- Establish a canonical replacement before removing or renaming a public name.
- Migrate in-tree callers before deleting compatibility declarations.
- Keep compatibility aliases and forwards through the non-breaking phases.
- Perform the approved compatibility removal as one explicit breaking slice.
- Preserve type identity while both canonical and compatibility names exist.
- Update `public-api-inventory.md` whenever a public declaration or method
  changes visibility, name, owner, or compatibility status.
- Decide new owner shapes in phase docs before adding facade operations or
  moving advanced `Device` methods.

## Phase 0: Freeze And Final Allocation (Complete)

Purpose: turn the inventory into a complete migration decision table before
editing public API.

Work:

- Freeze new root aliases and new `WindowContext` compatibility forwards.
- Recount root exports and reachable public runtime methods.
- Classify every root export as one of:
  - retained portable root;
  - namespace-only;
  - temporary compatibility alias;
  - `native.vulkan` or `native.metal`;
  - internalize;
  - remove after migration.
- Decide the final root status of the 30 provisional core candidates.
- Review the 28 common alias candidates against actual quick-start use.
- Record every old-to-canonical name mapping.
- Identify public records that have no user-facing consumer.

Exit gate:

- All 492 root exports have an explicit disposition.
- Every planned removal has a canonical replacement or an internal-only reason.
- The category totals still equal the measured root export count.
- The compatibility impact and removal phase are recorded.

## Phase 1: Complete Canonical Facades (Complete)

Purpose: provide stable destinations before migrating callers.

The existing facades are:

```text
resource
transfer
render
command
sync
presentation
diagnostics
```

Add the remaining canonical facades:

```text
shader
binding
compute
ray_tracing
interop
native
native.vulkan
native.metal
```

Work:

- Export existing public types through their canonical facade.
- Keep existing root aliases during this phase.
- Preserve declaration identity instead of introducing wrapper types.
- Keep facade dependencies backend-neutral. Only explicit native facades may
  expose backend-specific concepts, and they must not import raw bindings into
  portable API shapes.
- Add focused facade reachability and type-identity tests.

Exit gate:

- Every retained public declaration is reachable through one canonical domain.
- The new canonical paths compile without changing runtime behavior.
- No root alias has been removed yet.

## Phase 2: Migrate In-Tree Callers (Complete)

Purpose: make the repository itself demonstrate the intended public API.

Migrate in this order:

1. ordinary examples;
2. advanced examples;
3. tests and tools that intentionally act as API consumers;
4. API documentation;
5. usage documentation and README snippets.

Rules:

- Ordinary examples may use approved portable root names.
- Advanced ray tracing, interop, sparse, tessellation, mesh, and diagnostic
  examples use their canonical namespaces.
- Backend-specific names use `native.vulkan` or `native.metal` explicitly.
- Example use is evidence for root review, not automatic root admission.
- Add a source check that prevents migrated callers from returning to planned
  compatibility names.

Exit gate:

- No in-tree example or user-facing document uses a planned removal.
- The 41-name example regression set is refreshed.
- All examples still compile through the same public backend-neutral paths.

## Phase 3: Converge Runtime Owners (Complete)

Purpose: stop `WindowContext` and `Device` from acting as undifferentiated API
containers.

### WindowContext

Keep these provisional methods:

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

Migrate callers of the other 46 methods to `Device`, `Queue`, `Surface`,
`Swapchain`, or a domain facade. Keep the forwards until the breaking cleanup.

### Device

Review all 40 `plan*` and 19 `validate*` methods. Keep common creation,
compilation, capability, limit, and format operations on `Device` when device
ownership is natural. Move specialized planning and validation behind the
relevant domain only after its owner and error contract are documented.

Do not mechanically remove all planning methods. Common operations may remain
when they satisfy the owner and root admission rules, but every exception needs
a recorded reason.

Exit gate:

- In-tree callers use natural owners rather than `WindowContext` forwards.
- Every advanced `Device.plan*` and `Device.validate*` method has a keep, move,
  or internalize decision.
- Compatibility forwards remain behaviorally equivalent until final removal.

## Phase 4: Internalize Implementation-Shaped API (Complete)

Purpose: distinguish supported user concepts from prototype inspection records.

Review these groups first:

- `Vulkan*Lowering` and `Metal*Lowering` records;
- portable-looking sparse and ray-query records that actually expose a backend
  lowering choice;
- `NativeAdvancedClosure*` planning scaffolding;
- shape compatibility aliases;
- `Resolved*`, `*DebugState`, cache-plan, parity-plan, pressure-plan, and other
  implementation-shaped result records;
- exported runtime structs whose fields expose backend unions, trackers,
  descriptors, or private state.

Disposition rules:

- Put portable user concepts in the appropriate domain.
- Put supported backend-specific control under `native.vulkan` or
  `native.metal`.
- Put user-facing inspection data under `diagnostics`.
- Keep portable sparse descriptors and residency plans under `resource`, but
  put sparse lowering records and planners under `native`.
- Remove the public ray-query lowering mode and keep `RayQueryPlan` portable.
- Replace public runtime implementation fields with one `_state` opaque-storage
  field and preserve supported construction through factories.
- Internalize records used only by backend lowering, tests, or roadmap probes.
- Remove records that have neither a public consumer nor a supported contract.

Exit gate:

- Portable API contains no backend implementation naming.
- Public planning records have a documented user-facing use case.
- Backend-private state is not reachable through the public module.
- The runtime handle field allowlist and the sole `SurfaceSource.vulkan`
  callback exception are explicit and guardable.

## Phase 5: Approve The Breaking Cutover (Complete)

Purpose: review the exact compatibility break before applying it.

Work:

- Finalize the retained root set and root-admission justification for each name.
- Produce an old-to-new migration table for all aliases and forwards to remove.
- Confirm all examples, tests, tools, and docs already use canonical paths.
- Record intentional removals that have no replacement because they were
  implementation-only.
- Review descriptor defaults, error tags, ownership, lifetime, capability, and
  limit meanings for non-name compatibility changes.
- Record the source break for callers that constructed runtime handles with
  struct literals or accessed their implementation fields.

Exit gate:

- The proposed public diff is reviewable without reading backend changes.
- No removal is required merely to make an in-tree caller compile.
- The migration guide covers every user-visible breaking change.

## Phase 6: Execute One Breaking Cleanup (Complete)

Purpose: remove the approved compatibility surface at one explicit pre-release
boundary.

Remove together:

- unapproved flat root aliases;
- obsolete `WindowContext` forwards;
- shape compatibility aliases;
- internalized lowering and planning records;
- public runtime implementation fields, replaced by guarded `_state` storage;
- superseded names with canonical replacements.

Update the inventory, API reference, usage guides, examples, and migration guide
in the same slice. Do not combine this cleanup with new backend features.

Exit gate:

- The root is within the working 50-to-80 range or every exception is justified.
- `WindowContext` contains only the approved owner/lifecycle surface.
- No compatibility-only name remains without an explicit temporary exception.
- The public API count and owner-method inventory match the implementation.
- Every guarded runtime handle exposes exactly one `_state` field and no raw
  implementation type.

## Phase 7: Release Polish And Freeze (Complete)

Purpose: validate and document the first intentional compatibility surface.

Work:

- Document optional Vulkan validation-layer setup.
- Document Metal API validation and local Xcode validation notes.
- Publish an explicit feature and limit reference for the current resource,
  shader, render, transfer, compute, and advanced coverage.
- Review example names, build commands, expected output, and screenshots.
- Make quick-start guides use only the final API.
- Publish the migration guide and final public inventory.

Exit gate:

- API and usage documentation describe only supported final names.
- The compatibility and capability claims match validation evidence.
- The API is frozen for the first tagged compatibility release.

## Validation By Phase

Documentation-only allocation changes require `git diff --check` and link/count
review. Facade, owner, field-layout, visibility, or compatibility changes
require:

```sh
zig fmt --check build.zig src examples tools
zig build run-api-guard
zig build test --summary all
zig build
git diff --check
```

Before the final freeze, also run the hosted macOS, Linux, and Windows matrix and
the relevant physical Metal/Vulkan smoke, pixel, ray tracing, and bounded soak
evidence. An API-only migration must not silently change backend behavior.

## Intended Commit Sequence

Keep the migration reviewable with this approximate sequence:

```text
docs: define final API allocation and migration map
api: add remaining canonical namespace facades
examples: migrate callers to canonical namespaces
api: migrate WindowContext callers to natural owners
api: move advanced Device planning behind domains
api: internalize backend lowering and scaffolding records
api!: remove legacy aliases and compatibility forwards
docs: publish final API and migration guide
```

The central rule is: establish the new path, migrate callers, then remove the
old path once.
