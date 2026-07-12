# Period 46 Closeout

Status: complete.

Implementation evidence commit:
`8023539505ecc47f21ce0dc271d924459ece166e`.

## Delivered

- Replaced occlusion placeholders with native Vulkan query pools and Metal
  Boolean visibility storage. The portable result is zero for no visible
  samples and nonzero for visibility; exact sample counts are not claimed.
- Added native timestamp writes, CPU readback, and GPU resolve on both backends
  behind their complete executable gates. Logical fallback remains distinct,
  and native results are raw ticks rather than calibrated durations.
- Kept pipeline statistics and device-specific counter breadth closed because
  the current one-`u64` result shape cannot represent them exactly.
- Added Metal vertex, fragment, and compute function-constant specialization
  by stable numeric ID for `bool`, `i32`, `u32`, and `f32` values.
- Enforced one write per query slot after reset, exact pass/query association,
  same-runtime command resources, pending producer/resolve lifetimes, and
  copy-destination usage for resolves.
- Updated the public API, capability, compatibility, semantic inventory,
  protocol ledger, gap routing, and backend validation matrices.

## Public Compatibility

The guarded surface counts remain root 68, `Device` 34 methods,
`WindowContext` 10 methods, and 35 opaque runtime handles. The default-null
`RenderPassDescriptor.occlusion_query_set` field preserves existing pass
literals. `QueryBackendFailure` expands the public `QueryError`, so Period 46
targets `v0.2.0`; exhaustive error switches need one new arm.

## Validation

- `zig fmt --check build.zig src examples tools tests/package_consumer`
- `zig build run-api-guard`: 68/34/10/35 passed.
- `zig build run-semantic-inventory-check`: 86 feature fields, 55 family IDs,
  101 Metal semantics, 78 protocols, and 75 routed gaps passed.
- `zig build test --summary all`: 590/590 tests passed.
- `zig build --summary all`: 54/54 steps passed.
- `zig build -Dvulkan --summary all`: 54/54 steps passed.
- `zig build probe-build`
- `git diff --check`

## Physical Metal Evidence

On 2026-07-12, the clean implementation commit above passed
`scripts/ci/run_gpu_smoke.sh metal artifacts/period46-metal` on macOS 15.7.3
and an Apple M4 Pro:

- native occlusion returned `visible=1` and `empty=0` twice;
- CPU readback and GPU resolve agreed;
- reset/reuse passed;
- the numeric-ID specialization regression produced the expected non-black
  pixel with `max_channel_delta=0`;
- the smoke bundle recorded `smoke_status=passed`.

That device did not expose the complete draw/dispatch/blit timestamp sampling
set. It correctly reported `logical_sequence`; this proves the capability gate,
not native Metal timestamp execution.

## Evidence Boundary And Next Work

Vulkan query lowering has focused deterministic tests, source inspection, API
validation, and a full forced-Vulkan build. A physical Vulkan query rerun is
useful follow-up evidence but was not a Period 46 closure prerequisite, and no
such run is claimed here. Native timestamp execution likewise still needs a
device that exposes the complete backend gate. Timestamp calibration, exact
occlusion counts, pipeline statistics, and advanced Metal counters remain
routed to Period 54.

Period 47 is next: common resource, format, render, compute, and reflection
breadth.
