# Period 25: Platform, Surface, And Interop Completion

Status: planned after Period 24.

Goal: make vkmtl fit cleanly inside larger native applications, tools, media
pipelines, and multi-window environments.

Expected result: vkmtl can manage multiple surfaces, cooperate with external
resources, and expose explicit native interop hooks without leaking backend
types into ordinary portable APIs.

## Phase 1: Multi-Surface Runtime

- Support multiple presentation surfaces from one device.

See `phase1.md`.

## Phase 2: Present Modes And Frame Pacing

- Add vsync/present-mode configuration and frame pacing baseline.

See `phase2.md`.

## Phase 3: External Memory And Textures

- Lower external memory and texture import.

See `phase3.md`.

## Phase 4: External Semaphores And Shared Events

- Lower cross-API synchronization primitives.

See `phase4.md`.

## Phase 5: Native Command Insertion

- Add intentional native command insertion escape hatches.

See `phase5.md`.

## Phase 6: Interop Examples And Matrix

- Add examples and backend matrix coverage for interop features.

See `phase6.md`.
