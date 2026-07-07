# Phase 3: Persistent Runtime Cache

Phase 3 persists selected runtime artifacts across runs.

## Scope

- Define cache versioning.
- Store driver cache and binary archive data.
- Keep shader compile artifacts inspectable.
- Handle stale or incompatible cache entries gracefully.

## Validation

- Add cold/warm cache tests where possible.
- Document cache directory behavior.
