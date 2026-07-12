# Period 46: Native Queries, Counters, And Specialization

Status: in progress.

Goal: replace the Period 45 query placeholders with real capability-gated GPU
results and finish Metal function-constant specialization. The public changes
are the default-null `RenderPassDescriptor.occlusion_query_set` association
required to bind exact Metal visibility storage and the precise
`QueryBackendFailure` error for native readback failures. They add no root name,
owner method, or runtime handle. The field preserves existing render-pass
literals; the error-set expansion targets `v0.2.0` because exhaustive switches
need one new arm.

## Phase Plan

### Phase 1: Native Query ABI And Lifetime

- Give runtime query sets backend-private native storage.
- Preserve logical timestamps only on fallback/test-only paths.
- Keep result availability, reset, readback, and resolve semantics explicit.
- Do not report native GPU time merely because logical timestamp ordering
  exists.

See `phase1.md`.

### Phase 2: Vulkan Query Pools

- Create/reset/destroy Vulkan query pools.
- Encode occlusion begin/end and timestamp writes.
- Read or copy native 64-bit query results with truthful not-ready behavior.
- Keep pipeline statistics unsupported until its multi-counter result shape is
  representable without ambiguity.

See `phase2.md`.

### Phase 3: Metal Visibility And Counter Sampling

- Bind an explicit occlusion query set to each render pass.
- Allocate per-pass visibility storage and copy used slots into the query set.
- Use timestamp counter sample buffers only when the device reports the
  required sampling points and common timestamp counter set.
- Resolve/copy native results and keep unsupported counter families closed.

See `phase3.md`.

### Phase 4: Metal Function Constants

- Translate vkmtl specialization values into `MTLFunctionConstantValues`.
- Specialize vertex, fragment, and compute entry points before pipeline
  creation.
- Open `shader_specialization` only after both Vulkan and Metal executable paths
  are present.

See `phase4.md`.

### Phase 5: Evidence And Closeout

- Add deterministic backend mapping and runtime tests.
- Add a physical-GPU query smoke path where ordinary CI cannot prove results.
- Update the semantic ledger, gap routing, capability docs, and parity matrix.

See `phase5.md`.

## Acceptance

- A usable occlusion query returns a native GPU visibility result, never the
  former constant placeholder. Zero means no samples passed; any nonzero value
  means visible, and its magnitude is intentionally not a portable sample
  count.
- Native timestamp query sets report `native_gpu`; logical fallback query sets
  report `logical_sequence`.
- `native_gpu` values are backend-native ticks. Period 46 does not claim a GPU
  duration because the portable API does not yet expose Vulkan timestamp
  period or Metal timestamp frequency calibration; `gpu_duration_available`
  remains false.
- Unsupported pipeline statistics and unavailable Metal counters fail with
  existing typed errors before invalid native work.
- Metal specialization constants affect native function creation.
- API guard, semantic inventory, all tests, default build, and forced-Vulkan
  build pass.
