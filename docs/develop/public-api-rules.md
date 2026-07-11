# Public API Evolution Rules

This document is the authoritative policy for adding, changing, moving, or
removing vkmtl public API. Read it before editing `src/vkmtl.zig`, adding public
methods to runtime objects, or changing public descriptors, errors, defaults,
ownership, or lifetime behavior.

The Period 1 Phase 9 migration applied this policy to the prototype surface.
The resulting 68-name root, 34-method `Device`, and 10-method `WindowContext`
are the `v0.1.0` compatibility baseline and explicit allowlists rather than
precedent for uncontrolled growth. `release-policy.md` defines the versioned
promise applied to that surface.

## Goals

- Keep the common rendering path small, portable, and Metal-inspired.
- Keep advanced and backend-sensitive features out of the flat root namespace.
- Let Vulkan and Metal implementations evolve without changing ordinary user
  code.
- Preserve working vertical slices while the public surface is reorganized.
- Make compatibility breaks explicit, reviewable, and tied to a release gate.

API size is not controlled by a numeric target alone. The working target is a
root module with roughly 50 to 80 common names, but the admission rules below
decide whether a declaration belongs there.

## What Counts As Public API

All of the following are public API when reachable through the `vkmtl` module:

- declarations exported by `src/vkmtl.zig` or a public namespace below it
- public methods and fields on exported types
- enum tags, flag fields, error names, descriptor defaults, and validation
  behavior
- ownership, destruction order, borrowing, and synchronization rules
- capability and limit meanings
- example code and documented command sequences presented as supported usage

Changing a default, error, lifetime rule, or capability meaning can be a
breaking change even when the Zig declaration keeps the same name.

Backend-private declarations, generated shader artifacts, test helpers, and
implementation records must not become reachable from the public module by
accident.

## Public API Lanes

Every public declaration must belong to one primary lane.

### Portable Core

Portable core names describe the ordinary path shared by Vulkan and Metal.
They may be exported at the root only when they satisfy the root admission
rules. Examples include backend selection, adapters, devices, queues, surfaces,
common resources, pipelines, and command objects.

### Domain Namespaces

Descriptors, helpers, and less common objects belong to a domain namespace.
The intended namespace map is:

| Namespace | Owns |
| --- | --- |
| `resource` | formats, usage, buffers, textures, views, samplers, heaps, and portable sparse resource descriptors and residency plans |
| `shader` | shader declarations, reflection, specialization, and compilation descriptors |
| `binding` | bind group layouts, bind groups, resource tables, dynamic offsets, and constants |
| `render` | render passes, render pipelines, attachments, raster state, and draw descriptors |
| `compute` | compute pipelines, dispatch, atomics, and threadgroup memory |
| `transfer` | copy, fill, blit, mipmap, and readback descriptors |
| `command` | command buffer lifecycle, encoder state, and command errors |
| `sync` | barriers, fences, events, queue selection, and ownership transfer |
| `presentation` | surfaces, swapchains, present modes, resize, and frame pacing |
| `ray_tracing` | acceleration structures, ray pipelines, shader binding tables, and ray queries |
| `interop` | external resources, platform sharing, and explicit import/export contracts |
| `diagnostics` | capability reports, validation classification, profiling, capture, and debug data |
| `native` | explicit backend-native handles and backend-selected lowering records and operations |

A declaration should have one canonical home. Compatibility aliases may exist
temporarily, but documentation and examples must use the canonical name.

### Capability-Gated Advanced API

Advanced features may be portable in shape while remaining optional in
execution. They must:

- live in the relevant domain namespace rather than expanding the flat root
- validate through `DeviceFeatures`, `DeviceLimits`, or format capabilities
- return typed unsupported errors before backend work begins
- document whether support is executable, planning-only, or native-only

A backend planning record is not automatically a portable user-facing API.

### Native Escape Hatches

Backend-specific handles and operations belong under `native` or an explicitly
backend-specific subnamespace. Vulkan or Metal types must not appear in portable
descriptors, ordinary resource methods, or the flat root.

`presentation.SurfaceSource.vulkan` is the one approved native callback
exception in presentation integration. It accepts the callback-only
`native.vulkan.SurfaceProvider` shape needed to create a Vulkan surface without
importing raw Vulkan binding types into the portable descriptor. This exception
does not admit other backend-specific fields into portable API. Any additional
exception requires an explicit design decision, inventory update, and API guard
change.

Sparse resource descriptors, mappings, and residency plans remain portable
under `resource`. `SparseBufferLoweringMode`, `SparseBufferLowering`,
`SparseTextureLoweringMode`, `SparseTextureLowering`, and the two
`planSparse*Lowering` operations are backend-selection results and therefore
belong under `native`.

### Runtime Handle Representation

Exported runtime handle structs expose exactly one implementation-storage field
named `_state`. Its type must be either inline opaque byte storage for a
value-owned handle or `*anyopaque` for a heap-owned or borrowed runtime view.
No backend union, `BackendRuntime`, `Impl`, `ResourceTracker`, debug record, or
other private state type may be reachable through a public handle field.

Callers create handles through documented factories and interact with them
through public methods. Direct struct literals, reads or writes of `_state`, and
dependencies on its size, alignment, or layout are unsupported. The `_state`
name and storage are an implementation boundary, not an application extension
point. The API guard locks the handle list and this one-field shape; changing it
requires the same compatibility review as any other public layout change.

### Compatibility Surface

Compatibility aliases and forwarding methods are temporary migration tools,
not preferred API. They must have a canonical replacement and must not be used
by new examples or documentation.

For `v0.1.x`, canonical portable declarations, documented public owner methods,
descriptor defaults, typed errors, ownership/lifetime rules, and supported
capability meanings are source-compatible. Intentional breaking changes to
that surface require `v0.2.0` or later and migration guidance. This does not
make the binary ABI, opaque `_state` layout, native-handle values, or
backend-native escape hatches stable.

The prototype `WindowContext.make*` and related forwarding methods were removed
in the Phase 9 pre-release cleanup. Resource and pipeline APIs must be owned by
`Device`, `Queue`, `Surface`, `Swapchain`, or a canonical facade. Do not restore
compatibility forwards without a documented, time-bounded migration decision.

## Root Module Admission Rules

A new root export is allowed only when all of these are true:

1. It is part of the common quick-start path, not an advanced planning helper.
2. It has backend-neutral semantics on both Vulkan and Metal.
3. Its ownership and lifetime belong to a stable public owner.
4. Its name and default behavior can remain source-compatible throughout the
   active minor release line.
5. Keeping it only in a domain namespace would make ordinary use materially
   harder.

If any condition is uncertain, place the declaration in its domain namespace.
Do not add a root alias merely because older declarations are flat.

The common owner methods may remain direct and Metal-inspired, such as
`Device.makeBuffer`, `Device.makeTexture`, `Device.makeRenderPipelineState`,
and `Queue.makeCommandBuffer`. Specialized planning, interop, diagnostics, and
advanced backend work should not continuously enlarge these common owners.

## Naming And Boundary Rules

- Prefer backend-neutral concepts and Metal-like object usage where practical.
- Use `Descriptor` for explicit creation or encoding inputs.
- Use typed enums and flags instead of stringly-typed options.
- Keep native backend names inside `native`, backend diagnostics, or an
  explicitly backend-specific advanced namespace.
- Do not expose backend-private record layouts or generated binding types.
- Keep runtime handles on the guarded single-`_state` representation; do not
  add a convenience field that makes implementation state reachable again.
- Keep public errors specific to the operation and failure category.
- Do not report a native feature as usable until the public execution path is
  implemented and validated.
- Public facade modules may import core/runtime modules, but must not import raw
  Vulkan bindings, Metal bridge declarations, GLFW internals, or platform
  Objective-C details.

## Required Workflow For Public API Changes

Before implementation:

1. Identify the declaration's lane and canonical namespace.
2. Decide its owner, lifetime, capability gate, and typed error behavior.
3. Check whether an existing declaration can be extended without changing its
   established meaning.
4. Record a design decision in the active phase docs when a new root export,
   compatibility alias, or breaking change is proposed.

During implementation:

1. Add the declaration at its canonical location.
2. Add focused validation tests and backend compile coverage.
3. Keep ordinary examples on portable APIs and canonical names.
4. Add compatibility forwarding only when an existing supported path would
   otherwise break.

Before completion:

1. Update API and usage docs for user-visible behavior.
2. Update `public-api-inventory.md`.
3. Confirm public files do not import backend-private dependencies.
4. Confirm the runtime handle field allowlist and the sole
   `SurfaceSource.vulkan` callback exception are unchanged or intentionally
   updated.
5. Run `zig fmt --check build.zig src examples tools`,
   `zig build run-api-guard`, `zig build test`, `zig build`, and
   `git diff --check` for API or backend changes.

## Compatibility And Removal Process

The pre-tag breaking cleanup ended at the `v0.1.0` baseline. Throughout
`v0.1.x`, breaking cleanup of the documented portable surface is not allowed as
incidental phase or backend work. Schedule an intentional portable source break
for `v0.2.0` or later.

Removing or renaming an existing public declaration requires this sequence:

1. Define the canonical replacement and document the reason for the change.
2. Migrate all in-tree examples, tests, and user-facing docs.
3. Keep a compatibility alias or forwarding method through the current minor
   line when practical.
4. Record the compatibility impact in the changelog, active release review,
   API inventory, and migration guide.
5. Remove compatibility declarations together only at the planned next-minor
   release boundary.

Changes to defaults, enum tags, errors, ownership, lifetime, capability
meaning, or limit meaning follow the same process even if no declaration is
renamed. Fixes may reject invalid input earlier or return a more specific error
without preserving the old invalid behavior. Capability-gated operations are
compatible only within the support truth reported by the selected device; a
planning-only record is not an executable feature promise.

Do not mix broad public renaming with backend implementation changes. Public
facade migration and internal file decomposition should be separate reviewable
changes.

## Completed Migration Baseline

`api-migration-roadmap.md` records the completed execution, and
`api-migration-map.md` records the approved allocation. The cutover:

1. freeze uncontrolled root and compatibility growth, then finalize the
   allocation and migration map;
2. add the remaining canonical facades without removing aliases;
3. migrate examples, tests, tools, and docs to canonical paths;
4. converge `WindowContext` and advanced `Device` owner surfaces;
5. internalize implementation-shaped records and approve the exact public diff;
6. remove approved aliases and forwards in one explicit breaking cleanup;
7. complete release documentation, validation, and API freeze.

All seven implementation phases plus release polish are complete. The final
surface and counts are in `public-api-inventory.md`; caller changes are in
`api-migration-guide.md`. This surface is the `v0.1.0` compatibility baseline.
Future compatibility removals must still establish a canonical destination,
migrate in-tree callers, and wait for the documented release boundary before
deleting an old path.

## Review Checklist

For every public API change, verify:

- [ ] The declaration has one canonical lane and namespace.
- [ ] A root export, if any, satisfies every root admission rule.
- [ ] Portable descriptors contain no Vulkan, Metal, GLFW, or platform-private
  types other than the approved `SurfaceSource.vulkan` callback shape.
- [ ] Runtime handles expose only their guarded `_state` storage field, and no
  private implementation record is reachable through it.
- [ ] Ownership, lifetime, and destruction order are explicit.
- [ ] Optional behavior has truthful feature, limit, or format gates.
- [ ] Failures use typed validation, unsupported, backend, device, or surface
  errors as appropriate.
- [ ] Examples and documentation use the canonical API rather than a
  compatibility alias.
- [ ] Compatibility impact and removal timing are documented.
- [ ] The change satisfies `release-policy.md` for the active version line.
- [ ] The exact API guard allowlists are unchanged or intentionally updated.
- [ ] Focused tests and the validation commands appropriate to the change pass.
