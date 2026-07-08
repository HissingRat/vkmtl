# Period 25: Platform, Surface, And Interop Completion

Status: completed platform/interop validation slice.

Goal: make vkmtl fit cleanly inside larger native applications, tools, media
pipelines, and multi-window environments.

Expected result: vkmtl can manage multiple surfaces, cooperate with external
resources, and expose explicit native interop hooks without leaking backend
types into ordinary portable APIs.

## Phase 1: Multi-Surface Runtime

- Add device-owned surface registries and multi-surface runtime state.

See `phase1.md`.

## Phase 2: Present Modes And Frame Pacing

- Add present-mode resolution and frame pacing diagnostics.

See `phase2.md`.

## Phase 3: External Memory And Textures

- Add external memory, buffer, and texture runtime wrappers.

See `phase3.md`.

## Phase 4: External Semaphores And Shared Events

- Add external semaphore/event wrappers and commit-time validation.

See `phase4.md`.

## Phase 5: Native Command Insertion

- Add explicit encoder-level native command insertion hooks.

See `phase5.md`.

## Phase 6: Interop Examples And Matrix

- Add examples and backend matrix coverage for interop features.

See `phase6.md`.

Deferred native lowering:

- Native multi-surface presentation, native present-mode queries, native
  external memory/texture import, external sync wait/signal, and command
  encoder native handle views are deferred to Period 29 Phase 5.
