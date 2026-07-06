# Phase 5: Compute Pipeline Cache Requirements

Phase 5 defines cache-key inputs without implementing the shared object cache.

## First Slice

- Include compute shader identity and entry point in cache keys.
- Include bind group layouts and specialization constants.
- Keep the actual cache implementation in Period 8.

## Current Limits

- Runtime shader artifact caching already exists.
- Native compute pipeline object caching is still future work.
