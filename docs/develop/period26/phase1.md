# Phase 1: Native Object Reuse

Phase 1 turns cache-key descriptors into real reuse.

## Scope

- Reuse shader modules by source and entry identity.
- Reuse bind group layouts and pipeline layouts.
- Reuse render and compute pipeline objects.
- Reuse sampler states.
- Keep opt-out policies honored.

## Validation

- Add cache hit/miss tests.
- Add diagnostics for equivalent recreations.
