# Period 20: Common Render Backend Completion

Status: active.

Goal: take render-pipeline and render-pass API shapes that already exist and
finish their Vulkan / Metal native backend lowering without rewriting the public
API. This period is a second-pass backend completion period, not a rewrite of
Period 5.

Period 5 remains the historical API-shape and validation period. Period 20
tracks the follow-up native backend work for the same render concepts.

## Phase 1: Blend State Lowering

- Lower single color attachment blend state to Vulkan and Metal.
- Keep independent blend tied to the MRT phase.

See `phase1.md`.

## Phase 2: Raster And Depth-Bias Backend State

- Lower pipeline depth-bias state.
- Add wireframe / line fill mode where supported.
- Keep conservative rasterization capability-gated.

See `phase2.md`.

## Phase 3: Vertex Instance Step Rate

- Lower non-default instance step rates to Vulkan and Metal.
- Keep vertex descriptor validation backend-neutral.

See `phase3.md`.

## Phase 4: Stencil Backend State

- Lower stencil render-pass attachment state.
- Lower stencil pipeline state and reference rules.

See `phase4.md`.

## Phase 5: Multiple Render Targets

- Lower multiple color attachments in render pass and pipeline state.
- Revisit independent blend once MRT is available.

See `phase5.md`.

## Phase 6: Render Backend Validation

- Add focused tests, examples, and backend matrix notes for the completed render
  backend slices.

See `phase6.md`.
