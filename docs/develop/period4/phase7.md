# Phase 7: Shader Specialization

Phase 7 defines shader specialization data and cache-key rules.

## First Slice

- Add specialization value descriptors.
- Add specialization descriptor validation.
- Include specialization inputs in shader library cache-key requirements.
- Keep backend specialization lowering gated for later pipeline work.

## Current Limits

- Runtime shader compilation still compiles the source without specialization
  variants.
