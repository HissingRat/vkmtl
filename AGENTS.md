# AGENTS.md

Project guidance for agents working in this repository.

## Project Goal

vkmtl is a Zig graphics abstraction library with interchangeable Vulkan and
Metal backends. The public API should describe vkmtl concepts, while backend
modules translate those concepts into native API calls.

The core rule is simple: every major subsystem must be replaceable without
rewriting the rest of the library.

## Architecture Principles

- Keep modules pluggable. Backends, platform surfaces, shader compilation, and
  examples should be swappable behind small interfaces.
- Keep boundaries clear. Public API modules should not depend on concrete
  Vulkan or Metal implementation details.
- Prefer capability queries over platform assumptions. Backend selection should
  be explicit and report why a backend is unavailable.
- Keep native handles behind intentional escape hatches. Do not leak Vulkan or
  Metal types through ordinary public API shapes.
- Make errors typed and specific enough to identify the failing backend and
  operation.
- Grow from working vertical slices. Preserve the current triangle path while
  moving pieces behind the abstraction layer.
- Shape the public API around Metal-like naming and usage where possible:
  descriptors, command queues, command buffers, render command encoders, and
  pipeline state objects. Keep Vulkan complexity behind the backend boundary.

## Public API Evolution

`docs/develop/public-api-rules.md` is the authoritative policy for public API
changes. Read it before adding, removing, renaming, or moving any declaration
reachable through `src/vkmtl.zig`, and before changing public methods, fields,
enum tags, errors, defaults, ownership, lifetime, capability, or limit meaning.
`docs/develop/public-api-inventory.md` is the current surface snapshot and
canonical namespace assignment; update it in the same change whenever the
public surface changes. `docs/develop/api-migration-guide.md` records the
intentional Phase 9 break and is the compatibility reference for callers
updating from the prototype surface.

In particular:

- Do not add advanced declarations to the flat root merely because existing
  declarations are flat.
- New public declarations need one canonical domain namespace and must satisfy
  the documented root admission rules before receiving a root alias.
- Do not add new `WindowContext` compatibility forwards without a documented
  design decision.
- Examples and user-facing docs must use canonical APIs rather than temporary
  compatibility aliases.
- Breaking cleanup must follow the documented migration and release-gate
  process; it must not happen incidentally during backend work.
- `zig build run-api-guard` enforces the exact root, `Device`, and
  `WindowContext` allowlists. Any intentional change to those sets must update
  the allocation decision, inventory, compatibility guidance when applicable,
  and guard allowlist in the same change.

## Intended Module Boundaries

Suggested dependency direction:

```text
examples
  -> public vkmtl API
    -> core descriptors, handles, validation, capability types
      -> backend interface
        -> backend/vulkan
        -> backend/metal
      -> platform/window integration
      -> shader pipeline
```

Rules:

- `backend/vulkan` may import Vulkan bindings.
- `backend/metal` may import Metal bridge bindings.
- Public API files may define backend-neutral enums, descriptors, flags, and
  opaque handles.
- Public API files should not import `vulkan-zig`, Metal bridge headers, GLFW
  internals, or platform-specific Objective-C details.
- Platform/window integration should be isolated from resource, pipeline, and
  command APIs.
- Shader tooling should be isolated so Slang compilation can be replaced or
  extended without touching render command code.

## Example Policy

Examples live under `examples/` and are users of the public vkmtl API.

`examples/triangle` is the first backend-independent public API sample. New
examples should start under `examples/` and use public vkmtl modules.

Rules:

- Examples may use public vkmtl platform/window helpers.
- Examples may choose backends through public options such as `.auto`,
  `.vulkan`, and `.metal`.
- Examples must not import backend-private modules, raw Vulkan bindings, Metal
  bridge headers, or platform internals.
- If an example needs backend-specific access, either add a public abstraction
  or make it an explicit native-handle/debug sample.

## Backend Interface Expectations

Backend implementations should satisfy the same conceptual contract:

- enumerate adapters
- report features and limits
- create/destroy devices and queues
- create/destroy surfaces and presentation chains
- create/destroy buffers, textures, views, and samplers
- create/destroy shader modules and pipelines
- encode commands
- submit work and present frames

If one backend cannot support a feature, expose that through features/limits
instead of baking backend-specific branches into user-facing code.

## Shader Direction

Slang is the shader source language. Public examples should embed `.slang`
files with `@embedFile(...)` and compile them through the runtime `Device`
returned by `WindowContext.device()`, using `Device.compileRenderShader(...)`
or `Device.compileComputeShader(...)`.

The shader compilation pipeline is:

- Vulkan: Slang to SPIR-V.
- Metal: Slang to MSL, then runtime Metal library creation.

`zig build` prepares the pinned Slang distribution by default on build hosts
with known release packages and precompiles known embedded shader declarations
into a generated `vkmtl_precompiled_shaders` module. Runtime shader APIs do not
spawn `slangc`, do not require `slangc` beside the executable, and must report a
typed missing-precompiled-shader error when no matching name/entry/source hash
blob exists. Unknown build hosts must use an explicit build-time
`-Dslangc=/path/to/build-time/slangc` override. Runtime shader APIs must consume
embedded precompiled blobs directly from memory and must not create
`vkmtl-cache`, parse `--cache-dir`, or write SPIR-V/MSL/reflection JSON beside
the executable. Build-time artifact copies for inspection belong under
`zig-out/shaders/<shader-name>/`.
`build.zig` owns the pinned Slang distribution version and auto-download
metadata. Slang setup command bodies belong in `scripts/`, not inline heredocs
in `build.zig`.

Keep build-time shader artifacts inspectable while the pipeline is young.
Reflection data feeds bind group layout derivation, vertex descriptor
derivation, and binding validation. Explicit descriptors are still allowed when
an example or application needs direct control. Keep examples on the public
runtime shader declaration APIs; the build-time precompiler owns the embedded
artifact blobs.

## Phase Discipline

Follow `docs/develop/roadmap.md`.

Before starting work on any phase, read `docs/develop/checklist.md` and
complete the checklist items that define or unblock that phase. If a checklist
item is a design decision, make the decision explicit in docs before
implementing code that depends on it.

Before changing public API during a phase, also read and apply
`docs/develop/public-api-rules.md`.

Current priority follows the active phase in `docs/develop/checklist.md`. Keep
work in small vertical slices and do not jump to broad engine features before
the backend boundary for the current slice is stable.

## Worktree Habits

- Do not check `git status` and `git diff` every turn by habit.
- Use git inspection when it is needed for the task: before committing, before
  staging, when avoiding overwriting user work, when reviewing changes, or when
  a file's current state is unclear.
- Do not revert user changes unless explicitly asked.
- Prefer small, scoped edits that keep the current prototype runnable.

## Validation

Use validation that matches the edit.

- Documentation-only changes usually need no build unless package metadata or
  build files changed.
- Build or package metadata changes should run `zig build --fetch` or the
  closest relevant build command.
- API and backend changes should add or update focused tests when possible.
- Public root, `Device`, or `WindowContext` changes must run
  `zig build run-api-guard` in addition to the normal API validation.
- Rendering behavior changes should keep at least one runnable example working.

## Style

- Keep code and docs plain ASCII unless a file already uses non-ASCII or the
  content clearly requires it.
- Prefer explicit descriptors and small structs over hidden global state.
- Prefer typed flags/enums over strings for public API choices.
- Keep comments short and useful; use them to explain non-obvious backend
  mapping or lifetime rules.
