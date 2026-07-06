# Roadmap

This document is the route map for vkmtl. It describes the order and intent of
major work, not the detailed task list.

Use these companion documents for the other views:

- `docs/develop/checklist.md` tracks concrete checkable work.
- `docs/api/zh_cn/core.md` and `docs/api/en_us/core.md` describe the public API
  surface.
- `docs/usage/zh_cn/quick-start.md` and `docs/usage/en_us/quick-start.md` show
  how to use the current API.
- `docs/develop/period1/` keeps the first major stage and its polish notes.
- `docs/develop/period2/` starts broader application coverage work.
- `docs/develop/period3/` tracks future stabilization and parity work.

## Direction

vkmtl is a small Vulkan + Metal graphics abstraction library. The public API
should describe graphics work in backend-neutral terms:

- select a backend
- describe a presentation surface
- create buffers, textures, views, samplers, shaders, pipelines, and bind groups
- encode render, transfer, and compute commands
- present to a drawable

Backend details stay behind `src/backend/vulkan` and `src/backend/metal`.
Windowing stays outside vkmtl core and enters through public surface
descriptors and provider callbacks. Native handles may exist later as explicit
escape hatches, but ordinary API paths should not expose Vulkan or Metal types.

The API should feel closer to Metal than Vulkan: descriptors, pipeline state
objects, command buffers, render command encoders, blit command encoders,
compute command encoders, and explicit resource handles.

## Period 1: Core Library Slice

Status: active until Phase 9 polish is complete.

This period takes vkmtl from a Vulkan triangle prototype to a working Vulkan +
Metal abstraction that is pleasant enough for early users. It covers:

- Phase 0: Vulkan and Metal bindings
- Phase 1: public library shape and backend selection
- Phase 2: surface and presentation
- Phase 3: buffers, textures, texture views, samplers, and upload helpers
- Phase 4: runtime Slang shader compilation, cache artifacts, and render
  pipelines
- Phase 5: command buffers and render command encoders
- Phase 6: bind group layouts, bind groups, reflection-assisted validation, and
  shader resources
- Phase 7: depth, offscreen render targets, MSAA, resolve attachments, and the
  rainbow cube integration example
- Phase 8: transfer commands, compute pipelines, compute dispatch, and
  deterministic readback examples
- Phase 9: API polish, docs, validation notes, CI, debug labels, and
  distribution cleanup

The important checkpoint is that examples now exercise the public API instead
of raw Vulkan or Metal calls. `examples/rainbow_cube` combines buffers,
textures, bind groups, depth, indexed drawing, and runtime Slang. Phase 8 adds
`examples/transfer_readback` and `examples/compute_readback`.

Current focus:

- keep the main docs separated into roadmap, checklist, project API, and usage
- audit public root exports before early release tags
- decide which temporary `WindowContext` owner APIs stay for early users
- document current limits, backend selection, shader authoring, and validation
  setup
- add backend object debug labels where native APIs support them
- add CI coverage for macOS and Linux
- review examples, run commands, and expected behavior

The active checklist lives in `docs/develop/checklist.md` under Phase 9.

## Period 2: Application Coverage

Status: future.

Period 2 should broaden vkmtl from core vertical slices into practical
application coverage. The long-term direction is that anything Metal and Vulkan
can reasonably do for graphics and compute should eventually have a vkmtl path,
while still preserving backend-neutral API boundaries.

Likely work:

- feature and limit queries
- more texture shapes, formats, mipmaps, arrays, cubemaps, and compressed
  formats where backend support exists
- richer render pass and synchronization coverage
- broader shader resource coverage, including dynamic offsets or equivalent
  portable patterns
- pipeline variants, cache behavior, and more complete validation
- multi-window or multi-surface workflows
- practical application examples that combine many subsystems

## Period 3: Stabilization And Parity

Status: future.

This period should happen after broader application coverage and real usage.
Likely work:

- move resource creation from `WindowContext` toward stable `Device` and `Queue`
  owners
- define feature and limit queries
- decide the native-handle escape hatch shape
- close portability gaps discovered by application examples
- add higher-level convenience layers only if they fit the library boundary

The rule for later periods is the same as before: grow from working vertical
slices and keep backend boundaries replaceable.
