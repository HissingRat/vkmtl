# Phase 1: Shader Module Cache

Phase 1 defines shader module object-cache identity without changing the
existing runtime shader artifact cache.

## First Slice

- Add a shader module cache-key descriptor.
- Include source identity, compile option identity, entry point identity, and
  backend.
- Keep SPIR-V/MSL/reflection artifact caching untouched.

## Current Limits

- Runtime shader artifacts are cached on disk already.
- Native shader module handle reuse is key/diagnostic first in this period.
