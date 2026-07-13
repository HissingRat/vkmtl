# Period 49: Native Heaps, Memory Telemetry, And Attachment Residency

Status: complete.

Progress: Phases 1-5 complete.

Goal: replace heap and memory-budget planning with native execution where the
portable contract is exact, expose a truthful hardware-memoryless attachment
lane, and close sparse/residency source rows without enabling planning-only
features.

## Routed Rows

| Row | Period 49 target | Explicit boundary |
| --- | --- | --- |
| `MTL-DEV-005` | Native budget and current-allocation telemetry | Fallback estimates remain labeled fallback. |
| `MTL-RES-009` | Native placement heaps and heap-backed buffers/textures | Purgeability is not part of the portable contract. |
| `MTL-RES-010` | Precise unsupported decision for explicit residency sets | Ordinary heap ownership does not imply residency-set execution. |
| `MTL-RES-011` | Keep resource-state sparse mapping closed until operations identify native resources | Planning records are not command execution. |
| `MTL-RES-013` | Capability-gated hardware memoryless attachments on Metal | Vulkan lazily allocated memory cannot guarantee no physical backing. |
| `MTL-RES-014` | Preserve sparse/tiled planning while executable resource/page APIs remain closed | Native feature queries do not open usable features. |
| `MTL-RES-017` | Preserve default portable cache behavior | Explicit write-combined/cache-policy selection is unsupported. |
| `MTL-XFR-008` | Precise unsupported decision for content optimization hints | No cross-backend observable correctness semantic exists. |

## Phase Plan

1. Semantic splits, public allocation, and lifetime rules.
2. Native placement heaps and heap-backed resources.
3. Native memory budget/current-allocation telemetry.
4. Hardware memoryless attachments and sparse/residency closure.
5. Physical evidence, inventories, and closeout.

See `phase1.md` through `phase5.md`.
The final implementation and evidence boundary is recorded in `closeout.md`.

## Compatibility Boundary

No root alias, `Device` method, `WindowContext` method, or runtime-handle name
is added. Existing `Heap` gains specialized allocation/query methods in the
`resource` domain. `ResourceStorageMode`, `DeviceFeatures`, and typed errors may
grow for the memoryless lane; those additions target `v0.2.0`.

## Acceptance

- Heap features open only when a native heap and heap-backed buffer/texture
  path execute.
- Heap resources retain the heap allocation lifetime and must be destroyed
  before their heap.
- Native memory reports use driver/device values rather than caller estimates.
- Memoryless means a hardware tile-memory guarantee, not the existing
  transient lifetime hint.
- Sparse/tiled/residency planning never appears as executable support.
