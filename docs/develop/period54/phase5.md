# Period 54 Phase 5: Evidence And Inventory Closeout

Status: complete.

## Physical Query Evidence

The offscreen regression selects `.counting` whenever the device reports
`occlusion_counting_queries`. On an Apple M4 Pro with Metal API Validation
enabled, both the initial query and the reset/reuse query reported:

```text
native occlusion regression ok mode=counting visible=61170 empty=0
```

The same run completed transfer and compute readback, query reset/reuse, and
the render pixel comparison with `max_channel_delta=0`. This establishes that
the Metal path returns exact visible sample counts instead of a Boolean
non-zero placeholder.

The Vulkan lowering has focused coverage for `.precise_bit`, physical-device
feature propagation, logical-device enablement, and forced Vulkan builds.
Physical Vulkan counting evidence remains a device-matrix follow-up and is not
claimed by this closeout.

## Inventory Closeout

- All 111 Metal semantic ledger rows now have a terminal support state.
- The exactly-once gap routing contains zero incomplete rows.
- The compact native inventory contains 72 IDs and maps the new counting
  capability to `QRY-05`.
- The public inventory records 85 diagnostics declarations and 534 facade
  declarations without changing the root or owner allowlists.
- Roadmap, checklist, backend/validation matrices, English and Chinese API and
  usage docs, migration guidance, and changelog match the executable surface.

## Validation

- `zig fmt --check build.zig src examples tools tests/package_consumer`
- `git diff --check`
- `zig build test --summary all`: 630/630 tests passed.
- `zig build run-api-guard`: root 69, `Device` 34, `WindowContext` 10,
  `HeadlessContext` 6, runtime handles 37.
- `zig build run-semantic-inventory-check`: 93 device features, 72 compact
  inventory IDs, 111 Metal units, 78 protocols, zero routed gaps.
- `zig build --summary all`: 58/58 steps passed.
- `zig build -Dvulkan --summary all`: 58/58 steps passed.
- `scripts/ci/run_package_smoke.sh`: 10/10 steps and 1/1 consumer tests
  passed.
- `clang -std=c99 -fsyntax-only src/backend/metal/bridge_stub.c` passed.
- `MTL_DEBUG_LAYER=1 VKMTL_BACKEND=metal zig build run-pixel-regression`
  passed with Metal API Validation enabled, counting `61170` visible samples
  and `0` empty samples in both query lifetimes.
