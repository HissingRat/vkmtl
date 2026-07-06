# Phase 3: Reflection Schema Stabilization

Phase 3 stabilizes the vkmtl reflection schema used by runtime-generated JSON
and manual reflection overrides.

## First Slice

- Add a schema version constant.
- Add schema metadata to core reflection descriptors.
- Accept current JSON artifacts without a version for compatibility.
- Include schema version in newly generated runtime reflection JSON.

## Current Limits

- Reflection remains intentionally small: stage, entry point, vertex inputs, and
  bind groups.
