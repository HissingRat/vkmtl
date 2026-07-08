# Period 24: Resource And Transfer Utility Completion

Status: completed resource utility validation slice.

Goal: finish practical resource utilities needed by tools, texture pipelines,
streaming systems, and asset upload paths.

Expected result: applications need fewer app-side workarounds for common texture,
buffer, mipmap, and memory-management operations.

## Phase 1: Automatic Mipmap Generation

- Lower full-texture mipmap generation through Vulkan and Metal blit paths.

See `phase1.md`.

## Phase 2: Fill Buffer Fallbacks

- Support non-4-byte-aligned fills on Vulkan through fallback paths.

See `phase2.md`.

## Phase 3: Broader Texture Copy Coverage

- Expand texture copy format, dimension, and layer coverage.

See `phase3.md`.

## Phase 4: Sampler Border Color

- Lower sampler border colors where supported.

See `phase4.md`.

## Phase 5: Heaps And Transient Allocation

- Add heap planning/reservation and transient allocation diagnostics. Native
  heap-backed resource creation is deferred to Period 29 Phase 5.

See `phase5.md`.

## Phase 6: Resource Utility Validation

- Add tests and docs for resource utility backend paths.

See `phase6.md`.
