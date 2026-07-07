# Period 21: Binding And Shader Backend Completion

Status: planned after Period 20.

Goal: finish the native backend paths for binding and shader features that are
already represented in public descriptors.

Expected result: material systems can use dynamic offsets, resource arrays,
constants, and specialization without flattening every shader into custom
one-off bindings.

## Phase 1: Dynamic Buffer Offsets

- Lower dynamic buffer offsets through render and compute `setBindGroup(...)`.

See `phase1.md`.

## Phase 2: Resource Arrays

- Lower resource arrays for textures, samplers, and buffers.

See `phase2.md`.

## Phase 3: Descriptor Indexing And Argument Buffers

- Lower advanced binding models to Vulkan descriptor indexing and Metal argument
  buffers.

See `phase3.md`.

## Phase 4: Small Constants And Root Constants

- Lower small/root constants to push constants or Metal-visible equivalents.

See `phase4.md`.

## Phase 5: Shader Specialization

- Lower shader specialization constants to Vulkan and Metal pipeline creation.

See `phase5.md`.

## Phase 6: Binding Backend Validation

- Add tests, docs, and example coverage for completed binding backend paths.

See `phase6.md`.
