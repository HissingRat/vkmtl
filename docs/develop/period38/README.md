# Period 38: Resource Tables And Pipeline Persistence

Status: planned after Period37.

Goal: prove large resource tables and persistent pipeline caches under scale
instead of only descriptor-shape validation.

## Expected Result

After Period38, descriptor indexing and Metal argument buffers should survive
large table pressure tests, update-after-bind semantics should be documented and
validated, and pipeline/cache artifacts should persist across runs with clear
invalidation rules.

## Phase Plan

### Phase 1: Descriptor Indexing Pressure Tests

- Add Vulkan descriptor indexing stress cases with large sampled-texture and
  buffer tables.
- Validate partially-bound and update-after-bind behavior where supported.
- Keep limits visible through capability reports.

### Phase 2: Metal Argument Buffer Pressure Tests

- Add Metal argument buffer stress cases with equivalent resource tables.
- Validate argument-buffer tier behavior and fallback reasons.
- Keep table layout derivation backend-neutral.

### Phase 3: Update-After-Bind And Dynamic Binding Semantics

- Define public rules for updating tables while work is in flight.
- Validate dynamic offsets and small constant update paths.
- Add backend-specific unsupported diagnostics.

### Phase 4: Vulkan Pipeline Cache And Library Persistence

- Persist Vulkan pipeline cache/library artifacts where supported.
- Define cache key inputs and compatibility checks.
- Validate stale-cache recovery.

### Phase 5: Metal Binary Archive Persistence

- Persist Metal binary archives where supported.
- Define archive invalidation for shader/source/backend changes.
- Validate fallback behavior when archives are unavailable.

### Phase 6: Cache Compatibility Validation

- Add tests for shader hash, entry point, reflection, backend, and format
  changes invalidating cached artifacts.
- Document inspectable artifact locations and production cache policy.

## Acceptance

- Large resource-table tests pass or report precise unsupported features.
- Pipeline/cache artifacts persist across runs where supported.
- Cache invalidation behavior is deterministic and documented.
