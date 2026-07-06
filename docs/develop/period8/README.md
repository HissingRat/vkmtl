# Period 8: Pipeline / Object Cache

Status: in progress.

Goal: manage expensive native objects so real applications do not repeatedly
create equivalent shader modules, layouts, pipelines, and samplers.

Earlier periods may define local cache key requirements. Period 8 is where
those requirements are unified into a coherent runtime cache.

## Phase 1: Shader Module Cache

- Shader source hash.
- Compile option hash.
- Entry point hash.
- Backend target hash.

See `phase1.md`.

## Phase 2: Bind Group Layout Cache

- Group layout key.
- Binding visibility.
- Resource type.
- Dynamic offset flag.
- Array count.

See `phase2.md`.

## Phase 3: Pipeline Layout Cache

- Bind group layout list.
- Push constant or small constant layout.
- Shader stage visibility.

See `phase3.md`.

## Phase 4: Render Pipeline Cache

- Shader modules.
- Render target formats.
- Depth/stencil format.
- Raster state.
- Blend state.
- Vertex layout.
- Specialization constants.

See `phase4.md`.

## Phase 5: Compute Pipeline Cache

- Compute shader.
- Bind group layout.
- Specialization constants.

See `phase5.md`.

## Phase 6: Sampler Cache

- Sampler descriptor key.
- Avoid duplicate native sampler creation.
- Support explicit cache opt-out for advanced users.

See `phase6.md`.

## Phase 7: Cache Diagnostics

- Cache hit and miss statistics.
- Pipeline creation timing.
- Debug warnings for repeated equivalent object creation.

See `phase7.md`.
