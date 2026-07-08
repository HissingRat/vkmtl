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

## Result

- Cacheable descriptors now carry a defaulted `cache_policy`:
  `ShaderModuleDescriptor`, `BindGroupLayoutDescriptor`,
  `RenderPipelineDescriptor`, `ComputePipelineDescriptor`, and
  `SamplerDescriptor`.
- The runtime `ResourceTracker` has a lookup/finish path that records cache
  hits, equivalent recreations, diagnostics-only bypasses, disabled diagnostics,
  and creation cost through `ObjectCacheDiagnostics`.
- Shader modules, bind group layouts, render pipelines, compute pipelines, and
  samplers all feed this lookup path.
- Period 26 Phase 1 intentionally does not share backend-native handles yet.
  Lifetime-safe native object pools are deferred to Period 29 Phase 5, where
  native handle ownership and advanced escape hatches are closed together.
