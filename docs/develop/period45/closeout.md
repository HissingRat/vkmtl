# Period 45 Closeout

Status: complete.

## Delivered

- Corrected the false-positive usable occlusion capability without changing
  the public declaration surface.
- Preserved Metal/Vulkan native occlusion availability separately from usable
  vkmtl execution.
- Audited 99 stable Metal semantic units against the macOS 26.2 SDK baseline.
- Mapped all 78 concrete Metal protocols to ledger IDs.
- Mapped all 86 current `DeviceFeatures` fields to the feature-family native
  semantic inventory.
- Classified each Metal/Vulkan result with the approved exact, unsupported, or
  incomplete vocabulary and separate evidence class.
- Routed all 77 incomplete semantics exactly once to Periods 46-54.
- Added `zig build run-semantic-inventory-check` and included the same check in
  `zig build test`.

## Truthfulness Result

`occlusion_queries` remains a public capability field, but both usable backend
reports keep it false. Vulkan query pools and Metal visibility result buffers
remain native facts. `Device.makeQuerySet(.occlusion)` returns the existing
typed `UnsupportedOcclusionQueries` until Period 46 adds real GPU result
lowering.

No other public declaration, root name, owner method, or opaque runtime handle
changed. The API guard baseline remains root 68, `Device` 34,
`WindowContext` 10, and runtime handles 35.

## Validation

- `zig fmt --check build.zig src examples tools tests/package_consumer`
- `zig build run-api-guard`: 68/34/10/35 passed.
- `zig build run-semantic-inventory-check`: 86 feature fields, 54 family IDs,
  99 Metal semantics, 78 protocols, and 77 routed gaps passed.
- `zig build test --summary all`: 583/583 tests passed.
- `zig build --summary all`: 54/54 steps passed.
- `zig build -Dvulkan --summary all`: 54/54 steps passed.
- `git diff --check`

## Follow-Up Order

1. Period 46: native queries, counters, and Metal specialization.
2. Period 47: common resource, format, render, and compute breadth.
3. Period 48: native synchronization, queues, and presentation timing.
4. Period 49: heaps, residency, sparse resources, and memoryless allocation.
5. Period 50: binding tables, indirect commands, and pipeline persistence.
6. Period 51: advanced rasterization and geometry.
7. Period 52: ray tracing breadth.
8. Period 53: external interop, Metal I/O, and device topology.
9. Period 54: Metal 4 command model, pipeline datasets, tensor, and ML.

The exact routing is in `gap-routing.tsv`; rationale and acceptance boundaries
are in `gap-backlog.md`.
