# Phase 6: Sampler Cache

Phase 6 defines sampler cache identity and opt-out policy.

## First Slice

- Add a sampler cache-key descriptor.
- Reuse existing sampler descriptor validation.
- Add an explicit cache policy so advanced users can opt out.

## Current Limits

- `SamplerCacheKeyDescriptor` wraps `SamplerDescriptor` and an
  `ObjectCachePolicy`.
- `ObjectCachePolicy.mode = .disabled` opts out of reuse and diagnostics;
  `.diagnostics_only` records diagnostics without requesting reuse.
- Native sampler reuse is not implemented yet.
