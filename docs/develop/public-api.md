# Public API And Compatibility Policy

This is the authoritative policy for declarations reachable through the
`vkmtl` module and for the compatibility promise attached to released
versions. Read it before changing `src/vkmtl.zig`, a public owner method,
descriptor, enum tag, error, default, capability, limit, ownership rule, or
lifetime rule.

`public-api-inventory.md` is the exact current surface snapshot. `migration.md`
is the caller-facing compatibility reference. User-visible changes also belong
in the repository `CHANGELOG.md`.

## Goals

- Keep the ordinary rendering path small, portable, and Metal-inspired.
- Keep advanced and backend-sensitive declarations in domain namespaces.
- Let Vulkan and Metal lower the same vkmtl concepts without leaking native
  types through portable shapes.
- Make compatibility breaks explicit, reviewable, documented, and tied to a
  release boundary.
- Preserve truthful feature, limit, and format capability reporting.

The root has a working size target of roughly 50 to 80 common names, but the
admission rules below, not the number alone, decide whether a declaration
belongs there.

## What Counts As Public API

Public API includes:

- declarations exported by `src/vkmtl.zig` or a public namespace below it;
- public methods and fields on exported types;
- enum tags, flag fields, errors, descriptor defaults, and validation behavior;
- ownership, destruction order, borrowing, and synchronization rules;
- capability and limit meanings;
- examples and documented command sequences presented as supported usage.

A change can be breaking even when no Zig name changes. Backend-private
declarations, generated shader artifacts, tests, tools, and implementation
records must not become reachable from the package module.

## API Lanes

Every declaration has one primary lane and one canonical owner.

### Portable core

Portable core describes the common quick-start path shared by Vulkan and
Metal: backend selection, adapters, devices, queues, surfaces, common
resources, pipelines, command objects, and presentation. Only names satisfying
all root-admission rules may receive root exports.

### Domain namespaces

| Namespace | Owns |
| --- | --- |
| `resource` | formats, usage, buffers, textures, views, samplers, heaps, and portable sparse resource descriptors and residency plans |
| `shader` | declarations, reflection, specialization, and compilation descriptors |
| `binding` | bind group layouts, bind groups, resource tables, dynamic offsets, and constants |
| `render` | render passes, pipelines, attachments, raster state, tessellation, mesh rendering, and draw descriptors |
| `compute` | compute pipelines, dispatch, atomics, and threadgroup memory |
| `transfer` | copy, fill, blit, mipmap, and readback descriptors |
| `command` | command-buffer lifecycle, encoder state, and command errors |
| `sync` | barriers, fences, events, queue selection, and ownership transfer |
| `presentation` | surfaces, swapchains, present modes, resize, and frame pacing |
| `ray_tracing` | acceleration structures, ray pipelines, shader binding tables, dispatch, and ray queries |
| `interop` | external resources, platform sharing, and explicit import/export contracts |
| `diagnostics` | capabilities, validation classification, profiling, capture, and debug data |
| `native` | intentional native handles, backend-selected lowerings, and backend-specific operations |

Compatibility aliases may exist temporarily, but examples and current docs use
the canonical name.

### Capability-gated advanced API

An advanced feature may have one portable shape while remaining optional in
execution. It must:

- live in its domain namespace rather than expanding the flat root;
- validate through `DeviceFeatures`, `DeviceLimits`, or format capabilities;
- return a typed unsupported result before backend work begins;
- distinguish executable, planning-only, native-only, and unsupported states.

A native query, lowering plan, or declaration alone is not executable support.

### Native escape hatches

Backend-specific handles and operations belong under `native` or an explicit
backend-specific namespace. Vulkan and Metal types do not belong in portable
descriptors or ordinary resource methods.

`presentation.SurfaceSource.vulkan` is the sole approved portable-shape
exception. Its callback-only `native.vulkan.SurfaceProvider` creates a Vulkan
surface without exposing raw binding types. Another exception requires an
explicit design decision, inventory update, compatibility review, and API
guard update.

Portable sparse descriptors and mappings remain under `resource`. Backend
selection results such as `SparseBufferLowering` and
`SparseTextureLowering` remain under `native`.

## Runtime Handle Representation

Every exported runtime handle exposes exactly one implementation-storage field
named `_state`. Its type is inline opaque bytes for a value-owned handle or
`*anyopaque` for a heap-owned or borrowed view. Backend unions, runtime
implementations, trackers, and debug records must remain private.

Callers use documented factories and methods. Struct literals, `_state`
inspection or mutation, and dependencies on its size, alignment, layout, or
contents are unsupported. The API guard locks the handle list and one-field
shape.

## Root And Owner Admission

A new root export is admitted only when all of these are true:

1. It is part of the common quick-start path.
2. It has backend-neutral semantics on Vulkan and Metal.
3. Its ownership and lifetime belong to a stable public owner.
4. Its name and default behavior can remain compatible for the active minor
   release line.
5. Keeping it only in a domain namespace would materially harm ordinary use.

When any condition is uncertain, keep the declaration in its namespace.
Existing flat declarations are not precedent for another root alias.

Common Metal-inspired owner methods such as `Device.makeBuffer`,
`Device.makeTexture`, `Device.makeRenderPipelineState`, and
`Queue.makeCommandBuffer` may remain direct. Specialized planning, interop,
diagnostics, and backend-specific work must not continuously grow `Device` or
`WindowContext`.

The prototype `WindowContext.make*` forwards were removed before `v0.1.0`.
Do not restore compatibility forwards without an explicit, time-bounded
migration decision.

## Naming And Boundary Rules

- Prefer backend-neutral concepts and Metal-like object usage when practical.
- Use `Descriptor` for explicit creation or encoding inputs.
- Use typed enums and flags instead of strings.
- Keep native names in `native`, backend diagnostics, or explicit advanced
  namespaces.
- Do not expose generated bindings or backend-private record layouts.
- Use typed errors specific to the operation and failure class.
- Keep public facades independent of Vulkan bindings, Metal bridge types,
  GLFW internals, and platform Objective-C details.
- Do not report a capability usable until its complete public execution path is
  implemented and validated.

## Workflow For Public Changes

Before implementation:

1. Assign the declaration to one lane and canonical namespace.
2. Decide its owner, lifetime, capability gate, defaults, and typed errors.
3. Check whether an existing declaration can be extended without changing its
   meaning.
4. Record a design decision for a new root export, compatibility alias, or
   breaking change in `roadmap.md`.

During implementation:

1. Add the declaration only at its canonical location.
2. Add focused validation and both-backend compile coverage.
3. Keep examples on portable canonical APIs.
4. Add compatibility forwarding only when an already-supported path would
   otherwise break.

Before completion:

1. Update API and usage docs.
2. Update `public-api-inventory.md` in the same change.
3. Update `native-semantic-coverage-inventory.md` when support meaning or
   evidence changes.
4. Confirm public files do not import backend-private dependencies.
5. Update the API guard allowlist for an intentional root, `Device`,
   `WindowContext`, or `HeadlessContext` change.
6. Run validation appropriate to the change, including
   `zig build run-api-guard` for public surface changes.

## Version And Compatibility Policy

vkmtl uses semantic-looking `0.x.y` versions while the architecture evolves:

- patch releases preserve the documented portable Zig source API of their
  minor line;
- intentional portable source breaks require the next minor version;
- therefore a `v0.1.x` source break requires `v0.2.0` or later, changelog
  coverage, and migration guidance;
- fixes may reject invalid input earlier or return a more precise typed error
  without preserving invalid behavior.

The `v0.1.x` promise covers canonical portable declarations, documented owner
methods and descriptor defaults, typed error categories, ownership and
borrowing rules, and reported capability/limit/format meanings. It applies
only to supported portable paths on devices that report the required
capabilities.

Additive declarations may enter a patch release when existing source behavior
does not change. `HeadlessContext` is additive: it owns a no-presentation
device/queue runtime while leaving `WindowContext` unchanged.

### Intentional removal or rename

1. Define and document the canonical replacement.
2. Migrate in-tree examples, tests, tools, and user docs.
3. Keep an alias or forward through the current minor line when practical.
4. Record the impact in the changelog, inventory, migration guide, and release
   review.
5. Remove the old path only at the planned next-minor boundary.

Defaults, tags, errors, ownership, lifetime, capabilities, and limits follow
the same process. Do not mix broad public renaming with backend implementation
work.

## Explicit Non-Guarantees

vkmtl does not promise:

- a stable binary ABI;
- stable `_state` size, alignment, representation, or contents;
- stable raw native-handle values or identity;
- stability of backend-native escape hatches across `0.x` minor releases;
- support not reported by the selected device;
- compatibility with Zig versions outside the release contract.

`v0.1.x` targets Zig `0.16.0`, which is also the package minimum.

## Package And Shader Contract

The package exports one supported module named `vkmtl`:

```zig
const vkmtl_dep = b.dependency("vkmtl", .{
    .target = target,
    .optimize = optimize,
    .shader_manifest = b.path("shaders/manifest.json"),
});

exe.root_module.addImport("vkmtl", vkmtl_dep.module("vkmtl"));
```

Examples, common window adapters, tools, and tests are repository-private.
Consumers register shaders with a source-backed `shader_manifest`
`std.Build.LazyPath`. Generated manifests are unsupported because inputs are
enumerated while constructing the dependency graph.

Schema 1 contains `render_shaders`, `compute_shaders`, and
`ray_tracing_shaders`. Schema 2 retains them and adds
`tessellation_shaders` and `mesh_shaders`; optional `task_entry` is
schema-valid but does not make the pinned compiler's unstable task/object
artifact executable.

Shader paths are relative to the manifest, remain inside its logical root, and
use portable lowercase names. The build tracks the manifest, sources, and
Slang depfile imports, produces SPIR-V/MSL/reflection artifacts, and embeds
them. Runtime APIs never launch `slangc` or write a shader cache. Unknown build
hosts must supply the build-time `slangc` option explicitly.

## Release Gates

A release commit must:

1. update package metadata, changelog, compatibility docs, and migration
   guidance where applicable;
2. pass API, semantic inventory, tests, builds, formatting, and diff checks
   appropriate to the release;
3. pass an external package smoke using only `vkmtl` and a consumer-owned
   shader manifest;
4. pass hosted CI on the exact release commit;
5. record required physical Metal and Vulkan evidence for that commit;
6. create an annotated tag only after those gates pass;
7. verify the tag archive from a fresh external consumer before publication.

Evidence from another commit remains useful history but does not satisfy the
current release gate.

## Review Checklist

- [ ] One canonical lane, namespace, and owner are identified.
- [ ] Every root export satisfies all admission rules.
- [ ] Portable shapes contain no unapproved backend-private types.
- [ ] Runtime handles expose only their guarded `_state` field.
- [ ] Ownership, borrowing, lifetime, and destruction order are explicit.
- [ ] Optional behavior has truthful feature, limit, or format gates.
- [ ] Errors identify validation, unsupported, backend, device, or surface
  failure appropriately.
- [ ] Examples and docs use canonical APIs.
- [ ] Compatibility impact and removal timing are documented.
- [ ] Inventories and guard allowlists are updated in the same change.
- [ ] Required tests, builds, package smoke, and physical evidence pass.
