# Period 37: Memory, Heaps, And Residency

Status: planned after Period36.

Goal: add production memory behavior: heap-backed allocation, aliasing,
memory-budget reporting, pressure handling, and real sparse/tiled residency
stress coverage.

## Expected Result

After Period37, vkmtl should be able to allocate resources from explicit memory
heaps where supported, validate aliasing and transient resource reuse, report
memory budget/pressure information, and run long-lived sparse/tiled residency
workloads without relying on descriptor-only scaffolding.

## Phase Plan

### Phase 1: Heap And Allocator Contract

- Define heap descriptors, resource placement, and heap-backed allocation
  ownership.
- Map Vulkan device memory and Metal heap behavior through capability gates.
- Keep ordinary resource creation working without explicit heaps.

### Phase 2: Aliasing And Transient Resource Validation

- Define aliasing eligibility for buffers and textures.
- Validate lifetime, usage, and hazard requirements for aliasing.
- Add transient allocator diagnostics for frame-overlap use.

### Phase 3: Memory Budget And Pressure Reporting

- Query memory budget and heap pressure where backends expose it.
- Provide fallback reports when native budget data is unavailable.
- Add diagnostics suitable for issue reports and pressure-test logs.

### Phase 4: Native Sparse/Tiled Residency Updates

- Lower sparse/tiled page mapping to Vulkan sparse binding where supported.
- Lower tiled residency behavior to Metal APIs where supported.
- Keep unsupported residency paths typed and capability-gated.

### Phase 5: Long-Running Residency And Churn Tests

- Add residency stress tests with many commit/uncommit cycles.
- Add resource churn tests for heap and transient allocations.
- Record memory pressure behavior in backend test matrix.

## Acceptance

- Heap-backed resources work on supported backends.
- Aliasing validation catches invalid reuse.
- Sparse/tiled examples move from descriptor probes to real residency work
  where supported.
- Long-run tests produce deterministic pass/fail diagnostics.
