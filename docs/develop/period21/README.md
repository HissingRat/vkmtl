# Period 21: Binding And Shader Backend Completion

Status: completed as a binding backend validation slice.

Goal: finish the native backend paths for binding and shader features that are
already represented in public descriptors.

Expected result: material systems can use dynamic offsets and first-slice
resource arrays without flattening every binding into unique slots. Advanced
binding layouts, root-constant pipeline compatibility, and specialization cache
identity are represented and validated, while bindless table updates, command
constant writes, immutable/static samplers, dynamic buffer arrays, and native
specialization lowering remain explicit Period 22 backend work.

## Phase 1: Dynamic Buffer Offsets

- Lower dynamic buffer offsets through render and compute `setBindGroup(...)`.

See `phase1.md`.

## Phase 2: Resource Arrays

- Lower resource arrays for textures, samplers, and buffers.

See `phase2.md`.

## Phase 3: Descriptor Indexing And Argument Buffers

- Snapshot advanced binding ranges into backend-aware layout metadata and keep
  bindless table allocation, updates, and command binding deferred to Period 22.

See `phase3.md`.

## Phase 4: Small Constants And Root Constants

- Add root-constant layout compatibility to pipeline descriptors and keep
  command writes/native lowering deferred to Period 22.

See `phase4.md`.

## Phase 5: Shader Specialization

- Verify specialization identity in pipeline fingerprints and keep native
  specialization lowering deferred to Period 22.

See `phase5.md`.

## Phase 6: Binding Backend Validation

- Add tests, docs, and example coverage for completed binding backend paths.

See `phase6.md`.
