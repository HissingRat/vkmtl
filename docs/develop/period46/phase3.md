# Phase 3: Metal Visibility And Counter Sampling

Status: planned.

## Mapping

- A render pass explicitly binds one optional occlusion query set through
  `RenderPassDescriptor.occlusion_query_set`.
- Each bound pass uses a scratch visibility buffer because older Metal render
  passes reset visibility storage at encoder creation. `endEncoding` copies
  only the slots used by that pass into the query set's canonical shared
  result buffer.
- Begin/end select `MTLVisibilityResultModeBoolean` and then disable visibility
  writes. Zero means occluded; any nonzero value means visible.
- Direct readback reads the completed canonical shared range; GPU resolve
  copies that range through the blit encoder.
- Timestamp query sets use `MTLCounterSampleBuffer` with the common timestamp
  counter set only when the device reports the required encoder sampling
  points.
- Counter resolve uses a blit encoder and a shared result buffer. Unavailable
  sampling points leave native GPU timestamps unsupported.
- Native timestamps are advertised only when the common timestamp counter and
  draw-, dispatch-, and blit-boundary sampling are all available. Partial
  encoder support keeps the whole portable timestamp path on
  `logical_sequence`.

Metal pipeline statistics remain unsupported because Metal counter sets are
device-specific and do not provide the current portable three-flag contract on
every supported device.
