# Phase 6: Compute Examples

Phase 6 records compute example coverage and future gallery targets.

## First Slice

- Keep `examples/compute_readback` as the deterministic first compute example.
- Document future image-filter, particle, prefix-sum, reduction, and storage
  texture write examples.
- Keep examples using public vkmtl APIs only.

## Current Limits

- The current runnable compute example focuses on deterministic readback.
- Current coverage:
  - `examples/compute_readback`: storage texture write, storage buffer write,
    copy readback, reflection-derived layout, deterministic byte validation.
- Future gallery targets:
  - image filter: sampled input texture plus storage output texture.
  - particle simulation: storage buffer update across frames.
  - prefix sum: multi-pass buffer compute and synchronization.
  - buffer reduction: deterministic scalar readback.
  - storage texture write: visual and readback variants.
- Broader example gallery coverage belongs to Period 9.
