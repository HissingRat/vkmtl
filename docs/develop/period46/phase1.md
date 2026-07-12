# Phase 1: Native Query ABI And Lifetime

Status: in progress.

## Decisions

- `QuerySet` keeps its public opaque representation and gains only
  backend-private implementation state.
- `RenderPassDescriptor.occlusion_query_set` is a default-null association in
  the existing `render` lane. It is required because Metal chooses the
  visibility result buffer before creating the render encoder. Existing pass
  descriptors remain source-compatible, and no root export or owner method is
  added.
- `beginOcclusionQuery` and `endOcclusionQuery` accept only the exact query set
  bound by the pass descriptor; mismatches reuse the existing
  `InvalidRenderCommandEncoderState` error.
- Encoding marks a slot pending; native readback reports `QueryNotReady` until
  the driver makes the result available.
- Reset is legal only before a set is first encoded or after the producer's
  synchronous `commit()` returns. Ending the encoder is not enough: from the
  first write/begin through command-buffer completion, reset and destruction
  are forbidden. Runtime safety builds reject a reset/deinit while native
  writer work is still pending.
- A slot may be written once after reset. A second begin/write before reset is
  rejected rather than relying on backend-specific undefined reuse behavior.
- Native query resources are destroyed with `QuerySet`; callers must keep the
  query set alive until encoded command buffers complete.
- Direct `readback` is a CPU operation after submission. `resolveQuerySet`
  records a GPU copy into the caller's destination buffer after a nonblocking
  native readiness preflight. With the current one-encoder/synchronous command
  model, the producer command buffer must have committed before a separate
  resolve command buffer is recorded; otherwise resolve returns
  `QueryNotReady` instead of recording an unfulfillable wait.
- Native timestamp readback and resolve preserve the same backend-native tick
  units. Until a later calibrated period/frequency contract exists, callers
  may compare ordering but must not convert a delta to duration;
  `ProfilingPlan.gpu_duration_available` stays false.
- A destination for `resolveQuerySet` must have `copy_destination` usage.
- Native driver/readback failures use `QueryBackendFailure`; they are never
  reported as `QueryNotReady`.
- `QueryBackendFailure` extends `QueryError` only for the newly executable
  native readback path; no previously supported native failure result existed
  to preserve. Invalid encoder/pass association reuses an existing command
  error to avoid a second public error-set expansion. The new backend-failure
  tag is called out in the changelog and migration guide. Because exhaustive
  downstream `QueryError` switches need one new arm, Period 46 targets
  `v0.2.0`, not a `v0.1.x` patch.
