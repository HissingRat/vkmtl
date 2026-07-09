# Phase 2: Compute Example Gallery

Phase 2 defines the compute example gallery beyond the deterministic
`compute_readback` first slice.

## First Slice

- Record planned compute examples for image filters, particles, prefix sums,
  readback, and storage texture coverage.
- Keep `examples/compute_readback` as the implemented deterministic example.
- Validate gallery metadata so docs do not drift from the intended cases.

## Current Limits

- `compute_readback` is the only implemented compute gallery case.
- Planned gallery cases are recorded in `tools/development_matrix.zig` and
  validated by `zig build test`.
- Additional compute examples may be planned before their full backend and
  visual implementations are added.
