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

## Result

- `runtime_cache_schema_version`, `RuntimeCacheManifestDescriptor`,
  `RuntimeCacheCompatibility`, `RuntimeCachePlanDescriptor`, and
  `RuntimeCachePlan` define the persistent runtime cache manifest layer.
- `Device.planRuntimeCache(...)` and `WindowContext.planRuntimeCache(...)`
  produce artifact directory and manifest paths and classify cache entries as
  compatible, missing, stale schema, backend mismatch, source hash mismatch, or
  toolchain mismatch.
- The existing inspectable Slang artifact layout remains unchanged.
- Automatic manifest file read/write in the shader compiler is deferred to
  Period 29 Phase 5 so it can land with the native cache and escape-hatch
  closure.
