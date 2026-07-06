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
files with `@embedFile(...)` and compile them through
`WindowContext.compileRenderShader(...)` or
`WindowContext.compileComputeShader(...)`.

The shader compilation pipeline is:

- Vulkan: Slang to SPIR-V.
- Metal: Slang to MSL, then runtime Metal library creation.

`zig build` prepares the pinned Slang distribution by default on build hosts
with known release packages. Unknown hosts fall back to `slangc` on `PATH` or an
explicit `-Dslangc=/path/to/slangc`. Runtime shader artifacts live in
`vkmtl-cache` beside the executable by default. Applications may either pass an
explicit `WindowContextOptions.shader_cache_dir` or pass process arguments to
`WindowContextOptions.process_args` so vkmtl can parse its own runtime
arguments such as `--cache-dir`.
`build.zig` owns the pinned Slang distribution version and auto-download
metadata. Slang setup command bodies belong in `scripts/`, not inline heredocs
in `build.zig`.

Keep runtime shader cache artifacts inspectable while the pipeline is young.
Reflection data feeds bind group layout derivation, vertex descriptor
derivation, and binding validation. Explicit descriptors are still allowed when
an example or application needs direct control. Do not reintroduce a build-time
shader artifact path; examples should compile embedded Slang through the runtime
cache.

## Phase Discipline

Follow `docs/develop/roadmap.md`.

Before starting work on any phase, read `docs/develop/checklist.md` and
complete the checklist items that define or unblock that phase. If a checklist
item is a design decision, make the decision explicit in docs before
implementing code that depends on it.

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
- Rendering behavior changes should keep at least one runnable example working.

## Style

- Keep code and docs plain ASCII unless a file already uses non-ASCII or the
  content clearly requires it.
- Prefer explicit descriptors and small structs over hidden global state.
- Prefer typed flags/enums over strings for public API choices.
- Keep comments short and useful; use them to explain non-obvious backend
  mapping or lifetime rules.
