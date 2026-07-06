# Period 7: Compute

Status: completed validation/API expansion, with advanced compute features and
example gallery growth gated for later backend/example work.

Goal: make compute capable of supporting real workflows independently of render
examples.

Compute features should reuse the same binding, synchronization, and cache
rules as render features. Compute-only examples should verify deterministic GPU
work and readback.

## Phase 1: Compute Dispatch Completeness

- Compute pipeline.
- Bind groups.
- Dispatch.
- Workgroup size queries.
- Dispatch size validation.

See `phase1.md`.

## Phase 2: Dispatch Indirect

- Indirect buffer.
- Indirect offset.
- Argument alignment.
- Backend capability gate.

See `phase2.md`.

## Phase 3: Storage Resource Rules

- Read-only storage buffers.
- Read-write storage buffers.
- Storage texture format limits.
- Storage texture access modes.
- Shader stage visibility.
- Resource hazard tracking.

See `phase3.md`.

## Phase 4: Atomics / Threadgroup Memory

- Document atomic support differences.
- Document threadgroup or shared memory usage.
- Provide portable shader patterns.
- Document backend limits.

See `phase4.md`.

## Phase 5: Compute Pipeline Cache Requirements

- Define compute pipeline cache keys.
- Include compute shader identity.
- Include bind group layouts.
- Include specialization constants.
- Include debug and release compile options.
- Leave shared cache implementation to Period 8.

See `phase5.md`.

## Phase 6: Compute Examples

- Image filter.
- Particle simulation.
- Prefix sum.
- GPU readback.
- Storage texture write.
- Buffer reduction.

See `phase6.md`.
